// NOVA's account-bound relay. This is an independent implementation of the
// existing NOVA snapshot protocol, not Harbor source or its unauthenticated API.
const PROTOCOL = 'nova-watch-party';
const VERSION = 1;
const ROOM_MS = 6 * 60 * 60 * 1000;
const MEMBER_MS = 75000;
const TICKET_MS = 10 * 60 * 1000;
const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const CODE = /^(?:[A-HJ-NP-Z2-9]{6}|[A-HJ-NP-Z2-9]{8})$/;
const SOURCE_KEY = /^(torrent:([a-f0-9]{40}|[a-f0-9]{64}):(-1|0|[1-9][0-9]{0,7})|stream:[a-f0-9]{64})$/;
const MAX_BODY = 32768;
const json = (value, status = 200) => new Response(JSON.stringify(value), {
  status, headers: { 'content-type': 'application/json', 'cache-control': 'no-store' },
});
const number = (value, min, max) => typeof value === 'number' &&
  Number.isFinite(value) && value >= min && value <= max;
const integer = (value, min, max) => Number.isInteger(value) && number(value, min, max);
const text = (value, max) => typeof value === 'string' && value.length > 0 && value.length <= max;
const keyOf = media => media ? `${media.type}|${media.id}|${media.video_id}` : null;

export function sanitizeMedia(value) {
  if (!value || !['movie', 'series', 'anime'].includes(value.type) ||
      !text(value.id, 300) || !text(value.video_id, 300) || !text(value.title, 300) ||
      (value.type !== 'movie' && (!integer(value.season, 0, 10000) ||
        !integer(value.episode, 0, 100000)))) throw new Error('invalid_media');
  return { id: value.id, type: value.type, video_id: value.video_id,
    title: value.title, poster: safeAvatar(value.poster),
    ...(value.type === 'movie' ? {} : { season: value.season, episode: value.episode }) };
}

export function sanitizeSource(value) {
  if (value == null) return null;
  if (typeof value.key !== 'string' || !SOURCE_KEY.test(value.key)) throw new Error('invalid_source');
  const source = { key: value.key, name: publicLabel(value.name) ?? 'Source' };
  if (value.key.startsWith('torrent:')) {
    const [, hash, index] = value.key.split(':');
    source.info_hash = hash;
    if (index !== '-1') source.file_index = Number(index);
  }
  return source;
}

function publicLabel(value) {
  if (typeof value !== 'string') return null;
  const label = value.replace(/[\x00-\x1f\x7f]/g, ' ').replace(/\s+/g, ' ').trim();
  if (!label || /(:\/\/|magnet:|bearer\s|(?:token|password|secret|api.?key|authorization|signature)\s*[:=])/i.test(label) ||
      /\b[A-Za-z0-9_-]{40,}\b/.test(label)) return null;
  return [...label].slice(0, 160).join('');
}

export function sanitizeAudio(value) {
  if (value == null) return null;
  if (!['auto', 'off', 'track'].includes(value.mode)) throw new Error('invalid_audio');
  const audio = { mode: value.mode };
  if (value.mode !== 'track') return audio;
  if (value.language != null) {
    if (!text(value.language, 35) || !/^[A-Za-z0-9_-]+$/.test(value.language)) throw new Error('invalid_audio');
    const language = value.language.toLowerCase().replace(/_/g, '-');
    const [primary, ...parts] = language.split('-');
    const mapped = { eng: 'en', ara: 'ar', jpn: 'ja', spa: 'es', fra: 'fr', fre: 'fr',
      deu: 'de', ger: 'de', zho: 'zh', chi: 'zh', kor: 'ko', por: 'pt', rus: 'ru', ita: 'it' }[primary];
    if (language !== 'und') audio.language = [mapped ?? primary, ...parts].join('-');
  }
  if (value.title != null) {
    const title = publicLabel(value.title);
    if (title) audio.title = title;
  }
  if (value.source_key != null) {
    if (typeof value.source_key !== 'string' || !SOURCE_KEY.test(value.source_key)) throw new Error('invalid_audio');
    audio.source_key = value.source_key;
  }
  if (value.index != null) {
    if (!integer(value.index, 0, 9999)) throw new Error('invalid_audio');
    audio.index = value.index;
  }
  if (audio.language == null && audio.title == null && audio.index == null) throw new Error('invalid_audio');
  return audio;
}

