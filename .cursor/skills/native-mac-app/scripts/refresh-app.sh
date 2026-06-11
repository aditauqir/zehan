#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../../../" && pwd)"
APP_SRC="/tmp/ZehanDerivedData/Build/Products/Debug/Zirn.app"
APP_DST="/Applications/Zirn.app"

osascript -e 'quit app "Zirn"' 2>/dev/null || true
pkill -x Zirn 2>/dev/null || true

cd "$ROOT"
xcodebuild -project Zehan.xcodeproj \
  -scheme Zehan \
  -configuration Debug \
  -derivedDataPath /tmp/ZehanDerivedData \
  clean build

rm -rf "$APP_DST"
cp -R "$APP_SRC" "$APP_DST"
/System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister -f -R -trusted "$APP_DST"
open "$APP_DST"

echo "Refreshed: $APP_DST"
