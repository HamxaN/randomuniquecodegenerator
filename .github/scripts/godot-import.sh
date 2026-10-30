#!/usr/bin/env bash
# Imports a project's assets, then parses every script on its own so a typo fails
# the build here with a clear message rather than later at run time.
set -euo pipefail
p="$1"
godot --headless --path "$p" --import 2>&1 | tee import.log || true
# A second pass picks up anything that depended on the first one's results.
godot --headless --path "$p" --import 2>&1 | tee -a import.log
status=0
for f in $(cd "$p" && find scripts -name '*.gd' | sort); do
  if ! out=$(godot --headless --path "$p" --check-only --script "res://$f" 2>&1); then
    echo "$out"
    echo "::error file=$p/$f::script does not parse"
    status=1
  elif echo "$out" | grep -qE "SCRIPT ERROR|Parse Error"; then
    echo "$out"
    echo "::error file=$p/$f::script does not parse"
    status=1
  fi
done
if grep -E "SCRIPT ERROR|Parse Error" import.log; then
  echo "::error::script errors during import"
  status=1
fi
exit $status
