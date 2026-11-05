#!/bin/bash
# Frame times in the simulator, under a busy level with demo taps and slices. Compare runs on one machine only:
# simulator numbers show hitches and relative change, not what a device will do.
# Usage: scripts/perf.sh [simulator name] [level]
cd "$(dirname "$0")/.."
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
SIM="${1:-iPhone 17 Pro Max}"; LEVEL="${2:-29}"
APP=build/dd/Build/Products/Debug-iphonesimulator/HingePop.app
BID=com.mutaafaziz.hingepop
ID=$(xcrun simctl list devices available | grep -F "    $SIM (" | head -1 | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/')
xcrun simctl boot "$ID" 2>/dev/null; xcrun simctl bootstatus "$ID" -b >/dev/null
xcrun simctl install "$ID" "$APP"
xcrun simctl terminate "$ID" "$BID" 2>/dev/null
READY="$(xcrun simctl get_app_container "$ID" "$BID" data)/Library/Caches/hingepop.ready"; rm -f "$READY"
xcrun simctl launch "$ID" "$BID" -fresh -toured -level "$LEVEL" -demo -demoSwipe -perf >/dev/null
for _ in $(seq 1 120); do grep -q "^perf" "$READY" 2>/dev/null && break; sleep 0.5; done
grep "^perf" "$READY" || echo "no perf line"
xcrun simctl terminate "$ID" "$BID" 2>/dev/null
