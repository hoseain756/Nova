-- Run as the database operator. All fixtures and broadcasts roll back.
begin;
do $test$
<<fixture>>
declare
  a uuid:=gen_random_uuid(); b uuid:=gen_random_uuid(); c uuid:=gen_random_uuid();
  pa uuid:=gen_random_uuid(); pb uuid:=gen_random_uuid(); pc uuid:=gen_random_uuid();
  da uuid:=gen_random_uuid(); db uuid:=gen_random_uuid(); dc uuid:=gen_random_uuid();
  room_id uuid; ha uuid; mb uuid; code text; r jsonb; s jsonb; message_id bigint;
  media jsonb:='{"id":"tt-nova-party-smoke","type":"movie","title":"Smoke test","video_id":"tt-nova-party-smoke","url":"https://private.invalid","headers":{"Authorization":"dummy"}}';
  rev bigint; n integer; client_id uuid:=gen_random_uuid();
  src jsonb:=jsonb_build_object('key','stream:'||repeat('a',64),'name','Same edition');
  relay text:='https://nova-relay.workers.dev'; ticket jsonb;
begin
  insert into auth.users(id,email,raw_app_meta_data,raw_user_meta_data,is_anonymous) values
    (a,'nova-party-smoke-'||a||'@example.invalid','{"provider":"email","providers":["email"]}','{}',false),
    (b,'nova-party-smoke-'||b||'@example.invalid','{"provider":"email","providers":["email"]}','{}',false),
    (c,'nova-party-smoke-'||c||'@example.invalid','{"provider":"email","providers":["email"]}','{}',false);
  insert into public.profiles(id,account_id,name,avatar_value) values
    (pa,a,'Host','nova_avatar_01_smile'),(pb,b,'Guest','nova_avatar_01_smile'),(pc,c,'Other','nova_avatar_01_smile');
  perform set_config('request.jwt.claims',jsonb_build_object('sub',a,'role','authenticated','is_anonymous',true)::text,true);
  r:=public.nova_party('create',da,pa);
  assert r->>'error'='account_required','anonymous Auth must be rejected';
  perform set_config('request.jwt.claims',jsonb_build_object('sub',a,'role','authenticated','is_anonymous',false)::text,true);
  r:=public.nova_party('create',da,pb);
  assert r->>'error'='profile_required','cannot use another account profile';
  r:=public.nova_party('create',da,pa,null,null,jsonb_build_object('media',jsonb_build_object('id','bad')));
  assert r->>'error'='invalid_media','invalid creation must not leave a membership';
  assert not exists(select 1 from app_private.nova_party_members where account_id=a),'invalid create had side effects';
  r:=public.nova_party('create',da,pa,null,null,'{"host_only":"false"}');
  assert r->>'error'='invalid','creation control mode must be a boolean';
  assert not exists(select 1 from app_private.nova_party_members where account_id=a),'invalid control mode had side effects';
  r:=public.nova_party('create',da,pa,null,null,jsonb_build_object('media',media));
  assert r->>'error' is null,'create failed';
  assert not (r->'room'->>'host_only')::boolean,'new rooms must default to shared playback control';
  room_id:=(r->'room'->>'id')::uuid; ha:=(r->>'self_member_id')::uuid;
  code:=r->'room'->>'code';
  assert char_length(code)=8 and code ~ '^[A-HJ-NP-Z2-9]{8}$','invalid room code';
  assert r->'room'->'media'->>'url' is null and r->'room'->'media'->'headers' is null,'transport credentials must be discarded';
  assert app_private.nova_party_receive('nova-party:'||ha),'host channel access';
  r:=public.nova_party('create',da,pa);
  assert r->>'error'='already_in_room' and r->'snapshot'->>'self_member_id'=ha::text,'lost-response creation recovery';

  perform set_config('request.jwt.claims',jsonb_build_object('sub',c,'role','authenticated','is_anonymous',false)::text,true);
  r:=public.nova_party('snapshot',dc,pc,room_id);
  assert r->>'error'='not_member','outsider snapshot leaked';
  assert not app_private.nova_party_receive('nova-party:'||ha),'outsider private topic access';
  for n in 1..20 loop r:=public.nova_party('join',dc,pc,null,'ZZZZZZZZ'); end loop;
  r:=public.nova_party('join',dc,pc,null,code);
  assert r->>'error'='rate_limited','failed code guesses must count';

  perform set_config('request.jwt.claims',jsonb_build_object('sub',b,'role','authenticated','is_anonymous',false)::text,true);
  r:=public.nova_party('join',db,pb,null,code); mb:=(r->>'self_member_id')::uuid;
  assert r->>'error' is null and mb is not null,'guest join';
  perform set_config('request.jwt.claims',jsonb_build_object('sub',a,'role','authenticated','is_anonymous',false)::text,true);
  r:=public.nova_party('configure',da,pa,room_id,null,jsonb_build_object(
      'revision',r->'room'->'revision','source_locked',true,'source',src||'{"url":"private"}'::jsonb));
  assert r->'room'->'source'=src and (r->'room'->>'source_locked')::boolean,'public-only locked source descriptor';
  perform set_config('request.jwt.claims',jsonb_build_object('sub',b,'role','authenticated','is_anonymous',false)::text,true);
  rev:=(r->'room'->>'revision')::bigint;
  r:=public.nova_party('command',db,pb,room_id,null,jsonb_build_object('revision',rev,'command','play','media_key','movie|tt-nova-party-smoke|tt-nova-party-smoke'));
  assert r->>'error'='source_mismatch','locked guest needs matching source';
  r:=public.nova_party('command',db,pb,room_id,null,jsonb_build_object('revision',rev,'command','audio',
    'audio_track',jsonb_build_object('mode','track','language','ar','index',1,'source_key',src->>'key'),
    'media_key','movie|tt-nova-party-smoke|tt-nova-party-smoke','source_key',src->>'key'));
  assert r->'room'->'audio_track'->>'language'='ar','guest audio selection';
  perform set_config('request.jwt.claims',jsonb_build_object('sub',a,'role','authenticated','is_anonymous',false)::text,true);
  r:=public.nova_party('publish',da,pa,room_id,null,jsonb_build_object('revision',r->'room'->'revision',
    'duration_ms',60000,'position_ms',0,'media_key','movie|tt-nova-party-smoke|tt-nova-party-smoke','audio_track','{"mode":"auto"}'::jsonb));
  assert r->'room'->'audio_track'->>'language'='ar','sample must preserve explicit audio';
  r:=public.nova_party('configure',da,pa,room_id,null,jsonb_build_object('revision',r->'room'->'revision','source_locked',false));
  ticket:=public.nova_party_relay_ticket(da,pa,relay);
  assert public.nova_party_relay_verify(ticket->>'token',relay)->'identity'->>'account_id'=a::text,'origin-bound relay identity';
  assert public.nova_party_relay_verify(ticket->>'token','https://other.workers.dev')->>'error'='invalid_ticket','origin isolation';
  assert public.nova_party_relay_ticket(da,pb,relay)->>'error'='profile_required','cross-account relay ticket issuance';
  perform set_config('request.jwt.claims',jsonb_build_object('sub',b,'role','authenticated','is_anonymous',false)::text,true);
  rev:=(r->'room'->>'revision')::bigint;
  r:=public.nova_party('command',db,pb,room_id,null,jsonb_build_object('revision',rev,'command','play','media_key','movie|tt-nova-party-smoke|tt-nova-party-smoke'));
  assert r->>'error' is null and (r->'room'->>'playing')::boolean,'guest can play in a new shared-control room';
  rev:=(r->'room'->>'revision')::bigint;
  perform set_config('request.jwt.claims',jsonb_build_object('sub',a,'role','authenticated','is_anonymous',false)::text,true);
  r:=public.nova_party('configure',da,pa,room_id,null,jsonb_build_object('revision',rev,'host_only',true));
  assert (r->'room'->>'host_only')::boolean,'host can restrict playback control';
  rev:=(r->'room'->>'revision')::bigint;
  perform set_config('request.jwt.claims',jsonb_build_object('sub',b,'role','authenticated','is_anonymous',false)::text,true);
  r:=public.nova_party('command',db,pb,room_id,null,jsonb_build_object('revision',rev,'command','pause','media_key','movie|tt-nova-party-smoke|tt-nova-party-smoke'));
  assert r->>'error'='host_required','host-only guest control';
  r:=public.nova_party('publish',da,pb,room_id,null,jsonb_build_object('revision',rev,'media_key','movie|tt-nova-party-smoke|tt-nova-party-smoke','position_ms',100,'duration_ms',100000));
  assert r->>'error'='not_member','device ID cannot impersonate another account';
  r:=public.nova_party('transfer',db,pb,room_id,null,jsonb_build_object('revision',rev,'member_id',mb));
  assert r->>'error'='host_required','guest cannot take host';

  perform set_config('request.jwt.claims',jsonb_build_object('sub',a,'role','authenticated','is_anonymous',false)::text,true);
  r:=public.nova_party('snapshot',da,pa,room_id);rev:=(r->'room'->>'revision')::bigint;
  r:=public.nova_party('command',da,pa,room_id,null,jsonb_build_object('command','play','media_key','movie|tt-nova-party-smoke|tt-nova-party-smoke'));
  assert r->>'error'='invalid','revision is mandatory';
  r:=public.nova_party('command',da,pa,room_id,null,jsonb_build_object('revision',rev-1,'command','play','media_key','movie|tt-nova-party-smoke|tt-nova-party-smoke'));
  assert r->>'error'='conflict','stale revision';
  r:=public.nova_party('configure',da,pa,room_id,null,jsonb_build_object('revision',rev,'host_only',false));
  rev:=(r->'room'->>'revision')::bigint;
  perform set_config('request.jwt.claims',jsonb_build_object('sub',b,'role','authenticated','is_anonymous',false)::text,true);
  r:=public.nova_party('command',db,pb,room_id,null,jsonb_build_object('revision',rev,'command','seek','position_ms',50000,'media_key','movie|tt-nova-party-smoke|tt-nova-party-smoke'));
  assert (r->'room'->>'position_ms')::bigint=50000,'group seek';
  rev:=(r->'room'->>'revision')::bigint;
  r:=public.nova_party('command',db,pb,room_id,null,jsonb_build_object('revision',rev,'command','play','media_key','movie|tt-nova-party-smoke|tt-nova-party-smoke'));
  assert (r->'room'->>'playing')::boolean,'group play';
  r:=public.nova_party('heartbeat',db,pb,room_id,null,'{"status":"buffering","media_key":"movie|tt-nova-party-smoke|tt-nova-party-smoke"}');
  assert (r->'room'->>'waiting')::boolean and not (r->'room'->>'playing')::boolean,'buffering wait';
  update app_private.nova_party_rooms set wait_until=clock_timestamp()-interval '1 second' where id=room_id;
  r:=public.nova_party('heartbeat',db,pb,room_id,null,'{"status":"buffering","media_key":"movie|tt-nova-party-smoke|tt-nova-party-smoke"}');
  assert not (r->'room'->>'waiting')::boolean and (r->'room'->>'playing')::boolean,'bounded waiting';
  r:=public.nova_party('heartbeat',db,pb,room_id,null,'{"status":"buffering","media_key":"movie|tt-nova-party-smoke|tt-nova-party-smoke"}');
  assert not (r->'room'->>'waiting')::boolean,'timed-out waiter re-paused the room';
  r:=public.nova_party('chat',db,pb,room_id,null,jsonb_build_object('client_id',client_id,'body','Hello'));
  message_id:=(r->'message'->>'id')::bigint;assert message_id is not null,'chat send';
  r:=public.nova_party('chat',db,pb,room_id,null,jsonb_build_object('client_id',client_id,'body','Hello'));
  assert (r->'message'->>'id')::bigint=message_id,'chat retry must be idempotent';
  for n in 1..6 loop
    r:=public.nova_party('join',gen_random_uuid(),pb,null,code);
    assert r->>'error' is null,'fill room';
  end loop;
  r:=public.nova_party('join',gen_random_uuid(),pb,null,code);assert r->>'error'='full','member cap';

  perform set_config('request.jwt.claims',jsonb_build_object('sub',a,'role','authenticated','is_anonymous',false)::text,true);
  r:=public.nova_party('snapshot',da,pa,room_id);rev:=(r->'room'->>'revision')::bigint;
  r:=public.nova_party('remove',da,pa,room_id,null,jsonb_build_object('revision',rev,'member_id',mb));
  assert jsonb_array_length(r->'members')=7,'remove';
  perform set_config('request.jwt.claims',jsonb_build_object('sub',b,'role','authenticated','is_anonymous',false)::text,true);
  assert not app_private.nova_party_receive('nova-party:'||mb),'removed channel must be unauthorized';
  r:=public.nova_party('snapshot',db,pb,room_id);assert r->>'error'='not_member','removed member snapshot';
  r:=public.nova_party('join',db,pb,null,code);assert r->>'error'='removed','removed account cannot rejoin';

  perform set_config('request.jwt.claims',jsonb_build_object('sub',a,'role','authenticated','is_anonymous',false)::text,true);
  r:=public.nova_party('snapshot',da,pa,room_id);
  select m.id into mb from app_private.nova_party_members m where m.room_id=fixture.room_id and m.account_id=b and m.left_at is null limit 1;
  rev:=(r->'room'->>'revision')::bigint;
  r:=public.nova_party('transfer',da,pa,room_id,null,jsonb_build_object('revision',rev,'member_id',mb));
  assert r->'room'->>'host_member_id'=mb::text,'host transfer';
  r:=public.nova_party('end',da,pa,room_id);assert r->>'error'='host_required','old host cannot end room';
  update app_private.nova_party_members set seen_at=clock_timestamp()-interval '80 seconds' where id=mb;
  r:=public.nova_party('heartbeat',da,pa,room_id,null,'{"status":"ready","media_key":"movie|tt-nova-party-smoke|tt-nova-party-smoke"}');
  assert r->'room'->>'host_member_id'=ha::text,'stale-host election';
  update app_private.nova_party_rooms set expires_at=clock_timestamp()-interval '1 second' where id=room_id;
  r:=public.nova_party('snapshot',da,pa,room_id);assert r->>'error'='ended','expiry enforced';
  assert not has_table_privilege('authenticated','app_private.nova_party_rooms','select'),'direct room access';
  assert not has_function_privilege('anon','public.nova_party(text,uuid,uuid,uuid,text,jsonb)','execute'),'anon RPC access';
  perform set_config('nova.party.test_device',da::text,true);
  perform set_config('nova.party.test_profile',pa::text,true);
