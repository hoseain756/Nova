# iOS local torrent playback

NOVA now routes iOS torrent sources through an embedded TorrServerKit engine and
the existing libmpv player. The torrent data and HTTP Range stream stay on the
iPhone. Debrid remains an optional alternative. This path supports playback,
not offline torrent download jobs or background P2P transfer.

## Source and build

- Upstream: `YouROK/TorrServer`, tag `MatriX.147.2`, commit
  `8a69eadd28e6d243cea62ab6e37dbf55eb4eb77a` (GPL-3.0).
- `tool/prepare_ios_torrent.sh` clones that exact source on macOS and builds
  `TorrServerKit.xcframework` into the local Flutter plugin. The binary is a
  generated build artifact, excluded from Git. The plugin podspec embeds it.
- The build patches upstream's empty `ExecArgs.IPs`, which otherwise listens
  on all interfaces, to `127.0.0.1`. It also disables Bonjour, DLNA, LPD and
  UPnP for this embedded build. The script aborts if the expected source lines
  change. Do not replace this with the upstream prebuilt XCFramework: it does
  not include NOVA's loopback restriction.
- New Runner builds and the plugin require iOS 18.0 or later. The user approved
  this minimum change. The generated iOS Podfile must resolve the local plugin.

## Playback flow

`TorrentService` keeps the existing player and ownership API. On iOS it calls
`IosTorrentService`, which starts the native engine, adds the magnet to the
local `/torrents` API, waits for metadata, selects the exact add-on file index
or filename, then hands `/stream/<name>?link=<hex>&index=<one-based>&play`
to libmpv. Add-on `fileIdx` remains zero-based; TorrServer IDs are one-based.
Stopping playback drops the active torrent and keeps its cached pieces. Only
one active torrent is owned by this adapter at a time.

## Verification boundary

The Dart hash and local API mapping tests plus Flutter analysis run on Windows.
They do not compile the Swift bridge or the Go XCFramework. Run the repository
`nova-ios-validation` Codemagic workflow, inspect the unsigned Release IPA,
then test on an iPhone running iOS 18+ with a known healthy torrent and a multi-file episode
pack. Check playback start, seek, source switching, cancel/exit, cellular and
Wi-Fi use, and that the local HTTP port is unreachable from another device.
TorrServerKit carries GPL-3.0 source and license obligations for any distributed
combined app; review those obligations before distribution.
