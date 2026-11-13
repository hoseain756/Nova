# Harbor relay research and NOVA Cloudflare transport

Research date: 2026-11-13. The target is the user-supplied local Harbor tree at
`C:\Users\hosea\projects\app\player-refereences\harbor`. This report supplements
`REVERSE_ENGINEERING.md`; it does not replace the NOVA protocol documentation.

## Evidence and limits

The reverse-engineer-anything skill was read. REA MCP initially was absent from
the active tool list, then became available; no installation, client configuration
repair, native engine installation, or target application execution was needed.

The exact REA operation was `analyze_javascript_application` with:

```json
{
  "input_path": "C:\\Users\\hosea\\projects\\app\\player-refereences\\harbor",
  "format": "directory",
  "detail": "summary",
  "max_semantic_nodes": 30000,
  "max_semantic_nodes_per_file": 5000,
  "source_paths": [
    "package.json",
    "src/lib/together/cf-deploy.ts",
    "src/views/settings/relay-panel.tsx",
    "src/views/settings/relay-panel/use-relay-health.ts",
    "src/lib/together/invite.ts",
    "src/lib/together/relay-version.ts",
    "src/lib/together/protocol.ts",
    "src/lib/together/client.ts",
    "src-tauri/relay/worker.js",
    "src/lib/together/host-stream.ts"
  ]
}
```

| Evidence | Identifier |
|---|---|
| Complete retained application parent | `ev_ea8b1ab0a9a755ebd1ba45b4c32ac2909e6008fd859103eddf4cdeae41fcdd7c` |
| Summary projection | `ev_cca60a84be3753c2ca1a20a4f85137fb641f2dff68c233aa4e82d65a49534ff2` |
| Focused deployment/health/version facts projection | `ev_be276e8db5a97476b0048aa8903fe1985ceec9476723196c8e279d0c1c9cf726` |
| Harbor artifact root SHA-256 | `6b29ce445588057761a282757cbc049ab29d673f161d804145a6eac9582dd9a1` |

The facts projection selects the three deployment/health/version modules, 16
records from a total of 33; this is a bounded page, not an exhaustive negative
search. The parent analysis is **partial**: 5,294 inventoried files were outside
source selection and 64,008 semantic unknowns remain. REA's generic authority
label says shipped-artifact, but the input here is a local source tree. Static
syntax and candidate relationships do not establish runtime execution, a complete
call graph, or successful Cloudflare deployment. Rust deployment code was read
directly; it was not analyzed as JavaScript.

The three records were exported to the local, unversioned research artifact
`.codex/watch-party-relay-research/harbor-relay-rea.json.gz`. The uncompressed
92,984,409-byte export was checked after gzip round-trip; its SHA-256 is
`5ea60e73598d9cae06e2ee7199bc8a4764dd9324a1f2719d1cc9d45dd6610687`.
No native REA target was opened.

## Observed Harbor settings and behavior

| Concern | Source observation | NOVA implementation |
|---|---|---|
| Public relay | `src/lib/together/relay-version.ts:1` requires version 11 and declares `wss://pub.harbor.site` | NOVA retains its checked Supabase service by default. Harbor's public endpoint uses a different protocol and is not a NOVA endpoint. |
| Custom relay | `src/views/settings/relay-panel.tsx:243` reads the configured relay, copies its URL, and exposes endpoint editing | Device-local TLS origin setting, copyable server address, explicit Supabase/custom selection. |
| Health/version | `relay-panel/use-relay-health.ts:34` converts WSS to HTTPS and fetches `/health`; it measures latency and flags old versions | A credential-free `/health` check requires NOVA protocol identity and version 1 and reports round-trip latency. It does not prove account/room authorization. |
| Deployment | `src/lib/together/cf-deploy.ts:19` delegates to native Tauri commands; `src-tauri/src/cf_relay.rs:59` lists accounts and `:100` uploads the bundled module with a SQLite Durable Object migration | NOVA has an app setup wizard with account discovery, subdomain setup, bundled Worker deployment/redeployment, route enablement and public health verification. |
| Admin actions | Harbor's relay panel distinguishes saved managed deployment from an arbitrary endpoint, can check/delete the managed Worker, and can clear an endpoint without deleting it (`relay-panel.tsx:268`, `:306`, `:526`) | NOVA can check/redeploy/remove its recognized Worker with a newly supplied Cloudflare management token. Switching/resetting a local endpoint leaves the Worker running. An arbitrary unrelated Worker is not silently overwritten/deleted. |
| Invite transport | Harbor invitations can carry its relay URL and update settings (`src/components/together-modal.tsx:106`) | NOVA invitations can identify a custom relay origin, but joining requires visible confirmation before health/configuration/account capability issuance. Pasting alone performs no request. Legacy invite parsing does not silently discard the relay field. |
| Room actor | Harbor's `src-tauri/relay/worker.js:140` owns a WebSocket room, host, state and six-hour idle lifecycle | NOVA uses a separate account-bound, checked snapshot protocol with eight members, an absolute six-hour room expiry, 75-second member leases, shared controls, source locking and portable audio selection. |

