-- Delegated managers may save or revoke an existing permission they do not
-- personally hold. Only a false -> true transition is a new grant.
create or replace function public.set_shared_collection_member_permissions(
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

  select * into v_target from public.shared_collection_members
    where collection_id = p_collection_id and account_id = p_account_id
    for update;
  if not found or v_target.role = 'owner'
  then raise exception 'member_missing' using errcode = '42501'; end if;

  if v_user <> v_owner then
    select * into v_actor from public.shared_collection_members
      where collection_id = p_collection_id and account_id = v_user;
    -- The collection lock serializes permission changes. Compare the locked
    -- target state, so unchanged true flags do not count as grants.
    if (p_can_view and not v_target.can_view and not v_actor.can_view)
      or (p_can_add and not v_target.can_add and not v_actor.can_add)
      or (p_can_edit and not v_target.can_edit and not v_actor.can_edit)
      or (p_can_delete and not v_target.can_delete and not v_actor.can_delete)
      or (p_can_manage_members and not v_target.can_manage_members
        and not v_actor.can_manage_members)
      or (p_can_manage_invites and not v_target.can_manage_invites
        and not v_actor.can_manage_invites)
    then raise exception 'permission_escalation' using errcode = '42501'; end if;
  end if;

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

revoke all on function public.set_shared_collection_member_permissions(
  uuid,uuid,boolean,boolean,boolean,boolean,boolean,boolean)
  from public, anon;
grant execute on function public.set_shared_collection_member_permissions(
  uuid,uuid,boolean,boolean,boolean,boolean,boolean,boolean)
  to authenticated;
