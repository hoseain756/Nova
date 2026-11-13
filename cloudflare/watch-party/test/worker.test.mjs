import assert from 'node:assert/strict';
import { after, before, test } from 'node:test';
import { fileURLToPath } from 'node:url';
import { Miniflare } from 'miniflare';
import { sanitizeAudio, sanitizeMedia, sanitizeSource } from '../src/worker.mjs';

const origin = 'https://relay.example.com';
const project = 'https://example.supabase.co';
const id = n => `00000000-0000-4000-8000-${String(n).padStart(12, '0')}`;
const token = n => String(n).padStart(64, '0');
const identity = n => ({ account_id: id(n), profile_id: id(n + 100),
  device_id: id(n + 200), name: `Member ${n}`, avatar: null });
const media = { id: 'tt1234', type: 'series', title: 'An episode',
  video_id: 'tt1234:2:7', season: 2, episode: 7 };
const source = { key: `stream:${'a'.repeat(64)}`, name: '1080p' };
let mf;
const verifications = [];
before(async () => {
  mf = new Miniflare({ modules: true,
    scriptPath: fileURLToPath(new URL('../src/worker.mjs', import.meta.url)),
    compatibilityDate: '2026-07-30',
    durableObjects: { ROOMS: { className: 'NovaPartyRoom', useSQLite: true } },
    bindings: { NOVA_RELAY_ORIGIN: origin, NOVA_SUPABASE_URL: project,
      NOVA_SUPABASE_PUBLIC_KEY: 'sb_publishable_test' },
    outboundService: async request => {
      assert.equal(request.url, `${project}/rest/v1/rpc/nova_party_relay_verify`);
      assert.equal(request.headers.get('authorization'), null);
      assert.equal(request.headers.get('apikey'), 'sb_publishable_test');
      const body = await request.json();
      verifications.push(body);
      assert.equal(body.p_relay_url, origin);
      const n = Number(body.p_token);
      return Response.json(n >= 1 && n <= 12
        ? { identity: identity(n), expires_at_ms: Date.now() + 600000 }
        : { error: 'account_required' });
    },
  });
  await mf.ready;
});
after(async () => { await mf?.dispose(); });

async function rpc(n, action, code, payload = {}, roomId) {
  const response = await mf.dispatchFetch(`${origin}/rpc`, { method: 'POST',
    headers: { authorization: `Bearer ${token(n)}`, 'content-type': 'application/json' },
    body: JSON.stringify({ p_action: action, p_device_id: identity(n).device_id,
      p_profile_id: identity(n).profile_id, p_code: code, p_room_id: roomId,
      p_payload: payload }),
  });
  assert.equal(response.status, 200);
  return response.json();
}
async function create(payload = {}) {
  const room = await rpc(1, 'create', undefined, { media, playing: true, ...payload });
  assert.ok(room.room, JSON.stringify(room));
  assert.match(room.room.code, /^[A-HJ-NP-Z2-9]{6}$/);
  return room;
}
async function socket(n, code) {
  const response = await mf.dispatchFetch(`${origin}/r/${code}`, {
    headers: { upgrade: 'websocket', authorization: `Bearer ${token(n)}` },
  });
  assert.equal(response.status, 101);
  const ws = response.webSocket;
  const frames = [], pending = [];
  ws.addEventListener('message', message => {
    const data = JSON.parse(message.data); frames.push(data);
    for (const wait of [...pending]) if (wait.predicate(data)) {
      pending.splice(pending.indexOf(wait), 1); clearTimeout(wait.timer); wait.resolve(data);
    }
  });
  ws.accept();
  return { ws, frames, next(predicate) {
    const known = frames.find(predicate);
    if (known) return Promise.resolve(known);
    return new Promise((resolve, reject) => {
      const wait = { predicate, resolve, timer: setTimeout(() => reject(new Error('Missing relay event')), 3000) };
      pending.push(wait);
    });
  } };
}

