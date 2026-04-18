# iOS Garmin SDK Frameworks

Place the Garmin Companion SDK XCFramework here. The plugin's podspec is **already wired** to vendor this framework via weak linking, so apps without the binary still launch — Garmin methods just throw `"SDK not available"` at runtime.

## Setup Instructions

1. Download `Companion.xcframework-4.7.x.zip` from:
   https://github.com/garmin-health-sdk/ios-companion/releases

2. Extract and copy `Companion.xcframework` into this directory:

   ```bash
   unzip Companion.xcframework-4.7.x.zip
   cp -R Companion.xcframework ios/Frameworks/
   ```

3. Reinstall pods in your consuming app:

   ```bash
   cd ios && pod deintegrate && pod install
   ```

No further podspec edits are required — `ios/synheart_wear.podspec` already contains:

```ruby
s.vendored_frameworks = 'Frameworks/Companion.xcframework'
s.pod_target_xcconfig = {
  'DEFINES_MODULE' => 'YES',
  'OTHER_LDFLAGS'  => '-weak_framework Companion',
}
```

## Expected Structure

```
Frameworks/
├── README.md
└── Companion.xcframework/
    ├── Info.plist
    ├── ios-arm64/
    └── ios-arm64_x86_64-simulator/
```

## Note

The Garmin SDK requires a commercial license. Contact Garmin Health for licensing.
For end-to-end setup (license, companion overlay, runtime behaviour), see
[`../../GARMIN_SETUP.md`](../../GARMIN_SETUP.md).
