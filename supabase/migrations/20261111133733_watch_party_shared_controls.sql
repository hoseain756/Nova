-- New rooms allow all viewers to control playback. Existing rooms keep their
-- chosen mode; only the host can change it through the checked configure RPC.
alter table app_private.nova_party_rooms alter column host_only set default false;

create or replace function app_private.nova_party_api(p_action text,p_device_id uuid,p_profile_id uuid,
  p_room_id uuid,p_code text,p_payload jsonb)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := auth.uid(); v_now timestamptz := clock_timestamp();
  v_room app_private.nova_party_rooms%rowtype; v_member app_private.nova_party_members%rowtype;
  v_profile public.profiles%rowtype; v_id uuid; v_count integer; v_limit integer;
  v_bucket text; v_code text; v_raw bytea; v_alphabet text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  v_media jsonb; v_position bigint; v_duration bigint; v_rate double precision;
  v_expected bigint; v_action text; v_changed boolean := false; v_blocked uuid[];
  v_message app_private.nova_party_messages%rowtype; v_target uuid;
begin
  if v_uid is null or coalesce((auth.jwt()->>'is_anonymous')::boolean,true) then
    return jsonb_build_object('error','account_required');
  end if;
  if p_device_id is null or p_action is null or p_action not in
    ('create','join','resume','snapshot','heartbeat','media','command','publish','configure','transfer','remove','leave','end','chat')
    or p_payload is null or jsonb_typeof(p_payload)<>'object' or octet_length(p_payload::text)>8192 then
    return jsonb_build_object('error','invalid');
  end if;
  if p_action='create' and p_payload ? 'host_only' and jsonb_typeof(p_payload->'host_only') is distinct from 'boolean' then
    return jsonb_build_object('error','invalid');
  end if;
  if p_action='create' and p_payload ? 'media' and app_private.nova_party_media(p_payload->'media') is null then
    return jsonb_build_object('error','invalid_media');
  end if;
  if p_action in ('create','media') and (coalesce(p_payload->>'position_ms','0')!~'^[0-9]{1,8}$'
    or coalesce((p_payload->>'position_ms')::bigint,0)>43200000
    or (p_payload ? 'rate' and (jsonb_typeof(p_payload->'rate') is distinct from 'number' or (p_payload->>'rate')::double precision not between 0.25 and 4))
    or (p_payload ? 'playing' and jsonb_typeof(p_payload->'playing') is distinct from 'boolean')) then return jsonb_build_object('error','invalid'); end if;
  -- Failed joins count too: expected errors are values, not rolled-back exceptions.
  v_bucket := case when p_action in ('create','join') then 'entry' when p_action='chat' then 'chat' else 'transport' end;
  v_limit := case v_bucket when 'entry' then 20 when 'chat' then 20 else 180 end;
  insert into app_private.nova_party_limits(account_id,bucket,window_at,count) values(v_uid,v_bucket,v_now,1)
    on conflict(account_id,bucket) do update set
      count=case when nova_party_limits.window_at < v_now-interval '1 minute' then 1 else nova_party_limits.count+1 end,
      window_at=case when nova_party_limits.window_at < v_now-interval '1 minute' then v_now else nova_party_limits.window_at end
    returning count into v_count;
  if v_count>v_limit then return jsonb_build_object('error','rate_limited'); end if;

  if p_action in ('create','join','resume') then
    perform pg_advisory_xact_lock(hashtextextended(v_uid::text||p_device_id::text,91411));
    select * into v_profile from public.profiles where id=p_profile_id and account_id=v_uid;
    if not found then return jsonb_build_object('error','profile_required'); end if;
    -- Lazy retention cleanup; every operation also enforces expires_at.
    delete from app_private.nova_party_rooms where expires_at<v_now-interval '1 day';
    update app_private.nova_party_members m set left_at=v_now where m.account_id=v_uid and m.device_id=p_device_id
      and m.left_at is null and (m.seen_at<v_now-interval '75 seconds' or exists(
        select 1 from app_private.nova_party_rooms r where r.id=m.room_id and (r.ended_at is not null or r.expires_at<=v_now)));
    select * into v_member from app_private.nova_party_members where account_id=v_uid and device_id=p_device_id and left_at is null;
    if p_action='resume' then
      if v_member.id is null or v_member.profile_id<>p_profile_id then return jsonb_build_object('snapshot',null); end if;
      p_room_id := v_member.room_id;
    elsif v_member.id is not null then
      if p_action='join' and v_member.profile_id=p_profile_id and exists(select 1 from app_private.nova_party_rooms where id=v_member.room_id and code=upper(btrim(p_code))) then
        return app_private.nova_party_snapshot(v_member.room_id,v_member.id,true);
      end if;
      return jsonb_build_object('error','already_in_room','snapshot',case when v_member.profile_id=p_profile_id then app_private.nova_party_snapshot(v_member.room_id,v_member.id,true) else null end);
    elsif p_action='create' then
      -- Eight random symbols; modulo bias is absent because alphabet has 32 symbols.
      loop
        v_raw:=extensions.gen_random_bytes(8); v_code:='';
        for v_count in 0..7 loop v_code:=v_code||substr(v_alphabet,(get_byte(v_raw,v_count)%32)+1,1); end loop;
        begin
          insert into app_private.nova_party_rooms(code,host_only)
            values(v_code,coalesce((p_payload->>'host_only')::boolean,false)) returning * into v_room;
          exit;
        exception when unique_violation then null;
        end;
      end loop;
      p_room_id:=v_room.id;
    else
      v_code:=upper(btrim(p_code));
      if v_code is null or v_code !~ '^[A-HJ-NP-Z2-9]{8}$' then return jsonb_build_object('error','not_found'); end if;
      select id into p_room_id from app_private.nova_party_rooms where code=v_code;
      if p_room_id is null then return jsonb_build_object('error','not_found'); end if;
    end if;
  end if;

  select * into v_room from app_private.nova_party_rooms where id=p_room_id for update;
  if not found or v_room.ended_at is not null or v_room.expires_at<=v_now then return jsonb_build_object('error','ended'); end if;
  -- All mutations, joins and host elections serialize on the room row.
  update app_private.nova_party_members set left_at=v_now where room_id=p_room_id and left_at is null and seen_at<v_now-interval '75 seconds';
  get diagnostics v_count=row_count; v_changed:=v_count>0;
  if p_action in ('create','join') then
    if exists(select 1 from app_private.nova_party_members where room_id=p_room_id and account_id=v_uid and removed) then return jsonb_build_object('error','removed'); end if;
    if (select count(*) from app_private.nova_party_members where room_id=p_room_id and left_at is null)>=8 then return jsonb_build_object('error','full'); end if;
    insert into app_private.nova_party_members(room_id,account_id,profile_id,device_id,display_name,avatar)
      values(p_room_id,v_uid,p_profile_id,p_device_id,left(v_profile.name,40),left(v_profile.avatar_value,512)) returning * into v_member;
    v_changed:=true;
  else
    select * into v_member from app_private.nova_party_members where room_id=p_room_id and account_id=v_uid and device_id=p_device_id and left_at is null;
    if v_member.id is null then return jsonb_build_object('error','not_member'); end if;
    if v_member.profile_id is distinct from p_profile_id then return jsonb_build_object('error','profile_required'); end if;
  end if;
  update app_private.nova_party_members set seen_at=v_now where id=v_member.id;
  if not exists(select 1 from app_private.nova_party_members where id=v_room.host_member_id and left_at is null) then
    select id into v_room.host_member_id from app_private.nova_party_members where room_id=p_room_id and left_at is null order by joined_at,id limit 1;
    v_changed:=true;
  end if;
  if p_action in ('media','configure','transfer','remove','end') and v_member.id<>v_room.host_member_id then return jsonb_build_object('error','host_required'); end if;
  if p_action in ('command','publish') and ((v_room.host_only and v_member.id<>v_room.host_member_id) or (p_action='publish' and v_member.id<>v_room.host_member_id)) then
    return jsonb_build_object('error','host_required');
  end if;
  if p_action in ('media','command','publish','configure','transfer','remove') then
    if jsonb_typeof(p_payload->'revision') is distinct from 'number' then return jsonb_build_object('error','invalid'); end if;
    v_expected:=(p_payload->>'revision')::bigint;
    if v_expected<>v_room.revision then return jsonb_build_object('error','conflict','snapshot',app_private.nova_party_snapshot(p_room_id,v_member.id,true)); end if;
  end if;

  if p_action='media' or (p_action='create' and p_payload ? 'media') then
    v_media:=app_private.nova_party_media(p_payload->'media');
    if v_media is null then return jsonb_build_object('error','invalid_media'); end if;
    v_room.media:=v_media;
    v_position:=coalesce((p_payload->>'position_ms')::bigint,0);
    v_rate:=coalesce((p_payload->>'rate')::double precision,1);
    if v_position not between 0 and 43200000 or v_rate not between 0.25 and 4 then return jsonb_build_object('error','invalid'); end if;
    v_room.position_ms:=v_position; v_room.duration_ms:=0;
    v_room.playing:=coalesce((p_payload->>'playing')::boolean,false); v_room.rate:=v_rate;
    v_room.waiting:=false; v_room.ignored_waiters:='{}'; v_room.state_at:=v_now; v_changed:=true;
  elsif p_action in ('command','publish') then
    if v_room.media is null or p_payload->>'media_key' is distinct from concat_ws('|',v_room.media->>'type',v_room.media->>'id',v_room.media->>'video_id') then return jsonb_build_object('error','media_mismatch'); end if;
    v_action:=case when p_action='publish' then 'sample' else p_payload->>'command' end;
    if v_action is null or v_action not in ('play','pause','seek','rate','sample') then return jsonb_build_object('error','invalid'); end if;
    v_position:=least(43200000,v_room.position_ms+case when v_room.playing then greatest(0,floor(extract(epoch from (v_now-v_room.state_at))*1000*v_room.rate)::bigint) else 0 end);
    if v_room.duration_ms>0 then v_position:=least(v_position,v_room.duration_ms); end if;
    if v_action in ('seek','sample') then
      if coalesce(p_payload->>'position_ms','')!~'^[0-9]{1,8}$' then return jsonb_build_object('error','invalid'); end if;
      v_position:=(p_payload->>'position_ms')::bigint;
      if v_position>43200000 then return jsonb_build_object('error','invalid'); end if;
    end if;
    if v_action='sample' then
      if coalesce(p_payload->>'duration_ms','')!~'^[0-9]{1,8}$' then return jsonb_build_object('error','invalid'); end if;
      v_duration:=(p_payload->>'duration_ms')::bigint;
      if v_duration>43200000 then return jsonb_build_object('error','invalid'); end if;
      -- A delayed host sample cannot change play/pause/rate; only explicit commands can.
      if not v_room.waiting then v_room.position_ms:=v_position; end if;
      v_room.duration_ms:=v_duration;
    elsif v_action='rate' then
      if jsonb_typeof(p_payload->'rate') is distinct from 'number' then return jsonb_build_object('error','invalid'); end if;
      v_rate:=(p_payload->>'rate')::double precision;
      if v_rate not between 0.25 and 4 then return jsonb_build_object('error','invalid'); end if;
      v_room.rate:=v_rate; v_room.position_ms:=v_position;
    else
      v_room.position_ms:=v_position;
      if v_action in ('play','pause') then
        v_room.playing:=v_action='play'; v_room.waiting:=false;
        if v_action='play' then
          select coalesce(array_agg(id),'{}') into v_room.ignored_waiters from app_private.nova_party_members
            where room_id=p_room_id and left_at is null and status in ('loading','buffering');
        end if;
      end if;
    end if;
    v_room.state_at:=v_now; v_changed:=true;
  elsif p_action='configure' then
    if jsonb_typeof(p_payload->'host_only') is distinct from 'boolean' then return jsonb_build_object('error','invalid'); end if;
    v_room.host_only:=(p_payload->>'host_only')::boolean; v_changed:=true;
  elsif p_action in ('transfer','remove') then
    if coalesce(p_payload->>'member_id','')!~'^[0-9a-f-]{36}$' then return jsonb_build_object('error','invalid'); end if;
    v_target:=(p_payload->>'member_id')::uuid;
    if v_target=v_member.id or not exists(select 1 from app_private.nova_party_members where id=v_target and room_id=p_room_id and left_at is null) then return jsonb_build_object('error','not_member'); end if;
    if p_action='transfer' then v_room.host_member_id:=v_target;
    else
      perform realtime.send(jsonb_build_object('reason','removed'),'closed','nova-party:'||v_target::text,true);
      update app_private.nova_party_members set left_at=v_now,removed=true where id=v_target;
    end if;
    v_changed:=true;
  elsif p_action in ('leave','end') then
    if p_action='end' then
      perform app_private.nova_party_emit(p_room_id,'closed',jsonb_build_object('reason','ended'));
      update app_private.nova_party_members set left_at=v_now where room_id=p_room_id and left_at is null;
      v_room.ended_at:=v_now; v_room.playing:=false;
    else
      update app_private.nova_party_members set left_at=v_now where id=v_member.id;
      if v_room.host_member_id=v_member.id then
        select id into v_room.host_member_id from app_private.nova_party_members where room_id=p_room_id and left_at is null order by joined_at,id limit 1;
      end if;
      if v_room.host_member_id is null then v_room.ended_at:=v_now; v_room.playing:=false; end if;
    end if;
    v_changed:=true;
  elsif p_action='chat' then
    if char_length(btrim(coalesce(p_payload->>'body',''))) not between 1 and 500 or coalesce(p_payload->>'client_id','')!~'^[0-9a-f-]{36}$' then return jsonb_build_object('error','invalid'); end if;
    select * into v_message from app_private.nova_party_messages where room_id=p_room_id and member_id=v_member.id and client_id=(p_payload->>'client_id')::uuid;
    if v_message.id is null then
      if v_member.last_chat_at>v_now-interval '800 milliseconds' then return jsonb_build_object('error','rate_limited'); end if;
      insert into app_private.nova_party_messages(room_id,member_id,display_name,client_id,body)
        values(p_room_id,v_member.id,v_member.display_name,(p_payload->>'client_id')::uuid,btrim(p_payload->>'body')) returning * into v_message;
      update app_private.nova_party_members set last_chat_at=v_now where id=v_member.id;
      delete from app_private.nova_party_messages where room_id=p_room_id and id<(select id from app_private.nova_party_messages where room_id=p_room_id order by id desc offset 199 limit 1);
      perform app_private.nova_party_emit(p_room_id,'chat',to_jsonb(v_message)-'room_id');
    end if;
  end if;

  if p_action='heartbeat' then
    if coalesce(p_payload->>'status','') not in ('browsing','loading','buffering','ready') then return jsonb_build_object('error','invalid'); end if;
    if v_member.status is distinct from p_payload->>'status' or v_member.media_key is distinct from p_payload->>'media_key' then
      update app_private.nova_party_members set status=p_payload->>'status',media_key=left(p_payload->>'media_key',800) where id=v_member.id;
      v_changed:=true;
    end if;
  end if;
  -- Buffering waits are bounded. Ignore a timed-out waiter until it becomes ready.
  v_room.ignored_waiters:=array(select id from app_private.nova_party_members where id=any(v_room.ignored_waiters) and left_at is null and status<>'ready');
  select coalesce(array_agg(id),'{}') into v_blocked from app_private.nova_party_members
    where room_id=p_room_id and left_at is null and status in ('loading','buffering') and not(id=any(v_room.ignored_waiters))
      and media_key=concat_ws('|',v_room.media->>'type',v_room.media->>'id',v_room.media->>'video_id');
  if v_room.waiting and (cardinality(v_blocked)=0 or v_room.wait_until<=v_now) then
    if cardinality(v_blocked)>0 then v_room.ignored_waiters:=v_room.ignored_waiters||v_blocked; end if;
    v_room.waiting:=false; v_room.playing:=true; v_room.state_at:=v_now; v_changed:=true;
  elsif not v_room.waiting and v_room.playing and cardinality(v_blocked)>0 then
    v_room.position_ms:=least(43200000,v_room.position_ms+greatest(0,floor(extract(epoch from (v_now-v_room.state_at))*1000*v_room.rate)::bigint));
    v_room.waiting:=true; v_room.playing:=false; v_room.wait_until:=v_now+interval '15 seconds'; v_room.state_at:=v_now; v_changed:=true;
  end if;
  if v_changed then v_room.revision:=v_room.revision+1; end if;
  update app_private.nova_party_rooms set host_member_id=v_room.host_member_id,host_only=v_room.host_only,media=v_room.media,
    position_ms=v_room.position_ms,duration_ms=v_room.duration_ms,playing=v_room.playing,rate=v_room.rate,state_at=v_room.state_at,
    revision=v_room.revision,waiting=v_room.waiting,wait_until=v_room.wait_until,ignored_waiters=v_room.ignored_waiters,ended_at=v_room.ended_at where id=p_room_id;
  if v_changed then perform app_private.nova_party_emit(p_room_id); end if;
  if p_action in ('leave','end') then return jsonb_build_object('left',true); end if;
  if p_action='chat' then return jsonb_build_object('message',to_jsonb(v_message)-'room_id','server_time_ms',floor(extract(epoch from clock_timestamp())*1000)::bigint); end if;
  return app_private.nova_party_snapshot(p_room_id,v_member.id,p_action in ('create','join','resume','snapshot'));
end;
$$;