function safeAvatar(value) {
  if (!text(value, 2048)) return null;
  try {
    const url = new URL(value);
    return url.protocol === 'https:' && !url.username && !url.password ? value : null;
  } catch { return null; }
}

async function bodyOf(request) {
  if (Number(request.headers.get('content-length')) > MAX_BODY) throw new Error('invalid');
  const reader = request.body?.getReader();
  if (!reader) throw new Error('invalid');
  const chunks = []; let count = 0;
  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    count += value.byteLength;
    if (count > MAX_BODY) { await reader.cancel(); throw new Error('invalid'); }
    chunks.push(value);
  }
  const bytes = new Uint8Array(count); let offset = 0;
  for (const chunk of chunks) { bytes.set(chunk, offset); offset += chunk.byteLength; }
  const data = JSON.parse(new TextDecoder().decode(bytes));
  if (!data || Array.isArray(data) || typeof data !== 'object') throw new Error('invalid');
  return data;
}

export async function authorize(request, env) {
  const self = new URL(env.NOVA_RELAY_ORIGIN);
  if (self.protocol !== 'https:' || self.origin !== env.NOVA_RELAY_ORIGIN ||
      new URL(request.url).origin !== self.origin) throw new Error('account_required');
  const auth = request.headers.get('authorization') ?? '';
  const match = /^Bearer ([A-Za-z0-9_-]{32,128})$/.exec(auth);
  if (!match) throw new Error('account_required');
  const project = new URL(env.NOVA_SUPABASE_URL);
  if (project.origin !== env.NOVA_SUPABASE_URL || project.protocol !== 'https:' ||
      !/^[a-z0-9-]+\.supabase\.co$/.test(project.hostname)) throw new Error('account_required');
  // The relay capability is opaque and scoped to this deployment's own origin.
  // This fetch never contains the Flutter account's Supabase access/refresh JWT.
  const response = await fetch(`${project.origin}/rest/v1/rpc/nova_party_relay_verify`, {
    method: 'POST', redirect: 'manual', signal: AbortSignal.timeout(8000),
    headers: { apikey: env.NOVA_SUPABASE_PUBLIC_KEY, 'content-type': 'application/json' },
    body: JSON.stringify({ p_token: match[1], p_relay_url: self.origin }),
  });
  if (!response.ok) throw new Error('account_required');
  const data = await response.json();
  const identity = data?.identity;
  const now = Date.now();
  if (!identity || !UUID.test(identity.account_id) || !UUID.test(identity.profile_id) ||
      !UUID.test(identity.device_id) || !number(data.expires_at_ms, now + 1, now + TICKET_MS + 10000)) {
    throw new Error('account_required');
  }
  return { account_id: identity.account_id, profile_id: identity.profile_id,
    device_id: identity.device_id, name: text(identity.name, 80) ? identity.name : 'NOVA',
    avatar: safeAvatar(identity.avatar), expires_at_ms: data.expires_at_ms };
}

