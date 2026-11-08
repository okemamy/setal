#!/bin/bash
# Construit build/Setal.app (signature ad hoc).
#   ./build-app.sh            → build/Setal.app
#   ./build-app.sh --install  → copie aussi dans ~/Applications
set -euo pipefail
cd "$(dirname "$0")"

APP="build/Setal.app"
# Binaire universel : Apple Silicon et Intel.
ARCHS=(--arch arm64 --arch x86_64)
swift build -c release "${ARCHS[@]}"
BIN="$(swift build -c release "${ARCHS[@]}" --show-bin-path)/Setal"

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
# Le français est la langue source : pas de fichier compilé, mais le dossier
# doit exister pour que macOS le propose.
mkdir -p "$APP/Contents/Resources/fr.lproj"
codesign --force --sign - "$APP"
echo "✓ $APP"

if [ "${1:-}" = "--install" ]; then
  mkdir -p "$HOME/Applications"
  rm -rf "$HOME/Applications/Setal.app"
  cp -R "$APP" "$HOME/Applications/"
  echo "✓ installée dans ~/Applications/Setal.app"
fi
