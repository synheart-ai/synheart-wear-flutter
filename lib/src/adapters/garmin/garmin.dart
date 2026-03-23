/// Garmin Health SDK adapter for SynheartWear
///
/// Provides integration with Garmin wearable devices via the native
/// Garmin Health SDK (XCFramework for iOS, AAR for Android).
///
/// ## Quick Start
///
/// ```dart
/// import 'package:synheart_wear/synheart_wear.dart';
///
/// final garmin = GarminHealth(licenseKey: 'your-license-key');
/// await garmin.initialize();
///
/// // Scan for devices
/// garmin.scannedDevicesStream.listen((devices) {
///   print('Found ${devices.length} devices');
/// });
/// await garmin.startScanning();
///
/// // Pair with device
/// final device = await garmin.pairDevice(scannedDevice);
///
/// // Read unified metrics
/// final metrics = await garmin.readMetrics();
/// print('Heart Rate: ${metrics?.getMetric(MetricType.hr)}');
///
/// // Real-time streaming (returns WearMetrics)
/// garmin.realTimeStream.listen((metrics) {
///   print('HR: ${metrics.getMetric(MetricType.hr)}');
/// });
/// await garmin.startStreaming();
/// ```
library garmin;

export 'garmin_health.dart';