test('health is public, account JWTs are rejected without introspection', async () => {
  const health = await mf.dispatchFetch(`${origin}/health`);
  assert.deepEqual(await health.json(), { ok: true, protocol: 'nova-watch-party', version: 1 });
  const count = verifications.length;
  const denied = await mf.dispatchFetch(`${origin}/rpc`, { method: 'POST',
    headers: { authorization: 'Bearer eyJaccount.JWT.mustNeverBeForwarded' }, body: '{}' });
  assert.equal((await denied.json()).error, 'account_required');
  assert.equal(verifications.length, count);
});

test('two authenticated WebSockets receive shared pause/play/seek/chat immediately', async () => {
  const initial = await create();
  const joined = await rpc(2, 'join', initial.room.code);
  const host = await socket(1, initial.room.code), guest = await socket(2, initial.room.code);
  let latest = await rpc(2, 'command', initial.room.code,
    { revision: joined.room.revision, command: 'pause', media_key: 'series|tt1234|tt1234:2:7' }, initial.room.id);
  assert.equal(latest.room.playing, false);
  const hostPause = await host.next(event => event.payload?.room?.revision === latest.room.revision);
  const guestPause = await guest.next(event => event.payload?.room?.revision === latest.room.revision);
  assert.equal(hostPause.payload.self_member_id, initial.self_member_id);
  assert.equal(guestPause.payload.self_member_id, joined.self_member_id);
  assert.equal(hostPause.payload.room.playing, false);
  latest = await rpc(1, 'command', initial.room.code, { revision: latest.room.revision,
    command: 'seek', position_ms: 91000, media_key: 'series|tt1234|tt1234:2:7' });
  assert.equal(latest.room.position_ms, 91000);
  latest = await rpc(2, 'command', initial.room.code, { revision: latest.room.revision,
    command: 'play', media_key: 'series|tt1234|tt1234:2:7' });
  assert.equal(latest.room.playing, true);
  const sent = await rpc(2, 'chat', initial.room.code, { body: 'Hello together', client_id: id(999) });
  assert.equal(sent.message.body, 'Hello together');
  const chat = await host.next(event => event.payload?.messages?.some(message => message.id === sent.message.id));
  assert.equal(chat.payload.messages.at(-1).name, 'Member 2');
  host.ws.close(); guest.ws.close();
});

test('source lock and host-only control are independent server-enforced settings', async () => {
  let room = await create({ source, source_locked: true });
  room = await rpc(2, 'join', room.room.code);
  const command = { revision: room.room.revision, command: 'pause',
    media_key: 'series|tt1234|tt1234:2:7' };
  const wrong = await rpc(2, 'command', room.room.code, command);
  assert.equal(wrong.error, 'source_mismatch');
  room = await rpc(2, 'command', room.room.code, { ...command, source_key: source.key });
  assert.equal(room.room.playing, false);
  room = await rpc(1, 'configure', room.room.code, { revision: room.room.revision,
    source_locked: false, host_only: true });
  const denied = await rpc(2, 'command', room.room.code, { ...command,
    revision: room.room.revision, source_key: source.key });
  assert.equal(denied.error, 'host_required');
  room = await rpc(1, 'configure', room.room.code, { revision: room.room.revision,
    host_only: false, source_locked: true, source: null });
  assert.equal(room.room.source_locked, true);
  assert.equal(room.room.source, null);
  assert.equal((await rpc(2, 'command', room.room.code,
    { ...command, revision: room.room.revision, source_key: source.key })).error, 'source_mismatch');
});

test('audio selection survives samples and preserves exact-source ordinal guard', async () => {
  let room = await create({ source });
  const audio = { mode: 'track', language: 'ar', title: 'Arabic', index: 2, source_key: source.key };
  room = await rpc(1, 'command', room.room.code, { revision: room.room.revision,
    command: 'audio', media_key: 'series|tt1234|tt1234:2:7', audio_track: audio });
  room = await rpc(1, 'publish', room.room.code, { revision: room.room.revision,
    media_key: 'series|tt1234|tt1234:2:7', position_ms: 10000, duration_ms: 100000,
    source, audio_track: { mode: 'auto' } });
  assert.deepEqual(room.room.audio_track, audio);
  room = await rpc(1, 'command', room.room.code, { revision: room.room.revision,
    command: 'audio', media_key: 'series|tt1234|tt1234:2:7', audio_track: { mode: 'off' } });
  assert.deepEqual(room.room.audio_track, { mode: 'off' });
});

