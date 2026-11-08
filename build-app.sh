#!/bin/bash
# Construit build/Setal.app (signature ad hoc).
#   ./build-app.sh            → build/Setal.app
#   ./build-app.sh --install  → copie aussi dans ~/Applications
set -euo pipefail
cd "$(dirname "$0")"

APP="build/Setal.app"
swift build -c release
BIN="$(swift build -c release --show-bin-path)/Setal"

if [ ! -f build/AppIcon.icns ]; then
  swift Scripts/make-icon.swift build/AppIcon.iconset
  iconutil -c icns build/AppIcon.iconset -o build/AppIcon.icns
fi

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Setal"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp build/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
xcrun xcstringstool compile Resources/Localizable.xcstrings --output-directory "$APP/Contents/Resources"
for lang in fr en es pt; do mkdir -p "$APP/Contents/Resources/$lang.lproj"; done
codesign --force --sign - "$APP"
echo "✓ $APP"

if [ "${1:-}" = "--install" ]; then
  mkdir -p "$HOME/Applications"
  rm -rf "$HOME/Applications/Setal.app"
  cp -R "$APP" "$HOME/Applications/"
  echo "✓ installée dans ~/Applications/Setal.app"
fi
