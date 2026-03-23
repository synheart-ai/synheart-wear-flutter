# Synheart Wear SDK – Example App

This example app demonstrates **only** the Wear SDK: WHOOP, Garmin, RAMEN, and Settings. No behavior, health, or other SDKs.

## What’s included

- **Settings** – Base URL, App ID, API Key, Project ID, Redirect URI (shared by WHOOP and Garmin).
- **Devices** – Connect or disconnect WHOOP and Garmin.
- **WHOOP** – OAuth connect, fetch recovery / sleep / cycles, real-time SSE events.
- **Garmin** – OAuth connect, fetch dailies / sleep / HRV / etc., backfill, SSE events.
- **RAMEN** – gRPC real-time events (host, port, App ID, API Key, Device ID; user ID from WHOOP/Garmin after connect).

## How to run

```bash
cd example
flutter pub get
flutter run
```

## Flow

1. Open **Settings**, set Base URL, App ID, API Key, and Redirect URI, then **Save**.
2. Open **Devices**, tap WHOOP or Garmin to connect (OAuth in browser; return to app via deep link).
3. Open **WHOOP** or **Garmin** to fetch data and see real-time events.
4. Open **RAMEN**, ensure Host/Port/App ID/API Key are set (App ID/API Key pre-fill from Settings). Connect WHOOP or Garmin first so a user ID exists; tap **Connect** to stream events.

## Deep link

Configure your app for OAuth return URL (e.g. `synheart://oauth/callback`). iOS: URL scheme in Xcode. Android: intent filter in `AndroidManifest.xml`.
