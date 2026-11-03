-- Shared collections are account-scoped. The existing profile `lists` bucket
-- remains private; shared writes are individual, versioned server operations.
create table public.shared_collections (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.accounts(id) on delete cascade,
  name text not null,
  description text not null default '',
  version bigint not null default 1 check (version > 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint shared_collections_name_valid check (
    name = btrim(name) and char_length(name) between 1 and 80
    and name !~ '[[:cntrl:]]'
  ),
  constraint shared_collections_description_valid check (
    description = btrim(description) and char_length(description) <= 500
    and description !~ '[[:cntrl:]]'
  )
);
create index shared_collections_owner_idx on public.shared_collections(owner_id);

create table public.shared_collection_members (
  collection_id uuid not null references public.shared_collections(id) on delete cascade,
  account_id uuid not null references public.accounts(id) on delete cascade,
  role text not null check (role in ('owner', 'member')),
  can_view boolean not null default true,
  can_add boolean not null default true,
  can_edit boolean not null default false,
  can_delete boolean not null default false,
  can_manage_members boolean not null default false,
  can_manage_invites boolean not null default false,
  joined_at timestamptz not null default now(),
  primary key (collection_id, account_id),
  constraint shared_collection_member_permissions_valid check (
    (can_view or not (can_add or can_edit or can_delete
      or can_manage_members or can_manage_invites))
    and (role <> 'owner' or (can_view and can_add and can_edit
      and can_delete and can_manage_members and can_manage_invites))
  )
);
create unique index shared_collection_one_owner_idx
  on public.shared_collection_members(collection_id) where role = 'owner';
create index shared_collection_members_account_idx
  on public.shared_collection_members(account_id, collection_id);

create table public.shared_collection_items (
  id uuid primary key default gen_random_uuid(),
  collection_id uuid not null references public.shared_collections(id) on delete cascade,
  media_type text not null check (media_type in ('series', 'anime', 'movie')),
  media_id text,
  title text not null,
  poster_url text,
  -- Keep the original contributor ID if their account is later deleted.
  added_by uuid not null,
  added_by_name text not null,
  version bigint not null default 1 check (version > 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint shared_collection_item_title_valid check (
    title = btrim(title) and char_length(title) between 1 and 200
    and title !~ '[[:cntrl:]]'
  ),
  constraint shared_collection_item_media_id_valid check (
    media_id is null or (media_id = btrim(media_id)
      and char_length(media_id) between 1 and 256
      and media_id !~ '[[:cntrl:]]')
  ),
  constraint shared_collection_item_poster_valid check (
    poster_url is null or (char_length(poster_url) <= 2048
      and poster_url ~ '^https://[^[:space:]]+$')
  ),
  constraint shared_collection_item_contributor_valid check (
    char_length(added_by_name) between 1 and 32
    and added_by_name !~ '[[:cntrl:]]'
  )
);
create index shared_collection_items_order_idx
  on public.shared_collection_items(collection_id, created_at desc, id);
create unique index shared_collection_item_media_unique_idx
  on public.shared_collection_items(collection_id, media_type, media_id)
  where media_id is not null;

-- The raw token is private so owners can view the current link. Public clients
-- may only use a token through the join RPC; 32 random bytes make guessing
-- infeasible. Rotation replaces it immediately.
create table app_private.shared_collection_invites (
  collection_id uuid primary key references public.shared_collections(id) on delete cascade,
  token text not null unique check (token ~ '^[0-9a-f]{64}$'),
  enabled boolean not null default true,
  updated_at timestamptz not null default now()
);

-- A per-account invalidation row covers item/member/collection deletion too:
-- a removed user cannot receive a deleted collection's RLS-protected row.
create table public.shared_collection_sync (
  account_id uuid primary key references public.accounts(id) on delete cascade,
  revision bigint not null default 1 check (revision > 0),
  updated_at timestamptz not null default now()
);

alter table public.shared_collections enable row level security;
alter table public.shared_collection_members enable row level security;
alter table public.shared_collection_items enable row level security;
alter table public.shared_collection_sync enable row level security;
alter table app_private.shared_collection_invites enable row level security;

revoke all on public.shared_collections, public.shared_collection_members,
  public.shared_collection_items, public.shared_collection_sync
  from public, anon, authenticated;
grant select on public.shared_collections, public.shared_collection_members,
  public.shared_collection_items, public.shared_collection_sync
  to authenticated;
revoke all on app_private.shared_collection_invites from public, anon, authenticated;

-- This helper's effective database role owns the membership table and bypasses
-- its RLS. It derives the identity from the JWT, never a caller-supplied UUID.
create function public.shared_collection_can(p_collection_id uuid, p_permission text)
returns boolean language plpgsql stable security definer set search_path = '' as $$
declare
  v_user uuid := (select auth.uid());
  v_member public.shared_collection_members;
begin
  if v_user is null or p_collection_id is null then return false; end if;
  if exists(select 1 from public.shared_collections
    where id = p_collection_id and owner_id = v_user) then return true; end if;
  select * into v_member from public.shared_collection_members
    where collection_id = p_collection_id and account_id = v_user;
  if not found or not v_member.can_view then return false; end if;
  return case p_permission
    when 'view' then v_member.can_view
    when 'add' then v_member.can_add
    when 'edit' then v_member.can_edit
    when 'delete' then v_member.can_delete
    when 'manage_members' then v_member.can_manage_members
    when 'manage_invites' then v_member.can_manage_invites
    else false end;
end;
$$;

create policy shared_collections_read_member on public.shared_collections
  for select to authenticated using (public.shared_collection_can(id, 'view'));
create policy shared_collection_members_read_member on public.shared_collection_members
  for select to authenticated
  using (public.shared_collection_can(collection_id, 'view'));
create policy shared_collection_items_read_member on public.shared_collection_items
  for select to authenticated
  using (public.shared_collection_can(collection_id, 'view'));
create policy shared_collection_sync_read_own on public.shared_collection_sync
  for select to authenticated using (account_id = (select auth.uid()));

create function app_private.bump_shared_collection_sync(p_collection_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
begin
  insert into public.shared_collection_sync(account_id, revision, updated_at)
  select m.account_id, 1, now() from public.shared_collection_members m
    join public.accounts a on a.id = m.account_id
    where m.collection_id = p_collection_id
    order by m.account_id
  on conflict(account_id) do update set
    revision = public.shared_collection_sync.revision + 1,
    updated_at = excluded.updated_at;
end;
$$;

-- Also notify remaining members when a collection disappears through an Auth
-- account cascade, outside the owner-facing delete RPC.
create function app_private.notify_shared_collection_delete()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  perform app_private.bump_shared_collection_sync(old.id);
  return old;
end;
$$;
create trigger shared_collection_before_delete
  before delete on public.shared_collections
  for each row execute function app_private.notify_shared_collection_delete();

create function public.create_shared_collection(
  p_name text, p_description text default ''
) returns public.shared_collections
language plpgsql security definer set search_path = '' as $$
declare
  v_user uuid := (select auth.uid());
  v_collection public.shared_collections;
begin
  if v_user is null or not exists(select 1 from public.accounts where id = v_user)
  then raise exception 'not_authenticated' using errcode = '42501'; end if;
  insert into public.shared_collections(owner_id, name, description)
    values(v_user, btrim(p_name), btrim(coalesce(p_description, '')))
    returning * into v_collection;
  insert into public.shared_collection_members(
    collection_id, account_id, role, can_view, can_add, can_edit, can_delete,
    can_manage_members, can_manage_invites
  ) values(v_collection.id, v_user, 'owner', true, true, true, true, true, true);
  perform app_private.bump_shared_collection_sync(v_collection.id);
  return v_collection;
end;
$$;

create function public.update_shared_collection(
  p_collection_id uuid, p_name text, p_description text, p_expected_version bigint
) returns public.shared_collections
language plpgsql security definer set search_path = '' as $$
declare
  v_collection public.shared_collections;
begin
  select * into v_collection from public.shared_collections
    where id = p_collection_id for update;
  if not found or v_collection.owner_id <> (select auth.uid())
  then raise exception 'collection_forbidden' using errcode = '42501'; end if;
  if p_expected_version is null or v_collection.version <> p_expected_version
  then raise exception 'revision_conflict' using errcode = '40001'; end if;
  update public.shared_collections set name = btrim(p_name),
    description = btrim(coalesce(p_description, '')),
    version = version + 1, updated_at = now()
    where id = p_collection_id returning * into v_collection;
  perform app_private.bump_shared_collection_sync(p_collection_id);
  return v_collection;
end;
$$;

create function public.delete_shared_collection(p_collection_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
declare v_owner uuid;
begin
  select owner_id into v_owner from public.shared_collections
    where id = p_collection_id for update;
  if not found or v_owner <> (select auth.uid())
  then raise exception 'collection_forbidden' using errcode = '42501'; end if;
  delete from public.shared_collections where id = p_collection_id;
end;
$$;

create function public.read_shared_collection_invite(p_collection_id uuid)
returns text language plpgsql security definer set search_path = '' as $$
declare v_token text;
begin
  if not public.shared_collection_can(p_collection_id, 'manage_invites')
  then raise exception 'invite_forbidden' using errcode = '42501'; end if;
  select token into v_token from app_private.shared_collection_invites
    where collection_id = p_collection_id and enabled;
  return v_token;
end;
$$;

create function public.rotate_shared_collection_invite(p_collection_id uuid)
returns text language plpgsql security definer set search_path = '' as $$
declare v_token text;
begin
  perform 1 from public.shared_collections where id = p_collection_id for update;
  if not found or not public.shared_collection_can(p_collection_id, 'manage_invites')
  then raise exception 'invite_forbidden' using errcode = '42501'; end if;
  v_token := encode(extensions.gen_random_bytes(32), 'hex');
  insert into app_private.shared_collection_invites(collection_id, token, enabled)
    values(p_collection_id, v_token, true)
  on conflict(collection_id) do update set
    token = excluded.token, enabled = true, updated_at = now();
  perform app_private.bump_shared_collection_sync(p_collection_id);
  return v_token;
end;
$$;

create function public.disable_shared_collection_invite(p_collection_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
begin
  perform 1 from public.shared_collections where id = p_collection_id for update;
  if not found or not public.shared_collection_can(p_collection_id, 'manage_invites')
  then raise exception 'invite_forbidden' using errcode = '42501'; end if;
  update app_private.shared_collection_invites
    set enabled = false, updated_at = now() where collection_id = p_collection_id;
  perform app_private.bump_shared_collection_sync(p_collection_id);
end;
$$;

create function public.join_shared_collection(p_token text)
returns uuid language plpgsql security definer set search_path = '' as $$
declare
  v_user uuid := (select auth.uid());
  v_collection_id uuid;
begin
  if v_user is null or not exists(select 1 from public.accounts where id = v_user)
  then raise exception 'not_authenticated' using errcode = '42501'; end if;
  if p_token is null or p_token !~ '^[0-9a-f]{64}$'
  then raise exception 'invalid_invite' using errcode = '22023'; end if;
  select collection_id into v_collection_id
    from app_private.shared_collection_invites
    where token = p_token and enabled;
  if not found then raise exception 'invalid_invite' using errcode = '22023'; end if;
  perform 1 from public.shared_collections where id = v_collection_id for update;
  if not found or not exists(
    select 1 from app_private.shared_collection_invites
      where collection_id = v_collection_id and token = p_token and enabled
  ) then raise exception 'invalid_invite' using errcode = '22023'; end if;
  insert into public.shared_collection_members(collection_id, account_id, role)
    values(v_collection_id, v_user, 'member') on conflict do nothing;
  perform app_private.bump_shared_collection_sync(v_collection_id);
  return v_collection_id;
end;
$$;

create function public.shared_collection_member_details(p_collection_id uuid)
returns table(
  account_id uuid, username text, role text, can_view boolean, can_add boolean,
  can_edit boolean, can_delete boolean, can_manage_members boolean,
  can_manage_invites boolean, joined_at timestamptz
) language plpgsql stable security definer set search_path = '' as $$
begin
  if not public.shared_collection_can(p_collection_id, 'view')
  then raise exception 'collection_forbidden' using errcode = '42501'; end if;
  return query select m.account_id, a.username, m.role, m.can_view,
    m.can_add, m.can_edit, m.can_delete, m.can_manage_members,
    m.can_manage_invites, m.joined_at
  from public.shared_collection_members m
  left join public.accounts a on a.id = m.account_id
  where m.collection_id = p_collection_id
  order by (m.role = 'owner') desc, m.joined_at, m.account_id;
end;
$$;

create function public.set_shared_collection_member_permissions(
  p_collection_id uuid, p_account_id uuid, p_can_view boolean,
  p_can_add boolean, p_can_edit boolean, p_can_delete boolean,
  p_can_manage_members boolean, p_can_manage_invites boolean
) returns public.shared_collection_members
language plpgsql security definer set search_path = '' as $$
declare
  v_user uuid := (select auth.uid());
  v_owner uuid;
  v_actor public.shared_collection_members;
  v_target public.shared_collection_members;
begin
  select owner_id into v_owner from public.shared_collections
    where id = p_collection_id for update;
  if not found or v_user is null or p_account_id is null
    or not public.shared_collection_can(p_collection_id, 'manage_members')
  then raise exception 'members_forbidden' using errcode = '42501'; end if;
  if p_account_id = v_owner or p_account_id = v_user
  then raise exception 'owner_or_self_immutable' using errcode = '42501'; end if;
  if p_can_view is null or p_can_add is null or p_can_edit is null
    or p_can_delete is null or p_can_manage_members is null
    or p_can_manage_invites is null
    or (not p_can_view and (p_can_add or p_can_edit or p_can_delete
      or p_can_manage_members or p_can_manage_invites))
  then raise exception 'invalid_permissions' using errcode = '22023'; end if;
  -- Delegated managers cannot grant a permission they do not hold themselves.
  if v_user <> v_owner then
    select * into v_actor from public.shared_collection_members
      where collection_id = p_collection_id and account_id = v_user;
    if (p_can_add and not v_actor.can_add)
      or (p_can_edit and not v_actor.can_edit)
      or (p_can_delete and not v_actor.can_delete)
      or (p_can_manage_invites and not v_actor.can_manage_invites)
    then raise exception 'permission_escalation' using errcode = '42501'; end if;
  end if;
  select * into v_target from public.shared_collection_members
    where collection_id = p_collection_id and account_id = p_account_id
    for update;
  if not found or v_target.role = 'owner'
  then raise exception 'member_missing' using errcode = '42501'; end if;
  update public.shared_collection_members set
    can_view = p_can_view, can_add = p_can_add, can_edit = p_can_edit,
    can_delete = p_can_delete, can_manage_members = p_can_manage_members,
    can_manage_invites = p_can_manage_invites
    where collection_id = p_collection_id and account_id = p_account_id
    returning * into v_target;
  perform app_private.bump_shared_collection_sync(p_collection_id);
  return v_target;
end;
$$;

create function public.remove_shared_collection_member(
  p_collection_id uuid, p_account_id uuid
) returns void language plpgsql security definer set search_path = '' as $$
declare
  v_user uuid := (select auth.uid());
  v_owner uuid;
begin
  select owner_id into v_owner from public.shared_collections
    where id = p_collection_id for update;
  if not found or v_user is null or p_account_id = v_owner
  then raise exception 'members_forbidden' using errcode = '42501'; end if;
  if p_account_id <> v_user and
    not public.shared_collection_can(p_collection_id, 'manage_members')
  then raise exception 'members_forbidden' using errcode = '42501'; end if;
  if not exists(select 1 from public.shared_collection_members
    where collection_id = p_collection_id and account_id = p_account_id)
  then raise exception 'member_missing' using errcode = '42501'; end if;
  -- Bump before removal so the removed account receives an invalidation.
  perform app_private.bump_shared_collection_sync(p_collection_id);
  delete from public.shared_collection_members
    where collection_id = p_collection_id and account_id = p_account_id;
  -- A removed member may know the old token. Rotate it before commit so the
  -- removed account cannot immediately rejoin with the same link.
  if p_account_id <> v_user then
    update app_private.shared_collection_invites
      set token = encode(extensions.gen_random_bytes(32), 'hex'),
      updated_at = now()
      where collection_id = p_collection_id and enabled;
  end if;
end;
$$;

create function public.add_shared_collection_item(
  p_collection_id uuid, p_media_type text, p_title text,
  p_media_id text default null, p_poster_url text default null
) returns public.shared_collection_items
language plpgsql security definer set search_path = '' as $$
declare
  v_item public.shared_collection_items;
  v_added_by_name text;
begin
  perform 1 from public.shared_collections where id = p_collection_id for update;
  if not found or not public.shared_collection_can(p_collection_id, 'add')
  then raise exception 'items_forbidden' using errcode = '42501'; end if;
  select coalesce(username, 'Member') into v_added_by_name
    from public.accounts where id = (select auth.uid());
  insert into public.shared_collection_items(
    collection_id, media_type, title, media_id, poster_url, added_by,
    added_by_name
  ) values(
    p_collection_id, p_media_type, btrim(p_title), nullif(btrim(p_media_id), ''),
    nullif(btrim(p_poster_url), ''), (select auth.uid()), v_added_by_name
  ) returning * into v_item;
  perform app_private.bump_shared_collection_sync(p_collection_id);
  return v_item;
end;
$$;

create function public.update_shared_collection_item(
  p_item_id uuid, p_expected_version bigint, p_media_type text,
  p_title text, p_media_id text, p_poster_url text
) returns public.shared_collection_items
language plpgsql security definer set search_path = '' as $$
declare
  v_collection_id uuid;
  v_item public.shared_collection_items;
begin
  select collection_id into v_collection_id from public.shared_collection_items
    where id = p_item_id;
  if not found then raise exception 'items_forbidden' using errcode = '42501'; end if;
  perform 1 from public.shared_collections where id = v_collection_id for update;
  if not found or not public.shared_collection_can(v_collection_id, 'edit')
  then raise exception 'items_forbidden' using errcode = '42501'; end if;
  select * into v_item from public.shared_collection_items
    where id = p_item_id for update;
  if not found then raise exception 'items_forbidden' using errcode = '42501'; end if;
  if p_expected_version is null or v_item.version <> p_expected_version
  then raise exception 'revision_conflict' using errcode = '40001'; end if;
  update public.shared_collection_items set
    media_type = p_media_type, title = btrim(p_title),
    media_id = nullif(btrim(p_media_id), ''),
    poster_url = nullif(btrim(p_poster_url), ''),
    version = version + 1, updated_at = now()
    where id = p_item_id returning * into v_item;
  perform app_private.bump_shared_collection_sync(v_collection_id);
  return v_item;
end;
$$;

create function public.delete_shared_collection_item(
  p_item_id uuid, p_expected_version bigint
) returns void language plpgsql security definer set search_path = '' as $$
declare
  v_collection_id uuid;
  v_version bigint;
begin
  select collection_id into v_collection_id from public.shared_collection_items
    where id = p_item_id;
  if not found then raise exception 'items_forbidden' using errcode = '42501'; end if;
  perform 1 from public.shared_collections where id = v_collection_id for update;
  if not found or not public.shared_collection_can(v_collection_id, 'delete')
  then raise exception 'items_forbidden' using errcode = '42501'; end if;
  select version into v_version from public.shared_collection_items
    where id = p_item_id for update;
  if not found then raise exception 'items_forbidden' using errcode = '42501'; end if;
  if p_expected_version is null or v_version <> p_expected_version
  then raise exception 'revision_conflict' using errcode = '40001'; end if;
  delete from public.shared_collection_items where id = p_item_id;
  perform app_private.bump_shared_collection_sync(v_collection_id);
end;
$$;

-- Only the tiny account-specific invalidation row enters Realtime. Clients
-- refetch RLS-scoped tables after each revision, including removals/deletes.
alter publication supabase_realtime add table public.shared_collection_sync;

revoke all on function public.shared_collection_can(uuid,text),
  public.create_shared_collection(text,text),
  public.update_shared_collection(uuid,text,text,bigint),
  public.delete_shared_collection(uuid),
  public.read_shared_collection_invite(uuid),
  public.rotate_shared_collection_invite(uuid),
  public.disable_shared_collection_invite(uuid),
  public.join_shared_collection(text),
  public.shared_collection_member_details(uuid),
  public.set_shared_collection_member_permissions(
    uuid,uuid,boolean,boolean,boolean,boolean,boolean,boolean),
  public.remove_shared_collection_member(uuid,uuid),
  public.add_shared_collection_item(uuid,text,text,text,text),
  public.update_shared_collection_item(uuid,bigint,text,text,text,text),
  public.delete_shared_collection_item(uuid,bigint)
  from public, anon;
grant execute on function public.shared_collection_can(uuid,text),
  public.create_shared_collection(text,text),
  public.update_shared_collection(uuid,text,text,bigint),
  public.delete_shared_collection(uuid),
  public.read_shared_collection_invite(uuid),
  public.rotate_shared_collection_invite(uuid),
  public.disable_shared_collection_invite(uuid),
  public.join_shared_collection(text),
  public.shared_collection_member_details(uuid),
  public.set_shared_collection_member_permissions(
    uuid,uuid,boolean,boolean,boolean,boolean,boolean,boolean),
  public.remove_shared_collection_member(uuid,uuid),
  public.add_shared_collection_item(uuid,text,text,text,text),
  public.update_shared_collection_item(uuid,bigint,text,text,text,text),
  public.delete_shared_collection_item(uuid,bigint)
  to authenticated;
revoke all on function app_private.bump_shared_collection_sync(uuid)
  from public, anon, authenticated;
revoke all on function app_private.notify_shared_collection_delete()
  from public, anon, authenticated;
