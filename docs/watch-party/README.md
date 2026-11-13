# NOVA Watch Party

Implemented on 2026-11-11 as an independent protocol, informed by the reference
research in `REVERSE_ENGINEERING.md` and `NUVIO_PARTY.md`. No reference source,
native library or hosted reference service is bundled or contacted by NOVA.

## Using the feature

- The people icon next to Search on Home opens the join dialog. Open
  **Watch together / المشاهدة الجماعية** from Library or the fullscreen
  player to create a room. A full signed-in NOVA account and active profile are
  required. Anonymous Auth guests, Kids, live channels and non-recording
  playback routes are excluded.
- Enter a six-character code such as `ABC DEF` or paste the invitation.
  Existing eight-character codes remain valid. Cloudflare invitations carry
  the relay origin so the guest can confirm the server before connecting.
- A room created from the player uses that movie/episode and current playback.
  An empty room adopts the host's next supported playback route. Each member
  uses **Join playback** inside the room. In personal-source mode this opens
  the exact room episode in the local source picker. In locked mode the guest
  resolves the leader's source fingerprint through their own installed add-ons.
  With local P2P enabled, an exact torrent hash and file index can also open
  directly. NOVA checks the selected file index after native preparation.
  A missing match displays a message and keeps the guest in the room.
  This bypasses detail metadata and local resume
  history, preserving the shared playback identity. No playable URL, torrent
  endpoint, HTTP header or service credential is
  included in the Party media descriptor.
- New rooms allow every member to play/pause/seek/change speed and select a
  shared audio track by default. The client matches the track to local engine
  IDs using language and track metadata. Device speaker volume stays local.
  The host can restrict control in **Viewers & controls**; existing rooms keep
  their previous mode. The current control mode is visible beside the playback
  action. Only the host can change room media,
  transfer the host role, remove members or end the room. Leaving and ending
  are distinct; leaving the destination with Back keeps the room active.
- Chat confirms optimistic messages by server ID plus member/client ID and
  offers retry. The current history is room-scoped, separate from cloud sync
  buckets. Membership ends on sign-out, profile switch or entry into Kids.
- Room and chat have separate tabs. Chat keeps its composer at the bottom;
  invitations stay near the room code, with viewer/admin actions disclosed
  separately and leave/end actions in the room menu.

Android registers the new invite host on the existing activity; iOS already
registers the shared scheme and forwards all incoming URLs. Pending invitation
codes are held in secure storage until a full account/profile is active.
Opening a link presents the join screen and does not silently join a room.

## Client architecture

`lib/core/watch_party/` contains immutable media/member/message snapshots, the
monotonic server clock, invitation parsing, `WatchPartyController`, and the
Supabase and Cloudflare gateways. Room membership outlives an individual player route.
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

The room calls `watch_party_playback.dart` and the shared
`media/media_playback_launcher.dart` directly. The launcher also serves normal
detail playback, retaining source headers, torrent preparation and native
retirement barriers. It rechecks room membership/media after source selection
and resolution, and before native navigation; stale prepared leases are stopped.
The binding applies pause before seeking, checks Core command outcomes rather
than discarding rejected commands, and reports native reconciliation failures.
Transport checks tolerate membership-only revisions, and a snapshot received
during native work schedules an immediate follow-up reconciliation.
An already hung native operation still owns Core's serialized command lane;
new room intent is retained until that operation completes or native ownership
is retired. The client does not create another native engine to bypass it.

When a room is opened above a different-media player, the route-local handoff
retires the old player before opening the new source picker. Core retains its
shared ownership barrier; Legacy awaits native close before releasing its
torrent, including late cleanup after a retirement timeout. A retirement
failure blocks that handoff instead of starting simultaneous playback.

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
application seeks only above 250 ms of drift, so a zero-start source does not
need seek capability merely to begin. Periodic correction seeks
above 1500 ms while playing. Paused positions use an 80 ms tolerance and
up to three accepted corrections for a stable target. Smaller playing drift starts
a local ±5% rate adjustment above 250 ms and stops inside 80 ms. Seek attempts
are spaced by at least 500 ms. Host exact samples publish every two seconds
after seek settling, using the current revision; samples cannot overwrite a
new play/pause/rate command. A runtime mismatch exceeding a bounded duration
tolerance reports a different edition while both members continue to receive
transport commands. Different edits can show different scenes at the same time.
Lock the room source to select the same edition on both devices.

