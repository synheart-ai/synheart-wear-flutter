/// Unified wearable SDK for Flutter
///
/// Stream HR, HRV, steps, calories, and distance from Apple Watch, Fitbit, Garmin,
/// Whoop, and Samsung devices with a single, standardized API.
///
/// ## Quick Start
///
/// ```dart
/// import 'dart:io';
/// import 'package:flutter/widgets.dart';
/// import 'package:synheart_wear/synheart_wear.dart';
///
/// void main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///
///   final synheart = SynheartWear(
///     config: SynheartWearConfig.withAdapters({DeviceAdapter.platformHealth}),
///   );
///
///   await synheart.requestPermissions(
///     permissions: {
///       PermissionType.heartRate,
///       PermissionType.steps,
///       PermissionType.calories,
///     },
///     reason: 'This app needs access to your health data.',
///   );
///
///   await synheart.initialize();
///   final metrics = await synheart.readMetrics();
///   print('HR: ${metrics.getMetric(MetricType.hr)} bpm');
/// }
/// ```
///
/// ## Supported Devices
///
/// - **Apple Watch** (iOS) - HealthKit
/// - **Health Connect** (Android) - Health Connect API
/// - **Whoop** (iOS/Android) - cloud OAuth via `WhoopProvider`
/// - **Fitbit** (iOS/Android) - cloud OAuth via `FitbitProvider`
/// - **Oura** (iOS/Android) - cloud OAuth via `OuraProvider`
/// - **Garmin** (iOS/Android) - Companion / Standard SDK (real-time, license-gated)
///
/// ## Data shape
///
/// `WearMetrics.toJson()` produces this shape:
///
/// ```json
/// {
///   "timestamp": "2025-10-20T18:30:00Z",
///   "device_id": "applewatch_1234",
///   "source": "apple_healthkit",
///   "metrics": {
///     "hr": 72,
///     "hrv_rmssd": 45,
///     "hrv_sdnn": 62,
///     "steps": 1045,
///     "calories": 120.4,
///     "distance": 2.5
///   },
///   "meta": {
///     "battery": 0.82
///   }
/// }
/// ```
///
/// `metrics` keys are scoped by the `MetricType` enum; adapters set the
/// keys they actually have. `meta` is a free-form
/// `Map<String, Object?>` — only `meta.battery` is read back by the
/// SDK (via `WearMetrics.batteryLevel`).
///
/// **Access in code:**
///
/// ```dart
/// final metrics = await synheart.readMetrics();
/// print(metrics.getMetric(MetricType.hr));        // 72
/// print(metrics.getMetric(MetricType.steps));     // 1045
/// print(metrics.getMetric(MetricType.distance));  // 2.5
/// print(metrics.batteryLevel);                     // 0.82
/// ```
///
/// ## Platform Configuration
///
/// ### Android
///
/// Add Health Connect permissions to `android/app/src/main/AndroidManifest.xml`:
///
/// ```xml
/// <uses-permission android:name="android.permission.health.READ_HEART_RATE"/>
/// <uses-permission android:name="android.permission.health.WRITE_HEART_RATE"/>
/// <uses-permission android:name="android.permission.health.READ_STEPS"/>
/// <uses-permission android:name="android.permission.health.WRITE_STEPS"/>
/// <!-- Add other permissions as needed -->
/// ```
///
/// **Note:** `MainActivity` must extend `FlutterFragmentActivity` for Android 14+.
///
/// ### iOS
///
/// Add to `ios/Runner/Info.plist`:
///
/// ```xml
/// <key>NSHealthShareUsageDescription</key>
/// <string>This app needs access to your health data.</string>
/// <key>NSHealthUpdateUsageDescription</key>
/// <string>This app needs permission to update your health data.</string>
/// ```
///
/// ## Platform Limitations
///
/// - **Android**: HRV uses `HRV_RMSSD` (not `HRV_SDNN`). Distance uses `DISTANCE_DELTA`.
/// - **iOS**: Full support for all metrics.
///
/// For complete documentation, see the [README](https://github.com/synheart-ai/synheart_wear)
/// and [API documentation](https://synheart-ai.github.io/synheart_wear/).
library synheart_wear;

export 'src/core/synheart_wear.dart';
export 'src/core/models.dart';
export 'src/core/config.dart';
export 'src/core/consent_manager.dart';
export 'src/core/local_cache.dart';
export 'src/core/logger.dart';
export 'src/normalization/normalizer.dart';
export 'src/adapters/android_health_helper.dart';

// Wear Service (REST) for historical data backfill
export 'src/wear/wear_service_client.dart';

// RAMEN streaming envelope + capability-flavored DeliveryHint
// (see `proto/ramen.proto` for the canonical wire shape). App code
// consuming the streaming layer can decode incoming JSON into
// RamenEvent and branch on `requiresPull` / `deliveryHint`.
export 'src/wear/ramen_event.dart';

// Materializes an incoming RamenEvent into a usable payload,
// pulling via REST when the cloud sent a ping notification
// (see RamenEventDispatcher).
export 'src/wear/ramen_event_dispatcher.dart';

// Garmin SDK adapter — Dart side is fully open-source. Only the native
// Kotlin wrapper (which depends on `com.garmin.health.*`) is overlaid from
// the private companion repo via `make build-with-garmin`. Without that
// overlay, every method that hits the platform channel returns a graceful
// `UNAVAILABLE` PlatformException (caught and surfaced as `GarminSDKError`).
export 'src/adapters/garmin/garmin.dart';

// Garmin data models (devices, connection state, real-time/wellness/sleep/activity).
export 'src/models/garmin_device.dart';
export 'src/models/garmin_connection_state.dart';
export 'src/models/garmin_realtime_data.dart';
export 'src/models/garmin_wellness_data.dart';
export 'src/models/garmin_sleep_data.dart';
export 'src/models/garmin_activity_data.dart';

// Generic wearable device types
export 'src/models/wearable_device.dart';

// Cross-adapter workout / exercise event contract.
export 'src/models/workout_event.dart';

// HealthKit / Health Connect
export 'src/adapters/health_adapter.dart';
export 'src/adapters/healthkit_rr_channel.dart';
export 'src/adapters/health_profile_channel.dart';
export 'src/models/health_profile_snapshot.dart';

// Workout adapters.
export 'src/adapters/health_workout_adapter.dart';
export 'src/adapters/whoop/whoop_workout_adapter.dart';
export 'src/adapters/garmin_health/garmin_workout_adapter.dart';

// BLE Heart Rate Monitor
export 'src/adapters/ble_hrm_models.dart';
export 'src/adapters/ble_hrm_bridge.dart';

// Cloud vendor providers — vendor link flows (OAuth, credential storage,
// deep-link callbacks) live here alongside the direct-device adapters.
// Once linked, the Stream service consumes these handles for transport.
export 'src/adapters/whoop/whoop_provider.dart';
export 'src/adapters/garmin_health/garmin_provider.dart';
export 'src/adapters/oura/oura_provider.dart';
export 'src/adapters/fitbit/fitbit_provider.dart';

// Apple Health XML backfill.
// Streaming parser + idempotency key for one-shot historical import
// from Apple Health's `export.zip`. See
// the Apple Health XML import spec.
export 'src/apple_xml/apple_health_xml_types.dart';
export 'src/apple_xml/apple_health_xml_parser.dart';
export 'src/apple_xml/apple_health_xml_import.dart';
export 'src/apple_xml/idempotency_key.dart';
