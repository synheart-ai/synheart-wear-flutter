# Garmin Health SDK Integration Guide

This guide explains how to integrate the Garmin Health SDK with `synheart_wear` for real-time health data streaming (RTS) from Garmin wearables.

> **TL;DR** — get a Garmin Health SDK license, drop the iOS XCFramework into `ios/Frameworks/` and the Android AAR into `android/repo/com/garmin/health/companion-sdk/4.7.0/`, then run `make build-with-garmin` from the package root to overlay the real RTS implementation.

## Architecture overview

Only the **native code that textually references Garmin SDK symbols** actually requires the Garmin licence. Everything else — the Dart facade, the platform-channel scaffolding, all data models, the iOS Swift stub, the iOS pure-Swift channel handlers, and the Android bridge stub — is open-source and ships in this repo by default. The companion overlay swaps in the Kotlin wrapper(s) and the Swift impl at build time:

| Layer                              | Where it lives                                                              | Licensed? |
| ---------------------------------- | --------------------------------------------------------------------------- | --------- |
| `GarminHealth` Dart facade         | `lib/src/adapters/garmin/garmin_health.dart`                                | No (OSS)  |
| Platform channel + device manager  | `lib/src/adapters/garmin/garmin_platform_channel.dart`, `garmin_device_manager.dart`, `garmin_sdk_adapter.dart`, `garmin_errors.dart` | No (OSS)  |
| Garmin data models                 | `lib/src/models/garmin_*.dart`                                              | No (OSS)  |
| iOS Swift stub bridge              | `ios/Classes/Garmin/GarminSDKBridge.swift` — zero Garmin SDK symbols; registers Flutter channels and looks up the impl at runtime via `NSClassFromString("GarminSDKBridgeImpl")` | No (OSS)  |
| iOS pure-Swift channel handlers    | `ios/Classes/Garmin/GarminChannelHandlers.swift` — four `FlutterStreamHandler`s (connection state, scanned devices, real-time data, sync progress). No SDK dependency. | No (OSS)  |
| Android native bridge stub         | `android/.../GarminSDKBridge.kt`                                            | No (OSS — returns `UNAVAILABLE` until overlay runs)   |
| **Android licensed wrapper**       | `android/.../GarminHealthSdkWrapper.kt`, `android/.../GarminSdkWrapper.kt` (gitignored) | **Yes — companion repo** |
| **iOS licensed impl**              | `ios/Classes/Garmin/Impl/GarminSDKBridgeImpl.swift` (gitignored)            | **Yes — companion repo** |

`make link-garmin` performs three overlay operations:

- **Android protected stub** — backs `GarminSDKBridge.kt` up to `GarminSDKBridge.kt.stub`, then symlinks the licensed version from `.garmin/` over it.
- **Android licensed wrappers** — symlinks `GarminSdkWrapper.kt` / `GarminHealthSdkWrapper.kt` into the gitignored slot beside the bridge.
- **iOS licensed impl** — symlinks `GarminSDKBridgeImpl.swift` into the gitignored `ios/Classes/Garmin/Impl/` directory.

`.garmin/`, `Garmin*Wrapper.kt`, and `ios/Classes/Garmin/Impl/*.swift` are all gitignored, so the symlinked files never end up in the open-source tree. Because the iOS Impl path is fully gitignored (no tracked stub to protect), it doesn't need the same pre-commit guard that the Android bridge uses.

In stub mode (no overlay): every Garmin Dart call still compiles cleanly and uses the same data classes, but the platform channel returns `UNAVAILABLE` `PlatformException`s which the Dart layer surfaces as `GarminSDKError`. On iOS the stub bridge's runtime `NSClassFromString` lookup returns `nil` and every method returns `UNAVAILABLE`. Non-Garmin adapters are unaffected.

---

## Prerequisites

### 1. Obtain a Garmin Health SDK License

The Garmin Health SDK is **not open source** and requires a commercial license from Garmin. Currently we target **SDK v4.7.0** on both platforms.

1. Contact Garmin Health to discuss licensing: https://developer.garmin.com/health-api/overview/
2. You will receive:
   - SDK license key(s) tied to your app's bundle ID / package name
   - Access to the private GitHub repositories containing the SDK binaries

### 2. Companion repo access (recommended)

If your team has been added to the private companion repo, the build pipeline will pull the real implementation automatically:

- Repo: `git@github.com:synheart-ai/synheart-wear-garmin-companion.git`
- Verify access: `make check-garmin`

Without companion access the build still succeeds but `GarminHealth.startScanning() / pairDevice() / startStreaming()` throw `UnsupportedError`. All non-Garmin adapters (Apple HealthKit, Health Connect, Whoop, BLE HRM, …) are unaffected.

