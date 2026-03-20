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
///     config: SynheartWearConfig.withAdapters({DeviceAdapter.appleHealthKit}),
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
/// - **Whoop** (iOS/Android) - REST API
/// - **Fitbit** (iOS/Android) - REST API (In Development)
/// - **Garmin** (iOS/Android) - Connect API (In Development)
///
/// ## Data Schema
///
/// All data follows the **Synheart Data Schema v1.0**:
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
///     "battery": 0.82,
///     "synced": true
///   }
/// }
/// ```
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
export 'src/swip/swip_hooks.dart';
export 'src/sources/whoop_cloud.dart';
export 'src/sources/garmin_cloud.dart';
export 'src/sources/event_subscription.dart';
export 'src/adapters/android_health_helper.dart';

// Garmin SDK adapter (public facade only)
export 'src/adapters/garmin/garmin.dart';

// Generic wearable device types
export 'src/models/wearable_device.dart';

// HealthKit / Health Connect
export 'src/adapters/health_adapter.dart';

// BLE Heart Rate Monitor
export 'src/adapters/ble_hrm_models.dart';
export 'src/adapters/ble_hrm_bridge.dart';

