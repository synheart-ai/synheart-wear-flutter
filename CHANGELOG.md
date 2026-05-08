# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
