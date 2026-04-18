# Local Maven repo for the Garmin Health SDK

This directory is a **local Maven layout** that the plugin's Gradle build resolves
licensed Garmin SDK artifacts from. The matching `.pom` files are committed; the
binary `.aar` files are **gitignored** because they are licensed.

## Why a Maven layout?

Earlier versions of the plugin used `flatDir { dirs 'libs' }`, but `flatDir`
repositories don't propagate when this plugin is consumed as a transitive
Gradle library module (a common Flutter setup). Resolving via a real Maven
coordinate (`com.garmin.health:companion-sdk:4.7.0`) works in both standalone
apps and library consumers.

## Drop-in setup

1. Get the licensed AAR from
   <https://github.com/garmin-health-sdk/android-sdk/packages>
   (Companion variant for direct-Bluetooth, Standard variant for use alongside
   Garmin Connect Mobile).
2. Place it next to the existing POM:

   ```text
   android/repo/com/garmin/health/companion-sdk/4.7.0/
   ├── companion-sdk-4.7.0.pom   ← committed
   └── companion-sdk-4.7.0.aar   ← drop in licensed binary (gitignored)
   ```

3. The plugin's `android/build.gradle` is already wired:

   ```gradle
   repositories { maven { url "${project.projectDir}/repo" } }
   dependencies { implementation 'com.garmin.health:companion-sdk:4.7.0' }
   ```

## Switching to the Standard variant

Mirror the Companion folder structure for the standard SDK, then update the
dependency line in `android/build.gradle`:

```text
android/repo/com/garmin/health/standard-sdk/4.7.0/
├── standard-sdk-4.7.0.pom
└── standard-sdk-4.7.0.aar
```

```gradle
implementation 'com.garmin.health:standard-sdk:4.7.0'
```

You'll need to author a matching `.pom` (copy `companion-sdk-4.7.0.pom` and
change `<artifactId>` to `standard-sdk`).

## See also

- [`../../GARMIN_SETUP.md`](../../GARMIN_SETUP.md) — full Garmin integration guide
- [`../libs/README.md`](../libs/README.md) — legacy `flatDir` layout (still
  supported for app-level integrations)
