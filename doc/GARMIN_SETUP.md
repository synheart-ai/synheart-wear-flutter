# Garmin Health SDK integration

This guide walks you through enabling **real-time streaming (RTS)** from
Garmin wearables in `synheart_wear`. RTS is **not** part of the open-source
build — Garmin's SDK is licensed, so the native code that calls it ships
separately, in a private companion repository.

The rest of `synheart_wear` (Apple HealthKit, Health Connect, Whoop, BLE
HRM, etc.) keeps working with no extra setup. Garmin RTS is opt-in.

---

## Getting started — the three things you need

To enable Garmin RTS, you need all three:

1. **A Garmin Health SDK license** — issued by Garmin to your company,
   tied to your app's bundle identifier or Android package name.
2. **Access to the Synheart private companion repository** — request this
   *after* you have a Garmin license.
3. **The Garmin SDK binaries** — the iOS XCFramework and Android AAR for
   Companion SDK 4.7.0. You receive download access along with your
   Garmin license.

### 1. Get a Garmin Health SDK license

Garmin Health is an enterprise programme; licensing is handled by Garmin
directly, not by Synheart.

- Start here: <https://developer.garmin.com/health-api/overview/>
- Once approved, Garmin issues:
  - **License keys** scoped to your application identifier
  - **Access to the Garmin Health SDK binaries** for iOS
    (`Companion.xcframework`) and Android (`companion-sdk` AAR)
    through Garmin's licensee distribution channel.

Until you have a license, skip ahead to **Stub mode** below — Garmin
methods will return `UNAVAILABLE` and the rest of the SDK keeps working.

### 2. Request access to the Synheart companion repository

