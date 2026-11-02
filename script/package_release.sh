#!/usr/bin/env bash
set -euo pipefail

APP_NAME="Quietly"
VERSION="0.1.2"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RELEASE_DIR="$ROOT_DIR/release"
APP_BUNDLE="$RELEASE_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
UNIVERSAL_BINARY="$APP_MACOS/$APP_NAME"
ARCH_BUILD_DIR="$ROOT_DIR/.build-architectures"

if [[ -d "/Applications/Xcode.app/Contents/Developer" ]]; then
  export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
fi

cd "$ROOT_DIR"

xcrun swift build -c release --arch arm64 --scratch-path "$ARCH_BUILD_DIR/arm64"
xcrun swift build -c release --arch x86_64 --scratch-path "$ARCH_BUILD_DIR/x86_64"

ARM_BINARY="$ARCH_BUILD_DIR/arm64/arm64-apple-macosx/release/$APP_NAME"
INTEL_BINARY="$ARCH_BUILD_DIR/x86_64/x86_64-apple-macosx/release/$APP_NAME"

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_MACOS" "$APP_RESOURCES"
lipo -create "$ARM_BINARY" "$INTEL_BINARY" -output "$UNIVERSAL_BINARY"
cp "$ROOT_DIR/Resources/Info.plist" "$APP_CONTENTS/Info.plist"
cp "$ROOT_DIR/Resources/AppIcon.icns" "$APP_RESOURCES/AppIcon.icns"
chmod +x "$UNIVERSAL_BINARY"

codesign --force --deep --sign - "$APP_BUNDLE"

ZIP_PATH="$RELEASE_DIR/$APP_NAME-$VERSION-macOS-universal.zip"
rm -f "$ZIP_PATH" "$ZIP_PATH.sha256"
ditto -c -k --sequesterRsrc --keepParent "$APP_BUNDLE" "$ZIP_PATH"
shasum -a 256 "$ZIP_PATH" > "$ZIP_PATH.sha256"

file "$UNIVERSAL_BINARY"
codesign --verify --deep --strict "$APP_BUNDLE"
echo "$ZIP_PATH"
