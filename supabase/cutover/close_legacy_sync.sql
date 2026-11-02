-- DO NOT APPLY until the new account/profile client has passed production
-- cutover checks and all needed old device buckets have been imported/backed
-- up. This is intentionally outside supabase/migrations so db push cannot
-- run it accidentally. It preserves legacy rows for audited recovery.
begin;
revoke all on table public.noor_devices, public.noor_sync
  from public, anon, authenticated, noor_app;
alter table public.noor_devices enable row level security;
alter table public.noor_sync enable row level security;
alter role noor_app nologin password null;
commit;

-- Existing pooler sessions can retain their already-established privileges
-- until disconnected. Run this only at the approved cutover window.
select pg_terminate_backend(pid)
from pg_stat_activity
where usename = 'noor_app' and pid <> pg_backend_pid();

-- Expected: RLS on, no anon/authenticated/noor_app table privileges,
-- noor_app cannot log in, old row counts unchanged, no noor_app sessions.
select c.relname, c.relrowsecurity,
  has_table_privilege('anon',c.oid,'SELECT') as anon_select,
  has_table_privilege('authenticated',c.oid,'SELECT') as authenticated_select,
  has_table_privilege('noor_app',c.oid,'SELECT') as legacy_role_select
from pg_class c join pg_namespace n on n.oid=c.relnamespace
where n.nspname='public' and c.relname in ('noor_devices','noor_sync');
select rolname,rolcanlogin from pg_roles where rolname='noor_app';
select 'noor_devices' as source,count(*) from public.noor_devices
union all select 'noor_sync',count(*) from public.noor_sync;
select count(*) as remaining_legacy_sessions from pg_stat_activity
where usename='noor_app';
