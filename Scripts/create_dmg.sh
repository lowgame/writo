#!/usr/bin/env bash
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
cd "$DIR"

# 1. Ensure latest app is built
./Scripts/build_app.sh

# 2. Create staging directory for DMG
DMG_STAGING="build/dmg_staging"
rm -rf "$DMG_STAGING"
mkdir -p "$DMG_STAGING"

# Copy Writo.app
cp -R "build/Writo.app" "$DMG_STAGING/Writo.app"

# Create Applications symlink
ln -s /Applications "$DMG_STAGING/Applications"

# 3. Create compressed DMG
DMG_PATH="build/writo.dmg"
rm -f "$DMG_PATH"
hdiutil create -volname "Writo" -srcfolder "$DMG_STAGING" -ov -format UDZO "$DMG_PATH"
rm -rf "$DMG_STAGING"

# 4. Create ZIP archive
cd build
rm -f writo.zip
zip -r -y writo.zip Writo.app
cd "$DIR"

echo "=== Packaging Complete ==="
echo "DMG: build/writo.dmg"
echo "ZIP: build/writo.zip"
