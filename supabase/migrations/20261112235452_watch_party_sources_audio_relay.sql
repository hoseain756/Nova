-- Keep the existing membership, revision and per-member broadcast transaction.
alter table app_private.nova_party_rooms
  add column source jsonb, add column source_locked boolean not null default false, add column audio_track jsonb;

create function app_private.nova_party_source_key(k text)
returns boolean language sql immutable strict set search_path='' as $$
  select k ~ '^(stream:[0-9a-f]{64}|torrent:([0-9a-f]{40}|[0-9a-f]{64}):(-1|0|[1-9][0-9]{0,7}))$';
$$;
create function app_private.nova_party_source(s jsonb)
returns jsonb language plpgsql immutable set search_path='' as $$
declare k text:=s->>'key'; label text:=s->>'name'; idx integer;
begin
  if jsonb_typeof(s) is distinct from 'object' or not coalesce(app_private.nova_party_source_key(k),false) then return null; end if;
  if nullif(btrim(label),'') is null or label ~* '(https?://|magnet:|bearer |(token|api.?key|password)=)' then label:='Source'; end if;
  if split_part(k,':',1)='torrent' then idx:=split_part(k,':',3)::integer; end if;
  return jsonb_strip_nulls(jsonb_build_object('key',k,'name',left(label,160),
    'info_hash',case when idx is not null then split_part(k,':',2) end,
    'file_index',case when idx>=0 then idx end));
end;
$$;
create function app_private.nova_party_audio(a jsonb)
returns jsonb language plpgsql immutable set search_path='' as $$
begin
  if jsonb_typeof(a) is distinct from 'object' then return null; end if;
  if a->>'mode' in ('off','auto') then return jsonb_build_object('mode',a->>'mode'); end if;
  if a->>'mode' is distinct from 'track' or not a ?| array['index','title','language']
    or (a ? 'source_key' and not coalesce(app_private.nova_party_source_key(a->>'source_key'),false))
    or (a ? 'language' and (jsonb_typeof(a->'language')<>'string' or length(a->>'language') not between 1 and 35))
    or (a ? 'title' and (jsonb_typeof(a->'title')<>'string' or length(a->>'title') not between 1 and 160))
    or (a ? 'index' and (jsonb_typeof(a->'index')<>'number' or a->>'index' !~ '^[0-9]{1,4}$')) then return null; end if;
  return jsonb_strip_nulls(jsonb_build_object('mode','track','language',a->>'language','title',a->>'title',
    'source_key',a->>'source_key','index',a->'index'));
end;
$$;
revoke all on function app_private.nova_party_source_key(text),app_private.nova_party_source(jsonb),
  app_private.nova_party_audio(jsonb) from public,anon,authenticated;

create or replace function app_private.nova_party_snapshot(p_room uuid, p_self uuid default null, p_history boolean default false)
returns jsonb language sql security definer set search_path = '' as $$
  select jsonb_build_object(
    'server_time_ms',floor(extract(epoch from clock_timestamp())*1000)::bigint,
    'self_member_id',p_self,
    'room',jsonb_build_object('id',r.id,'code',r.code,'host_member_id',r.host_member_id,
      'source',r.source,'source_locked',r.source_locked,'audio_track',r.audio_track,
      'host_only',r.host_only,'media',r.media,'position_ms',r.position_ms,'duration_ms',r.duration_ms,
      'playing',r.playing,'rate',r.rate,'at',floor(extract(epoch from r.state_at)*1000)::bigint,
      'revision',r.revision,'waiting',r.waiting,'expires_at',r.expires_at,'ended',r.ended_at is not null),
    'members',coalesce((select jsonb_agg(jsonb_build_object('id',m.id,'name',m.display_name,'avatar',m.avatar,
       'status',m.status,'media_key',m.media_key,'seen_at',m.seen_at) order by m.joined_at,m.id)
       from app_private.nova_party_members m where m.room_id=r.id and m.left_at is null),'[]'::jsonb),
    'messages',case when p_history then coalesce((select jsonb_agg(to_jsonb(msg) order by msg.id)
      from (select id,member_id,display_name,client_id,body,created_at from app_private.nova_party_messages
        where room_id=r.id order by id desc limit 100) msg),'[]'::jsonb) else null end)
  from app_private.nova_party_rooms r where r.id=p_room;
