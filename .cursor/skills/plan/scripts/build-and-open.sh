#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../../../" && pwd)"
APP_PATH="/tmp/ZehanDerivedData/Build/Products/Debug/Zirn.app"

build() {
  cd "$ROOT"
  xcodebuild -project Zehan.xcodeproj \
    -scheme Zehan \
    -configuration Debug \
    -derivedDataPath /tmp/ZehanDerivedData \
    clean build
}

open_app() {
  if [[ ! -d "$APP_PATH" ]]; then
    echo "App not found at $APP_PATH — run a build first." >&2
    exit 1
  fi
  open "$APP_PATH"
}

case "${1:-}" in
  --build-only)
    build
    echo "Build succeeded: $APP_PATH"
    ;;
  --open-only)
    open_app
    echo "Opened: $APP_PATH"
    ;;
  "")
    build
    open_app
    echo "Build succeeded and opened: $APP_PATH"
    ;;
  *)
    echo "Usage: $0 [--build-only | --open-only]" >&2
    exit 1
    ;;
esac
