# Android Garmin SDK Libraries (legacy)

> **Heads-up** — as of `synheart_wear` 0.3.x targeting Garmin Health SDK **4.7.0**, this directory is **no longer the primary integration point**. The plugin now resolves the AAR through a local Maven layout under [`../repo/`](../repo/) so it works correctly when consumed from another Gradle library module (where `flatDir` doesn't propagate).
>
> See **[`../../doc/GARMIN_SETUP.md`](../../doc/GARMIN_SETUP.md)** for the current setup.

## Current (recommended) layout — local Maven repo

Place the licensed AAR at:

```
android/repo/com/garmin/health/companion-sdk/4.7.0/companion-sdk-4.7.0.aar
```

The matching `.pom` is already committed. `android/build.gradle` is already wired up:

```gradle
repositories {
    maven { url "${project.projectDir}/repo" }
}

dependencies {
    implementation 'com.garmin.health:companion-sdk:4.7.0'
    implementation 'com.google.guava:guava:32.1.3-android'
}
```

```bash
mkdir -p ../repo/com/garmin/health/companion-sdk/4.7.0
cp garmin-health-companion-sdk-4.7.0.aar \
   ../repo/com/garmin/health/companion-sdk/4.7.0/companion-sdk-4.7.0.aar
```

## Legacy layout — `flatDir` AAR drop (still supported for app-level integrations)

If you're integrating Garmin **directly in your application module** (not via this plugin), Gradle's classic `flatDir` lookup still works:

1. Download the SDK AAR from your Garmin Health SDK distribution
   channel (`companion-sdk` for standalone apps, `standard-sdk` for
   apps used alongside Garmin Connect Mobile).
2. Copy and rename to this directory:

   ```bash
   cp garmin-health-companion-sdk-4.7.0.aar libs/garmin-health-sdk.aar
   ```

3. Add to your **app** `build.gradle`:

   ```gradle
   repositories {
       flatDir { dirs 'libs' }
   }
   dependencies {
       implementation(name: 'garmin-health-sdk', ext: 'aar')
       implementation 'com.google.guava:guava:32.1.3-android'
   }
```

## Note

The Garmin SDK requires a commercial license. Contact Garmin Health for licensing — see [`../../doc/GARMIN_SETUP.md`](../../doc/GARMIN_SETUP.md).
