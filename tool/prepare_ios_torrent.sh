#!/usr/bin/env bash
# Build the pinned upstream engine with its HTTP listener restricted to loopback.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cache="${CM_BUILD_DIR:-$root}/build/ios_torrent_cache"
source="$cache/TorrServer"
frameworks="$root/packages/nova_ios_torrent/ios/Frameworks"
revision="8a69eadd28e6d243cea62ab6e37dbf55eb4eb77a"
mobile_version="v0.0.0-20260821190718-4776eadac327"

if [[ "$(uname -s)" != Darwin ]]; then
  echo "The embedded iOS engine requires macOS and Xcode." >&2
  exit 1
fi
mkdir -p "$cache" "$frameworks"
if [[ ! -d "$source/.git" ]]; then
  git clone --depth 1 --branch MatriX.147.2 https://github.com/YouROK/TorrServer.git "$source"
fi
test "$(git -C "$source" rev-parse HEAD)" = "$revision"

# Upstream's nil IPs bind to every network interface. A local player must
# expose its unauthenticated stream and control API on 127.0.0.1 only.
python3 - "$source/server/mobile/torrserverkit/torrserverkit.go" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
source = path.read_text()
old = '\t\tPort:     portStr,\n\t\tPath:     dataDir,'
new = '\t\tPort:     portStr,\n\t\tIPs:      []string{"127.0.0.1"},\n\t\tPath:     dataDir,'
if source.count(new) == 1:
    pass
elif source.count(old) == 1:
    path.write_text(source.replace(old, new, 1))
else:
    raise SystemExit('Cannot verify the pinned loopback binding patch')
PY

# The upstream server also enables Bonjour and local peer discovery by
# default. They are unnecessary for NOVA's on-device playback endpoint.
python3 - "$source/server/server.go" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
source = path.read_text()
old = '\t// https checks\n'
new = (
    '\tsettings.BTsets.EnableBonjour = false\n'
    '\tsettings.BTsets.EnableDLNA = false\n'
    '\tsettings.BTsets.EnableLPD = false\n'
    '\tsettings.BTsets.DisableUPNP = true\n'
    '\t// https checks\n'
)
if source.count(new) == 1:
    pass
elif source.count(old) == 1:
    path.write_text(source.replace(old, new, 1))
else:
    raise SystemExit('Cannot verify the pinned LAN discovery patch')
PY

export GOTOOLCHAIN=auto
go install "golang.org/x/mobile/cmd/gomobile@$mobile_version"
go install "golang.org/x/mobile/cmd/gobind@$mobile_version"
export PATH="$(go env GOPATH)/bin:$PATH"
gomobile init

output="$frameworks/TorrServerKit.xcframework"
cd "$source/server/mobile/torrserverkit"
go mod tidy
gomobile bind \
  -target=ios,iossimulator \
  -iosversion=18.0 \
  -tags=nosqlite \
  -ldflags="-s -w -checklinkname=0 -X server/version.Version=MatriX.147.2" \
  -trimpath \
  -o "$output" \
  .
test -f "$output/ios-arm64/TorrServerKit.framework/TorrServerKit"
echo "Built TorrServerKit $revision with loopback-only HTTP on iOS 18+"
