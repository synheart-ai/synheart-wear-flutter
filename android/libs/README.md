# Android Garmin SDK Libraries

Place the Garmin Health SDK AAR file here.

## Setup Instructions

1. Download the SDK AAR from:
   https://github.com/garmin-health-sdk/android-sdk/packages

   Choose either:
   - `companion-sdk` - Standalone (no Garmin Connect Mobile required)
   - `standard-sdk` - Works with Garmin Connect Mobile

2. Copy and rename the AAR:
   ```bash
   cp garmin-health-companion-sdk-X.X.X.aar libs/garmin-health-sdk.aar
   # OR
   cp garmin-health-standard-sdk-X.X.X.aar libs/garmin-health-sdk.aar
   ```

3. Update `../build.gradle`:
   - Uncomment: `implementation(name: 'garmin-health-sdk', ext: 'aar')`
   - Uncomment: `implementation 'com.google.guava:guava:32.1.3-android'`

4. Rebuild your Android app

## Expected Structure

```
libs/
├── README.md
└── garmin-health-sdk.aar
```

## Note

The Garmin SDK requires a commercial license. Contact Garmin Health for licensing.
