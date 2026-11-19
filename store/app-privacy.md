# App Privacy: the answers for App Store Connect

App Privacy (the "nutrition label") has **no API**. Set it by hand in App Store Connect → Hinge Pop → App Privacy, then
**Publish**. `node ios/scripts/asc.mjs store-check` can't see it.

**Up to 0.4.0 the label is "Data Not Collected"**: those builds have no network code. That holds for 0.3.2 (in review on
2026-11-16) and for any 0.3.x/0.4.0 build.

**From 0.4.1 (the owner's call 2026-11-16, "update the native apps too"; Box Office rule 6) the app sends usage
events**, so the label changes to two rows, Usage Data → Product Interaction and Identifiers → Device ID, both for
Analytics, **linked**, **not tracking** (Cold Gas's design). **Change the label in App Store Connect and publish it in the
same submission as the 0.4.1 build**, never before (an earlier version in review must keep "Data Not Collected") and
never after (0.4.1 must not reach the store with the old label).

**From the first version after 0.5.0 that ships the health events** (the hardening pass, 2026-11-18: MetricKit
diagnostics and the in-play frame meter; whichever version this lands in, call it the *health version*) the label gains
two more rows, Diagnostics → **Crash Data** and Diagnostics → **Performance Data**, both for Analytics, **linked** (same
install id), **not tracking**. As before: **add them in App Store Connect and publish in the same submission as the
health version's build**, never before (0.5.0 and earlier keep the two-row label) and never after. Before
that submission also update the privacy policy page (`site/pages.mjs` → `privacy`, then `npm run deploy`) and the
review notes (`ios/scripts/asc.mjs`, "USAGE COUNTS") to name the health counts.

## Does the app collect data? From 0.4.1, yes.

What leaves the device, all to one host, mutaafaziz.com: Box Office's first-party relay, `mutaafaziz.com/boxoffice/e/*`
(mutaaf/box-office). Nothing else: no game server, no accounts.

| Request | What it carries | Kept |
|---|---|---|
| `POST /boxoffice/e/batch/` (usage events, **from 0.4.1, unless Settings > Privacy > Share usage stats is off**) | the web game's events (`HingePopCore/Insights.swift`): `session_start` (returning, days since the last), `game_start` (mode, level, difficulty), `game_over` (mode, level, difficulty, score, seconds, won, crossings, or draw in two-player), `tour_end` (which tour, completed or skipped). Numbers, flags and enums only; a random install id; the app's version; `platform: ios` | in the owner's PostHog project (through the relay: cookies stripped, the IP cut to /24 before it's forwarded, and `$geoip_disable` so no location is derived) |
| the same `POST` (health events, **from the health version**, same switch, same batches) | `perf_level` at each level's end (frame time p50/p95/max, dropped-frame %, the display's target rate, load time, peak node count, the worst thermal state, Low Power Mode, memory warnings, effects level, outcome); `app_metrics` about once a day from Apple's MetricKit (launch-time and hang-time histograms as counts and percentiles, peak memory, CPU/GPU seconds, foreground minutes, disk writes, exit counts by kind, app version, OS major version); `app_diagnostic` per MetricKit diagnostic (its kind, crash exception type/code and signal numbers, hang length, CPU or disk-write totals, launch time); `save_recovered` when a save had to be recovered (how). **Never** a call stack, file path, termination reason, exception name or any other text from a diagnostic: the app reads only number fields (`make -C ios rules` refuses the text ones) and `Insights.clean` drops anything outside each prop's range | same |

No account and no advertising identifier (no IDFA, no App Tracking Transparency prompt, no fingerprinting, no session
replay, no autocapture). The one identifier is the usage events' **install id**: a random UUID made on this device the
first time an event is kept, stored in UserDefaults (not the Keychain, so deleting the app resets it), and deleted by the
Settings switch along with any unsent events. Events are batched and sent at launch, at a level's end card, when a level
is left and when the app goes to the background; never during play. Debug builds send nothing (unless launched with
`-insights`), so tests, captures and our own runs never count.

## The label (0.4.1)

| Data type (Apple's name) | Collected | Purpose | Linked to the user | Used for tracking |
|---|---|---|---|---|
| Usage Data → **Product Interaction** (the usage events) | Yes | Analytics | **Yes** | **No** |
| Identifiers → **Device ID** (the random install id) | Yes | Analytics | **Yes** | **No** |

From the health version, two more rows:

| Data type (Apple's name) | Collected | Purpose | Linked to the user | Used for tracking |
|---|---|---|---|---|
| Diagnostics → **Crash Data** (`app_diagnostic`: crash kind and exception/signal numbers) | Yes | Analytics | **Yes** | **No** |
| Diagnostics → **Performance Data** (`perf_level`, `app_metrics`, and the hang/CPU/disk/launch diagnostics) | Yes | Analytics | **Yes** | **No** |

Everything else: **not collected**. No contact info, health, financial info, location (coarse or precise: the relay cuts
the IP and the events ask for no location), contacts, user content, browsing or search history, user ID, purchases,
other diagnostic data or sensitive info. Progress, scores and settings stay on the device and are never sent.

**In App Store Connect (with the 0.4.1 submission):** App Privacy → Edit → "Do you or your third-party partners collect
data from this app?" **Yes**. Tick Usage Data → *Product Interaction* and Identifiers → *Device ID*. For each: purpose
*Analytics* only; "linked to the user's identity": **Yes**; "used for tracking": **No**. Save, then **Publish**.

**In App Store Connect (with the health version's submission):** App Privacy → Edit → also tick Diagnostics → *Crash
Data* and Diagnostics → *Performance Data*. For each: purpose *Analytics* only; linked: **Yes**; tracking: **No**. Save,
then **Publish**, in the same submission as that build.

**Tracking: No.** Nothing is combined with other companies' data and nothing goes to an ad network or a data broker.
No App Tracking Transparency prompt. Adding any advertising or attribution SDK would change this answer
(`make -C ios rules` refuses them).

**Linked:** the rows are linked because every event carries the install id (the owner chose linked over dropping the
id for Cold Gas on 2026-11-13; every native app follows that design).

## The privacy manifest

`ios/HingePop/PrivacyInfo.xcprivacy` declares, from 0.4.1, `NSPrivacyCollectedDataTypeProductInteraction` and
`NSPrivacyCollectedDataTypeDeviceID` for `NSPrivacyCollectedDataTypePurposeAnalytics`, linked, not tracking.
`NSPrivacyTracking` stays false and `NSPrivacyTrackingDomains` empty (the relay is ours and nothing is tracking).
From the health version it also declares `NSPrivacyCollectedDataTypeCrashData` and
`NSPrivacyCollectedDataTypePerformanceData` (Analytics, linked, not tracking).
Required-reason APIs: UserDefaults (CA92.1: the save and its backup, the queue and the install id). `make -C ios rules`
checks the manifest declares the collected types while the sender (and, for the health rows, MetricKit or the health
events) exists.

## The privacy policy page

**https://mutaafaziz.com/hingepop/privacy/** (`site/pages.mjs` → `privacy`) says the app collects nothing up to 0.4.0 and
what it counts from 0.4.1. Deploy it (`npm run deploy`) before 0.4.1 is submitted. **Not yet updated for the health
events**: before the health version is submitted, add a line for the performance and crash numbers (as in the table
above) and deploy.

## Review notes

`ios/scripts/asc.mjs` (`STORE.reviewNotes`, and the beta review notes) carries a "USAGE COUNTS (NEW IN 0.4.1)" section;
`store-meta` sets it on the next editable version.
