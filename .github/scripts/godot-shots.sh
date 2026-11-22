#!/usr/bin/env bash
# Runs the game under a virtual display with software OpenGL. The game's own
# --shots mode plays itself, saves screenshots and quits. Any script error fails.
set -euo pipefail
p="$1"
out="$2"
res="${3:-1600x720}"
sudo apt-get update -qq >/dev/null
sudo apt-get install -y -qq xvfb libgl1-mesa-dri libglx-mesa0 >/dev/null
mkdir -p "$out"
set +e
timeout 600 xvfb-run -a -s "-screen 0 ${res}x24" \
  godot --path "$p" --rendering-driver opengl3 --audio-driver Dummy --resolution "$res" --position 0,0 \
  -- --shots="$out" 2>&1 | tee shots.log
code=${PIPESTATUS[0]}
set -e
echo "exit code: $code"
ls -la "$out"
fail=0
if grep -nE "SCRIPT ERROR|Parse Error" shots.log; then
  echo "::error::script errors while playing"
  fail=1
fi
if ! grep -q "SHOTS DONE" shots.log; then
  echo "::error::the play-test did not finish"
  fail=1
fi
other=$(grep -cE "^ERROR:" shots.log || true)
if [ "$other" != "0" ]; then
  echo "::warning::$other engine errors logged (see shots.log)"
fi
exit $fail
