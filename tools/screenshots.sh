#!/bin/bash
# Captures screenshots of every game on a running emulator.
# Run by .github/workflows/screenshots.yml; results land in ./shots.
set -u
OUT=shots
mkdir -p "$OUT"

# Root lets us open any screen directly, not just each game's launcher screen.
adb root >/dev/null 2>&1 || true
sleep 3
adb wait-for-device
adb shell settings put global window_animation_scale 0.5
adb shell settings put global transition_animation_scale 0.5
DENSITY=$(adb shell wm density | tr -dc '0-9\n' | tail -1)
SIZE=$(adb shell wm size | grep -o '[0-9]*x[0-9]*' | tail -1)
SHORT=${SIZE%x*}
LONG=${SIZE#*x}
echo "Screen ${SHORT}x${LONG} @ ${DENSITY}dpi"
dp() { echo $(( $1 * DENSITY / 160 )); }

shot() {
  adb exec-out screencap -p > "$OUT/$1.png"
  echo "captured $1"
}
start() { # package activity [extras...]
  local pkg=$1 act=$2
  shift 2
  adb shell am start -W -n "$pkg/$act" "$@" >/dev/null
}
stop() { adb shell am force-stop "$1"; }
tap() { adb shell input tap "$1" "$2"; }
hold() { adb shell input swipe "$1" "$2" "$1" "$2" "$3"; }
drag() { adb shell input swipe "$1" "$2" "$3" "$4" "${5:-500}"; }

install_all() {
  for apk in app/build/outputs/apk/debug/*.apk */app/build/outputs/apk/debug/*.apk; do
    echo "installing $apk"
    adb install -r -g "$apk" >/dev/null || echo "install failed: $apk"
  done
}
install_all

# ---------------------------------------------------------------- Wash It Clean (portrait)
P=com.hamxanadeem.washitclean.debug
U=com.hamxanadeem.washitclean.ui
start $P $U.MainActivity; sleep 5; shot washitclean-1-menu
start $P $U.GameActivity; sleep 3; shot washitclean-2-dirty
# Scrub back and forth across the object.
for y in 900 1000 1100 1200 1300 1400 1500; do drag 150 $y $((SHORT - 150)) $y 350; done
sleep 1; shot washitclean-3-washing
for y in 800 950 1100 1250 1400 1550 1700; do drag $((SHORT - 150)) $y 150 $y 300; done
for y in 850 1000 1150 1300 1450 1600; do drag 150 $y $((SHORT - 150)) $y 300; done
sleep 2; shot washitclean-4-clean
start $P $U.ShopActivity; sleep 2; shot washitclean-5-shop
stop $P

# ---------------------------------------------------------------- Blocky Gems (portrait)
P=com.hamxanadeem.blockygems.debug
U=com.hamxanadeem.blockygems.ui
start $P $U.MainActivity; sleep 5; shot blockygems-1-menu
start $P $U.GameActivity --ez new_game true; sleep 3; shot blockygems-2-board
TRAY_Y=$(( LONG * 70 / 100 ))
for round in 1 2 3; do
  for slot in 1 3 5; do
    drag $(( SHORT * slot / 6 )) $TRAY_Y $(( SHORT * (slot + round) / 8 )) $(( LONG * (40 + round * 5) / 100 )) 450
    sleep 0.6
  done
done
sleep 0.3; shot blockygems-3-playing
for round in 1 2 3; do
  for slot in 5 1 3; do
    drag $(( SHORT * slot / 6 )) $TRAY_Y $(( SHORT * (8 - slot - round) / 8 )) $(( LONG * (30 + round * 6) / 100 )) 450
    sleep 0.6
  done
done
sleep 0.3; shot blockygems-4-later
stop $P

# ---------------------------------------------------------------- Penguin Slide (landscape)
P=com.hamxanadeem.penguinslide.debug
U=com.hamxanadeem.penguinslide.ui
start $P $U.MainActivity; sleep 6; shot penguinslide-1-menu
start $P $U.GameActivity; sleep 2; shot penguinslide-2-start
hold $((LONG / 2)) $((SHORT / 2)) 1800 &
sleep 1.2; shot penguinslide-3-diving
wait
sleep 1.5; shot penguinslide-4-flying
hold $((LONG / 2)) $((SHORT / 2)) 2500 &
sleep 2; shot penguinslide-5-sliding
wait
sleep 2; shot penguinslide-6-later
start $P $U.ShopActivity; sleep 2; shot penguinslide-7-outfits
stop $P

# ---------------------------------------------------------------- Screw Puzzle (portrait)
P=com.hamxanadeem.screwpuzzle.debug
U=com.hamxanadeem.screwpuzzle.ui
start $P $U.MainActivity; sleep 3; shot screwpuzzle-1-menu
sleep 3; shot screwpuzzle-2-demo
start $P $U.GameActivity; sleep 3; shot screwpuzzle-3-level
# Level 1's screws in solution order, computed from the level generator for a
# 1080x2400 @420dpi screen (see PuzzleView.layoutAreas).
n=0
for xy in "548 1527" "612 1686" "486 1197" "264 1787" "591 1235" "301 1322"; do
  tap $xy
  n=$((n + 1))
  if [ $n -eq 2 ]; then sleep 0.35; shot screwpuzzle-4-unscrewing; fi
  if [ $n -eq 3 ]; then sleep 0.8; shot screwpuzzle-5-box-filled; fi
  sleep 0.9
done
sleep 0.6; shot screwpuzzle-6-confetti
sleep 1.2; shot screwpuzzle-7-complete
stop $P

# ---------------------------------------------------------------- Idle Bakery (portrait)
P=com.hamxanadeem.idlebakery.debug
U=com.hamxanadeem.idlebakery.ui
start $P $U.MainActivity; sleep 4; shot idlebakery-1-bakery
COOKIE_Y=$(( LONG * 31 / 100 ))
BUY_X=$(( SHORT - $(dp 66) ))
for i in $(seq 1 25); do tap $(dp 60) $COOKIE_Y; sleep 0.7; done
for i in 1 2 3 4 5 6; do tap $BUY_X $COOKIE_Y; sleep 0.3; done
for i in $(seq 1 10); do tap $(dp 60) $COOKIE_Y; sleep 0.7; done
shot idlebakery-2-baking
for i in 1 2 3 4; do tap $BUY_X $COOKIE_Y; sleep 0.3; done
for i in $(seq 1 15); do tap $(dp 60) $COOKIE_Y; sleep 0.7; done
shot idlebakery-3-growing
stop $P

# ---------------------------------------------------------------- Wiggle Wars (landscape)
P=com.hamxanadeem.wigglewars.debug
U=com.hamxanadeem.wigglewars.ui
start $P $U.MainActivity; sleep 5; shot wigglewars-1-menu
# Open the vs Computer setup screen.
tap $(( LONG - $(dp 177) )) $(( SHORT / 2 - $(dp 40) )); sleep 2; shot wigglewars-2-setup
start $P $U.OnlineActivity; sleep 3; shot wigglewars-3-online
start $P $U.GameActivity --ei worms 4; sleep 4; shot wigglewars-4-battle
FIRE_X=$(( LONG - $(dp 100) - $(dp 48) ))
FIRE_Y=$(( SHORT - $(dp 47) - $(dp 24) ))
WEAPON_X=$(( LONG - $(dp 122) ))
WEAPON_Y=$(( SHORT - $(dp 136) ))
# Whoever's turn it is, keep trying to fire: our shots land on our turns, and
# the computer's turns in between give more action.
for attempt in 1 2 3 4 5; do
  drag $(( LONG / 2 + $(dp 120) )) $(( SHORT / 2 - $(dp 90) )) $(( LONG / 2 + $(dp 130) )) $(( SHORT / 2 - $(dp 100) )) 200
  hold $FIRE_X $FIRE_Y 900 &
  sleep 0.7; shot wigglewars-5-charging-$attempt
  wait
  for k in 1 2 3; do sleep 0.6; shot wigglewars-6-action-$attempt-$k; done
  sleep 2.5
done
tap $WEAPON_X $WEAPON_Y; sleep 1; shot wigglewars-7-weapons
tap $(dp 40) $(( SHORT / 2 ))
for n in 1 2 3 4 5 6 7 8; do sleep 1.5; shot wigglewars-8-later-$n; done
stop $P

echo "done: $(ls $OUT | wc -l) screenshots"
