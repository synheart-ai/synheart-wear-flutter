# Overlay directory

This directory is populated at build time by `make link-garmin` with a
symlink into the licensed `synheart-wear-garmin-companion` repo:

```
ios/Classes/Garmin/Impl/GarminSDKBridgeImpl.swift  →  .garmin/dart/ios/Classes/Garmin/GarminSDKBridgeImpl.swift
```

The symlink is git-ignored (see the repo root `.gitignore`) so it can never
be committed. OSS builds without the companion overlay compile fine — the
stub in `../GarminSDKBridge.swift` returns `UNAVAILABLE` for every Garmin
method when no `GarminSDKBridgeImpl` class is present at runtime.

To enable real-time streaming on iOS:

```bash
make build-with-garmin    # auto-detects companion access
```

Without companion access, Garmin method channels return `UNAVAILABLE` but
the rest of the plugin (BLE HRM, health integrations, etc.) works normally.