$$;

create or replace function app_private.nova_party_api(p_action text,p_device_id uuid,p_profile_id uuid,
  p_room_id uuid,p_code text,p_payload jsonb)
returns jsonb language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := auth.uid(); v_now timestamptz := clock_timestamp();
  v_room app_private.nova_party_rooms%rowtype; v_member app_private.nova_party_members%rowtype;
  v_profile public.profiles%rowtype; v_id uuid; v_count integer; v_limit integer;
  v_bucket text; v_code text; v_raw bytea; v_alphabet text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  v_media jsonb; v_position bigint; v_duration bigint; v_rate double precision;
  v_code_length integer; v_expected bigint; v_action text; v_changed boolean := false; v_blocked uuid[];
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
  if (p_payload ? 'source_locked' and jsonb_typeof(p_payload->'source_locked') <> 'boolean')
    or (p_payload ? 'source' and p_payload->'source' <> 'null'::jsonb and app_private.nova_party_source(p_payload->'source') is null)
    or (p_payload ? 'audio_track' and p_payload->'audio_track' <> 'null'::jsonb and app_private.nova_party_audio(p_payload->'audio_track') is null)
    then return jsonb_build_object('error','invalid'); end if;
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
      -- Older versions understand only eight symbols. Current clients request six.
      v_code_length:=case when p_payload->>'code_length'='6' then 6 else 8 end;
      loop
        v_raw:=extensions.gen_random_bytes(v_code_length); v_code:='';
        for v_count in 0..(v_code_length-1) loop v_code:=v_code||substr(v_alphabet,(get_byte(v_raw,v_count)%32)+1,1); end loop;
        begin
          insert into app_private.nova_party_rooms(code,host_only,source_locked)
            values(v_code,coalesce((p_payload->>'host_only')::boolean,false),coalesce((p_payload->>'source_locked')::boolean,false)) returning * into v_room;
          exit;
        exception when unique_violation then null;
        end;
      end loop;
      p_room_id:=v_room.id;
    else
      v_code:=upper(btrim(p_code));
      if v_code is null or v_code !~ '^([A-HJ-NP-Z2-9]{6}|[A-HJ-NP-Z2-9]{8})$' then return jsonb_build_object('error','not_found'); end if;
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
  if p_action='command' and v_room.source_locked and v_member.id<>v_room.host_member_id and
    (v_room.source is null or p_payload->>'source_key' is distinct from v_room.source->>'key') then
    return jsonb_build_object('error','source_mismatch');
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
    v_room.source:=app_private.nova_party_source(p_payload->'source');
    v_room.audio_track:=app_private.nova_party_audio(p_payload->'audio_track');
    v_position:=coalesce((p_payload->>'position_ms')::bigint,0);
    v_rate:=coalesce((p_payload->>'rate')::double precision,1);
    if v_position not between 0 and 43200000 or v_rate not between 0.25 and 4 then return jsonb_build_object('error','invalid'); end if;
    v_room.position_ms:=v_position; v_room.duration_ms:=0;
    v_room.playing:=coalesce((p_payload->>'playing')::boolean,false); v_room.rate:=v_rate;
    v_room.waiting:=false; v_room.ignored_waiters:='{}'; v_room.state_at:=v_now; v_changed:=true;
  elsif p_action in ('command','publish') then
    if v_room.media is null or p_payload->>'media_key' is distinct from concat_ws('|',v_room.media->>'type',v_room.media->>'id',v_room.media->>'video_id') then return jsonb_build_object('error','media_mismatch'); end if;
    v_action:=case when p_action='publish' then 'sample' else p_payload->>'command' end;
    if v_action is null or v_action not in ('play','pause','seek','rate','audio','sample') then return jsonb_build_object('error','invalid'); end if;
    v_position:=least(43200000,v_room.position_ms+case when v_room.playing then greatest(0,floor(extract(epoch from (v_now-v_room.state_at))*1000*v_room.rate)::bigint) else 0 end);
    if v_room.duration_ms>0 then v_position:=least(v_position,v_room.duration_ms); end if;
    if v_action in ('seek','sample') or (v_action in ('play','pause') and p_payload ? 'position_ms') then
      if coalesce(p_payload->>'position_ms','')!~'^[0-9]{1,8}$' then return jsonb_build_object('error','invalid'); end if;
      v_position:=(p_payload->>'position_ms')::bigint;
      if v_position>43200000 then return jsonb_build_object('error','invalid'); end if;
    end if;
    if v_action='audio' then
      v_room.audio_track:=app_private.nova_party_audio(p_payload->'audio_track');
      if v_room.audio_track is null then return jsonb_build_object('error','invalid'); end if;
      v_room.position_ms:=v_position;
    elsif v_action='sample' then
      v_room.source:=coalesce(v_room.source,app_private.nova_party_source(p_payload->'source'));
      v_room.audio_track:=coalesce(v_room.audio_track,app_private.nova_party_audio(p_payload->'audio_track'));
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
    if not p_payload ?| array['host_only','source_locked','source'] or
      (p_payload ? 'host_only' and jsonb_typeof(p_payload->'host_only') <> 'boolean') then return jsonb_build_object('error','invalid'); end if;
    v_room.host_only:=coalesce((p_payload->>'host_only')::boolean,v_room.host_only);
    v_room.source_locked:=coalesce((p_payload->>'source_locked')::boolean,v_room.source_locked);
    if p_payload ? 'source' then v_room.source:=app_private.nova_party_source(p_payload->'source'); end if;
    v_changed:=true;
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
    source=v_room.source,source_locked=v_room.source_locked,audio_track=v_room.audio_track,
    position_ms=v_room.position_ms,duration_ms=v_room.duration_ms,playing=v_room.playing,rate=v_room.rate,state_at=v_room.state_at,
    revision=v_room.revision,waiting=v_room.waiting,wait_until=v_room.wait_until,ignored_waiters=v_room.ignored_waiters,ended_at=v_room.ended_at where id=p_room_id;
  if v_changed then perform app_private.nova_party_emit(p_room_id); end if;
  if p_action in ('leave','end') then return jsonb_build_object('left',true); end if;
  if p_action='chat' then return jsonb_build_object('message',to_jsonb(v_message)-'room_id','server_time_ms',floor(extract(epoch from clock_timestamp())*1000)::bigint); end if;
  return app_private.nova_party_snapshot(p_room_id,v_member.id,p_action in ('create','join','resume','snapshot'));
