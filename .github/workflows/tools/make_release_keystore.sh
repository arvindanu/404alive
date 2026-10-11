#!/usr/bin/env bash
# Creates the release keystore used to sign the APK/AAB you publish.
# !! Back it up somewhere safe and NEVER commit it. If you lose it you cannot update your Play Store app.
# Godot requires the store password and key password to be the same.
set -euo pipefail
OUT="${1:-$HOME/dont-look-back-release.keystore}"
ALIAS="${2:-dontlookback}"
[ -f "$OUT" ] && { echo "$OUT already exists - refusing to overwrite"; exit 1; }
read -r -s -p "Choose a keystore password (min 6 chars): " PW; echo
keytool -genkeypair -v -keystore "$OUT" -alias "$ALIAS" -keyalg RSA -keysize 2048 -validity 10000 \
  -storepass "$PW" -keypass "$PW"
echo
echo "Created $OUT (alias: $ALIAS). Build a signed release with:"
echo "  RELEASE_KEYSTORE=$OUT RELEASE_KEY_ALIAS=$ALIAS RELEASE_KEY_PASS=... tools/build_android.sh release"
