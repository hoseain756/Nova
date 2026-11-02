-- Optional PIN and default selection are committed with the new profile.
-- A failure in any step rolls back the whole RPC, including the profile row.
drop function public.create_profile(text,text,text);

create function public.create_profile(
  p_name text,
  p_avatar_kind text,
  p_avatar_value text,
  p_pin text default null,
  p_set_default boolean default false
) returns public.profiles language plpgsql security definer set search_path = '' as $$
declare
  v_user uuid := (select auth.uid());
  v_profile public.profiles;
begin
  if v_user is null then
    raise exception 'not_authenticated' using errcode='42501';
  end if;
  if p_pin is not null and p_pin !~ '^[0-9]{6}$' then
    raise exception 'invalid_pin' using errcode='22023';
  end if;
  perform 1 from public.accounts where id=v_user for update;
  if not found then
    raise exception 'account_missing' using errcode='42501';
  end if;
  if (select count(*) from public.profiles where account_id=v_user) >= 5 then
    raise exception 'profile_limit' using errcode='23514';
  end if;
  insert into public.profiles(account_id,name,avatar_kind,avatar_value,has_pin)
  values(v_user,btrim(p_name),p_avatar_kind,p_avatar_value,p_pin is not null)
  returning * into v_profile;
  if p_pin is not null then
    insert into app_private.profile_pin_verifiers(profile_id,verifier)
    values(v_profile.id,extensions.crypt(p_pin,extensions.gen_salt('bf',12)));
  end if;
  if coalesce(p_set_default,false) then
    update public.accounts set default_profile_id=v_profile.id,updated_at=now()
    where id=v_user;
  end if;
  return v_profile;
end;
$$;

revoke all on function public.create_profile(text,text,text,text,boolean)
  from public, anon;
grant execute on function public.create_profile(text,text,text,text,boolean)
  to authenticated;