### 3. GitHub Access Token (only for Maven/GitHub Packages flow)

Required only if you choose the GitHub Packages route instead of the local Maven layout.

- `read:packages`
- `repo`

Create one at: https://github.com/settings/tokens

---

## iOS Setup (Companion SDK 4.7.0)

### Option 1: Swift Package Manager

Use this if you're integrating Garmin in your app **directly** (not through this plugin).

1. In Xcode, choose **File ▸ Add Package Dependencies**
2. Enter: `https://github.com/garmin-health-sdk/ios-companion`
3. Authenticate with your GitHub credentials and pin to `4.7.0` or later

### Option 2: XCFramework into the plugin (used by this Flutter plugin)

1. **Download the SDK**

   Go to: https://github.com/garmin-health-sdk/ios-companion/releases and download `Companion.xcframework-4.7.x.zip`.

2. **Extract and copy**

   ```bash
   unzip Companion.xcframework-4.7.x.zip
   mkdir -p ios/Frameworks
   cp -R Companion.xcframework ios/Frameworks/
   ```

3. **Podspec is already wired**

   `ios/synheart_wear.podspec` already contains:

   ```ruby
   s.vendored_frameworks = 'Frameworks/Companion.xcframework'
   s.pod_target_xcconfig = {
     'DEFINES_MODULE' => 'YES',
     'OTHER_LDFLAGS'  => '-weak_framework Companion',
   }
   ```

   The framework is **weak-linked**, so apps that do not ship the binary still launch — Garmin methods just throw `"SDK not available"`.

4. **Reinstall pods** in your consuming app:

   ```bash
   cd ios && pod deintegrate && pod install
   ```

> **Note** — the iOS Companion SDK 4.x renamed several APIs (`heartRateVariability` → `beatToBeatInterval`, `spo2` → `oxygenLevel`, `respirationRate` → `breathsPerMinute`, `bodyBattery` → `bodyBatteryLevel`, `accelerometer.x/y/z` → `xValue/yValue/zValue`, sync direction `.download` → `.toPhone`, `DeviceType.all` → `DeviceType.allKnown`). These mappings live in the licensed companion impl (`GarminSDKBridgeImpl.swift` in the `synheart-wear-garmin-companion` repo, overlaid into `ios/Classes/Garmin/Impl/` by `make link-garmin`). The OSS stub (`GarminSDKBridge.swift`) has no SDK symbol references to keep in sync. If you bump the SDK further, re-check those mappings in the companion repo.

---

## Android Setup (Companion SDK 4.7.0)

