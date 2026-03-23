# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.3.1] - 2026-02-18

### Changed

- **Architecture boundary** - Enforced Wear/Input-layer invariants: this SDK collects and normalizes wearable signals, but does not generate HSI.
- **Native packaging** - Removed any Flux binary vendoring hooks from Android Gradle and iOS podspec.
- **Docs** - Updated README/CI/publish to reflect the Wear SDK API surface and pub.dev packaging.

### Removed

- **Flux integration** - Removed Flux/HSI APIs and native FFI bindings from `synheart_wear`. Use `synheart-flux` (HSI generation) and Synheart Core (orchestration/ingestion) instead.
- **Dependency** - Removed the `ffi` package dependency (no longer needed).

## [0.3.0] - 2026-02-17

### Added

- **Garmin Health SDK Integration** - Native device pairing, scanning, and real-time streaming
  - Added `GarminHealth` facade for native Garmin device integration (scan, pair, stream)
  - Supports Companion SDK (direct Bluetooth) and Standard SDK (via Garmin Connect Mobile)
  - Real-time biometric data streaming from Garmin wearables
  - See `GARMIN_SETUP.md` for setup instructions
- **BLE Heart Rate Monitor Support** - Direct BLE sensor access
  - Added BLE HRM bridge and models for generic Bluetooth heart rate sensors
  - Platform-native BLE scanning and connection
- **Wearable Device Models** - Generic wearable device types
  - Added `ScannedDevice`, `PairedDevice`, `DeviceConnectionState`, `DeviceConnectionEvent`
  - Unified device model across all adapter types

### Changed

- **Flux FFI** - Improved native library loading with symbol validation and graceful degradation
  - Added `_requiredSymbols` validation to prevent binding against incompatible libraries
  - Methods return `null` instead of throwing on failure for graceful degradation
  - Refactored library loading to use candidate path list pattern
  - Safer dispose with try-catch around native free calls
- **Podspec** - Updated iOS minimum to 16.0, added Flux XCFramework conditional bundling

## [0.2.3] - 2026-01-26

### Added

- **Flux Integration** - HSI 1.0 compliant data processing pipeline
  - Added `readFluxSnapshot()` method to `SynheartWear` for converting vendor data to HSI 1.0 format
  - Added `fetchRawDataForFlux()` to `WhoopProvider` for fetching and formatting WHOOP data for Flux
  - Added `fetchRawDataForFlux()` to `GarminProvider` for fetching and formatting Garmin data for Flux
  - Native Flux binaries automatically bundled for pub.dev users (no setup required)
  - Support for WHOOP and Garmin data processing into HSI-compliant format
  - Automatic data transformation (removes UUIDs, ensures required fields, calculates missing values)
  - HSI output includes sleep, physiology, and activity data organized by daily windows
- **Base URL Configuration** - Updated default base URL to `https://wear-service-dev.synheart.io` for both WHOOP and Garmin integrations
  - Automatic migration logic to update stored base URLs from old endpoints
  - Preserves explicitly provided base URLs while updating defaults
- **Comprehensive Logging** - Enhanced debugging capabilities across all providers
  - Added detailed logging to WHOOP OAuth flow (initialization, authorization, connection)
  - Added detailed logging to Garmin OAuth flow (initialization, authorization, deep link handling)
  - Improved SSE connection logging with connection status and event details
- **SSE Reconnection Logic** - Automatic reconnection for Server-Sent Events
  - Automatic reconnection attempts when SSE connection closes unexpectedly
  - Improved error handling to distinguish between normal closures and actual errors
  - Better buffer handling for incomplete SSE events
  - Heartbeat detection (comment lines starting with `:`) for connection health monitoring
- **WHOOP Historical Data Methods** - Added methods for fetching historical WHOOP data
  - `fetchRecovery()` - Fetch recovery data
  - `fetchSleep()` - Fetch sleep data
  - `fetchWorkouts()` - Fetch workout data
  - `fetchCycles()` - Fetch cycle data
- **Garmin Data Fetching Methods** - Added comprehensive methods for fetching Garmin data
  - `fetchDailies()` - Daily summary data
  - `fetchEpochs()` - Epoch-level activity data
  - `fetchSleeps()` - Sleep data
  - `fetchStressDetails()` - Stress data
  - `fetchHRV()` - Heart rate variability data
  - `fetchUserMetrics()` - User metrics
  - `fetchBodyComps()` - Body composition data
  - `fetchPulseOx()` - Pulse oximetry data
  - `fetchRespiration()` - Respiration data
  - `fetchHealthSnapshot()` - Health snapshot data
  - `fetchBloodPressures()` - Blood pressure data
  - `fetchSkinTemp()` - Skin temperature data

### Changed

