# iOS Garmin SDK Frameworks

Place the Garmin Companion SDK XCFramework here.

## Setup Instructions

1. Download `Companion.xcframework-X.X.X.zip` from:
   https://github.com/garmin-health-sdk/ios-companion/releases

2. Extract and copy `Companion.xcframework` to this directory

3. Update `../synheart_wear.podspec`:
   - Uncomment: `s.vendored_frameworks = 'Frameworks/Companion.xcframework'`

4. Run `pod install` in your app's ios directory

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
