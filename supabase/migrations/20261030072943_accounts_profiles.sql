-- Account and viewing-profile data. These new tables are RLS-protected while
-- the legacy device sync path remains in service until its separate cutover.
-- Anonymous Auth users are authenticated callers.
create schema if not exists app_private;
create schema if not exists extensions;
create extension if not exists pgcrypto with schema extensions;
do $$
begin
  if not exists (
    select 1 from pg_extension e join pg_namespace n on n.oid=e.extnamespace
    where e.extname='pgcrypto' and n.nspname='extensions'
  ) then
    raise exception 'pgcrypto must be installed in extensions schema';
  end if;
end;
$$;

create table public.accounts (
  id uuid primary key references auth.users(id) on delete cascade,
  username text,
  default_profile_id uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint accounts_username_format check (
    username is null or username ~ '^[a-z0-9_]{3,24}$'
  )
);
create unique index accounts_username_unique on public.accounts (username)
  where username is not null;

create table public.profiles (
  id uuid primary key default gen_random_uuid(),
  account_id uuid not null references public.accounts(id) on delete cascade,
  name text not null,
  avatar_kind text not null default 'pack',
  avatar_value text not null,
  has_pin boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (account_id, id),
  constraint profiles_name_format check (
    name = btrim(name) and char_length(name) between 1 and 32
  ),
  constraint profiles_avatar_kind check (avatar_kind in ('pack', 'url')),
  constraint profiles_avatar_value check (
    (avatar_kind = 'pack' and avatar_value ~ '^nova_avatar_0[1-9]_[a-z]+$')
    or (avatar_kind = 'url' and avatar_value ~ '^https://[^[:space:]]+$'
      and char_length(avatar_value) <= 2048)
  )
);
create index profiles_account_order on public.profiles(account_id, created_at, id);
alter table public.accounts add constraint accounts_default_profile_fk
  foreign key (id, default_profile_id)
  references public.profiles(account_id, id)
  deferrable initially deferred;

create table public.account_buckets (
  account_id uuid not null references public.accounts(id) on delete cascade,
  bucket text not null check (bucket in ('settings', 'addons')),
  data jsonb not null default '{}'::jsonb check (jsonb_typeof(data) = 'object'),
  rev bigint not null default 1 check (rev > 0),
  updated_at timestamptz not null default now(),
  primary key (account_id, bucket)
);
create table public.profile_buckets (
  profile_id uuid not null,
  account_id uuid not null,
  bucket text not null check (bucket in ('lists', 'watchlist', 'history', 'library')),
  data jsonb not null default '{}'::jsonb check (jsonb_typeof(data) = 'object'),
  rev bigint not null default 1 check (rev > 0),
  updated_at timestamptz not null default now(),
  primary key (profile_id, bucket),
  foreign key (account_id, profile_id)
    references public.profiles(account_id, id) on delete cascade
);
create index profile_buckets_account_idx on public.profile_buckets(account_id, profile_id);

create table app_private.profile_pin_verifiers (
  profile_id uuid primary key references public.profiles(id) on delete cascade,
  verifier text not null,
  failures integer not null default 0 check (failures >= 0),
  locked_until timestamptz
);
create table app_private.auth_login_limits (
  key_hash text primary key,
  window_started_at timestamptz not null,
  attempts integer not null check (attempts >= 0)
);
create table app_private.simkl_poll_limits (
  key_hash text primary key,
  last_poll timestamptz not null
);

alter table public.accounts enable row level security;
alter table public.profiles enable row level security;
alter table public.account_buckets enable row level security;
alter table public.profile_buckets enable row level security;
alter table app_private.profile_pin_verifiers enable row level security;
alter table app_private.auth_login_limits enable row level security;
alter table app_private.simkl_poll_limits enable row level security;

revoke all on public.accounts, public.profiles, public.account_buckets,
  public.profile_buckets from anon, authenticated;
grant select on public.accounts, public.profiles, public.account_buckets,
  public.profile_buckets to authenticated;
revoke all on schema app_private from public, anon, authenticated;
revoke all on all tables in schema app_private from public, anon, authenticated;

create policy accounts_read_own on public.accounts for select to authenticated
  using ((select auth.uid()) = id);
create policy profiles_read_own on public.profiles for select to authenticated
  using ((select auth.uid()) = account_id);
create policy account_buckets_read_own on public.account_buckets
  for select to authenticated using ((select auth.uid()) = account_id);
create policy profile_buckets_read_own on public.profile_buckets
  for select to authenticated using ((select auth.uid()) = account_id);