These are source observations and reconstruction choices. No Harbor room was
created on a live service during this investigation. No Harbor source is copied
into NOVA's Worker, and NOVA does not call Harbor's public relay or proxy routes.

## Set up from NOVA

1. Open Watch Together connection settings and choose Cloudflare setup.
2. Use a Cloudflare API token limited to the intended account with Account Read
   and Workers Scripts Edit permissions. Select the account in NOVA rather than
   guessing an account ID. If the account has no `workers.dev` subdomain, choose
   one in the setup flow.
3. Choose the NOVA Worker name and deploy. The app uploads the canonical bundled
   `cloudflare/watch-party/src/worker.mjs`; it does not maintain a second source
   copy. The token is supplied for that setup/admin operation and is not saved
   to settings, profiles, synchronization buckets, invitations or the relay.
4. Wait for the public health check to succeed. The chosen HTTPS origin is saved
   locally; the default Supabase transport remains available through settings.
5. Share the custom-relay invitation. The recipient signs into NOVA, reviews the
   displayed relay origin and confirms it. Both devices must select the same
   service. A bare code does not identify which of several services owns it.

Configuration changes are blocked while a room is active or an entry operation
is busy. During asynchronous preference updates, room entry is temporarily
disabled so a room cannot be created under one transport and restored under
another. Manual endpoints accept only a public HTTPS/WSS origin; userinfo,
query, fragment, non-root paths, custom ports, localhost and literal IP addresses
are rejected. WSS input is normalized to an HTTPS origin without a trailing slash.
Do not paste a Harbor relay or a provider video URL into this field.

## Worker deployment contract

`cloudflare/watch-party/wrangler.jsonc` documents the deployable binding. The
module exports its default fetch handler and the `NovaPartyRoom` class. Its
Durable Object binding is `ROOMS`; first deployment uses migration tag `v1` with
`new_sqlite_classes: ["NovaPartyRoom"]`. Compatibility date is `2026-07-30`.

The deployment binds these nonsecret values:

| Variable | Value |
|---|---|
| `NOVA_RELAY_ORIGIN` | Exact public HTTPS origin of this deployment, no slash |
| `NOVA_SUPABASE_URL` | NOVA's trusted Supabase HTTPS project origin, no slash |
| `NOVA_SUPABASE_PUBLIC_KEY` | The project's publishable client key; never a service-role/secret key |

The Worker derives ticket verification's relay origin from its own configured
origin and checks the incoming request's origin. A custom domain requires its
own origin binding; pointing a different hostname at the same code without
updating that binding does not grant authorization.

For operators preferring a local CLI, first fill the three variables in the
Wrangler config and intentionally select the correct Cloudflare account/login.
From `cloudflare/watch-party/`:

```powershell
npm ci --ignore-scripts
npm test
npx --yes wrangler@4.161.0 deploy
```

The deploy command is documentation, not a deployment performed by this task.
The app wizard is the normal device setup path. Clearing an endpoint is a local
operation; removing the Worker is a separate, explicit administrative action.

