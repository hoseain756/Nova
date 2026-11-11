# NOVA Watch Party

Implemented on 2026-11-11 as an independent protocol, informed by the reference
research in `REVERSE_ENGINEERING.md` and `NUVIO_PARTY.md`. No reference source,
native library or hosted reference service is bundled or contacted by NOVA.

## Using the feature

- Open **Watch together / المشاهدة الجماعية** from Library or the fullscreen
  player's tool row. A full signed-in NOVA account and active profile are
  required. Anonymous Auth guests, Kids, live channels and non-recording
  playback routes are excluded.
- Create a room, or enter its eight-character code. The paste button accepts a
  code or full invitation. Share/copy uses
  `app.nova.mobile://watch-party?code=ABCDEFGH`.
- A room created from the player uses that movie/episode and current playback.
  An empty room adopts the host's next supported playback route. Each member
  chooses a source from their own add-ons through the existing detail/source
  flow. No playable URL, torrent endpoint, HTTP header or service credential is
  included in the Party media descriptor.
- The host controls playback by default. Turning this switch off allows every
  member to play/pause/seek/change speed. Only the host can change room media,
  transfer the host role, remove members or end the room. Leaving and ending
  are distinct; leaving the destination with Back keeps the room active.
- Chat confirms optimistic messages by server ID plus member/client ID and
  offers retry. The current history is room-scoped, separate from cloud sync
  buckets. Membership ends on sign-out, profile switch or entry into Kids.

Android registers the new invite host on the existing activity; iOS already
registers the shared scheme and forwards all incoming URLs. Pending invitation
codes are held in secure storage until a full account/profile is active.
Opening a link presents the join screen and does not silently join a room.

## Client architecture

`lib/core/watch_party/` contains immutable media/member/message snapshots, the
monotonic server clock, invitation parsing, `WatchPartyController`, and the
Supabase gateway. Room membership outlives an individual player route.
Generation checks discard responses after scope/room changes. A reconnect
refreshes the snapshot and chat history. Five-second RPC refreshes recover
state while Realtime reconnects; network operations have a ten-second timeout.

`WatchPartyHandle` provides controller identity without subscribing the entire
fullscreen player to transport notifications. The room page listens to the
controller normally. `WatchPartyPlayerBinding` owns its own 250 ms timer and
reads exact engine state, independently from the display timeline coalescer.

Core and Legacy install a route-local transport interceptor on their existing
engine facade. Explicit user commands pass through the checked server RPC;
remote application and local drift correction use an async Zone bypass. Native
engine ownership, source retirement, torrent barriers, checkpoints and progress
storage stay with the existing player/session implementation. Detached bindings
cannot issue new native commands; status ownership prevents a retiring route
from clearing the new route's ready state.

Party playback opens paused and reconciles with the room, bypassing ordinary
resume prompts. Background pauses stay local; foreground return reconciles
again. Local tools do not pause/resume the whole room. Non-host auto-advance and
temporary 2× holds are disabled while synchronized. A foreign room title
prompts the viewer to choose its source rather than automatically opening a
URL or creating another native engine.

## Timing and buffering

Server state is `(media, position_ms, playing, rate, at, revision)`.

```text
target = position_ms + max(0, serverNow - at) × rate  (while playing)
target = position_ms                                (while paused)
```

The client anchors server time to a monotonic clock using the lowest observed
RPC RTT midpoint. Projection respects playback speed and local duration. First
application and play/pause changes seek to the room; periodic correction seeks
above 1500 ms while playing or 500 ms while paused. Smaller playing drift starts
a local ±5% rate adjustment above 250 ms and stops inside 80 ms. Seek attempts
are spaced by at least 500 ms. Host exact samples publish every two seconds
after seek settling, using the current revision; samples cannot overwrite a
new play/pause/rate command. A runtime mismatch exceeding a bounded duration
tolerance suspends synchronization and reports the different source version.

Loading and buffering statuses are scoped to the exact media key. Buffering is
reported after one second. The server pauses for a loading/buffering member,
resumes when ready, and limits a wait to 15 seconds. A timed-out member is
ignored until ready, so it cannot immediately pause the room again. Browsing
members and members watching different media do not block playback. These are
implementation rules, not measured device synchronization accuracy.

## Server contract and security

Apply both migrations in order:

1. `20261111091937_watch_parties.sql`
2. `20261111092449_watch_party_access_guards.sql`

They were applied to the existing configured NOVA project on 2026-11-11.
Their filenames match the versions returned by the deployed migration history.
No legacy sync table or account/profile sync contract was modified.

