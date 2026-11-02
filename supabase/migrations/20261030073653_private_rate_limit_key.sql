-- A database-held HMAC key keeps rate-limit identifiers opaque without an
-- extra Edge secret. The mobile client and Edge source never contain the key.
create table app_private.rate_limit_hmac_key (
  singleton boolean primary key default true check (singleton),
  secret bytea not null check (octet_length(secret) = 32)
);
alter table app_private.rate_limit_hmac_key enable row level security;
revoke all on app_private.rate_limit_hmac_key from public, anon, authenticated;
insert into app_private.rate_limit_hmac_key(singleton,secret)
values(true,extensions.gen_random_bytes(32));

create or replace function public.consume_auth_login_attempt_secure(
  p_scope text, p_limit integer, p_window_seconds integer
) returns boolean language plpgsql security definer set search_path = '' as $$
declare
  v_secret bytea;
  v_hash text;
begin
  if p_scope is null or length(p_scope) not between 1 and 512
  then return false; end if;
  select secret into v_secret from app_private.rate_limit_hmac_key
    where singleton=true;
  if not found then return false; end if;
  v_hash := encode(extensions.hmac(convert_to(p_scope,'UTF8'),v_secret,'sha256'),'hex');
  return public.consume_auth_login_attempt(v_hash,p_limit,p_window_seconds);
end;
$$;

create or replace function public.consume_simkl_poll_secure(
  p_scope text, p_min_seconds integer
) returns boolean language plpgsql security definer set search_path = '' as $$
declare
  v_secret bytea;
  v_hash text;
begin
  if p_scope is null or length(p_scope) not between 1 and 512
  then return false; end if;
  select secret into v_secret from app_private.rate_limit_hmac_key
    where singleton=true;
  if not found then return false; end if;
  v_hash := encode(extensions.hmac(convert_to(p_scope,'UTF8'),v_secret,'sha256'),'hex');
  return public.consume_simkl_poll(v_hash,p_min_seconds);
end;
$$;

revoke all on function public.consume_auth_login_attempt_secure(text,integer,integer),
  public.consume_simkl_poll_secure(text,integer) from public, anon, authenticated;
grant execute on function public.consume_auth_login_attempt_secure(text,integer,integer),
  public.consume_simkl_poll_secure(text,integer) to service_role;
