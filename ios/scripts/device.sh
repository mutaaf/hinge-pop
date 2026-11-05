#!/bin/sh
# Build Hinge Pop and install it on a paired iPhone or iPad, over USB or Wi-Fi.
set -e
cd "$(dirname "$0")/.."
TEAM_ID="${TEAM_ID:-Z73865R687}"
list=$(xcrun devicectl list devices 2>/dev/null | grep 'available (paired)' || true)
DEVICE="${DEVICE:-$(echo "$list" | grep -oE '[0-9A-F]{8}-[0-9A-F]{16}' | head -1)}"
[ -n "$DEVICE" ] || { echo "No paired device available. Unlock the phone, and cable it once if it has never trusted this Mac."; exit 1; }
xcodegen generate >/dev/null
xcodebuild -project HingePop.xcodeproj -scheme HingePop -configuration Release -destination "generic/platform=iOS" \
  -derivedDataPath build/device DEVELOPMENT_TEAM="$TEAM_ID" CODE_SIGN_STYLE=Automatic -allowProvisioningUpdates -quiet build
xcrun devicectl device install app --device "$DEVICE" build/device/Build/Products/Release-iphoneos/HingePop.app
xcrun devicectl device process launch --device "$DEVICE" com.mutaafaziz.hingepop
echo "Hinge Pop is on your device."
