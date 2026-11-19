#!/bin/bash
# Main-thread CPU in a steady state, for any build of the app, read from outside with `ps -M` (so a build from
# before a change measures the same way as one after). Runs the Mac Catalyst debug app made by perf-mac.sh.
# Usage: scripts/cpu-mac.sh <HingePop.app> <wait s> <measure s> [launch flags...]
#   scripts/cpu-mac.sh build/cat/Build/Products/Debug-maccatalyst/HingePop.app 14 10 -fresh -toured          # Home
#   scripts/cpu-mac.sh build/cat/Build/Products/Debug-maccatalyst/HingePop.app 5 15 -fresh -toured -level 29 -demo -demoSwipe
# Prints main-thread and whole-process CPU as a share of one core. Compare runs on one Mac only.
APP="$1"; WAIT="$2"; SECS="$3"; shift 3
secs() { # STIME+UTIME of the main thread (first row) and of every thread, in seconds
  ps -M -p "$1" | awk 'NR>1 { if (NR==2) { s=$7; u=$8 } else { s=$(NF-1); u=$NF }
    split(s,a,":"); split(u,b,":"); t=a[1]*60+a[2]+b[1]*60+b[2]; if (NR==2) m=t; all+=t } END { printf "%f %f\n", m, all }'
}
"$APP/Contents/MacOS/HingePop" "$@" >/dev/null 2>&1 &
PID=$!
sleep "$WAIT"
read -r m0 a0 < <(secs $PID)
sleep "$SECS"
read -r m1 a1 < <(secs $PID)
kill -9 $PID 2>/dev/null
awk -v m0="$m0" -v m1="$m1" -v a0="$a0" -v a1="$a1" -v s="$SECS" 'BEGIN { printf "main %.1f%%  process %.1f%%\n", (m1-m0)/s*100, (a1-a0)/s*100 }'