- **README Documentation** - Comprehensive improvements to initialization patterns and usage examples
  - Added explicit permission control pattern (recommended approach) with step-by-step guidance
  - Added alternative simplified initialization pattern for cases where custom reason isn't needed
  - Documented initialization validation behavior (`NO_WEARABLE_DATA`, `STALE_DATA` error codes)
  - Enhanced error handling examples with common error codes and proper exception handling
  - Added stream subscription lifecycle documentation with proper cleanup examples
  - Clarified platform-specific permission handling (Android vs iOS differences)
  - Added new "Initialization Flow & Best Practices" section explaining both patterns
  - Fixed inconsistencies between README examples and actual SDK implementation
  - Added note about config default constructor including fitbit adapter
- **WHOOP Authentication** - Fixed authentication response validation
  - Changed from checking string `status` field to boolean `success` field
  - Improved error message extraction from API responses
  - Better handling of API response structure
- **SSE Event Parsing** - Improved SSE event parsing to align with Go and Bash test clients
  - Only requires `currentData` to process an event (not both `currentEvent` and `currentData`)
  - Defaults event type to `'message'` if no `event:` field is present
  - Correctly handles comment lines (heartbeats) by logging them as debug messages
- **Garmin OAuth Flow** - Enhanced OAuth callback handling
  - Improved deep link callback processing
  - Better state management for OAuth flow
  - Fallback mechanism to check connection status periodically
  - Removed manual callback forwarding (backend handles callbacks directly)

### Fixed

- **WHOOP Base URL Migration** - Fixed issue where old base URL was being loaded from storage
  - Automatic migration from `synheart-wear-service-leatest.onrender.com` to new default
  - Ensures new default base URL is used even when old URL is stored locally
- **SSE Connection Stability** - Fixed SSE connection closing unexpectedly
  - Added reconnection mechanism with configurable delay
  - Improved error handling for connection failures
  - Better distinction between normal closures and errors

### Documentation

- Improved code examples with proper error handling and permission checks
- Added comprehensive error handling section with all common error codes
- Enhanced platform-specific permission handling documentation
- Clarified stream subscription behavior and lifecycle management
- Better alignment between README examples and actual SDK behavior
- Added detailed OAuth callback issue documentation for backend developers
- Improved logging documentation for debugging OAuth flows

## [0.2.2] - 2025-01-XX

### Added

- **SDK Initialization Validation** - Enhanced `initialize()` method to validate actual wearable data availability
  - Throws `NO_WEARABLE_DATA` error if no data is available after initialization
  - Throws `STALE_DATA` error if latest data is older than 24 hours
  - Ensures SDK is truly ready for use with fresh, valid data
- **Data Freshness Validation** - Added automatic data freshness checks in cloud providers
  - WHOOP: Validates data freshness in `connectWithCode()` and all `fetch()` methods
  - Ensures data is within 24 hours, with graceful handling of timezone differences
- **Unified Data Format** - Cloud providers now return standardized `WearMetrics` format
  - WHOOP: All `fetch()` methods now return `List<WearMetrics>` instead of raw `Map<String, dynamic>`
  - Consistent bio signal mapping (HR, HRV, steps, calories, distance, stress) across all sources
  - Automatic conversion of provider-specific data structures to unified schema
- **Garmin Integration (In Development)** - Initial implementation of Garmin cloud provider
  - ⚠️ **Status: Pending/Not Fully Functional** - Garmin integration is still in development
  - Added `requestBackfill()` method structure for requesting historical Garmin data via webhooks
  - Added data freshness validation structure in `handleDeepLinkCallback()` and `fetch()` methods
  - Added data format conversion to `WearMetrics` structure
  - Note: Garmin features are experimental and may not be fully functional yet

### Changed

- **License** - Updated from MIT License to Apache License 2.0
  - Updated LICENSE file with complete Apache 2.0 text
  - Updated `pubspec.yaml` license field to `Apache-2.0`
  - Updated README badge to reflect Apache 2.0 license
- **Garmin OAuth URL (In Development)** - Updated OAuth authorization URL to use configurable `baseUrl`
  - `getAuthorizationUrl()` now uses `$baseUrl/v1/garmin/oauth/authorize` instead of hardcoded URL
  - ⚠️ Note: Garmin integration is still pending/not fully functional
- **Enhanced Logging** - Improved initialization validation logging with emoji indicators for better visibility
  - Uses `logWarning()` for critical validation messages (visible by default)
  - Added data age and freshness indicators in logs
- **Cloud Provider Data Conversion** - Internal refactoring for consistent data handling
  - Added helper methods: `_convertToWearMetricsList()`, `_convertSingleItemToWearMetrics()`, `_toNum()`
  - Improved timestamp extraction and parsing across multiple formats (ISO strings, Unix seconds/milliseconds)
  - Better error handling for malformed API responses

### Fixed