-- The trigger creates a private account shell. The app must create a first
-- profile before entering the main shell; a brand-new Auth user briefly has 0.
create or replace function app_private.create_account_for_auth_user()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into public.accounts(id) values (new.id);
  return new;
end;
$$;
revoke all on function app_private.create_account_for_auth_user() from public;
create trigger create_nova_account after insert on auth.users
  for each row execute function app_private.create_account_for_auth_user();
insert into public.accounts(id)
select id from auth.users
on conflict(id) do nothing;

create or replace function public.set_username(p_username text)
returns text language plpgsql security definer set search_path = '' as $$
declare
  v_username text := lower(btrim(p_username));
  v_user auth.users%rowtype;
begin
  select * into v_user from auth.users where id = (select auth.uid());
  if not found or v_user.is_anonymous or v_user.email_confirmed_at is null then
    raise exception 'account_not_verified' using errcode = '42501';
  end if;
  if v_username is null or v_username !~ '^[a-z0-9_]{3,24}$' then
    raise exception 'invalid_username' using errcode = '22023';
  end if;
  update public.accounts set username = v_username, updated_at = now()
    where id = v_user.id;
  return v_username;
exception when unique_violation then
  raise exception 'username_unavailable' using errcode = '23505';
end;
$$;

create or replace function public.create_profile(
  p_name text, p_avatar_kind text, p_avatar_value text
) returns public.profiles language plpgsql security definer set search_path = '' as $$
declare
  v_user uuid := (select auth.uid());
  v_profile public.profiles;
begin
  if v_user is null then raise exception 'not_authenticated' using errcode='42501'; end if;
  perform 1 from public.accounts where id = v_user for update;
  if not found then raise exception 'account_missing' using errcode='42501'; end if;
  if (select count(*) from public.profiles where account_id = v_user) >= 5 then
    raise exception 'profile_limit' using errcode='23514';
  end if;
  insert into public.profiles(account_id,name,avatar_kind,avatar_value)
  values (v_user,btrim(p_name),p_avatar_kind,p_avatar_value)
  returning * into v_profile;
  return v_profile;
end;
$$;

create or replace function public.update_profile(
  p_profile_id uuid, p_name text, p_avatar_kind text, p_avatar_value text
) returns public.profiles language plpgsql security definer set search_path = '' as $$
declare v_profile public.profiles;
begin
  update public.profiles set name = btrim(p_name), avatar_kind = p_avatar_kind,
    avatar_value = p_avatar_value, updated_at = now()
  where id = p_profile_id and account_id = (select auth.uid())
  returning * into v_profile;
  if not found then raise exception 'profile_missing' using errcode='42501'; end if;
  return v_profile;
end;
$$;

