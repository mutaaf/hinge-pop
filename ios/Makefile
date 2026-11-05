# Hinge Pop for iPhone, iPad and iPhone Duo. `make up` is the one idempotent entry point.
SIM_PHONE ?= iPhone 17
SIM_PAD ?= iPad Pro 11-inch (M5)
DD := build/dd
export DEVELOPER_DIR ?= /Applications/Xcode.app/Contents/Developer
.PHONY: up gen icon core build test sim shots device balance clean
up: gen core sim
gen:
	@command -v xcodegen >/dev/null || brew install xcodegen
	@xcodebuild -showComponent MetalToolchain 2>/dev/null | grep -q 'Status: installed' || xcodebuild -downloadComponent MetalToolchain
	@test -f HingePop/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png || $(MAKE) icon
	xcodegen generate
icon:
	cd Packages/HingePopArt && swift run render-assets ../../build/art
	cp build/art/AppIcon-1024.png HingePop/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png
core:
	cd Packages/HingePopCore && swift test
	cd Packages/HingePopArt && swift test
balance:
	cd Packages/HingePopCore && swift run -c release hp-balance
build: gen
	xcodebuild -project HingePop.xcodeproj -scheme HingePop -destination 'platform=iOS Simulator,name=$(SIM_PHONE)' -derivedDataPath $(DD) -quiet build
test: core build
sim: build
	@for n in "$(SIM_PHONE)" "$(SIM_PAD)"; do \
	  id=$$(xcrun simctl list devices available | grep -F "    $$n (" | head -1 | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/'); \
	  xcrun simctl boot $$id 2>/dev/null || true; xcrun simctl install $$id $(DD)/Build/Products/Debug-iphonesimulator/HingePop.app; \
	  xcrun simctl launch $$id com.mutaafaziz.hingepop >/dev/null; done; open -a Simulator
shots: build
	scripts/shots.sh
device:
	scripts/device.sh
clean:
	rm -rf build HingePop.xcodeproj
