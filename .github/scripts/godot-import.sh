#!/usr/bin/env bash
# Imports a project's assets (models, textures, fonts) and fails on script errors.
# Scripts are fully exercised later by the play-test, which runs with autoloads.
set -euo pipefail
p="$1"
godot --headless --path "$p" --import > import.log 2>&1 || true
# A second pass picks up anything that depended on the first one's results.
godot --headless --path "$p" --import >> import.log 2>&1
grep -E "^(ERROR|WARNING|SCRIPT ERROR)" -A1 import.log | head -60 || true
if grep -qE "SCRIPT ERROR|Parse Error" import.log; then
  echo "::error::script errors during import"
  exit 1
fi
echo "import ok"
