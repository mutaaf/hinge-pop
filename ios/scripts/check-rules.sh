#!/bin/bash
# The native app's privacy rules (0.4.1, the usage events; Box Office rule 6). `make rules`; `make core` runs it.
#  1. No third-party SDKs or remote Swift packages: the only packages are our own, by path.
#  2. Own origin only: every web address the app's Swift sends to is Box Office's first-party relay,
#     mutaafaziz.com/boxoffice/e/ (HingePopCore/Insights.swift); other addresses are links a person taps (mutaafaziz.com).
#  3. No ads, analytics or attribution SDKs, no advertising id and no App Tracking Transparency: the usage events are
#     our own few lines over URLSession, never an SDK.
#  4. Once the app sends anything, the privacy manifest declares what (store/app-privacy.md says which), and tracking
#     stays off. The health events add Performance Data and Crash Data.
#  5. MetricKit's text (stacks, reasons, paths) never leaves the device: the app doesn't read those fields.
set -e
cd "$(dirname "$0")/.."
fail() { echo "rules: $*" >&2; exit 1; }

# 1
grep -n "url:" project.yml | grep -v "^\s*#" && fail "a remote package in project.yml"
for p in Packages/*/Package.swift; do grep -n '\.package(url:' "$p" && fail "a remote package in $p"; done

# 2
bad=$(grep -rhoE 'https?://[^"[:space:])]+' HingePop Packages/*/Sources --include=*.swift | grep -vE '^https://mutaafaziz\.com/(hingepop|boxoffice/e)/' || true)
[ -z "$bad" ] || fail "an address that isn't ours: $bad"
grep -rn 'URLSession\|URLRequest' HingePop Packages/*/Sources --include=*.swift | grep -v 'HingePop/Usage.swift' && fail "network code outside Usage.swift"

# 3
grep -rnE 'import (AdSupport|AppTrackingTransparency|FirebaseAnalytics|PostHog|Mixpanel|Amplitude|Segment)|ASIdentifierManager|advertisingIdentifier|requestTrackingAuthorization' HingePop Packages/*/Sources --include=*.swift && fail "an advertising id, ATT or an analytics SDK"

# 4
m=HingePop/PrivacyInfo.xcprivacy
plutil -lint "$m" >/dev/null
if grep -q 'Insights.endpoint' HingePop/Usage.swift; then
  for t in NSPrivacyCollectedDataTypeProductInteraction NSPrivacyCollectedDataTypeDeviceID NSPrivacyCollectedDataTypePurposeAnalytics; do
    grep -q "$t" "$m" || fail "the privacy manifest doesn't declare $t"
  done
fi
# 4b. The health events (hardening pass): MetricKit and the frame meter send performance numbers, and crash
#     diagnostics, so the manifest must declare Performance Data and Crash Data while they exist.
if grep -q '"perf_level"\|"app_metrics"' Packages/HingePopCore/Sources/HingePopCore/Insights.swift || grep -rq 'import MetricKit' HingePop; then
  for t in NSPrivacyCollectedDataTypePerformanceData NSPrivacyCollectedDataTypeCrashData; do
    grep -q "$t" "$m" || fail "the privacy manifest doesn't declare $t"
  done
fi
# 5. MetricKit is reduced to numbers on the device: no call stacks, termination reasons, memory-region text, exception
#    names or a payload's whole JSON in the app's Swift.
grep -rnE '\.(callStackTree|callStackPerThread|terminationReason|virtualMemoryRegionInfo|exceptionReason|jsonRepresentation|dictionaryRepresentation)\b' HingePop --include=*.swift \
  && fail "a MetricKit field that carries text or stacks"
plutil -extract NSPrivacyTracking raw "$m" | grep -qx false || fail "NSPrivacyTracking must stay false"
echo "rules: ok"