function code() {
  const alphabet = '23456789ABCDEFGHJKLMNPQRSTUVWXYZ';
  const bytes = crypto.getRandomValues(new Uint8Array(6));
  return [...bytes].map(value => alphabet[value & 31]).join('');
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (request.method === 'GET' && url.pathname === '/health') {
      return json({ ok: true, protocol: PROTOCOL, version: VERSION });
    }
    try {
      const identity = await authorize(request, env);
      const socketCode = /^\/r\/([A-HJ-NP-Z2-9]{6}|[A-HJ-NP-Z2-9]{8})$/.exec(url.pathname)?.[1];
      if (socketCode && request.headers.get('upgrade')?.toLowerCase() === 'websocket') {
        const id = env.ROOMS.idFromName(socketCode);
        return env.ROOMS.get(id).fetch(new Request(`${url.origin}/internal/connect`, {
          headers: { 'x-nova-identity': JSON.stringify(identity), upgrade: 'websocket' },
        }));
      }
      if (url.pathname !== '/rpc' || request.method !== 'POST') return json({ error: 'invalid' }, 404);
      const params = await bodyOf(request);
      if (params.p_profile_id !== identity.profile_id || params.p_device_id !== identity.device_id) {
        return json({ error: 'account_required' });
      }
      const action = params.p_action;
      if (action === 'resume' && !params.p_code) return json({ snapshot: null });
      if (action === 'create' || action === 'join') {
        const quota = env.ROOMS.get(env.ROOMS.idFromName(`quota:${identity.account_id}`));
        const allowed = await quota.fetch(new Request(`${url.origin}/internal/quota`, { method: 'POST' }));
        if (allowed.status !== 200) return json({ error: 'rate_limited' });
      }
      for (let attempt = 0; attempt < 3; attempt++) {
        const selected = action === 'create' ? code() : params.p_code;
        if (typeof selected !== 'string' || !CODE.test(selected)) return json({ error: 'not_found' });
        const id = env.ROOMS.idFromName(selected);
        const result = await env.ROOMS.get(id).fetch(new Request(`${url.origin}/internal/rpc`, {
          method: 'POST', headers: { 'x-nova-identity': JSON.stringify(identity) },
          body: JSON.stringify({ ...params, p_code: selected }),
        }));
        if (action !== 'create' || result.status !== 409) return result;
      }
      return json({ error: 'rate_limited' });
    } catch (error) {
      return json({ error: error?.message === 'account_required' ? 'account_required' : 'invalid' });
    }
  },
};

export class NovaPartyRoom {
  constructor(state, env) {
    this.state = state; this.env = env; this.room = null; this.lane = Promise.resolve();
    state.blockConcurrencyWhile(async () => { this.room = await state.storage.get('room') ?? null; });
  }
  async fetch(request) {
    const operation = async () => {
      if (new URL(request.url).pathname === '/internal/quota') {
        const now = Date.now();
        let quota = await this.state.storage.get('quota');
        if (!quota || now - quota.at >= 3600000) quota = { at: now, count: 0 };
        quota.count++;
        await this.state.storage.put('quota', quota);
        await this.state.storage.setAlarm(quota.at + 3600000);
        return json({}, quota.count <= 40 ? 200 : 429);
      }
      let identity;
      try { identity = JSON.parse(request.headers.get('x-nova-identity')); } catch { return json({ error: 'account_required' }); }
      if (!identity || identity.expires_at_ms <= Date.now()) return json({ error: 'account_required' });
      if (new URL(request.url).pathname === '/internal/connect') return this.connect(identity);
      const params = await bodyOf(request);
      const result = this.apply(params, identity, Date.now());
      await this.persist();
      this.broadcast();
      return json(result, result.error === 'already_in_room' && params.p_action === 'create' ? 409 : 200);
    };
    const response = this.lane.then(operation);
    this.lane = response.catch(() => {});
    try { return await response; } catch (error) {
      return json({ error: ['invalid_media', 'invalid_source', 'invalid_audio'].includes(error?.message)
        ? error.message : 'invalid' });
    }
  }