end;
$$;

-- A relay gets a short-lived credential scoped to this origin and device.
-- The NOVA account session stays between the Flutter client and NOVA Auth.
create table app_private.nova_party_relay_tickets (
  digest bytea primary key,
  account_id uuid not null,
  profile_id uuid not null,
  device_id uuid not null,
  origin text not null,
  expires_at timestamptz not null,
  foreign key(account_id,profile_id) references public.profiles(account_id,id) on delete cascade,
  unique(account_id,device_id,profile_id,origin)
);
create index nova_party_relay_tickets_expiry on app_private.nova_party_relay_tickets(expires_at);
alter table app_private.nova_party_relay_tickets enable row level security;
revoke all on app_private.nova_party_relay_tickets from public,anon,authenticated;
create policy nova_party_relay_tickets_private on app_private.nova_party_relay_tickets
  for all to anon,authenticated using(false) with check(false);

create function app_private.nova_party_relay_verify(p_token text,p_relay_url text)
returns jsonb language sql stable security definer set search_path='' as $$
  select coalesce((
    select jsonb_build_object('expires_at_ms',floor(extract(epoch from t.expires_at)*1000)::bigint,
      'identity',jsonb_build_object('account_id',t.account_id,'profile_id',t.profile_id,'device_id',t.device_id,
        'name',p.name,'avatar',p.avatar_value))
    from app_private.nova_party_relay_tickets t
    join public.profiles p on p.id=t.profile_id and p.account_id=t.account_id
    join auth.users u on u.id=t.account_id
    where length(p_token)=64 and t.digest=extensions.digest(p_token,'sha256')
      and t.origin=p_relay_url and t.expires_at>now()
      and u.is_anonymous is false and u.deleted_at is null and (u.banned_until is null or u.banned_until<=now())
  ),'{"error":"invalid_ticket"}'::jsonb);