create or replace function public.delete_profile(p_profile_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare v_user uuid := (select auth.uid());
begin
  if v_user is null then raise exception 'not_authenticated' using errcode='42501'; end if;
  perform 1 from public.accounts where id = v_user for update;
  if not exists(select 1 from public.profiles where id=p_profile_id and account_id=v_user)
  then raise exception 'profile_missing' using errcode='42501'; end if;
  if (select count(*) from public.profiles where account_id=v_user) <= 1
  then raise exception 'last_profile' using errcode='23514'; end if;
  update public.accounts set default_profile_id=null, updated_at=now()
    where id=v_user and default_profile_id=p_profile_id;
  delete from public.profiles where id=p_profile_id and account_id=v_user;
end;
$$;

create or replace function public.set_default_profile(p_profile_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare v_user uuid := (select auth.uid());
begin
  if v_user is null then raise exception 'not_authenticated' using errcode='42501'; end if;
  if p_profile_id is not null and not exists(
    select 1 from public.profiles where id=p_profile_id and account_id=v_user
  ) then raise exception 'profile_missing' using errcode='42501'; end if;
  update public.accounts set default_profile_id=p_profile_id, updated_at=now()
    where id=v_user;
end;
$$;

-- These functions use optimistic revisions. A caller that sees 40001 reloads
-- the remote bucket and merges before retrying; failed writes never overwrite.
create or replace function public.save_account_bucket(
  p_bucket text, p_data jsonb, p_expected_rev bigint
) returns table(rev bigint, updated_at timestamptz)
language plpgsql security definer set search_path = '' as $$
declare
  v_user uuid := (select auth.uid());
  v_rev bigint;
begin
  if v_user is null then raise exception 'not_authenticated' using errcode='42501'; end if;
  if p_bucket is null or p_bucket not in ('settings','addons')
    or p_data is null or jsonb_typeof(p_data) <> 'object'
    or octet_length(p_data::text) > 2097152
    or p_expected_rev is null or p_expected_rev < 0 then
    raise exception 'invalid_bucket' using errcode='22023';
  end if;
  perform 1 from public.accounts where id=v_user for update;
  if not found then raise exception 'account_missing' using errcode='42501'; end if;
  select b.rev into v_rev from public.account_buckets b
    where b.account_id=v_user and b.bucket=p_bucket;
  if coalesce(v_rev,0) <> p_expected_rev then
    raise exception 'revision_conflict' using errcode='40001';
  end if;
  insert into public.account_buckets(account_id,bucket,data,rev,updated_at)
  values(v_user,p_bucket,p_data,coalesce(v_rev,0)+1,now())
  on conflict(account_id,bucket) do update set
    data=excluded.data,rev=excluded.rev,updated_at=excluded.updated_at;
  return query select b.rev,b.updated_at from public.account_buckets b
    where b.account_id=v_user and b.bucket=p_bucket;
end;
$$;

create or replace function public.save_profile_bucket(
  p_profile_id uuid, p_bucket text, p_data jsonb, p_expected_rev bigint
) returns table(rev bigint, updated_at timestamptz)
language plpgsql security definer set search_path = '' as $$
declare
  v_user uuid := (select auth.uid());
  v_rev bigint;
begin
  if v_user is null then raise exception 'not_authenticated' using errcode='42501'; end if;
  if p_bucket is null or p_bucket not in ('lists','watchlist','history','library')
    or p_data is null or jsonb_typeof(p_data) <> 'object'
    or octet_length(p_data::text) > 2097152
    or p_expected_rev is null or p_expected_rev < 0 then
    raise exception 'invalid_bucket' using errcode='22023';
  end if;
  perform 1 from public.accounts where id=v_user for update;
  if not exists(select 1 from public.profiles where id=p_profile_id and account_id=v_user)
  then raise exception 'profile_missing' using errcode='42501'; end if;
  select b.rev into v_rev from public.profile_buckets b
    where b.profile_id=p_profile_id and b.bucket=p_bucket;
  if coalesce(v_rev,0) <> p_expected_rev then
    raise exception 'revision_conflict' using errcode='40001';
  end if;
  insert into public.profile_buckets(profile_id,account_id,bucket,data,rev,updated_at)
  values(p_profile_id,v_user,p_bucket,p_data,coalesce(v_rev,0)+1,now())
  on conflict(profile_id,bucket) do update set
    data=excluded.data,rev=excluded.rev,updated_at=excluded.updated_at;
  return query select b.rev,b.updated_at from public.profile_buckets b
    where b.profile_id=p_profile_id and b.bucket=p_bucket;
end;
$$;

-- PINs are an app access gate. The owner Auth session still has access to all
-- profile rows; a PIN is not an independent database authorization identity.
create or replace function public.verify_profile_pin(p_profile_id uuid, p_pin text)
returns boolean language plpgsql security definer set search_path = '' as $$
declare v_pin app_private.profile_pin_verifiers;
begin
  if not exists(select 1 from public.profiles
    where id=p_profile_id and account_id=(select auth.uid())) then
    return false;
  end if;
  select * into v_pin from app_private.profile_pin_verifiers
    where profile_id=p_profile_id for update;
  if not found or (v_pin.locked_until is not null and v_pin.locked_until > now())
  then return false; end if;
  if p_pin is not null and extensions.crypt(p_pin,v_pin.verifier)=v_pin.verifier then
    update app_private.profile_pin_verifiers set failures=0,locked_until=null
      where profile_id=p_profile_id;
    return true;
  end if;
  update app_private.profile_pin_verifiers set
    failures = case when failures >= 4 then 0 else failures+1 end,
    locked_until = case when failures >= 4 then now()+interval '15 minutes'
      else null end where profile_id=p_profile_id;
  return false;
end;
$$;

create or replace function public.set_profile_pin(
  p_profile_id uuid, p_old_pin text, p_new_pin text
) returns boolean language plpgsql security definer set search_path = '' as $$
declare v_has_pin boolean;
begin
  select has_pin into v_has_pin from public.profiles
    where id=p_profile_id and account_id=(select auth.uid());
  if not found then raise exception 'profile_missing' using errcode='42501'; end if;
  if v_has_pin and not public.verify_profile_pin(p_profile_id,p_old_pin) then
    -- Return rather than raise: a failed verification increments the durable
    -- attempt counter, which an exception would roll back.
    return false;
  end if;
  if p_new_pin is not null and p_new_pin !~ '^[0-9]{6}$' then
    raise exception 'invalid_pin' using errcode='22023';
  end if;
  if p_new_pin is null then
    delete from app_private.profile_pin_verifiers where profile_id=p_profile_id;
  else
    insert into app_private.profile_pin_verifiers(profile_id,verifier)
      values(p_profile_id,extensions.crypt(p_new_pin,extensions.gen_salt('bf',12)))
    on conflict(profile_id) do update set verifier=excluded.verifier,
      failures=0,locked_until=null;
  end if;
  update public.profiles set has_pin=(p_new_pin is not null),updated_at=now()
    where id=p_profile_id;
  return true;
end;
$$;

-- Called only by the server-side auth-login Edge Function with HMAC digests,
-- never a raw identifier or address. Both known and unknown users consume it.
create or replace function public.consume_auth_login_attempt(
  p_key_hash text, p_limit integer, p_window_seconds integer
) returns boolean language plpgsql security definer set search_path = '' as $$
declare v_attempts integer;
begin
  if p_key_hash !~ '^[0-9a-f]{64}$' or p_limit not between 1 and 100
    or p_window_seconds not between 60 and 3600 then return false; end if;
  insert into app_private.auth_login_limits(key_hash,window_started_at,attempts)
    values(p_key_hash,now(),1)
  on conflict(key_hash) do update set
    window_started_at = case when app_private.auth_login_limits.window_started_at
      < now()-make_interval(secs => p_window_seconds) then now()
      else app_private.auth_login_limits.window_started_at end,
    attempts = case when app_private.auth_login_limits.window_started_at
      < now()-make_interval(secs => p_window_seconds) then 1
      else app_private.auth_login_limits.attempts+1 end
  returning attempts into v_attempts;
  return v_attempts <= p_limit;
end;
$$;

-- The Simkl device grant has a provider-specified polling interval. This
-- server-only gate prevents concurrent mobile clients from hammering it.
create or replace function public.consume_simkl_poll(
  p_key_hash text, p_min_seconds integer
) returns boolean language plpgsql security definer set search_path = '' as $$
declare v_allowed boolean;
begin
  if p_key_hash is null or p_key_hash !~ '^[0-9a-f]{64}$'
    or p_min_seconds not between 3 and 60 then return false; end if;
  insert into app_private.simkl_poll_limits(key_hash,last_poll)
    values(p_key_hash,now())
  on conflict(key_hash) do update set last_poll=excluded.last_poll
    where app_private.simkl_poll_limits.last_poll <=
      now()-make_interval(secs => p_min_seconds)
  returning true into v_allowed;
  return coalesce(v_allowed,false);
end;
$$;

revoke all on function public.set_username(text),
  public.create_profile(text,text,text), public.update_profile(uuid,text,text,text),
  public.delete_profile(uuid), public.set_default_profile(uuid),
  public.save_account_bucket(text,jsonb,bigint),
  public.save_profile_bucket(uuid,text,jsonb,bigint),
  public.verify_profile_pin(uuid,text), public.set_profile_pin(uuid,text,text),
  public.consume_auth_login_attempt(text,integer,integer),
  public.consume_simkl_poll(text,integer) from public, anon;
grant execute on function public.set_username(text),
  public.create_profile(text,text,text), public.update_profile(uuid,text,text,text),
  public.delete_profile(uuid), public.set_default_profile(uuid),
  public.save_account_bucket(text,jsonb,bigint),
  public.save_profile_bucket(uuid,text,jsonb,bigint),
  public.verify_profile_pin(uuid,text), public.set_profile_pin(uuid,text,text)
  to authenticated;
revoke all on function public.consume_auth_login_attempt(text,integer,integer)
  from authenticated;
revoke all on function public.consume_simkl_poll(text,integer)
  from authenticated;
grant execute on function public.consume_auth_login_attempt(text,integer,integer)
  to service_role;
grant execute on function public.consume_simkl_poll(text,integer)
  to service_role;

-- Supabase Storage: pack content is immutable to mobile callers. Its stable
-- public URLs are safe; private profile data is never stored in this bucket.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('nova-profile-avatars','nova-profile-avatars',true,1048576,array['image/png','image/svg+xml'])
on conflict(id) do nothing;
create policy nova_avatar_pack_read on storage.objects for select to anon,authenticated
  using (bucket_id='nova-profile-avatars');
