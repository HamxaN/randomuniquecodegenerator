#!/usr/bin/env bash
# Exports a Godot project for Android.
#   godot-export-android.sh <project> debug|release <output .apk/.aab>
# Debug builds use a throwaway debug key. Release builds read
# KEYSTORE_PATH, KEY_ALIAS, KEYSTORE_PASSWORD from the environment.
set -euo pipefail
p="$1"
mode="$2"
out="$3"
mkdir -p "$(dirname "$out")"
ks="$HOME/debug.keystore"
if [ ! -f "$ks" ]; then
  keytool -genkeypair -keystore "$ks" -storepass android -alias androiddebugkey -keypass android \
    -keyalg RSA -keysize 2048 -validity 10000 -dname "CN=Android Debug,O=Android,C=US" >/dev/null 2>&1
fi
export GODOT_ANDROID_KEYSTORE_DEBUG_PATH="$ks"
export GODOT_ANDROID_KEYSTORE_DEBUG_USER=androiddebugkey
export GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD=android
if [ "$mode" = "release" ]; then
  export GODOT_ANDROID_KEYSTORE_RELEASE_PATH="$KEYSTORE_PATH"
  export GODOT_ANDROID_KEYSTORE_RELEASE_USER="$KEY_ALIAS"
  export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD="$KEYSTORE_PASSWORD"
fi
sdk="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-/usr/local/lib/android/sdk}}"
cfg="$HOME/.config/godot"
mkdir -p "$cfg"
ver=$(godot --version | cut -d. -f1,2)
for name in "editor_settings-4.tres" "editor_settings-${ver}.tres"; do
  cat > "$cfg/$name" <<SETTINGS
[gd_resource type="EditorSettings" format=3]

[resource]
export/android/android_sdk_path = "$sdk"
export/android/java_sdk_path = "${JAVA_HOME:-}"
export/android/debug_keystore = "$ks"
export/android/debug_keystore_user = "androiddebugkey"
export/android/debug_keystore_pass = "android"
SETTINGS
done
godot --headless --path "$p" "--export-$mode" "Android" "$out" 2>&1 | tee export.log
if [ ! -s "$out" ]; then
  echo "::error::export produced no file"
  exit 1
fi
ls -la "$out"
