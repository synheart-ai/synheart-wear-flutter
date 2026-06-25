# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.4.6] - 2026-06-25

### Fixed
- **BLE heart-rate handler: two native crash fixes.**
  - Bounds-check the HR Measurement parser (iOS + Android) before reading the
    flags byte, the 16-bit BPM, and each RR interval — a malformed/truncated
    notification no longer traps (Swift) / throws `ArrayIndexOutOfBoundsException`
    (Android).
  - Android scan now answers the result channel at most once: a single-fire
    guard shared between `onScanFailed` and the scan timeout prevents the
    `IllegalStateException: Reply already submitted` crash.

## [0.4.5] - 2026-06-18

### Fixed
- Android: the licensed Garmin `companion-sdk:4.7.0` dependency (and its
  transitive stack — guava, slf4j, logback, SQLCipher, Room) is now wired in
  only when the AAR is actually present at
  `android/repo/.../companion-sdk-4.7.0.aar`. The AAR is gitignored and absent
  from the published package, so previously **any** consumer of the published
  package failed to build with `Could not find com.garmin.health:companion-sdk`.
  Garmin is genuinely optional: without the AAR the OSS bridge stub ships and
  Garmin calls return `UNAVAILABLE`; with it (local dev after `make garmin`, or
  a provisioned CI) the full RTS stack is included. Dart API is unchanged.

## [0.4.4] - 2026-06-18

### Added
- `SleepNightSummary.sleepLatencyMinutes`: sleep onset latency derived from
  stage timing. `HealthAdapter.fetchSleepNights` tracks the in-bed start and
  the first non-awake stage start; latency = first sleep − in-bed, or `null`
  when it can't be derived. Additive and backward-compatible.
- Android: a foreground service keeps generic BLE HRM streaming alive when the
  app is backgrounded, so heart-rate sessions no longer drop on screen-off.

### Fixed
- BLE: auto-reconnect the HR monitor on a mid-session link drop instead of
  ending the session.

## [0.4.3] - 2026-05-26

### Fixed
- iOS: BLE HRM auto-reconnect on cold start no longer fails with
  `DEVICE_NOT_FOUND`. `BleHrmHandler.connect(deviceId:)` used to rely
  on an optional chain over `CBCentralManager`, which is `nil` on the
  first BLE call after a process launch — `retrievePeripherals` and
  `retrieveConnectedPeripherals` then returned nothing and the connect
  short-circuited before the radio came up. The fix mirrors what
  `scan()` already does: lazily instantiate the central manager, and
  if the state is still `.unknown` / `.resetting`, stash the request
  in a new `pendingConnect` slot and finish it from
  `centralManagerDidUpdateState` once `.poweredOn` is reached. On
  `.poweredOff` / `.unauthorized` the pending request is failed with
  the same error codes the scan path already returns. Hosts that
  drive auto-reconnect via `BleHrmService.ensureConnected()` at app
  startup now reconnect to a previously paired strap without a manual
  "Re-scan" tap.

## [0.4.2] - 2026-05-19

### Changed
- Logging hygiene pass across the four wearable adapters (WHOOP, Garmin,
  Fitbit, Oura). Default log level demoted so a live debug run no
  longer drowns the operator in init dumps and full-payload request /
  response logs. Multi-line emoji-prefixed init blocks collapsed to one
  summary line each. Full URIs, full third-party response bodies, and
  user identifiers are no longer logged at INFO level — they're
  DEBUG-only or redacted to suffix-only at INFO. Errors and lifecycle
  events still emit at WARN/ERROR.

### Privacy
- User identifiers and OAuth state nonces are no longer logged in full
  at INFO. Full URIs and full third-party API response bodies are
  DEBUG-only.

## [0.4.1] - 2026-05-08

### Fixed
- iOS: Auto-detect `Frameworks/Companion.xcframework` at `pod install`
  time. When the licensed Garmin Companion XCFramework is present, the
  podspec now wires up `vendored_frameworks` and `-weak_framework
  Companion` automatically (previously this required hand-uncommenting
  two lines, and licensed users hit `Unable to resolve module
  dependency: 'Companion'` if they forgot). OSS consumers without the
  framework continue to get a clean `pod install`; Garmin methods
  surface `GarminSDKError` at runtime as before.

## [0.4.0] - 2026-05-07



The SDK collects normalized wearable signals from the device's platform
health store (Apple HealthKit on iOS, Health Connect on Android) and
from supported third-party vendors (WHOOP, Garmin, Oura, Fitbit) via
their public APIs. Normalization happens in the SDK; HSI generation
happens upstream in `synheart_core`.

### Public surface
- `SynheartWear` facade, `SynheartWearConfig.withAdapters({...})`.
- `DeviceAdapter` enum — `platformHealth`, `whoop`, `garmin`, `oura`,
  `fitbit`. (`platformHealth` covers both Apple HealthKit and Health
  Connect; the legacy name `appleHealthKit` was renamed to make the
  cross-platform behavior obvious.)
- `MetricType` (`hr`, `hrvRmssd`, `hrvSdnn`, `steps`, `calories`,
  `distance`, `stress`), `WearMetrics`, `PermissionType`,
  `ConsentStatus`.
- `RamenEvent` typed event surface with a `DeliveryHint` enum
  (`stream` / `ping` / `unknown`) and `RamenEventDispatcher` that
  materializes a `RamenEvent` into a payload map regardless of
  delivery flavor.
- Garmin Dart layer (platform channel, device manager, SDK adapter,
  error types, all data models — `GarminDevice`,
  `GarminConnectionState`, `GarminRealTimeData`, `GarminWellnessData`,
  `GarminSleepData`, `GarminActivityData`) ships open-source. Only
  the native Kotlin/Swift wrapper that calls Garmin SDK symbols
  requires a Garmin license; without it, Garmin methods surface
  `GarminSDKError`.
- BLE Heart Rate Monitor adapter for direct BLE sensor access.

### Platform support
- iOS 16.0+
- Android API 26+ (Android 8.0+)
- Flutter 3.10.0+

[Unreleased]: https://github.com/synheart-ai/synheart-wear-flutter/compare/v0.4.0...HEAD
[0.4.0]: https://github.com/synheart-ai/synheart-wear-flutter/releases/tag/v0.4.0
[0.3.1]: https://github.com/synheart-ai/synheart-wear-flutter/releases/tag/v0.3.1
