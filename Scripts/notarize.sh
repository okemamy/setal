#!/bin/bash
# Notarise et agrafe build/Setal.app, puis produit dist/Setal-<version>.zip.
#
# Identifiants, au choix :
#   NOTARY_PROFILE=setal            profil créé avec `xcrun notarytool store-credentials`
#   APPLE_ID, APPLE_APP_PASSWORD, APPLE_TEAM_ID   (CI)
set -euo pipefail
cd "$(dirname "$0")/.."

APP="build/Setal.app"
VERSION="${1:-$(plutil -extract CFBundleShortVersionString raw "$APP/Contents/Info.plist")}"
mkdir -p dist
SUBMIT="dist/Setal-notarize.zip"
OUT="dist/Setal-v${VERSION}.zip"

codesign --display --verbose=2 "$APP" 2>&1 | grep -q "Authority=Developer ID Application" \
  || { echo "✗ $APP n'est pas signée Developer ID (lancer build-app.sh avec SIGN_IDENTITY)"; exit 1; }

if [ -n "${NOTARY_PROFILE:-}" ]; then
  CREDS=(--keychain-profile "$NOTARY_PROFILE")
else
  CREDS=(--apple-id "$APPLE_ID" --password "$APPLE_APP_PASSWORD" --team-id "$APPLE_TEAM_ID")
fi

ditto -c -k --keepParent "$APP" "$SUBMIT"
echo "Envoi à Apple pour notarisation (quelques minutes)…"
RESULT="$(xcrun notarytool submit "$SUBMIT" "${CREDS[@]}" --wait --output-format json)"
echo "$RESULT"
STATUS="$(echo "$RESULT" | python3 -c 'import json,sys; print(json.load(sys.stdin)["status"])')"
if [ "$STATUS" != "Accepted" ]; then
  ID="$(echo "$RESULT" | python3 -c 'import json,sys; print(json.load(sys.stdin)["id"])')"
  xcrun notarytool log "$ID" "${CREDS[@]}" || true
  echo "✗ Notarisation refusée : $STATUS"
  exit 1
fi

xcrun stapler staple "$APP"
xcrun stapler validate "$APP"
spctl --assess --type execute --verbose=2 "$APP"
rm -f "$SUBMIT"
ditto -c -k --keepParent "$APP" "$OUT"
echo "✓ $OUT (signée, notarisée, agrafée)"
