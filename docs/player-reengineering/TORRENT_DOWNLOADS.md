# Torrent offline downloads — 2026-10-24

## Request and cause

The user wants to download a source before comparing Media3 and libmpv, and
explicitly requires downloading after closing NOVA with a completion notification.
The initial foreground Dart transfer draft was replaced before installation.
MediaDetailPage._download previously filtered every source to HTTP URLs, hiding
infoHash-only Torrentio rows. Showing rows alone could not make them downloadable.

## Implementation

- Keep torrent hashes/magnets and direct files in the offline source list; exclude
  adaptive HLS/DASH playlists. Preserve file index, filename and tracker hints.
- Use configured Debrid resolution when available; otherwise use enabled native
  P2P on Android. Direct HTTP jobs retain Android DownloadManager ownership.
- nova/torrent_downloads transfers a durable job to NovaTorrentDownloadService,
  a dataSync foreground service with stopWithTask=false and START_STICKY. It does
  not need a Flutter engine, mounted page or Activity-owned streaming server.
- TorrentDownloadStore uses AtomicFile and Android Keystore AES-GCM for native
  queue state and source hints. Dart keeps its existing secure-source store and
  local job metadata. Retry uses stable hints, never a stale localhost endpoint.
- The service downloads one job at a time using its own libtorrent session and
  ephemeral listen ports. Streaming cannot replace its handle or delete its
  private job workspace. Selected-file priorities are applied before resume.
- Validate metadata against the requested hash, bound HTTP metadata reads, keep
  file paths inside the job workspace, and require all selected-file pieces,
  expected length and a video signature before completion. Retire libtorrent
  before moving/copying the file to the normal Downloads destination.
- A partial wake lock covers active transfer work. Progress uses a low-importance
  notification; completion/failure uses a separate NOVA channel and brand icon.
  Android 13+ requests POST_NOTIFICATIONS when a torrent download is queued.
- Cancel/remove wait for the active writer to retire. Native jobs are excluded
  from the Dart HTTP worker. Closing/disposal of Flutter does not cancel them.
- Completed files open through the normal player route, allowing the same local
  file to be played by either engine without the source network affecting it.

## Platform limits

Normal closing, backgrounding and removal from Recents are supported by this
service design. Android force-stop stops app services; the app does not bypass it.
Android 15+ dataSync time limits are handled through onTimeout with a retryable
failure. Notification denial or a disabled notification channel prevents visible
completion alerts. Partial torrent pieces are retained for retry; final copy may
temporarily need additional space. Failed/removed job cleanup stays within its
validated private workspace. No iOS background torrent support is introduced.

Official references: [service types](https://developer.android.com/develop/background-work/services/fgs/service-types),
[timeouts](https://developer.android.com/develop/background-work/services/fgs/timeout),
[notification permission](https://developer.android.com/develop/ui/compose/notifications/notification-permission).

## Evidence

- Kotlin service/store/bridge compilation succeeded before final robustness edits;
  final APK build result is recorded in DUAL_ENGINE_PLAN.md.
- Flutter tests cover retained source rows, native handoff without a Dart HTTP
  request, recovery after manager disposal, cancellation serialization, retry and
  rejection of false native completion when the file is missing/incomplete.
- Physical Android background transfer: VERIFIED-ON-DEVICE on SM-A217F / Android
  12, Profile 1.0.4+67, for the user's Black Clover S2:E3 torrent selection.
  At 03:10:11 UTC, progress was 35%; at 03:10:58 UTC, it was 43%.
  Both saved samples show the foreground download service active and no NOVA
  Activity or task in Recents. A later live observation reached 64% with no NOVA
  Activity/task present. Removal itself was not performed by the assistant:
  Recents was already empty when inspected.
- The phone then disconnected from USB. The user explicitly reported that the
  download completed and its notification appeared. This is USER-REPORTED device
  evidence; final notification inspection, file integrity and offline playback
  were not independently checked after disconnection.
- The user subsequently confirmed testing both players successfully and that
  downloading works: "لقد اختبرت المشغلين وهم يعملو والتحميل يعمل". Both engines
  therefore have USER-REPORTED Android functional evidence. The exact file used,
  offline conditions and quantitative metrics were not specified.
- See `evidence/dual-engine/2026-10-24/background-torrent-result.json` and the two
  saved background samples. Quantitative engine comparison remains NOT MEASURED;
  no performance improvement is inferred from functional success.