  member(identity) {
    return this.room?.members.find(member => member.account_id === identity.account_id &&
      member.profile_id === identity.profile_id && member.device_id === identity.device_id);
  }
  snapshot(memberId, now = Date.now()) {
    const room = this.room;
    return { self_member_id: memberId, server_time_ms: now,
      room: { id: room.id, code: room.code, host_member_id: room.host_member_id,
        host_only: room.host_only, media: room.media, source: room.source,
        source_locked: room.source_locked, audio_track: room.audio_track,
        position_ms: room.position_ms, duration_ms: room.duration_ms, playing: room.playing,
        rate: room.rate, at: room.at, revision: room.revision, waiting: room.waiting,
        ended: room.ended, expires_at: room.expires_at },
      members: room.members.map(({ id, name, avatar, status, media_key }) => ({ id, name, avatar, status, media_key })),
      messages: room.messages };
  }
  position(now) {
    const r = this.room;
    return Math.round(Math.min(r.duration_ms > 0 ? r.duration_ms : 43200000,
      r.position_ms + (r.playing ? Math.max(0, now - r.at) * r.rate : 0)));
  }
  prune(now) {
    const r = this.room;
    if (!r) return;
    const previous = r.members.length;
    r.members = r.members.filter(member => now - member.last_seen < MEMBER_MS);
    if (r.expires_at <= now || r.members.length === 0) r.ended = true;
    if (!r.members.some(member => member.id === r.host_member_id)) {
      r.host_member_id = r.members[0]?.id ?? r.host_member_id;
    }
    if (previous !== r.members.length) r.revision++;
    this.wait(now);
  }
  wait(now) {
    const r = this.room;
    if (!r || r.ended) return;
    r.ignored = r.ignored.filter(id => r.members.some(member => member.id === id && member.status !== 'ready'));
    const blocked = r.members.filter(member => ['loading', 'buffering'].includes(member.status) &&
      member.media_key === keyOf(r.media) && !r.ignored.includes(member.id)).map(member => member.id);
    if (r.waiting && (blocked.length === 0 || now >= r.wait_until)) {
      r.ignored.push(...blocked); r.waiting = false; r.playing = true; r.at = now; r.revision++;
    } else if (!r.waiting && r.playing && blocked.length) {
      r.position_ms = this.position(now); r.at = now;
      r.waiting = true; r.playing = false; r.wait_until = now + 15000; r.revision++;
    }
  }
  apply(params, identity, now) {
    const action = params.p_action, payload = params.p_payload ?? {};
    if (action !== 'create') this.prune(now);
    if (action === 'create') {
      if (this.room) return { error: 'already_in_room' };
      if (payload.host_only != null && typeof payload.host_only !== 'boolean' ||
          payload.source_locked != null && typeof payload.source_locked !== 'boolean' ||
          !integer(payload.position_ms ?? 0, 0, 43200000) ||
          !number(payload.rate ?? 1, .25, 4) ||
          payload.playing != null && typeof payload.playing !== 'boolean') return { error: 'invalid' };
      this.room = { id: crypto.randomUUID(), code: params.p_code,
        host_member_id: null, host_only: payload.host_only ?? false,
        media: payload.media == null ? null : sanitizeMedia(payload.media),
        source: sanitizeSource(payload.source), source_locked: payload.source_locked ?? false,
        audio_track: sanitizeAudio(payload.audio_track),
        position_ms: payload.position_ms ?? 0, duration_ms: 0,
        playing: payload.playing ?? false, rate: payload.rate ?? 1,
        at: now, revision: 1, waiting: false, wait_until: 0, ignored: [],
        expires_at: now + ROOM_MS, ended: false, members: [], messages: [] };
    }
    const r = this.room;
    if (!r || r.ended) return action === 'resume' ? { snapshot: null } : { error: r ? 'ended' : 'not_found' };
    let member = this.member(identity);
    if (action === 'create' || action === 'join') {
      if (!member) {
        if (r.members.length >= 8) return { error: 'full' };
        member = { ...identity, id: crypto.randomUUID(), last_seen: now,
          status: 'browsing', media_key: null, joined_at: now, limits: {} };
        r.members.push(member); r.host_member_id ??= member.id; r.revision++;
      }
    }
    if (!member) return action === 'resume' ? { snapshot: null } : { error: 'not_member' };
    if (params.p_room_id != null && params.p_room_id !== r.id) return { error: 'not_member' };
    const bucket = action === 'chat' ? 'chat' : 'transport';
    let limit = member.limits[bucket];
    if (!limit || now - limit.at >= 60000) limit = member.limits[bucket] = { at: now, count: 0 };
    if (++limit.count > (bucket === 'chat' ? 60 : 240)) return { error: 'rate_limited' };
    member.last_seen = now; member.name = identity.name; member.avatar = identity.avatar;
    const host = member.id === r.host_member_id;
    const mutated = ['media', 'configure', 'command', 'publish', 'transfer', 'remove', 'end'].includes(action);
    if (mutated && payload.revision !== r.revision) return { error: 'conflict', snapshot: this.snapshot(member.id, now) };
    if (['media', 'configure', 'publish', 'transfer', 'remove', 'end'].includes(action) && !host) return { error: 'host_required' };
    if (action === 'heartbeat') {
      if (!['browsing', 'loading', 'buffering', 'ready'].includes(payload.status)) return { error: 'invalid' };
      const permittedSource = host || !r.source_locked || (r.source && payload.source_key === r.source.key);
      member.status = permittedSource ? payload.status : 'browsing';
      member.media_key = permittedSource && text(payload.media_key, 800) ? payload.media_key : null;
    } else if (action === 'media') {
      const media = sanitizeMedia(payload.media), source = sanitizeSource(payload.source);
      const audio = sanitizeAudio(payload.audio_track);
      if (!integer(payload.position_ms ?? 0, 0, 43200000) || !number(payload.rate ?? 1, .25, 4) ||
          typeof (payload.playing ?? false) !== 'boolean') return { error: 'invalid' };
      if (payload.source_locked != null) {
        if (typeof payload.source_locked !== 'boolean') return { error: 'invalid' };
        r.source_locked = payload.source_locked;
      }
      r.media = media; r.source = source; r.audio_track = audio;
      r.position_ms = payload.position_ms ?? 0; r.duration_ms = 0;
      r.playing = payload.playing ?? false; r.rate = payload.rate ?? 1; r.at = now;
      r.waiting = false; r.ignored = [];
    } else if (action === 'command' || action === 'publish') {
      if (payload.media_key !== keyOf(r.media) || r.media == null) return { error: 'media_mismatch' };
      if (!host && (r.host_only || r.source_locked && (!r.source || payload.source_key !== r.source.key))) {
        return { error: r.host_only ? 'host_required' : 'source_mismatch' };
      }
      const cmd = action === 'publish' ? 'sample' : payload.command;
      if (cmd === 'audio') {
        const audio = sanitizeAudio(payload.audio_track);
        if (!audio) return { error: 'invalid_audio' };
        r.audio_track = audio;
      } else {
        const position = payload.position_ms ?? this.position(now);
        if (!integer(position, 0, 43200000)) return { error: 'invalid' };
        if (cmd === 'sample') {
          if (!integer(payload.duration_ms, 0, 43200000)) return { error: 'invalid' };
          const source = payload.source == null ? null : sanitizeSource(payload.source);
          const audio = payload.audio_track == null ? null : sanitizeAudio(payload.audio_track);
          if (!r.waiting) r.position_ms = position;
          r.duration_ms = payload.duration_ms;
          r.source ??= source; r.audio_track ??= audio;
        } else if (cmd === 'rate') {
          if (!number(payload.rate, .25, 4)) return { error: 'invalid' };
          r.position_ms = position; r.rate = payload.rate;
        } else if (['play', 'pause', 'seek'].includes(cmd)) {
          r.position_ms = position;
          if (cmd !== 'seek') {
            r.playing = cmd === 'play'; r.waiting = false;
            if (r.playing) r.ignored = r.members.filter(m => ['loading', 'buffering'].includes(m.status)).map(m => m.id);
          }
        } else return { error: 'invalid' };
        r.at = now;
      }
    } else if (action === 'configure') {
      const source = 'source' in payload ? sanitizeSource(payload.source) : undefined;
      for (const field of ['host_only', 'source_locked']) {
        if (field in payload && typeof payload[field] !== 'boolean') return { error: 'invalid' };
      }
      if ('host_only' in payload) r.host_only = payload.host_only;
      if ('source_locked' in payload) r.source_locked = payload.source_locked;
      if (source !== undefined) r.source = source;
    } else if (action === 'transfer' || action === 'remove') {
      const target = r.members.find(m => m.id === payload.member_id);
      if (!target || target.id === member.id) return { error: 'invalid' };
      if (action === 'transfer') r.host_member_id = target.id;
      else r.members = r.members.filter(m => m.id !== target.id);
    } else if (action === 'leave') {
      r.members = r.members.filter(m => m.id !== member.id);
      if (host) r.host_member_id = r.members[0]?.id ?? member.id;
      if (r.members.length === 0) r.ended = true;
      r.revision++; return { left: true, server_time_ms: now };
    } else if (action === 'end') {
      r.ended = true; r.revision++; return { left: true, server_time_ms: now };
    } else if (action === 'chat') {
      if (!text(payload.body?.trim(), 500) || !UUID.test(payload.client_id)) return { error: 'invalid' };
      let message = r.messages.find(m => m.member_id === member.id && m.client_id === payload.client_id);
      if (!message) {
        message = { id: crypto.randomUUID(), client_id: payload.client_id, member_id: member.id,
          name: member.name, body: payload.body.trim(), created_at: new Date(now).toISOString() };
        r.messages.push(message); r.messages = r.messages.slice(-100);
      }
      return { message, server_time_ms: now };
    } else if (!['create', 'join', 'resume', 'snapshot'].includes(action)) return { error: 'invalid' };
    this.wait(now);
    if (mutated || action === 'heartbeat') r.revision++;
    return this.snapshot(member.id, now);
  }
  async persist() {
    if (!this.room) return;
    await this.state.storage.put('room', this.room);
    const now = Date.now();
    const next = Math.min(this.room.expires_at,
      ...this.room.members.map(member => member.last_seen + MEMBER_MS),
      ...(this.room.waiting ? [this.room.wait_until] : []),
      ...this.state.getWebSockets().map(ws => ws.deserializeAttachment()?.expires_at_ms ?? now + MEMBER_MS));
    if (!this.room.ended) await this.state.storage.setAlarm(Math.max(now + 1000, next));
  }
  async connect(identity) {
    this.prune(Date.now());
    const member = this.member(identity);
    if (!this.room || this.room.ended || !member) return json({ error: 'not_member' }, 403);
    const peers = this.state.getWebSockets().filter(ws => ws.deserializeAttachment()?.member_id === member.id);
    for (const ws of peers) ws.close(4000, 'Reconnected');
    const [client, server] = Object.values(new WebSocketPair());
    server.serializeAttachment({ member_id: member.id, expires_at_ms: identity.expires_at_ms });
    this.state.acceptWebSocket(server);
    await this.persist();
    server.send(JSON.stringify({ event: 'snapshot', payload: this.snapshot(member.id) }));
    return new Response(null, { status: 101, webSocket: client });
  }
  broadcast() {
    for (const ws of this.state.getWebSockets()) {
      const identity = ws.deserializeAttachment();
      try {
        if (!identity || identity.expires_at_ms <= Date.now()) { ws.close(4001, 'Capability expired'); continue; }
        if (this.room?.ended || !this.room?.members.some(m => m.id === identity.member_id)) {
          ws.send(JSON.stringify({ event: 'closed', payload: { error: this.room?.ended ? 'ended' : 'removed' } }));
          ws.close(4000, 'Room closed'); continue;
        }
        ws.send(JSON.stringify({ event: 'snapshot', payload: this.snapshot(identity.member_id) }));
      } catch { try { ws.close(); } catch {} }
    }
  }
  async webSocketMessage(ws, message) {
    const auth = ws.deserializeAttachment();
    if (!auth || auth.expires_at_ms <= Date.now()) { ws.close(4001, 'Capability expired'); return; }
    // State is accepted only through checked HTTP actions. A socket can never
    // broadcast a forged snapshot, chat message, or host identity.
    if (typeof message !== 'string' || message.length > 1024) { ws.close(1008, 'Invalid message'); return; }
    try {
      if (JSON.parse(message).type !== 'ping') { ws.close(1008, 'Read-only channel'); return; }
      ws.send(JSON.stringify({ type: 'pong', server_time_ms: Date.now() }));
    } catch { ws.close(1008, 'Invalid message'); }
  }
  webSocketClose() {}
  webSocketError(ws) { try { ws.close(); } catch {} }
  async alarm() {
    if (!this.room) { await this.state.storage.deleteAll(); return; }
    this.prune(Date.now()); await this.persist(); this.broadcast();
    if (this.room.ended) await this.state.storage.deleteAll();
  }
}
