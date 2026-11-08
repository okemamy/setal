#!/bin/bash
# Ajoute au catalogue Resources/Localizable.xcstrings les nouvelles chaînes du
# code (extraites par le compilateur). Les traductions se font ensuite dans
# Xcode : ouvrir Resources/Localizable.xcstrings.
set -euo pipefail
cd "$(dirname "$0")/.."
OUT="$(mktemp -d)"
swift build -Xswiftc -emit-localized-strings -Xswiftc -emit-localized-strings-path -Xswiftc "$OUT" >/dev/null
xcrun xcstringstool sync Resources/Localizable.xcstrings --stringsdata "$OUT"/*.stringsdata
rm -rf "$OUT"
echo "✓ catalogue synchronisé"
