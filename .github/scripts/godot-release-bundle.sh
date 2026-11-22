#!/usr/bin/env bash
# Turns a project's Android preset into a signed Play Store bundle (.aab) build
# with the given version, then exports it.
#   godot-release-bundle.sh <project> <version name> <version code> <output .aab>
set -euo pipefail
p="$1"
name="$2"
code="$3"
out="$4"
preset="$p/export_presets.cfg"
sed -i "s/^version\/code=.*/version\/code=$code/; s/^version\/name=.*/version\/name=\"$name\"/" "$preset"
sed -i 's/^gradle_build\/export_format=.*/gradle_build\/export_format=1/' "$preset"
# Play wants 64-bit ARM; drop the emulator-only x86_64 build from the bundle.
sed -i 's/^architectures\/x86_64=true/architectures\/x86_64=false/' "$preset"
"$(dirname "$0")/godot-export-android.sh" "$p" release "$out"
