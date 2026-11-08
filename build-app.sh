#!/bin/bash
# Construit build/Setal.app (signature ad hoc).
#   ./build-app.sh            → build/Setal.app
#   ./build-app.sh --install  → copie aussi dans ~/Applications
#
# Signature : ad hoc par défaut. Avec SIGN_IDENTITY (par ex.
# "Developer ID Application: Nom (TEAMID)"), signature Developer ID avec le
# hardened runtime et un horodatage, prête pour Scripts/notarize.sh.
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
if [ -n "${SIGN_IDENTITY:-}" ]; then
  codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$APP"
  codesign --verify --strict --verbose=2 "$APP"
else
  codesign --force --sign - "$APP"
fi
echo "✓ $APP"

if [ "${1:-}" = "--install" ]; then
  mkdir -p "$HOME/Applications"
  rm -rf "$HOME/Applications/Setal.app"
  cp -R "$APP" "$HOME/Applications/"
  echo "✓ installée dans ~/Applications/Setal.app"
fi