$$;

create function app_private.nova_party_relay_ticket(p_device_id uuid,p_profile_id uuid,p_relay_url text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare uid uuid:=auth.uid(); token text; n integer;
begin
  if uid is null or coalesce((auth.jwt()->>'is_anonymous')::boolean,true) or not exists(
    select 1 from auth.users u where u.id=uid and u.is_anonymous is false and u.deleted_at is null
    and (u.banned_until is null or u.banned_until<=now())) then return '{"error":"account_required"}'; end if;
  if p_device_id is null or not exists(select 1 from public.profiles where id=p_profile_id and account_id=uid) then
    return '{"error":"profile_required"}'; end if;
  if p_relay_url is null or length(p_relay_url)>261 or p_relay_url !~ '^https://([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]([a-z0-9-]{0,61}[a-z0-9])?$' then
    return '{"error":"invalid"}'; end if;
  insert into app_private.nova_party_limits(account_id,bucket,window_at,count) values(uid,'relay_ticket',now(),1)
    on conflict(account_id,bucket) do update set count=case when nova_party_limits.window_at<now()-interval '1 minute' then 1 else nova_party_limits.count+1 end,
      window_at=case when nova_party_limits.window_at<now()-interval '1 minute' then now() else nova_party_limits.window_at end returning count into n;
  if n>30 then return '{"error":"rate_limited"}'; end if;
  delete from app_private.nova_party_relay_tickets where expires_at<=now();
  token:=encode(extensions.gen_random_bytes(32),'hex');
  insert into app_private.nova_party_relay_tickets(digest,account_id,profile_id,device_id,origin,expires_at)
    values(extensions.digest(token,'sha256'),uid,p_profile_id,p_device_id,p_relay_url,now()+interval '10 minutes')
    on conflict(account_id,device_id,profile_id,origin) do update set digest=excluded.digest,expires_at=excluded.expires_at;
  return app_private.nova_party_relay_verify(token,p_relay_url)||jsonb_build_object('token',token);
end;
$$;

-- SQL-standard bodies bind the private function names at migration time.
create function public.nova_party_relay_ticket(p_device_id uuid,p_profile_id uuid,p_relay_url text)
returns jsonb language sql security invoker set search_path='' return app_private.nova_party_relay_ticket(p_device_id,p_profile_id,p_relay_url);
create function public.nova_party_relay_verify(p_token text,p_relay_url text)
returns jsonb language sql stable security invoker set search_path='' return app_private.nova_party_relay_verify(p_token,p_relay_url);
revoke all on function public.nova_party_relay_ticket(uuid,uuid,text),app_private.nova_party_relay_ticket(uuid,uuid,text),
  public.nova_party_relay_verify(text,text),app_private.nova_party_relay_verify(text,text) from public,anon,authenticated;
grant execute on function public.nova_party_relay_ticket(uuid,uuid,text),app_private.nova_party_relay_ticket(uuid,uuid,text) to authenticated;
grant execute on function public.nova_party_relay_verify(text,text),app_private.nova_party_relay_verify(text,text) to anon,authenticated;