The plugin uses a **local Maven repository** under `android/repo/`. This works for both library-module consumers (where `flatDir` doesn't propagate) and standalone apps.

### Option 1: Local Maven layout (recommended)

1. **Download the SDK AAR**

   Go to: https://github.com/garmin-health-sdk/android-sdk/packages and download the `companion-sdk` (or `standard-sdk`) AAR for **4.7.0**.

2. **Drop it into the local Maven layout**

   ```bash
   mkdir -p android/repo/com/garmin/health/companion-sdk/4.7.0
   cp companion-sdk-4.7.0.aar \
      android/repo/com/garmin/health/companion-sdk/4.7.0/companion-sdk-4.7.0.aar
   ```

   The matching POM (`companion-sdk-4.7.0.pom`) is already committed in the repo.

3. **`android/build.gradle` is already wired**

   ```gradle
   repositories {
       maven { url "${project.projectDir}/repo" }   // local Garmin Maven layout
   }

   dependencies {
       implementation 'com.garmin.health:companion-sdk:4.7.0'
       implementation 'com.google.guava:guava:32.1.3-android'
   }
   ```

4. Rebuild your app: `flutter clean && flutter pub get && cd android && ./gradlew assembleDebug`.

### Option 2: GitHub Packages

1. **Set GitHub credentials**

   Add to your app's `local.properties`:

   ```properties
   gpr.user=YOUR_GITHUB_USERNAME
   gpr.key=YOUR_GITHUB_TOKEN
   ```

   …or export `GITHUB_USER` / `GITHUB_TOKEN` env vars.

2. **Uncomment the Maven block** in `android/build.gradle`:

   ```gradle
   maven {
       url 'https://maven.pkg.github.com/garmin-health-sdk/android-sdk'
       credentials {
           username = project.findProperty("gpr.user") ?: System.getenv("GITHUB_USER") ?: ""
           password = project.findProperty("gpr.key") ?: System.getenv("GITHUB_TOKEN") ?: ""
       }
   }
   ```

   …and switch the dependency line if you want the standard variant:

   ```gradle
   // implementation 'com.garmin.health:standard-sdk:4.7.0'
   ```

> **Note** — Android Companion SDK 4.7.0 renamed several APIs (`addDevicePairedStateListener` → `addPairedStateListener`, `device.batteryLevel()` → `device.batteryPercentage()`, `device.unitId()` is now non-nullable, and `RealTimeHRV.beatToBeatIntervals` was dropped). Our `GarminHealthSdkWrapper.kt` is already updated for these.

---

## Building with Garmin RTS Support

The real-time streaming (RTS) source lives in the private companion repo and is overlaid at build time:

```bash
make build                  # auto-detect: with companion if accessible, otherwise stub
make build-with-garmin      # explicit: requires companion repo access
make build-without-garmin   # explicit: stub-only build (RTS calls throw UnsupportedError)
make check-garmin           # verify your SSH access to the companion repo
make clean-garmin           # remove .garmin/, restore stubs from .stub backups
make verify-clean           # CI-friendly: fail if overlay symlinks are in the tree
make install-hooks          # configure git core.hooksPath → .githooks (idempotent)
```

What `make build-with-garmin` does:

1. `install-hooks` — points `git config core.hooksPath` at `.githooks/` so the pre-commit guard is active.
2. `fetch-garmin` — shallow-clones the companion repo into `.garmin/` (or `git pull --ff-only` if already present).
3. `link-garmin` performs three overlays:
   - **Android bridge** — backs the tracked `GarminSDKBridge.kt` stub up to `.stub`, symlinks the licensed Kotlin bridge over it.
   - **Android wrappers** — symlinks the two companion-only Kotlin wrappers (`GarminSdkWrapper.kt`, `GarminHealthSdkWrapper.kt`) into the gitignored slot beside the bridge.
   - **iOS impl** — symlinks `GarminSDKBridgeImpl.swift` into the gitignored `ios/Classes/Garmin/Impl/` directory. If the companion clone predates the iOS overlay (i.e. the file isn't present in `.garmin/`), link-garmin logs a skip notice and Android-only stays functional.

`.garmin/`, `Garmin*Wrapper.kt`, and `ios/Classes/Garmin/Impl/*.swift` are gitignored. `GarminSDKBridge.kt` **must** stay tracked (otherwise `pub publish` breaks for stub-mode consumers), so it's guarded a different way (see below). On iOS, `GarminSDKBridge.swift` is a pure-Swift stub with zero SDK symbol references — the licensed impl drops into the separate, gitignored `Impl/` directory, so no pre-commit guard is required for the iOS path. All Dart code is plain OSS — the overlay no longer touches `lib/`.

### Overlay safety net

Three layered defences keep the Android overlay from leaking into the open-source repo:

1. **`.gitignore`** — `Garmin*Wrapper.kt` is ignored so the two licensed Kotlin wrappers can never be staged. `ios/Classes/Garmin/Impl/*.swift` is ignored so the iOS licensed impl can never be staged either.
2. **Pre-commit hook (`.githooks/pre-commit`)** — refuses any commit that stages `GarminSDKBridge.kt` as a symlink. Activated by `make install-hooks` (run once per clone — `make build*` does it for you).
3. **CI check (`make verify-clean`)** — runs in the `garmin-overlay-guard` job on every PR/push and fails if the working tree has the overlay symlink at the protected Android path.

The iOS `Impl/` path has no tracked stub, so a hook is not needed — the `.gitignore` rule alone makes `git add` a no-op for any symlink placed there.

If you ever see the hook fire:

```text
✗ Refusing to commit: Garmin overlay symlinks detected in the index.
    android/src/main/kotlin/ai/synheart/wear/garmin/GarminSDKBridge.kt
      → /Volumes/.../.garmin/dart/android/.../GarminSDKBridge.kt
```

…run `make clean-garmin` (which restores the stub from `.stub` backup), re-stage your real changes, and try again. To get RTS back, just rerun `make build-with-garmin` afterwards.

---

## Dart Usage

Once the native SDK is configured **and** you've run a `make build-with-garmin`, use the `GarminHealth` facade:

```dart
import 'package:synheart_wear/synheart_wear.dart';

final garmin = GarminHealth(licenseKey: 'YOUR_LICENSE_KEY');
await garmin.initialize();

// Wire into SynheartWear
final synheart = SynheartWear(
  config: SynheartWearConfig.withAdapters({DeviceAdapter.garmin}),
  garminHealth: garmin,
);

// Scan
await garmin.startScanning();
garmin.scannedDevicesStream.listen((devices) {
  for (final d in devices) {
    print('Found: ${d.name} (${d.identifier})');
  }
});

// Pair
final paired = await garmin.pairDevice(scannedDevice);

// Real-time streaming
await garmin.startStreaming(device: paired);
garmin.realTimeStream.listen((metrics) {
  print('HR: ${metrics.getMetric(MetricType.hr)}');
});

// Cleanup
synheart.dispose();
```

In stub-only builds, `initialize()` succeeds but the scanning/pairing/streaming methods throw `UnsupportedError`.

---

## SDK Variant Comparison

| Feature                        | Companion SDK | Standard SDK   |
| ------------------------------ | ------------- | -------------- |
| Garmin Connect Mobile required | No            | Yes            |
| Direct Bluetooth connection    | Yes           | No             |
| Works offline                  | Yes           | Yes            |
| Real-time data                 | Yes           | Yes            |
| Activity sync                  | Via SDK       | Via GCM        |
| Platform                       | iOS, Android  | Android only   |

**Choose Companion SDK** if:

- Your users may not have Garmin Connect Mobile installed
- You need direct Bluetooth communication
- You're targeting iOS

**Choose Standard SDK** if:

- Your users will have Garmin Connect Mobile
- You want to leverage GCM's existing device connection

---

## Troubleshooting

### `SDK not available` error at runtime

The native binary isn't linked. Verify:

1. **iOS** — `ios/Frameworks/Companion.xcframework/` exists and `pod install` was rerun.
2. **Android** — `android/repo/com/garmin/health/companion-sdk/4.7.0/companion-sdk-4.7.0.aar` exists.
3. The Dart side was overlaid via `make build-with-garmin` (otherwise you're hitting the stub).

### `License invalid` error

- Ensure your license key matches your app's bundle ID / package name exactly.
- Contact Garmin support if it persists.

### `Skipping unsupported real-time type: …`

This is **expected** on devices that don't support a particular metric (e.g. SpO2 on entry-level trackers). The bridge enables each `RealTimeDataType` individually so a single unsupported type doesn't fail the whole streaming session.

### Bluetooth permission errors

**iOS** — add to `Info.plist`:

```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>Required for Garmin device connection</string>
<key>NSBluetoothPeripheralUsageDescription</key>
<string>Required for Garmin device connection</string>
```

**Android** — add to `AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.BLUETOOTH" />
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
```

### Build errors

**iOS — `No such module 'Companion'`** — XCFramework not vendored. Confirm the file is in `ios/Frameworks/` and rerun `pod deintegrate && pod install`.

**Android — `Could not find com.garmin.health:companion-sdk:4.7.0`** — AAR is missing from `android/repo/com/garmin/health/companion-sdk/4.7.0/`. Drop in the licensed AAR (the matching `.pom` is already committed).

**Dart — `Unresolved reference: GarminAdapter`** — you're in stub mode. Run `make build-with-garmin` (requires companion repo access).

---

## Directory Structure

After a full setup with companion access, the package looks like:

```
synheart_wear/
├── .garmin/                                                        # ← cloned by `make fetch-garmin` (gitignored)
│   └── dart/
│       ├── android/.../GarminSDKBridge.kt + wrappers               # ← real Android bridge + wrappers
│       └── ios/Classes/Garmin/GarminSDKBridgeImpl.swift            # ← real iOS Swift impl
├── android/
│   ├── build.gradle                                                # ← wired for SDK 4.7.0
│   ├── repo/com/garmin/health/companion-sdk/4.7.0/
│   │   ├── companion-sdk-4.7.0.pom                                 # committed
│   │   └── companion-sdk-4.7.0.aar                                 # ← drop in licensed AAR (gitignored)
│   └── src/main/kotlin/ai/synheart/wear/garmin/
│       ├── GarminSDKBridge.kt                                      # tracked stub; symlinked to .garmin/ after overlay
│       ├── GarminSDKBridge.kt.stub                                 # backup created by link-garmin (auto-deleted on clean)
│       ├── GarminSdkWrapper.kt                                     # symlink into .garmin/ after overlay (gitignored)
│       └── GarminHealthSdkWrapper.kt                               # symlink into .garmin/ after overlay (gitignored)
├── ios/
│   ├── synheart_wear.podspec                                       # ← wired for Companion.xcframework
│   ├── Frameworks/
│   │   └── Companion.xcframework/                                  # ← drop in licensed framework (gitignored)
│   └── Classes/Garmin/
│       ├── GarminSDKBridge.swift                                   # tracked OSS stub — zero Garmin SDK symbols
│       ├── GarminChannelHandlers.swift                             # tracked OSS — pure-Swift FlutterStreamHandlers
│       └── Impl/
│           ├── README.md                                           # tracked — describes the overlay slot
│           └── GarminSDKBridgeImpl.swift                           # symlink into .garmin/ after overlay (gitignored)
└── lib/                                                             # all Dart lives here as regular tracked files (no overlay)
```

---

## Support

- **Garmin SDK issues** — Garmin Health SDK Support
- **Plugin issues** — https://github.com/synheart-ai/synheart_wear/issues
- **Companion repo access** — opensource@synheart.ai
