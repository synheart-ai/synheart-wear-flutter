# Synheart Wear

[![Version](https://img.shields.io/badge/version-0.3.1-blue.svg)](https://github.com/synheart-ai/synheart_wear)
[![Flutter](https://img.shields.io/badge/flutter-%3E%3D3.22.0-blue.svg)](https://flutter.dev)
[![License](https://img.shields.io/badge/license-Apache--2.0-green.svg)](LICENSE)

> **Unified wearable SDK** for Flutter — Stream HR, HRV, steps, calories, and distance from Apple Watch, Fitbit, Garmin, Whoop, and Samsung devices with a single, standardized API.

## ✨ Features

| Feature                | Description                                 |
| ---------------------- | ------------------------------------------- |
| 📱 **Cross-Platform**  | iOS & Android support                       |
| ⌚ **Multi-Device**    | Apple Watch, Fitbit, Garmin, Whoop, Samsung |
| 🔄 **Real-Time**       | Live HR and HRV streaming                   |
| 📊 **Unified Schema**  | Consistent data format across all devices   |
| 🔒 **Privacy-First**   | Consent-based access with encryption        |
| 💾 **Offline Support** | Encrypted local data persistence            |

## 🚀 Quick Start

### Installation

```yaml
dependencies:
  synheart_wear: ^0.3.1
```

```bash
flutter pub get
```

### Basic Usage

**Recommended Pattern (Explicit Permission Control):**

```dart
import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:synheart_wear/synheart_wear.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Step 1: Create SDK instance
  final adapters = <DeviceAdapter>{
    DeviceAdapter.appleHealthKit, // Uses Health Connect on Android
  };

  // Use withAdapters() to explicitly specify which adapters to enable
  // Note: Default constructor includes fitbit by default, so use withAdapters() for clarity
  final synheart = SynheartWear(
    config: SynheartWearConfig.withAdapters(adapters),
  );

  // Step 2: Request permissions (with reason for better UX)
  final result = await synheart.requestPermissions(
    permissions: {
      PermissionType.heartRate,
      PermissionType.steps,
      PermissionType.calories,
    },
    reason: 'This app needs access to your health data.',
  );

  // Step 3: Initialize SDK (validates permissions and data availability)
  if (result.values.any((s) => s == ConsentStatus.granted)) {
    try {
      await synheart.initialize();
      
      // Step 4: Read metrics
      final metrics = await synheart.readMetrics();
      print('HR: ${metrics.getMetric(MetricType.hr)} bpm');
      print('Steps: ${metrics.getMetric(MetricType.steps)}');
    } on SynheartWearError catch (e) {
      print('Initialization failed: $e');
      // Handle errors: NO_WEARABLE_DATA, STALE_DATA, etc.
    }
  }
}
```

**Alternative Pattern (Simplified):**

If you don't need to provide a custom reason, you can let `initialize()` handle permissions automatically:

```dart
final synheart = SynheartWear(
  config: SynheartWearConfig.withAdapters({DeviceAdapter.appleHealthKit}),
);

// Initialize will request permissions internally if needed
await synheart.initialize();
final metrics = await synheart.readMetrics();
```

**Note:** `initialize()` validates that wearable data is available and not stale (>24 hours old). If no data is available or data is too old, it will throw a `SynheartWearError` with codes `NO_WEARABLE_DATA` or `STALE_DATA`.

### Real-Time Streaming

```dart
// Stream heart rate every 5 seconds
// Note: Streams are created lazily when first listener subscribes
// Multiple calls to streamHR() return the same stream controller
final hrSubscription = synheart.streamHR(interval: Duration(seconds: 5))
  .listen((metrics) {
    final hr = metrics.getMetric(MetricType.hr);
    if (hr != null) print('Current HR: $hr bpm');
  }, onError: (error) {
    print('Stream error: $error');
  });

// Stream HRV in 5-second windows
final hrvSubscription = synheart.streamHRV(windowSize: Duration(seconds: 5))
  .listen((metrics) {
    final hrv = metrics.getMetric(MetricType.hrvRmssd);
    if (hrv != null) print('HRV RMSSD: $hrv ms');
  }, onError: (error) {
    print('HRV stream error: $error');
  });

// Don't forget to cancel subscriptions when done
// hrSubscription.cancel();
// hrvSubscription.cancel();
```

## 📊 Data Schema

All data follows the **Synheart Data Schema v1.0**:

```json
{
  "timestamp": "2025-10-20T18:30:00Z",
  "device_id": "applewatch_1234",
  "source": "apple_healthkit",
  "metrics": {
    "hr": 72,
    "hrv_rmssd": 45,
    "hrv_sdnn": 62,
    "steps": 1045,
    "calories": 120.4,
    "distance": 2.5
  },
  "meta": {
    "battery": 0.82,
    "firmware_version": "10.1",
    "synced": true
  }
}
```

**Access in code:**

```dart
final metrics = await synheart.readMetrics();
print(metrics.getMetric(MetricType.hr));        // 72
print(metrics.getMetric(MetricType.steps));     // 1045
print(metrics.getMetric(MetricType.distance));  // 2.5
print(metrics.batteryLevel);                     // 0.82
```

📚 **[Full API Documentation](https://synheart-ai.github.io/synheart_wear/)** | **[Data Schema Details](#data-schema-details)**

## ⌚ Supported Devices

| Device         | Platform    | Status            |
| -------------- | ----------- | ----------------- |
| Apple Watch    | iOS         | ✅ Ready          |
| Health Connect | Android     | ✅ Ready          |
| Whoop          | iOS/Android | ✅ Ready          |
| Fitbit         | iOS/Android | 🔄 In Development |
| Garmin         | iOS/Android | 🔄 In Development |
| Samsung Watch  | Android     | 📋 Planned        |

## ⚙️ Platform Configuration

### Android

Add to `android/app/src/main/AndroidManifest.xml`:

```xml
<!-- Health Connect Permissions -->
<uses-permission android:name="android.permission.health.READ_HEART_RATE"/>
<uses-permission android:name="android.permission.health.WRITE_HEART_RATE"/>
<uses-permission android:name="android.permission.health.READ_HEART_RATE_VARIABILITY"/>
<uses-permission android:name="android.permission.health.WRITE_HEART_RATE_VARIABILITY"/>
<uses-permission android:name="android.permission.health.READ_STEPS"/>
<uses-permission android:name="android.permission.health.WRITE_STEPS"/>
<uses-permission android:name="android.permission.health.READ_ACTIVE_CALORIES_BURNED"/>
<uses-permission android:name="android.permission.health.WRITE_ACTIVE_CALORIES_BURNED"/>
<uses-permission android:name="android.permission.health.READ_DISTANCE"/>
<uses-permission android:name="android.permission.health.WRITE_DISTANCE"/>

<!-- Health Connect Package Query -->
<queries>
    <package android:name="com.google.android.apps.healthdata" />
    <intent>
        <action android:name="androidx.health.ACTION_SHOW_PERMISSIONS_RATIONALE" />
    </intent>
</queries>

<application>
    <activity android:name=".MainActivity">
        <intent-filter>
            <action android:name="androidx.health.ACTION_SHOW_PERMISSIONS_RATIONALE" />
        </intent-filter>
    </activity>

    <!-- Required: Privacy Policy Activity Alias -->
    <activity-alias
        android:name="ViewPermissionUsageActivity"
        android:exported="true"
        android:targetActivity=".MainActivity"
        android:permission="android.permission.START_VIEW_PERMISSION_USAGE">
        <intent-filter>
            <action android:name="android.intent.action.VIEW_PERMISSION_USAGE" />
            <category android:name="android.intent.category.HEALTH_PERMISSIONS" />
        </intent-filter>
    </activity-alias>
</application>
```

**Note:** `MainActivity` must extend `FlutterFragmentActivity` (not `FlutterActivity`) for Android 14+.

### iOS

Add to `ios/Runner/Info.plist`:

```xml
<key>NSHealthShareUsageDescription</key>
<string>This app needs access to your health data to provide insights.</string>

<key>NSHealthUpdateUsageDescription</key>
<string>This app needs permission to update your health data.</string>
```

## ⚠️ Platform Limitations

| Platform    | Limitation                      | SDK Behavior                         |
| ----------- | ------------------------------- | ------------------------------------ |
| **Android** | HRV: Only `HRV_RMSSD` supported | Automatically maps to supported type |
| **Android** | Distance: Uses `DISTANCE_DELTA` | Automatically uses correct type      |
| **iOS**     | Full support for all metrics    | No limitations                       |

## 🔒 Privacy & Security

- ✅ Consent-first design
- ✅ AES-256-CBC encryption
- ✅ Automatic key management
- ✅ Anonymized UUIDs
- ✅ Right to forget (revoke & delete)

## 🧠 Flux (HSI compute)

This package **does not generate HSI** and **does not bundle Flux binaries**.
**HSI is generated in Flux** (see the `synheart-flux` repo) and is typically orchestrated/validated in **Synheart Core**. 



### Fetching Raw Data for Flux

Both `WhoopProvider` and `GarminProvider` include `fetchRawDataForFlux()` methods that fetch and format vendor data for Flux processing:

**WHOOP:**
```dart
final whoopProvider = WhoopProvider(appId: 'your-app-id', userId: 'user-123');
final rawData = await whoopProvider.fetchRawDataForFlux(
  start: DateTime.now().subtract(const Duration(days: 30)),
  end: DateTime.now(),
  limit: 50,
);
// Returns: { 'sleep': [...], 'recovery': [...], 'cycle': [...] }
```

**Garmin:**
```dart
final garminProvider = GarminProvider(appId: 'your-app-id', userId: 'user-123');
final rawData = await garminProvider.fetchRawDataForFlux(
  start: DateTime.now().subtract(const Duration(days: 30)),
  end: DateTime.now(),
);
// Returns: { 'dailies': [...], 'sleep': [...] }
```

These methods automatically:
- Fetch data from the appropriate vendor endpoints
- Transform data to match Flux's expected format
- Handle missing fields and data validation
- Return data ready for Flux processing

## 📖 Additional Resources

- **[Full API Documentation](https://synheart-ai.github.io/synheart_wear/)** — Complete API reference
- **[GitHub Issues](https://github.com/synheart-ai/synheart_wear/issues)** — Report bugs or request features
- **[pub.dev Package](https://pub.dev/packages/synheart_wear)** — Package details

---

## 📋 Detailed Sections

<details>
<summary><b>Initialization Flow & Best Practices</b></summary>

### Recommended Initialization Pattern

The SDK supports two initialization patterns:

**1. Explicit Permission Control (Recommended):**
```dart
// Step 1: Create SDK instance
final synheart = SynheartWear(
  config: SynheartWearConfig.withAdapters({DeviceAdapter.appleHealthKit}),
);

// Step 2: Request permissions with reason
final result = await synheart.requestPermissions(
  permissions: {PermissionType.heartRate, PermissionType.steps},
  reason: 'This app needs access to your health data.',
);

// Step 3: Initialize (validates permissions and data)
if (result.values.any((s) => s == ConsentStatus.granted)) {
  await synheart.initialize();
}
```

**2. Automatic Permission Handling:**
```dart
// Let initialize() handle permissions automatically
final synheart = SynheartWear(
  config: SynheartWearConfig.withAdapters({DeviceAdapter.appleHealthKit}),
);

await synheart.initialize(); // Requests permissions internally if needed
```

### What `initialize()` Does

The `initialize()` method:
1. Requests permissions (if not already granted)
2. Initializes all enabled adapters
3. Validates that wearable data is available
4. Checks that data is not stale (>24 hours old)

**Important:** `initialize()` will throw `SynheartWearError` if:
- No wearable data is available (`NO_WEARABLE_DATA`)
- Latest data is older than 24 hours (`STALE_DATA`)
- Permissions are denied (`PERMISSION_DENIED`)

### Permission Request Behavior

- Calling `requestPermissions()` before `initialize()` allows you to provide a custom reason
- `initialize()` will also request permissions internally if not already granted
- If permissions are already granted, `initialize()` will skip the permission request

</details>

<details>
<summary><b>Data Schema Details</b></summary>

### Field Descriptions

| Field               | Type                | Description              | Example                                    |
| ------------------- | ------------------- | ------------------------ | ------------------------------------------ |
| `timestamp`         | `string` (ISO 8601) | When data was recorded   | `"2025-10-20T18:30:00Z"`                   |
| `device_id`         | `string`            | Unique device identifier | `"applewatch_1234"`                        |
| `source`            | `string`            | Data source adapter      | `"apple_healthkit"`, `"fitbit"`, `"whoop"` |
| `metrics.hr`        | `number`            | Heart rate (bpm)         | `72`                                       |
| `metrics.hrv_rmssd` | `number`            | HRV RMSSD (ms)           | `45`                                       |
| `metrics.hrv_sdnn`  | `number`            | HRV SDNN (ms)            | `62`                                       |
| `metrics.steps`     | `number`            | Step count               | `1045`                                     |
| `metrics.calories`  | `number`            | Calories (kcal)          | `120.4`                                    |
| `metrics.distance`  | `number`            | Distance (km)            | `2.5`                                      |
| `meta.battery`      | `number`            | Battery level (0.0-1.0)  | `0.82` (82%)                               |
| `meta.synced`       | `boolean`           | Sync status              | `true`                                     |

**Notes:**

- Optional fields may be `null` if unavailable
- Platform limitations may affect metric availability
- `meta` object may contain device-specific fields

</details>

<details>
<summary><b>Platform-Specific Permission Handling</b></summary>

```dart
// Determine platform-specific permissions
Set<PermissionType> permissions;
if (Platform.isAndroid) {
  // Android Health Connect limitations:
  // - HRV: Only RMSSD supported (SDNN not available)
  // - Distance: Not directly supported (would need DISTANCE_DELTA)
  permissions = {
    PermissionType.heartRate,
    PermissionType.heartRateVariability, // Maps to RMSSD on Android
    PermissionType.steps,
    PermissionType.calories,
    // Note: Distance is not included as Health Connect doesn't support it
  };
} else {
  // iOS HealthKit supports all metrics
  permissions = {
    PermissionType.heartRate,
    PermissionType.heartRateVariability, // Supports both RMSSD and SDNN
    PermissionType.steps,
    PermissionType.calories,
    PermissionType.distance,
  };
}

final result = await synheart.requestPermissions(
  permissions: permissions,
  reason: 'This app needs access to your health data.',
);

// Check if permissions were granted before initializing
if (result.values.any((s) => s == ConsentStatus.granted)) {
  await synheart.initialize();
} else {
  // Handle permission denial
  print('Permissions were not granted');
}
```

</details>

<details>
<summary><b>Usage Examples</b></summary>

### Complete Health Monitoring App

```dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:synheart_wear/synheart_wear.dart';

class HealthMonitor extends StatefulWidget {
  @override
  _HealthMonitorState createState() => _HealthMonitorState();
}

class _HealthMonitorState extends State<HealthMonitor> {
  late SynheartWear _sdk;
  StreamSubscription<WearMetrics>? _hrSubscription;
  WearMetrics? _latestMetrics;
  bool _isConnected = false;

  @override
  void initState() {
    super.initState();
    _sdk = SynheartWear(
      config: SynheartWearConfig.withAdapters({DeviceAdapter.appleHealthKit}),
    );
  }

  Future<void> _connect() async {
    try {
      // Step 1: Request permissions
      final result = await _sdk.requestPermissions(
        permissions: {
          PermissionType.heartRate,
          PermissionType.steps,
          PermissionType.calories,
        },
        reason: 'This app needs access to your health data.',
      );

      // Step 2: Initialize if permissions granted
      if (result.values.any((s) => s == ConsentStatus.granted)) {
        await _sdk.initialize();
        
        // Step 3: Read initial metrics
        final metrics = await _sdk.readMetrics();
        setState(() {
          _isConnected = true;
          _latestMetrics = metrics;
        });
      } else {
        setState(() {
          _isConnected = false;
          // Show error: permissions denied
        });
      }
    } on SynheartWearError catch (e) {
      // Handle SDK-specific errors (NO_WEARABLE_DATA, STALE_DATA, etc.)
      print('SDK Error: $e');
      setState(() {
        _isConnected = false;
        // Show error message
      });
    } catch (e) {
      // Handle other errors
      print('Error: $e');
      setState(() {
        _isConnected = false;
      });
    }
  }

  void _startStreaming() {
    _hrSubscription = _sdk.streamHR(interval: Duration(seconds: 3))
      .listen((metrics) {
        setState(() => _latestMetrics = metrics);
      });
  }

  @override
  void dispose() {
    _hrSubscription?.cancel();
    _sdk.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Health Monitor')),
      body: _isConnected
          ? Column(
              children: [
                if (_latestMetrics != null) ...[
                  Text('HR: ${_latestMetrics!.getMetric(MetricType.hr)} bpm'),
                  Text('Steps: ${_latestMetrics!.getMetric(MetricType.steps)}'),
                ],
                ElevatedButton(
                  onPressed: _startStreaming,
                  child: Text('Start Streaming'),
                ),
              ],
            )
          : Center(
              child: ElevatedButton(
                onPressed: _connect,
                child: Text('Connect to Health'),
              ),
            ),
    );
  }
}
```

### Error Handling

```dart
try {
  // Request permissions
  final result = await synheart.requestPermissions(
    permissions: {PermissionType.heartRate, PermissionType.steps},
    reason: 'This app needs access to your health data.',
  );

  if (result.values.any((s) => s == ConsentStatus.granted)) {
    // Initialize (may throw if no data or stale data)
    await synheart.initialize();
    
    // Read metrics
    final metrics = await synheart.readMetrics();
    if (metrics.hasValidData) {
      print('Data available');
    }
  }
} on PermissionDeniedError catch (e) {
  print('Permission denied: $e');
  // User denied permissions - show message or retry
} on DeviceUnavailableError catch (e) {
  print('Device unavailable: $e');
  // Health data source not available - check device connection
} on SynheartWearError catch (e) {
  // Handle SDK-specific errors
  if (e.code == 'NO_WEARABLE_DATA') {
    print('No wearable data available. Please check device connection.');
  } else if (e.code == 'STALE_DATA') {
    print('Data is stale. Please sync your wearable device.');
  } else {
    print('SDK error: $e');
  }
} catch (e) {
  print('Unexpected error: $e');
}
```

**Common Error Codes:**
- `NO_WEARABLE_DATA`: No health data available from connected devices
- `STALE_DATA`: Latest data is older than 24 hours
- `PERMISSION_DENIED`: User denied required permissions
- `DEVICE_UNAVAILABLE`: Health data source is not available

</details>

<details>
<summary><b>Architecture</b></summary>

```
┌─────────────────────────┐
│   synheart_wear SDK     │
├─────────────────────────┤
│ Device Adapters Layer   │
│ (Apple, Fitbit, etc.)   │
├─────────────────────────┤
│ Normalization Engine    │
│ (standard output schema)│
├─────────────────────────┤
│   Local Cache & Storage │
│   (encrypted, offline)  │
└─────────────────────────┘
```

</details>

<details>
<summary><b>Roadmap</b></summary>

| Version | Goal                    | Status         |
| ------- | ----------------------- | -------------- |
| v0.1    | Core SDK                | ✅ Complete    |
| v0.2    | Real-time streaming     | ✅ Complete    |
| v0.3    | Extended device support | 🔄 In Progress |
| v0.4    | SWIP integration        | 📋 Planned     |
| v1.0    | Public Release          | 📋 Planned     |

</details>

---

## ⌚ Real-Time Watch Data

Due to HealthKit (iOS) and Health Connect (Android) API limitations, real-time biometric streaming (HR, HRV, accelerometer) requires an active workout/exercise session on the watch. For real-time session-based data, use the Synheart watch companion apps alongside the [Synheart Session SDK](https://github.com/synheart-ai/synheart-session):

- [synheart-wear-watch-ios](https://github.com/synheart-ai/synheart-wear-watch-ios) — watchOS companion (HKWorkoutSession)
- [synheart-wear-watch-android](https://github.com/synheart-ai/synheart-wear-watch-android) — Wear OS companion (Health Services)

This SDK handles non-realtime and historical data (daily HR, HRV, steps, sleep, etc.) which does not require a workout session.

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guidelines](CONTRIBUTING.md) or:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

Apache 2.0 License

## 👥 Authors

- **Israel Goytom** - _Initial work_ - [@isrugeek](https://github.com/isrugeek)
- **Synheart AI Team** - _RFC Design & Architecture_

---

**Made with ❤️ by the Synheart AI Team**

_Technology with a heartbeat._

## Patent Pending Notice

This project is provided under an open-source license. Certain underlying systems, methods, and architectures described or implemented herein may be covered by one or more pending patent applications.

Nothing in this repository grants any license, express or implied, to any patents or patent applications, except as provided by the applicable open-source license.