test('private channels deny nonmembers and never accept client snapshots', async () => {
  const room = await create();
  const outsider = await mf.dispatchFetch(`${origin}/r/${room.room.code}`, {
    headers: { upgrade: 'websocket', authorization: `Bearer ${token(3)}` },
  });
  assert.equal(outsider.status, 403);
  const peer = await socket(1, room.room.code);
  const closed = new Promise(resolve => peer.ws.addEventListener('close', resolve));
  peer.ws.send(JSON.stringify({ event: 'snapshot', payload: { room: { playing: false } } }));
  const event = await closed;
  assert.equal(event.code, 1008);
  const snapshot = await rpc(1, 'snapshot', room.room.code);
  assert.equal(snapshot.room.playing, true);
});

test('membership limit, removal, optimistic revision and chat deduplication', async () => {
  let room = await create();
  for (let n = 2; n <= 8; n++) room = await rpc(n, 'join', room.room.code);
  assert.equal((await rpc(9, 'join', room.room.code)).error, 'full');
  const conflict = await rpc(1, 'configure', room.room.code, { revision: 0, host_only: true });
  assert.equal(conflict.error, 'conflict');
  const payload = { body: 'once', client_id: id(988) };
  const first = await rpc(2, 'chat', room.room.code, payload);
  const second = await rpc(2, 'chat', room.room.code, payload);
  assert.equal(first.message.id, second.message.id);
  room = await rpc(1, 'remove', room.room.code, { revision: room.room.revision,
    member_id: room.members.find(member => member.name === 'Member 2').id });
  assert.equal((await rpc(2, 'heartbeat', room.room.code, { status: 'ready' })).error, 'not_member');
});

test('public descriptors strip credential-bearing URL/header fields', () => {
  assert.deepEqual(sanitizeSource({ ...source, url: 'https://secret/token', headers: { password: 'private' } }), source);
  assert.deepEqual(sanitizeAudio({ mode: 'off', volume: 0.1 }), { mode: 'off' });
  assert.equal('url' in sanitizeMedia({ ...media, url: 'private' }), false);
  assert.throws(() => sanitizeAudio({ mode: 'track', index: -1 }));
  assert.throws(() => sanitizeSource({ key: 'https://secret', name: 'bad' }));
  assert.throws(() => sanitizeSource({ key: 'other-fingerprint', name: 'bad' }));
  const hash = 'f'.repeat(40);
  assert.deepEqual(sanitizeSource({ key: `torrent:${hash}:3`, info_hash: 'forged', file_index: 99,
    name: 'https://provider.test/?token=private' }),
  { key: `torrent:${hash}:3`, info_hash: hash, file_index: 3, name: 'Source' });
  assert.equal(sanitizeSource({ ...source, name: 'token=private' }).name, 'Source');
  assert.equal(sanitizeSource({ ...source, name: 'Bearer opaque-private' }).name, 'Source');
  assert.equal(sanitizeSource({ ...source, name: 'a'.repeat(64) }).name, 'Source');
  assert.throws(() => sanitizeSource({ key: `torrent:${hash}:03`, name: 'bad' }));
  assert.equal(sanitizeSource({ ...source, name: '界'.repeat(200) }).name.length, 160);
  assert.deepEqual(sanitizeAudio({ mode: 'track', title: 'https://secret/token', language: 'ENG_us' }),
    { mode: 'track', language: 'en-us' });
  assert.throws(() => sanitizeAudio({ mode: 'track', source_key: 'arbitrary-source' }));
});
