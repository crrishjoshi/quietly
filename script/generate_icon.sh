#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMP_DIR="$(mktemp -d)"
ICONSET="$TEMP_DIR/AppIcon.iconset"
BASE_ICON="$TEMP_DIR/AppIcon-1024.png"

trap 'rm -rf "$TEMP_DIR"' EXIT

if [[ -d "/Applications/Xcode.app/Contents/Developer" ]]; then
  export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
fi

mkdir -p "$ICONSET"
xcrun swift "$ROOT_DIR/script/generate_icon.swift" "$BASE_ICON"

sips -z 16 16 "$BASE_ICON" --out "$ICONSET/icon_16x16.png" >/dev/null
sips -z 32 32 "$BASE_ICON" --out "$ICONSET/icon_16x16@2x.png" >/dev/null
sips -z 32 32 "$BASE_ICON" --out "$ICONSET/icon_32x32.png" >/dev/null
sips -z 64 64 "$BASE_ICON" --out "$ICONSET/icon_32x32@2x.png" >/dev/null
sips -z 128 128 "$BASE_ICON" --out "$ICONSET/icon_128x128.png" >/dev/null
sips -z 256 256 "$BASE_ICON" --out "$ICONSET/icon_128x128@2x.png" >/dev/null
sips -z 256 256 "$BASE_ICON" --out "$ICONSET/icon_256x256.png" >/dev/null
sips -z 512 512 "$BASE_ICON" --out "$ICONSET/icon_256x256@2x.png" >/dev/null
sips -z 512 512 "$BASE_ICON" --out "$ICONSET/icon_512x512.png" >/dev/null
cp "$BASE_ICON" "$ICONSET/icon_512x512@2x.png"

iconutil -c icns "$ICONSET" -o "$ROOT_DIR/Resources/AppIcon.icns"
echo "$ROOT_DIR/Resources/AppIcon.icns"
