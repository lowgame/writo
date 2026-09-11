#!/usr/bin/env bash
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
cd "$DIR"

echo "=== [1/3] Derleniyor: Swift Release ==="
swift build -c release

echo "=== [2/3] Paketleniyor: Writo.app ==="
APP_BUNDLE="build/Writo.app"
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Copy binary
cp ".build/release/Writo" "$APP_BUNDLE/Contents/MacOS/Writo"

# Copy Info.plist
cp "Resources/Info.plist" "$APP_BUNDLE/Contents/Info.plist"

# Copy AppIcon
cp "Resources/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
cp "Resources/AppIcon.png" "$APP_BUNDLE/Contents/Resources/AppIcon.png"

echo "=== [3/3] İmzalanıyor: Ad-hoc Codesign ==="
codesign --force --deep --sign - "$APP_BUNDLE"

# Also sync to root Writo.app for local development
rm -rf Writo.app
cp -R "$APP_BUNDLE" Writo.app

echo "Tamamlandı: $APP_BUNDLE başarıyla oluşturuldu!"
