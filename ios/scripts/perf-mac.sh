#!/bin/bash
# Frame times without a simulator: builds a Mac Catalyst debug copy of the app and runs the real SpriteKit scene
# on the desktop with demo taps and slices, then prints the `-perf` line. Compare runs on one Mac only: an M-series
# GPU hides fill-rate costs a phone pays, so read it for relative change, CPU work and hitches.
# The Catalyst switch goes into the generated (gitignored) project only; `make gen` puts it back.
# Usage: scripts/perf-mac.sh [level] [extra launch flags...]   e.g. scripts/perf-mac.sh 29 -perfFever
#        NOBUILD=1 skips the build. Delete build/cat when done.
cd "$(dirname "$0")/.." || exit 1
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
LEVEL="${1:-29}"; shift
DD=build/cat
APP=$DD/Build/Products/Debug-maccatalyst/HingePop.app
if [ -z "$NOBUILD" ]; then
  [ -d HingePop.xcodeproj ] || make gen >/dev/null
  grep -q SUPPORTS_MACCATALYST HingePop.xcodeproj/project.pbxproj || \
    sed -i '' 's/TARGETED_DEVICE_FAMILY = "1,2";/TARGETED_DEVICE_FAMILY = "1,2"; SUPPORTS_MACCATALYST = YES;/' HingePop.xcodeproj/project.pbxproj
  xcodebuild -project HingePop.xcodeproj -scheme HingePop -destination 'platform=macOS,variant=Mac Catalyst' \
    -derivedDataPath $DD CODE_SIGN_IDENTITY=- -quiet build 2>&1 | grep -E "\.swift:[0-9]+:[0-9]+: error:" && exit 1
fi
READY="$HOME/Library/Caches/hingepop.ready"; rm -f "$READY"
"$APP/Contents/MacOS/HingePop" -fresh -toured -level "$LEVEL" -demo -demoSwipe -perf "$@" >/dev/null 2>&1 &
PID=$!
for _ in $(seq 1 120); do grep -q "^perf" "$READY" 2>/dev/null && break; sleep 0.5; done
grep "^perf" "$READY" || echo "no perf line"
kill $PID 2>/dev/null