- **Timezone Handling** - Fixed negative data age calculation when timestamps are slightly in the future
  - Detects and handles timezone differences gracefully
  - Logs appropriate warnings for future timestamps without failing validation
- **CI Workflow** - Fixed Dart SDK version mismatch in GitHub Actions
  - Updated `flutter-version` from `3.32.0` to `3.30.0` to match Dart SDK requirements

## [0.2.1] - 2025-12-26

### Added

- Comprehensive dartdoc documentation for all public APIs
- Documentation for all public classes, enums, and methods
- Enhanced enum documentation with detailed descriptions

### Changed

- Improved documentation coverage across the entire SDK
- Updated LICENSE file with complete MIT License text

### Fixed

- Fixed incomplete LICENSE file
- Added missing documentation to error classes (PermissionDeniedError, DeviceUnavailableError, NetworkError)
- Added missing documentation to adapter classes (WearAdapter, FitbitAdapter, AppleHealthKitAdapter)
- Added missing documentation to provider classes (WhoopProvider, SwipHooks)
- Added documentation to all enum values (DeviceAdapter, ConsentStatus, PermissionType, MetricType)
- Added repository field to pubspec.yaml for better pub.dev scoring

## [0.1.0] - 2025-10-27

### Added

- Initial release of synheart_wear package
- Apple HealthKit integration for iOS
- Support for multiple health metrics: heart rate (HR), heart rate variability (HRV), steps, calories
- Real-time data streaming capabilities
- Local encrypted caching for offline data persistence
- Unified data schema following the Synheart RFC specification
- Permission management system
- Data normalization engine for multi-device support
- Example Flutter app demonstrating SDK usage

### Features

- Cross-platform support (iOS and Android)
- Real-time HR and HRV streaming
- Consent-based data access
- AES-256-CBC encryption for local storage
- Automatic data quality validation
- Support for both RMSSD and SDNN HRV metrics

### Platform Support

- iOS: Full support via HealthKit integration
- Android: Under development

## [0.2.0] - 2025-12-01

### Added

- **Whoop Integration** - Full REST API integration for Whoop devices (iOS/Android)
  - OAuth 2.0 authentication flow
  - Real-time data fetching (cycles, recovery, sleep, workouts)
  - User ID persistence and configuration management
- **Health Connect/HealthKit Integration** - Native platform health data access
  - Health Connect support for Android (via `health` package v13.2.1)
  - HealthKit support for iOS
  - Unified adapter for both platforms (`AppleHealthKitAdapter`)
  - Support for HR, HRV, steps, calories, and distance metrics
- Distance metric support across both iOS and Android platforms
  - iOS: `DISTANCE_WALKING_RUNNING` via HealthKit
  - Android: `DISTANCE_DELTA` via Health Connect
- Platform configuration documentation (AndroidManifest.xml and Info.plist setup)
- Comprehensive platform configuration section in README
- WidgetsFlutterBinding.ensureInitialized() in code examples
- Improved README with collapsible sections for better readability
- Enhanced library documentation with concise, professional formatting

### Changed

- Health adapter now supports both HealthKit (iOS) and Health Connect (Android)
- Distance handling now supports both iOS (`DISTANCE_WALKING_RUNNING`) and Android (`DISTANCE_DELTA`)
- Updated `HealthAdapter` to properly map distance types per platform
- Enhanced `AppleHealthKitAdapter` to include distance in Android supported permissions
- Improved error messages and logging throughout the SDK (replaced all `print()` with proper logger)
- README restructured for better readability and scannability (reduced from 648 to 454 lines)
- Library documentation streamlined and made more concise
- Replaced all `print()` statements with `SynheartLogger` for production-ready logging

### Fixed

- Distance data retrieval on Android via Health Connect (now uses `DISTANCE_DELTA`)
- Unit conversion for distance metrics (properly handles meters, km, miles, feet, yards)
- Missing distance case in `HealthAdapter` conversion logic
- Platform-specific permission handling for distance on Android

### Documentation

- Added comprehensive platform configuration guide
- Added field descriptions table for data schema
- Added platform limitations section
- Improved code examples with proper initialization
- Enhanced API documentation with better structure

[0.1.0]: https://github.com/synheart-ai/synheart_wear/releases/tag/v0.1.0
[0.2.0]: https://github.com/synheart-ai/synheart_wear/releases/tag/v0.2.0
[0.2.1]: https://github.com/synheart-ai/synheart_wear/releases/tag/v0.2.1
[0.2.2]: https://github.com/synheart-ai/synheart_wear/releases/tag/v0.2.2
[0.2.3]: https://github.com/synheart-ai/synheart_wear/releases/tag/v0.2.3
[0.3.0]: https://github.com/synheart-ai/synheart_wear/releases/tag/v0.3.0
[0.3.1]: https://github.com/synheart-ai/synheart_wear/releases/tag/v0.3.1