end;
$test$;
set local role authenticated;
do $roles$
declare r jsonb; mid text;
begin
  r:=public.nova_party('create',current_setting('nova.party.test_device')::uuid,current_setting('nova.party.test_profile')::uuid,null,null,'{"code_length":6}');
  assert r->>'error' is null,'authenticated invoker API must work';
  assert length(r->'room'->>'code')=6,'current clients create short codes';
  mid:=r->>'self_member_id';
  begin
    perform 1 from app_private.nova_party_rooms;
    raise exception 'direct table read unexpectedly allowed';
  exception when insufficient_privilege then null; end;
  begin
    insert into realtime.messages(topic,extension,payload,event,private)
      values('nova-party:'||mid,'broadcast','{}','snapshot',true);
    raise exception 'forged server broadcast unexpectedly allowed';
  exception when insufficient_privilege then null; end;
end;
$roles$;
set local role anon;
do $roles$
begin
  begin
    perform public.nova_party('resume',gen_random_uuid());
    raise exception 'anonymous RPC unexpectedly executable';
  exception when insufficient_privilege then null; end;
end;
$roles$;
reset role;
rollback;
select 'passed' as watch_party_transaction_smoke,
  (select count(*) from auth.users where email like 'nova-party-smoke-%@example.invalid') as remaining_fixture_users;
