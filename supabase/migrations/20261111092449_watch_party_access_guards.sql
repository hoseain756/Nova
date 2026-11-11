-- Explicit default deny on private tables documents the RPC-only boundary.
create policy nova_party_rooms_no_direct_access on app_private.nova_party_rooms
  for all to anon,authenticated using(false) with check(false);
create policy nova_party_members_no_direct_access on app_private.nova_party_members
  for all to anon,authenticated using(false) with check(false);
create policy nova_party_messages_no_direct_access on app_private.nova_party_messages
  for all to anon,authenticated using(false) with check(false);
create policy nova_party_limits_no_direct_access on app_private.nova_party_limits
  for all to anon,authenticated using(false) with check(false);
create or replace function app_private.nova_party_receive(p_topic text)
returns boolean language sql stable security definer set search_path = '' as $$
  select coalesce((select (auth.jwt()->>'is_anonymous')::boolean),true)=false and exists(
    select 1 from app_private.nova_party_members m
    join app_private.nova_party_rooms r on r.id=m.room_id
    where p_topic='nova-party:'||m.id::text and m.account_id=(select auth.uid())
      and m.left_at is null and r.ended_at is null and r.expires_at>now());
$$;
alter policy nova_party_receive on realtime.messages to authenticated
  using (coalesce((select (auth.jwt()->>'is_anonymous')::boolean),true)=false
    and extension='broadcast' and app_private.nova_party_receive(realtime.topic()));