The public `nova_party(p_action, p_device_id, p_profile_id, p_room_id, p_code,
p_payload)` is a SECURITY INVOKER wrapper around a private checked implementation.
Actions: create, join, resume, snapshot, heartbeat, media, command, publish,
configure, transfer, remove, leave, end, chat. Only `authenticated` may execute;
the implementation also rejects signed-in anonymous users and validates profile
ownership and account/device membership. Client-supplied names or sender IDs
cannot grant authority. The viewing profile remains an account-owned app scope,
not an independent database principal or a new PIN authorization boundary.

All tables are in `app_private`, with RLS, explicit deny policies and no client
table grants. Mutations serialize on the room row. Device entry serializes per
account/device. Authority and optimistic revision checks occur in that
transaction. Host transfer requires the current host; stale-host replacement
elects the oldest remaining active member, rather than accepting client claims.

Broadcasts use a separate `nova-party:<member UUID>` private topic per current
member. A SELECT policy checks the Auth user, non-anonymous claim, membership
and room expiry. A restrictive INSERT policy prevents clients from sending
trusted Party broadcasts even if a future feature adds a broader policy.
After removal, the server stops sending to that topic, avoiding reliance on
the lifetime of cached channel authorization. Clients decode the Realtime SDK's
`payload` envelope before applying data.

Limits and retention:

| Rule | Value |
|---|---|
| Membership | 8 device members; one active room per account/device |
| Room lifetime | Absolute six hours, checked on every operation |
| Disconnected membership | Expires after 75 seconds without requests |
| Join/create rate | 20 per account/minute; failed guesses count |
| Other transport calls | 180 per account/minute |
| Chat | 500 Unicode characters, 20 per account/minute, at least 800 ms between new messages |
| Chat retries | Idempotent `(room, member, client UUID)` |
| Chat storage/display | Last 200 server rows, last 100 on initial/reconnect snapshot |
| Cleanup | Lazy deletion of rooms expired for a day on subsequent entry operations |

Limits are server-side. There is no passwordless public room listing or public
metadata preview. Removal blocks that account from joining the same room again.
Existing other-device memberships of that account are separate members. An
offline local Leave stops client synchronization immediately; the server
membership expires if its leave request cannot reach the service.

## Validation

`supabase/tests/watch_party_smoke.sql` creates isolated Auth/profile fixtures,
checks server behavior, executes the invoker as `authenticated`, rejects direct
table reads and forged broadcast inserts, and rejects RPC execution as `anon`.
It rolls back all fixtures, room rows and test broadcasts. The run reported
`passed` and zero remaining fixture users. It also covers failed-code rate
limits, host-only/group control, stale revisions, exact media validation,
credential stripping, buffering timeout, chat deduplication, the member cap,
removal, transfer, stale-host election and expiry.

The managed Realtime service creates daily broadcast partitions when a client
joins over WebSocket. Before the SQL role test, run:

```powershell
node supabase/tests/watch_party_realtime_connect_smoke.mjs
```

This uses only the app's public URL/key, joins a unique public probe topic, sends
no chat/data message and creates no Auth user. The connection succeeded. It
warms Supabase's managed partition window instead of changing Realtime-owned
tables. See the official [broadcast troubleshooting guide](https://supabase.com/kb/troubleshooting/realtime-warn-sending-broadcast-message).

Flutter coverage is in `watch_party_models_test.dart`,
`watch_party_controller_test.dart`, `watch_party_player_binding_test.dart`,
`watch_party_page_test.dart`, and the Party interceptor regression in
`playback_session_test.dart`. Tests cover source/room generations, command echo
suppression, late disposal, reconnect history, profile switching, chat retries,
host-only control, clock/rate math and large-text Arabic/English layouts at
320×640 and 900×360.

```powershell
flutter analyze --no-pub
flutter test --no-pub
```

Security advisors reported no new Party findings after the explicit access
guards. Existing findings on legacy sync and older account/collection APIs
were left in their original scope.

Final verification on 2026-11-11: **894 Flutter tests passed**, full Flutter
analysis and the final changed-file analysis reported no issues, and the
Android arm64 Release APK built successfully. Its compiled manifest contains
the `app.nova.mobile://watch-party` handler. The artifact is
`build/app/outputs/flutter-apk/app-release.apk` (about 96.2 MB).
Logs and the current artifact SHA-256 are under `.codex/watch-party-*.log` and
`.codex/watch-party-validation.json`. Android tooling reported existing Gradle,
AGP and Kotlin upgrade notices; no build configuration was changed for them.

## Remaining acceptance

SQL claims/role tests and a public WebSocket probe do not establish a successful
authenticated private-channel conversation between actual accounts. Run two
signed-in clients through create/join, source selection, play/pause/seek/speed,
buffering, network loss/rejoin, host transfer/removal, profile switch, Kids,
six-hour expiry and native source/backend replacement. Measure actual drift,
latency and battery/resource use on physical Android and iPhone devices.
Codemagic/macOS compilation and iPhone runtime acceptance remain required for
iOS; no emulator was launched during implementation.
