-- Independent NOVA protocol. Clients cannot publish trusted room broadcasts.
create table app_private.nova_party_rooms (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  host_member_id uuid,
  host_only boolean not null default true,
  media jsonb,
  position_ms bigint not null default 0 check (position_ms between 0 and 43200000),
  duration_ms bigint not null default 0 check (duration_ms between 0 and 43200000),
  playing boolean not null default false,
  rate double precision not null default 1 check (rate between 0.25 and 4),
  state_at timestamptz not null default clock_timestamp(),
  revision bigint not null default 1,
  waiting boolean not null default false,
  wait_until timestamptz,
  ignored_waiters uuid[] not null default '{}',
  expires_at timestamptz not null default (now() + interval '6 hours'),
  ended_at timestamptz,
  created_at timestamptz not null default now()
);
create table app_private.nova_party_members (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references app_private.nova_party_rooms on delete cascade,
  account_id uuid not null references public.accounts on delete cascade,
  profile_id uuid not null references public.profiles on delete cascade,
  device_id uuid not null,
  display_name text not null,
  avatar text,
  status text not null default 'browsing' check (status in ('browsing','loading','buffering','ready')),
  media_key text,
  joined_at timestamptz not null default clock_timestamp(),
  seen_at timestamptz not null default clock_timestamp(),
  left_at timestamptz,
  removed boolean not null default false,
  last_chat_at timestamptz
);
create unique index nova_party_one_device on app_private.nova_party_members(account_id,device_id) where left_at is null;
create index nova_party_room_members on app_private.nova_party_members(room_id,joined_at,id) where left_at is null;
create index nova_party_profile_fk on app_private.nova_party_members(profile_id);
create index nova_party_expiry on app_private.nova_party_rooms(expires_at);
create table app_private.nova_party_messages (
  id bigint generated always as identity primary key,
  room_id uuid not null references app_private.nova_party_rooms on delete cascade,
  member_id uuid not null,
  display_name text not null,
  client_id uuid not null,
  body text not null check (char_length(body) between 1 and 500),
  created_at timestamptz not null default clock_timestamp(),
  unique(room_id,member_id,client_id)
);
create index nova_party_message_history on app_private.nova_party_messages(room_id,id desc);
create table app_private.nova_party_limits (
  account_id uuid not null references public.accounts on delete cascade,
  bucket text not null,
  window_at timestamptz not null,
  count integer not null,
  primary key(account_id,bucket)
);
alter table app_private.nova_party_rooms enable row level security;
alter table app_private.nova_party_members enable row level security;
alter table app_private.nova_party_messages enable row level security;
alter table app_private.nova_party_limits enable row level security;
revoke all on app_private.nova_party_rooms,app_private.nova_party_members,app_private.nova_party_messages,app_private.nova_party_limits from public,anon,authenticated;

create function app_private.nova_party_snapshot(p_room uuid, p_self uuid default null, p_history boolean default false)
returns jsonb language sql security definer set search_path = '' as $$
  select jsonb_build_object(
    'server_time_ms',floor(extract(epoch from clock_timestamp())*1000)::bigint,
    'self_member_id',p_self,
    'room',jsonb_build_object('id',r.id,'code',r.code,'host_member_id',r.host_member_id,
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

-- Deliver separately to current members. A removed member's cached channel
-- authorization cannot receive subsequent room state or messages.
create function app_private.nova_party_emit(p_room uuid, p_event text default 'snapshot', p_data jsonb default null)
returns void language plpgsql security definer set search_path = '' as $$
declare v_member uuid; v_data jsonb;
begin
  v_data := coalesce(p_data,app_private.nova_party_snapshot(p_room));
  for v_member in select id from app_private.nova_party_members where room_id=p_room and left_at is null loop
    perform realtime.send(v_data,p_event,'nova-party:'||v_member::text,true);
  end loop;
end;
$$;

create function app_private.nova_party_receive(p_topic text)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists(select 1 from app_private.nova_party_members m
    join app_private.nova_party_rooms r on r.id=m.room_id
    where p_topic='nova-party:'||m.id::text and m.account_id=(select auth.uid())
      and m.left_at is null and r.ended_at is null and r.expires_at>now());
$$;
create policy nova_party_receive on realtime.messages for select to authenticated
  using (extension='broadcast' and app_private.nova_party_receive(realtime.topic()));
-- Keep server attribution even if another feature later adds a permissive
-- INSERT policy to realtime.messages.
create policy nova_party_server_messages on realtime.messages as restrictive for insert to authenticated
  with check (topic not like 'nova-party:%');

create function app_private.nova_party_media(p_media jsonb)
returns jsonb language plpgsql immutable set search_path = '' as $$
begin
  if jsonb_typeof(p_media) is distinct from 'object'
    or coalesce(p_media->>'type','') not in ('movie','series','anime')
    or jsonb_typeof(p_media->'id') is distinct from 'string'
    or jsonb_typeof(p_media->'video_id') is distinct from 'string'
    or jsonb_typeof(p_media->'title') is distinct from 'string'
    or char_length(coalesce(p_media->>'id','')) not between 1 and 256
    or char_length(coalesce(p_media->>'video_id','')) not between 1 and 256
    or char_length(coalesce(p_media->>'title','')) not between 1 and 200
    or (p_media->>'type'<>'movie' and (coalesce(p_media->>'season','')!~'^[0-9]{1,4}$' or coalesce(p_media->>'episode','')!~'^[0-9]{1,5}$')) then return null; end if;
  return jsonb_build_object('id',p_media->>'id','type',p_media->>'type','video_id',p_media->>'video_id','title',p_media->>'title',
    'season',case when p_media->>'type'<>'movie' then (p_media->>'season')::integer else null end,
    'episode',case when p_media->>'type'<>'movie' then (p_media->>'episode')::integer else null end,
    'poster',case when char_length(p_media->>'poster')<=2048 and p_media->>'poster' ~ '^https://[^[:space:]]+$' then p_media->>'poster' else null end);
end;
$$;

create function app_private.nova_party_api(p_action text,p_device_id uuid,p_profile_id uuid,
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
          insert into app_private.nova_party_rooms(code) values(v_code) returning * into v_room;
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

-- Public invoker is a thin API; privileged implementation stays in a schema
-- not exposed by PostgREST. Every action checks Auth, membership and profile.
create function public.nova_party(p_action text,p_device_id uuid,p_profile_id uuid default null,
  p_room_id uuid default null,p_code text default null,p_payload jsonb default '{}'::jsonb)
returns jsonb language sql security invoker set search_path = '' as $$
  select app_private.nova_party_api(p_action,p_device_id,p_profile_id,p_room_id,p_code,p_payload);
$$;
revoke all on function app_private.nova_party_snapshot(uuid,uuid,boolean),app_private.nova_party_emit(uuid,text,jsonb),
  app_private.nova_party_media(jsonb),
  app_private.nova_party_receive(text),app_private.nova_party_api(text,uuid,uuid,uuid,text,jsonb),
  public.nova_party(text,uuid,uuid,uuid,text,jsonb) from public,anon,authenticated;
grant usage on schema app_private to authenticated;
grant execute on function app_private.nova_party_receive(text),app_private.nova_party_api(text,uuid,uuid,uuid,text,jsonb),
  public.nova_party(text,uuid,uuid,uuid,text,jsonb) to authenticated;
