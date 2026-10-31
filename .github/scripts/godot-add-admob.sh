#!/usr/bin/env bash
# Adds the Poing Studios AdMob plugin to a Godot project for an Android build:
# the GDScript API, its Android libraries, the AdMob app ID and the ad unit IDs,
# and switches the export to a Gradle build (the plugin pulls in Google's SDK).
#   godot-add-admob.sh <project> [app_id] [banner_id] [interstitial_id] [rewarded_id]
# Without IDs it uses Google's public test IDs.
set -euo pipefail
p="$1"
app_id="${2:-ca-app-pub-3940256099942544~3347511713}"
banner="${3:-ca-app-pub-3940256099942544/6300978111}"
interstitial="${4:-ca-app-pub-3940256099942544/1033173712}"
rewarded="${5:-ca-app-pub-3940256099942544/5224354917}"
plugin_version="v5.1.0"
godot_version="v$(godot --version | cut -d. -f1-3)"
base="https://github.com/poingstudios/godot-admob-plugin/releases/download/$plugin_version"
tmp=$(mktemp -d)
curl -sSfL -o "$tmp/plugin.zip" "$base/poing-godot-admob-$plugin_version.zip"
curl -sSfL -o "$tmp/android.zip" "$base/android-template-$godot_version.zip"
unzip -q "$tmp/plugin.zip" -d "$tmp/plugin"
mkdir -p "$p/addons"
rm -rf "$p/addons/admob"
cp -r "$tmp/plugin/poing-godot-admob/addons/admob" "$p/addons/admob"
mkdir -p "$p/addons/admob/android/bin"
unzip -q "$tmp/android.zip" -d "$p/addons/admob/android/bin"
rm -rf "$tmp"
cat >> "$p/project.godot" <<CFG

[editor_plugins]

enabled=PackedStringArray("res://addons/admob/plugin.cfg")

[admob]

general/android/enabled=true
general/android/app_id="$app_id"
CFG
cat > "$p/ad_units.cfg" <<CFG
[admob]
banner="$banner"
interstitial="$interstitial"
rewarded="$rewarded"
CFG
sed -i 's/^gradle_build\/use_gradle_build=false/gradle_build\/use_gradle_build=true/' "$p/export_presets.cfg"
# Install the Gradle build template into the project.
godot --headless --path "$p" --install-android-build-template --quit > /dev/null 2>&1 || true
if [ ! -d "$p/android/build" ]; then
  mkdir -p "$p/android/build"
  unzip -q -o "$HOME/.local/share/godot/export_templates/$(godot --version | cut -d. -f1-3 | sed 's/$/.stable/')/android_source.zip" -d "$p/android/build"
  godot --version | cut -d. -f1-4 > "$p/android/.build_version"
  touch "$p/android/build/.gdignore"
fi
# Re-import so the plugin's scripts are registered.
godot --headless --path "$p" --import > admob-import.log 2>&1 || true
echo "AdMob plugin $plugin_version added to $p"