## Authentication and protocol

The Flutter gateway calls `nova_party_relay_ticket` on the trusted Supabase
client with profile, local device UUID and selected relay origin. The RPC checks
the signed-in non-guest account/profile and issues a ten-minute opaque capability.
Only its hash is retained by the database. The account's Supabase access/refresh
JWT is never sent to the custom endpoint.

The Worker checks that opaque capability through `nova_party_relay_verify` at
its configured trusted Supabase project, with a publishable key and its own
configured relay origin. Client-supplied account IDs, roles, names, profile IDs
and expiry times are not authorization inputs. HTTP and WebSocket connections
use independent clients with redirects disabled; no token appears in a query
string or invitation. Capability issuance is coalesced and invalidated on account,
profile, Kids/logout scope reset. Resume lookup is hashed by account, profile,
device and relay origin, and cannot restore another account's room.

`GET /health` returns `{ok:true,protocol:"nova-watch-party",version:1}` without
credentials. `POST /rpc` uses the existing `p_action`/`p_payload` contract and
server snapshots. `GET /r/CODE` upgrades an authenticated member's private
WebSocket. Socket frames are server-authoritative; clients can send a bounded
ping, but cannot publish snapshots, impersonate another member or broadcast chat.
Capability-expired sockets close and reconnect with fresh authorization.

Guest commands require shared control permission. In a source-locked room they
also require the exact host source fingerprint. Source fingerprints are canonical
`stream:<64 lowercase hex>` or `torrent:<40/64 lowercase hex>:<index|-1>`;
torrent hash/index are derived from that key. Public labels are bounded and scrub
URL/credential patterns. Descriptors never contain playback URLs, request headers,
provider credentials, raw engine audio IDs or device volume. Portable audio mode
is `auto`, `off` or `track`; an ordinal fallback is tied to its exact `source_key`.
Host samples bootstrap absent source/audio fields and cannot overwrite a newer
explicit selection.

## Lifecycle and verification

- Rooms persist their snapshots and chat in a SQLite Durable Object. Members
  expire after 75 seconds without valid traffic; the oldest remaining member
  takes over an expired host. No member or room survives its six-hour expiry.
- Heartbeats use the existing five-second controller cadence. WebSocket reconnect
  backs off from one to ten seconds. Failed offline control actions are reported,
  not queued and replayed later. Reconnection fetches current authoritative state.
- Source loading/buffering waits are bounded to 15 seconds, matching NOVA's
  existing behavior; stale host samples do not change play/pause intent.
- A durable account quota limits create/join attempts to 40 per hour. Each room
  deduplicates account/profile/device membership and holds at most eight devices.
  The app permits one active room per controller. CF does not add a global
  cross-room device uniqueness constraint against manually constructed requests;
  this differs from the Supabase schema. Abandoned memberships still expire.
- HTTP bodies, response frames, chat and descriptors are bounded. WebSocket
  memberships are checked before connect and before each server broadcast.

`npm test` was executed against pinned Miniflare/workerd with two actual local
WebSocket clients. It covers shared pause/play/seek/chat, member-specific snapshots,
nonmember denial, forged-snapshot rejection, source lock vs host-only control,
audio/off and ordinal source key, revision conflicts, eight-member limit/removal,
chat deduplication and descriptor sanitization. The local authority RPC is mocked;
these tests do not prove an actual Cloudflare deployment, mobile network latency,
Android/iPhone engine synchronization or visual acceptance. The pinned development
dependency graph was checked with `npm audit` after patch overrides: zero reported
vulnerabilities. The deployed Worker itself has no npm runtime dependencies.

Implementation references: [Cloudflare WebSocket hibernation](https://developers.cloudflare.com/durable-objects/best-practices/websockets/),
[Durable Object configuration](https://developers.cloudflare.com/durable-objects/examples/websocket-server/),
and [Supabase changelog](https://supabase.com/changelog.md). The installed NOVA
Supabase Flutter dependency remains v2; the November v3 breaking change is not
silently introduced by this work.