Loading and buffering statuses are scoped to the exact media key. Buffering is
reported after one second. The server pauses for a loading/buffering member,
resumes when ready, and limits a wait to 15 seconds. A timed-out member is
ignored until ready, so it cannot immediately pause the room again. Browsing
members and members watching different media do not block playback. These are
implementation rules, not measured device synchronization accuracy.

## Server contract and security

Apply the migrations in order:

1. `20261111091937_watch_parties.sql`
2. `20261111092449_watch_party_access_guards.sql`
3. `20261111133733_watch_party_shared_controls.sql`
4. `20261112235452_watch_party_sources_audio_relay.sql`

All four migrations are deployed to the configured NOVA project.
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

Two separate signed-in test accounts on the deployed Supabase project each
subscribed to their private member WebSocket. Both received identical snapshots
for guest play, host seek to 128000 ms, guest pause at 128250 ms and a switch
to the Arabic audio track. End-to-end RPC and broadcast observations from the
Windows test host were 879, 819, 826 and 769 ms respectively. The server also
rejected a guest command in host-only mode, a mismatched locked source and a
relay ticket used for a different origin. The two fixture accounts were
removed. This test exercises the network protocol. Native playback latency and
speaker-to-speaker alignment on Android/iOS still require a two-phone run.

Cloudflare uses a Worker and a SQLite-backed Durable Object for the room.
The connection settings support provisioning an account-owned Worker or
testing an existing NOVA relay. See [Harbor and the NOVA relay](HARBOR_RELAY.md).

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
`watch_party_page_test.dart`, `watch_party_playback_test.dart`,
`watch_party_player_handoff_test.dart`, `media_playback_launcher_test.dart`,
and the Party interceptor regression in
`playback_session_test.dart`. Tests cover source/room generations, command echo
suppression, late disposal, reconnect history, profile switching, chat retries,
host-only control, clock/rate math and large-text Arabic/English layouts at
320×640 and 900×360.
An authoritative in-memory server fixture connects two controllers and two Core
sessions or Legacy-style engine bindings, covering both directions of play/pause/seek/
rate, rejection and echo suppression. Rendered room/chat checks also cover
390×844 with Arabic/English fonts and safe areas.

```powershell
flutter analyze --no-pub
flutter test --no-pub
```

Security advisors reported no new Party findings after the explicit access
guards. Existing findings on legacy sync and older account/collection APIs
were left in their original scope.

Final verification on 2026-11-11: **925 Flutter tests passed**, full Flutter
analysis and the final changed-file analysis reported no issues, and the
Android arm64 Release APK built successfully. Its compiled manifest contains
the `app.nova.mobile://watch-party` handler. The artifact is
`build/app/outputs/flutter-apk/app-release.apk` (about 96.4 MB).
Logs and the current artifact SHA-256 are under `.codex/watch-party-fix-*-final.log` and
`.codex/watch-party-fix-validation.json`. Android tooling reported existing Gradle,
AGP and Kotlin upgrade notices; no build configuration was changed for them.

## Two-phone feedback and remaining acceptance

The user tested Android with iPhone and confirmed room creation, invitations,
membership and chat worked. They reported that the guest had to start the
episode manually and that neither phone's pause controlled the other. The
follow-up fixes add direct exact-episode source entry, shared control by
default and native-command reconciliation regressions. These fixes still need
another physical Android/iPhone run; prior successful chat is not proof of
corrected playback synchronization.

Automated SQL claims/role tests and the public WebSocket probe do not establish
native playback synchronization. The user's invitation/chat result applies to
their reported two-phone run. Repeat with updated signed-in clients through
create/join, source selection, play/pause/seek/speed,
buffering, network loss/rejoin, host transfer/removal, profile switch, Kids,
six-hour expiry and native source/backend replacement. Measure actual drift,
latency and battery/resource use on physical Android and iPhone devices.
Codemagic/macOS compilation and iPhone runtime acceptance remain required for
iOS; no emulator was launched during implementation.
