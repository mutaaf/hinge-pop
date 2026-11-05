#!/bin/bash
# Raw captures for Lobby, on the App Store's device sizes: 6.9" iPhone, 13" iPad and iPhone Duo (outer display).
# Waits for the app's ready file rather than guessing, and warms the simulator up first so system banners
# (Apple Intelligence and friends) have gone before the first shot. Usage: [ONLY="boss map"] store-capture.sh [iphone ipad duo]
cd "$(dirname "$0")/.."
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
RAW=../store/lobby/raw
APP=build/dd/Build/Products/Debug-iphonesimulator/HingePop.app
BID=com.mutaafaziz.hingepop
WANT="${*:-iphone ipad duo}"
capture() { # folder simulator [--display=N]
  local folder="$1" sim="$2" display="$3" dir="$RAW/$1"
  echo " $WANT " | grep -q " $folder " || return
  mkdir -p "$dir"
  local id; id=$(xcrun simctl list devices available | grep -F "    $sim (" | head -1 | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/')
  [ -n "$id" ] || { echo "no simulator named $sim"; return; }
  xcrun simctl boot "$id" 2>/dev/null; xcrun simctl bootstatus "$id" -b >/dev/null
  xcrun simctl status_bar "$id" override --time 9:41 --batteryState charged --batteryLevel 100 --wifiBars 3 2>/dev/null
  xcrun simctl install "$id" "$APP"
  xcrun simctl launch "$id" "$BID" -fresh -toured >/dev/null; sleep 15
  shot() { local name="$1" settle="$2"; shift 2
    if [ -n "$ONLY" ] && ! echo " $ONLY " | grep -q " $name "; then return; fi
    xcrun simctl terminate "$id" "$BID" 2>/dev/null
    local ready; ready="$(xcrun simctl get_app_container "$id" "$BID" data)/Library/Caches/hingepop.ready"
    rm -f "$ready"
    xcrun simctl launch "$id" "$BID" "$@" >/dev/null
    for _ in $(seq 1 60); do [ -s "$ready" ] && break; sleep 0.25; done
    sleep "$settle"
    xcrun simctl io "$id" screenshot $display "$dir/$name.png" >/dev/null 2>&1 && echo "$folder $name"; }
  shot home 2 -fresh -toured
  shot swarm 5 -fresh -toured -level 29 -demo -demoSwipe
  shot gates 5 -fresh -toured -level 37 -demo
  shot boss 5 -fresh -toured -level 40 -demo
  shot versus 5 -fresh -toured -versus -demo -demoMeter 1
  shot map 2 -fresh -toured -unlock 14 -screen map
  shot guide 2 -fresh -toured -screen guide
  shot tour 2 -fresh -level 1 -tourStep 4
  shot won 5 -fresh -toured -level 3 -win
}
capture iphone "iPhone 17 Pro Max"
capture ipad "iPad Pro 13-inch (M5)"
capture duo "Hinge Pop Duo" --display=1
