#!/usr/bin/env bash
# Build 404: Alive for Android from the command line (Linux / macOS / WSL / CI).
#
#   tools/build_android.sh debug     -> build/404-alive-debug.apk   (installable, debug-signed)
#   tools/build_android.sh release   -> build/404-alive-release.apk (needs your release keystore)
#
# Requirements (see docs/BUILD_ANDROID.md):
#   * Godot 4.3+ (editor binary) on PATH as `godot`, or set GODOT=/path/to/godot
#   * Godot export templates installed for that exact version
#   * JDK 17 (JAVA_HOME or `javac` on PATH) and the Android SDK (ANDROID_HOME)
#   * For release: RELEASE_KEYSTORE, RELEASE_KEY_ALIAS, RELEASE_KEY_PASS
set -euo pipefail
cd "$(dirname "$0")/.."

MODE="${1:-debug}"
GODOT="${GODOT:-godot}"
OUT="build"
mkdir -p "$OUT"

command -v "$GODOT" >/dev/null 2>&1 || { echo "ERROR: Godot not found. Install Godot 4.3+ or set GODOT=/path/to/godot"; exit 1; }
: "${ANDROID_HOME:=${ANDROID_SDK_ROOT:-}}"
[ -n "$ANDROID_HOME" ] || { echo "ERROR: set ANDROID_HOME to your Android SDK directory"; exit 1; }
if [ -z "${JAVA_HOME:-}" ]; then
  command -v javac >/dev/null 2>&1 || { echo "ERROR: JDK 17 not found. Set JAVA_HOME."; exit 1; }
  JAVA_HOME="$(dirname "$(dirname "$(readlink -f "$(command -v javac)")")")"
fi
export ANDROID_HOME JAVA_HOME

# ---- 1. Locate (or create) Godot's editor settings file -----------------------------------------
if [ "$(uname)" = "Darwin" ]; then SETTINGS_DIR="$HOME/Library/Application Support/Godot"
else SETTINGS_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/godot"; fi
mkdir -p "$SETTINGS_DIR"
# Importing once also generates the editor settings on a fresh machine and imports all assets.
echo ">> Importing project assets..."
"$GODOT" --headless --editor --quit >/dev/null 2>&1 || true
SETTINGS_FILE="$(ls -t "$SETTINGS_DIR"/editor_settings-4*.tres 2>/dev/null | head -n1 || true)"
if [ -z "$SETTINGS_FILE" ]; then
  SETTINGS_FILE="$SETTINGS_DIR/editor_settings-4.tres"
  printf '[gd_resource type="EditorSettings" format=3]\n\n[resource]\n' > "$SETTINGS_FILE"
fi
set_setting() {  # key value
  if grep -q "^$1 = " "$SETTINGS_FILE"; then sed -i.bak "s|^$1 = .*|$1 = \"$2\"|" "$SETTINGS_FILE"
  else printf '%s = "%s"\n' "$1" "$2" >> "$SETTINGS_FILE"; fi
}
set_setting export/android/android_sdk_path "$ANDROID_HOME"
set_setting export/android/java_sdk_path "$JAVA_HOME"

# ---- 2. Signing ---------------------------------------------------------------------------------
if [ "$MODE" = "release" ]; then
  : "${RELEASE_KEYSTORE:?set RELEASE_KEYSTORE to your .keystore/.jks path}"
  : "${RELEASE_KEY_ALIAS:?set RELEASE_KEY_ALIAS}"
  : "${RELEASE_KEY_PASS:?set RELEASE_KEY_PASS (store + key password must match for Godot)}"
  export GODOT_ANDROID_KEYSTORE_RELEASE_PATH="$RELEASE_KEYSTORE"
  export GODOT_ANDROID_KEYSTORE_RELEASE_USER="$RELEASE_KEY_ALIAS"
  export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD="$RELEASE_KEY_PASS"
  EXPORT_FLAG="--export-release"
  TARGET="$OUT/404-alive-release.apk"
else
  DEBUG_KS="${DEBUG_KEYSTORE:-$HOME/.android/debug.keystore}"
  if [ ! -f "$DEBUG_KS" ]; then
    echo ">> Creating debug keystore at $DEBUG_KS"
    mkdir -p "$(dirname "$DEBUG_KS")"
    keytool -keyalg RSA -genkeypair -alias androiddebugkey -keypass android -keystore "$DEBUG_KS" \
      -storepass android -dname "CN=Android Debug,O=Android,C=US" -validity 9999 -deststoretype pkcs12
  fi
  export GODOT_ANDROID_KEYSTORE_DEBUG_PATH="$DEBUG_KS"
  export GODOT_ANDROID_KEYSTORE_DEBUG_USER="androiddebugkey"
  export GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD="android"
  set_setting export/android/debug_keystore "$DEBUG_KS"
  set_setting export/android/debug_keystore_user "androiddebugkey"
  set_setting export/android/debug_keystore_pass "android"
  EXPORT_FLAG="--export-debug"
  TARGET="$OUT/404-alive-debug.apk"
fi

# ---- 3. Export ----------------------------------------------------------------------------------
echo ">> Exporting $MODE APK -> $TARGET"
"$GODOT" --headless "$EXPORT_FLAG" "Android" "$TARGET"
[ -f "$TARGET" ] || { echo "ERROR: export produced no file - see the log above"; exit 1; }
echo ">> Done: $TARGET ($(du -h "$TARGET" | cut -f1))"
echo "   Install on a connected phone:  adb install -r \"$TARGET\""