The native code that calls Garmin's SDK lives at
[`synheart-ai/synheart-wear-garmin-companion`](https://github.com/synheart-ai/synheart-wear-garmin-companion)
(private). It's separate from this open-source plugin so the licensed
Garmin symbol references never end up in public history.

Once you have a Garmin license, email **<opensource@synheart.ai>** with:

- Proof that your company has a Garmin Health SDK license (a Garmin
  contact email, license confirmation, or the agreement reference is
  enough — we don't need the keys themselves).
- The GitHub username(s) you want added to the companion repo.
- The application bundle identifier(s) the license covers.

We add you to a read-only team on the companion repository, typically
within one business day. There's no fee — the gating exists only to
honour Garmin's licensing terms.

### 3. Drop in the Garmin SDK binaries

After Garmin grants you access to their SDK repositories, download:

- **iOS:** `Companion.xcframework-4.7.x.zip` from your Garmin
  Health SDK distribution channel.
- **Android:** `companion-sdk-4.7.0.aar` from your Garmin Health
  SDK distribution channel.

Put them at:

```
ios/Frameworks/Companion.xcframework/
android/repo/com/garmin/health/companion-sdk/4.7.0/companion-sdk-4.7.0.aar
```

Both paths are **gitignored** in this plugin, so the licensed binaries
never get committed.

---

## Building with Garmin RTS

Once you have all three (license, companion access, binaries), build:

```bash
make build-with-garmin
```

This:

1. Verifies you have SSH access to the companion repo.
2. Shallow-clones it into `.garmin/` (gitignored).
3. Symlinks the licensed Kotlin/Swift implementation files over the
   open-source stubs in your local checkout only.
4. Builds the plugin and its example app.

To go back to a clean state:

```bash
make clean-garmin
```

This removes `.garmin/`, restores the open-source stubs, and unlinks the
licensed files.

### Other Make targets

```bash
make build                  # auto-detect (with Garmin if SSH works, else stub)
make build-without-garmin   # explicit stub-only build
make check-garmin           # verify SSH access to the companion repo
make verify-clean           # CI helper: fail if overlay symlinks are present
make install-hooks          # set up the pre-commit overlay safety hook
```

---

## Stub mode (no license / no companion access)

The default build of `synheart_wear` is **stub mode**: Garmin classes
exist, the Dart facade compiles, but the native methods return
`UNAVAILABLE`. This is the path most consumers should ignore — every
non-Garmin adapter (Apple HealthKit, Health Connect, Whoop, BLE HRM)
works normally, and `GarminHealth.startScanning()` /
`pairDevice()` / `startStreaming()` throw `UnsupportedError` if you do
call them.

Use stub mode when you want to ship `synheart_wear` without bundling the
licensed Garmin SDK — for example, in a free tier or demo build.

---

## Dart usage

After a successful `make build-with-garmin`:

```dart
import 'package:synheart_wear/synheart_wear.dart';

final garmin = GarminHealth(licenseKey: 'YOUR_LICENSE_KEY');
await garmin.initialize();

final synheart = SynheartWear(
  config: SynheartWearConfig.withAdapters({DeviceAdapter.garmin}),
  garminHealth: garmin,
);

await garmin.startScanning();
garmin.scannedDevicesStream.listen((devices) {
  for (final d in devices) {
    print('Found: ${d.name} (${d.identifier})');
  }
});

final paired = await garmin.pairDevice(scannedDevice);
await garmin.startStreaming(device: paired);
garmin.realTimeStream.listen((metrics) {
  print('HR: ${metrics.getMetric(MetricType.hr)}');
});

synheart.dispose();
```

In stub-only builds, `initialize()` succeeds but the scanning / pairing /
streaming methods throw `UnsupportedError`.

---

## Choosing Companion vs Standard SDK

Garmin offers two SDK variants:

| Feature                        | Companion SDK | Standard SDK |
| ------------------------------ | ------------- | ------------ |
| Garmin Connect Mobile required | No            | Yes          |
| Direct Bluetooth connection    | Yes           | No           |
| Real-time data                 | Yes           | Yes          |
| Activity sync                  | Via SDK       | Via GCM      |
| Platforms                      | iOS, Android  | Android only |

**Companion** is the default in this plugin. Switch to **Standard**
(Android only, requires Garmin Connect Mobile installed on the phone) by
flipping the dependency line in `android/build.gradle`:

```gradle
implementation 'com.garmin.health:standard-sdk:4.7.0'
```

---

## iOS setup detail

```bash
unzip Companion.xcframework-4.7.x.zip
mkdir -p ios/Frameworks
cp -R Companion.xcframework ios/Frameworks/

cd example/ios && pod deintegrate && pod install
```

The plugin's podspec already vendors `Companion.xcframework` as a
weak-linked framework, so apps that do not bundle the binary still
launch. The license key validates at runtime.

Add to your app's `Info.plist`:

```xml
<key>NSBluetoothAlwaysUsageDescription</key>
<string>Required for Garmin device connection</string>
<key>NSBluetoothPeripheralUsageDescription</key>
<string>Required for Garmin device connection</string>
```

---

## Android setup detail

```bash
mkdir -p android/repo/com/garmin/health/companion-sdk/4.7.0
cp companion-sdk-4.7.0.aar \
   android/repo/com/garmin/health/companion-sdk/4.7.0/companion-sdk-4.7.0.aar
```

The matching `companion-sdk-4.7.0.pom` is already committed. The plugin's
`android/build.gradle` is wired to resolve from `android/repo/`.

Add to your app's `AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.BLUETOOTH" />
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
<uses-permission android:name="android.permission.BLUETOOTH_SCAN" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
```

If you'd rather pull the SDK from GitHub Packages instead of dropping the
AAR locally, see the GitHub Packages section in the appendix below.

---

## Troubleshooting

**`SDK not available` at runtime**

The native binary isn't linked. Verify:

1. iOS: `ios/Frameworks/Companion.xcframework/` exists and `pod install`
   was rerun.
2. Android: the AAR is at
   `android/repo/com/garmin/health/companion-sdk/4.7.0/companion-sdk-4.7.0.aar`.
3. You ran `make build-with-garmin` (otherwise you're in stub mode).

**`License invalid`**

The license key must exactly match your app's bundle identifier or
package name. Contact Garmin support if it persists.

**`Skipping unsupported real-time type: …`**

Expected on devices that don't support a given metric (for example, SpO2
on entry-level trackers). The bridge enables each `RealTimeDataType`
individually so one unsupported type doesn't fail the whole session.

**iOS — `No such module 'Companion'`**

XCFramework not vendored. Confirm
`ios/Frameworks/Companion.xcframework/` exists, then
`pod deintegrate && pod install`.

**Android — `Could not find com.garmin.health:companion-sdk:4.7.0`**

The AAR is missing from `android/repo/...`. Drop in the licensed AAR (the
matching `.pom` is already committed).

**Dart — `UnsupportedError` from a Garmin method**

You're in stub mode. Run `make build-with-garmin` (requires Synheart
companion repo access).

---

## Appendix

### How the overlay actually works

`synheart_wear` ships with **stub** implementations of the Garmin native
bridge. They satisfy the public Dart API, register the Flutter platform
channels, and return `UNAVAILABLE` for any method that would otherwise
need to call into the Garmin SDK. No file in this open-source repo
contains a single Garmin SDK symbol reference.

When you run `make build-with-garmin`, three things happen in your local
checkout:

1. **Android bridge** — the tracked stub
   `android/.../GarminSDKBridge.kt` is backed up to
   `GarminSDKBridge.kt.stub` and symlinked to the licensed bridge in
   `.garmin/`.
2. **Android wrappers** — two licensed Kotlin wrappers
   (`GarminSdkWrapper.kt`, `GarminHealthSdkWrapper.kt`) are symlinked
   into the gitignored slot beside the bridge.
3. **iOS implementation** — the licensed
   `GarminSDKBridgeImpl.swift` is symlinked into the gitignored
   `ios/Classes/Garmin/Impl/` directory; the iOS stub bridge resolves
   it at runtime via `NSClassFromString`.

`.garmin/`, `Garmin*Wrapper.kt`, and `ios/Classes/Garmin/Impl/*.swift`
are all gitignored, so none of the licensed content can be staged
accidentally.

### Three layers of protection against leaking the overlay

1. **`.gitignore`** — the licensed wrapper files and the iOS Impl
   directory are ignored.
2. **Pre-commit hook** (`.githooks/pre-commit`, installed by
   `make install-hooks`) — refuses any commit that stages
   `GarminSDKBridge.kt` as a symlink.
3. **CI guard** (`make verify-clean`) — fails the
   `garmin-overlay-guard` job on any PR/push that has the overlay
   symlink in the working tree.

If the hook fires, run `make clean-garmin` (which restores the stub from
`.stub` backup), re-stage your real changes, and try again. To get RTS
back, rerun `make build-with-garmin`.

### Directory structure after a full setup

```
synheart_wear/
├── .garmin/                                                       # cloned by make fetch-garmin (gitignored)
│   └── dart/
│       ├── android/.../GarminSDKBridge.kt + wrappers              # real Android bridge + wrappers
│       └── ios/Classes/Garmin/GarminSDKBridgeImpl.swift           # real iOS Swift impl
├── android/
│   ├── build.gradle                                               # wired for SDK 4.7.0
│   ├── repo/com/garmin/health/companion-sdk/4.7.0/
│   │   ├── companion-sdk-4.7.0.pom                                # committed
│   │   └── companion-sdk-4.7.0.aar                                # licensed AAR (gitignored)
│   └── src/main/kotlin/ai/synheart/wear/garmin/
│       ├── GarminSDKBridge.kt                                     # tracked stub; symlinked after overlay
│       ├── GarminSDKBridge.kt.stub                                # backup created by link-garmin
│       ├── GarminSdkWrapper.kt                                    # symlink (gitignored)
│       └── GarminHealthSdkWrapper.kt                              # symlink (gitignored)
├── ios/
│   ├── synheart_wear.podspec                                      # wired for Companion.xcframework
│   ├── Frameworks/
│   │   └── Companion.xcframework/                                 # licensed framework (gitignored)
│   └── Classes/Garmin/
│       ├── GarminSDKBridge.swift                                  # tracked OSS stub — zero Garmin SDK symbols
│       ├── GarminChannelHandlers.swift                            # tracked OSS — pure-Swift FlutterStreamHandlers
│       └── Impl/
│           ├── README.md                                          # tracked — describes the overlay slot
│           └── GarminSDKBridgeImpl.swift                          # symlink (gitignored)
└── lib/                                                           # all Dart, regular tracked files
```

### Pulling the Android SDK from GitHub Packages instead of a local AAR

If you'd rather not drop the AAR locally, you can pull it from
Garmin's authenticated package registry. Add to your app's
`local.properties`:

```properties
gpr.user=YOUR_USERNAME
gpr.key=YOUR_TOKEN
```

…and uncomment the authenticated maven block in
`android/build.gradle` (the URL is supplied with your Garmin
Health SDK access). The credentials need `read:packages` and
`repo` scopes.

---

## Support

- **Garmin SDK questions** — Garmin Health SDK support
- **Plugin issues** — <https://github.com/synheart-ai/synheart-wear-flutter/issues>
- **Companion repo access requests** — <opensource@synheart.ai>
