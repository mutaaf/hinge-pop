#!/bin/bash
# Screenshot the main screens. Usage: scripts/shots.sh <simulator name or udid> <tag> [outdir] [shot names...]
# DUOPOSE=book or tabletop pins a synthesized fold, because the simulator cannot fold by script.
cd "$(dirname "$0")/.."
SIM="$1"; TAG="$2"; OUT="${3:-build/shots}"; shift 3; ONLY="$*"
mkdir -p "$OUT"
APP=build/dd/Build/Products/Debug-iphonesimulator/HingePop.app
BID=com.mutaafaziz.hingepop
ID=$(xcrun simctl list devices available | grep -F "    $SIM (" | head -1 | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/'); [ -n "$ID" ] || ID="$SIM"
xcrun simctl boot "$ID" 2>/dev/null
xcrun simctl bootstatus "$ID" -b >/dev/null
xcrun simctl status_bar "$ID" override --time 9:41 --batteryState charged --batteryLevel 100 --wifiBars 3 2>/dev/null
xcrun simctl install "$ID" "$APP"
POSE=${DUOPOSE:+-pose $DUOPOSE}
shot() { # name settle args...
  local name="$1" settle="$2"; shift 2
  if [ -n "$ONLY" ] && ! echo " $ONLY " | grep -q " $name "; then return; fi
  xcrun simctl terminate "$ID" "$BID" 2>/dev/null
  # shellcheck disable=SC2086
  xcrun simctl launch "$ID" "$BID" $POSE ${LAND:+-landscape} "$@" >/dev/null
  sleep "$settle"
  xcrun simctl io "$ID" screenshot "$OUT/$TAG-$name.png" >/dev/null 2>&1 && echo "$TAG-$name"
}
shot home 3.5 -fresh -toured
shot map 3 -fresh -toured -unlock 14 -screen map
shot guide 3 -fresh -toured -screen guide
shot settings 3 -fresh -toured -unlock 25 -screen settings
shot tour1 3 -fresh -level 1
shot tour2 3 -fresh -level 1 -tourStep 1
shot tour6 4 -fresh -level 1 -tourStep 5
shot tour7 3 -fresh -level 1 -tourStep 6
shot tour12 3 -fresh -level 1 -tourStep 11
shot level1 3 -fresh -toured -level 1
shot play 7 -toured -level 9 -demo -demoMeter 2
shot meet 3 -fresh -toured -level 12
shot armored 6 -toured -level 15 -demo
shot gates 6 -toured -level 33 -demo
shot boss 6 -toured -level 30 -demo
shot tip 4 -toured -level 6 -demo -tip meter
shot won 7 -fresh -toured -level 3 -win
shot lost 6 -fresh -toured -level 6 -lose
shot versus 5 -toured -versus -demo
shot twotour 3 -fresh -versus
shot arcade 7 -toured -arcade -demo
