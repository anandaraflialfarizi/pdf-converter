#!/bin/bash
set -euo pipefail

SOURCE_DIR="$(cd "$(dirname "$0")" && pwd)"
OUTPUT_DIR="$SOURCE_DIR/build"
APP="$OUTPUT_DIR/pdf Converter.app"
ENGINE="${1:-/Applications/LibreOffice.app}"
BUILD_DIR="$OUTPUT_DIR"

if [ ! -x "$ENGINE/Contents/MacOS/soffice" ]; then
  echo 'Mesin LibreOffice tidak ditemukan. Jalankan: bash build.sh /lokasi/LibreOffice.app' >&2
  exit 1
fi

mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$BUILD_DIR/module-cache"
xcrun swiftc -target "$(uname -m)-apple-macos14.0" -O -swift-version 5 -module-cache-path "$BUILD_DIR/module-cache" \
  "$SOURCE_DIR/PDFConverter.swift" "$SOURCE_DIR/App.swift" \
  -framework AppKit -framework PDFKit -framework ImageIO \
  -o "$APP/Contents/MacOS/PDFLokal"
cp "$SOURCE_DIR/Info.plist" "$APP/Contents/Info.plist"
cp "$SOURCE_DIR/CREDITS.txt" "$APP/Contents/Resources/"
cp "$SOURCE_DIR/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
cp -R "$SOURCE_DIR/en.lproj" "$SOURCE_DIR/id.lproj" "$APP/Contents/Resources/"
if [ ! -d "$APP/Contents/Resources/LibreOffice.app" ]; then
  ditto "$ENGINE" "$APP/Contents/Resources/LibreOffice.app"
fi
codesign --force --sign - "$APP"
echo "$APP"
