#!/usr/bin/env bash
# Installs the Godot editor and its Android export templates. The workflow caches
# both folders, so this only downloads on a cache miss.
set -euo pipefail
v="$1"
dir="$HOME/godot"
tpl="$HOME/.local/share/godot/export_templates/${v}.stable"
base="https://github.com/godotengine/godot/releases/download/${v}-stable"
mkdir -p "$dir"
if [ ! -x "$dir/godot" ]; then
  curl -sSfL -o /tmp/godot.zip "$base/Godot_v${v}-stable_linux.x86_64.zip"
  unzip -q -o /tmp/godot.zip -d "$dir"
  mv "$dir/Godot_v${v}-stable_linux.x86_64" "$dir/godot"
  rm /tmp/godot.zip
fi
if [ ! -f "$tpl/android_release.apk" ]; then
  curl -sSfL -o /tmp/templates.tpz "$base/Godot_v${v}-stable_export_templates.tpz"
  rm -rf /tmp/tpl && mkdir -p /tmp/tpl "$tpl"
  # Only the Android templates are needed.
  unzip -q -o /tmp/templates.tpz 'templates/android_*' 'templates/version.txt' -d /tmp/tpl
  mv /tmp/tpl/templates/* "$tpl/"
  rm -rf /tmp/tpl /tmp/templates.tpz
fi
echo "$dir" >> "$GITHUB_PATH"
"$dir/godot" --version
ls "$tpl"
