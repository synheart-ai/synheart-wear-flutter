import 'dart:async';

import '../../core/consent_manager.dart';
import '../../core/models.dart';
import '../../models/wearable_device.dart';
import '../wear_adapter.dart';

/// Public facade for Garmin Health SDK integration
///
/// **Important:** The Garmin Health SDK real-time streaming (RTS) capability
/// requires a separate license from Garmin. This stub is included in the
/// open-source SDK for API compatibility. The full implementation is available
/// in the private `synheart-wear-garmin-companion` repository.
///
/// For cloud-based Garmin data (OAuth + webhooks), use `GarminProvider` instead.
///
/// To enable RTS support, run `make build` — it will auto-detect
/// companion repo access and link the full implementation.
///
/// ```dart
/// final garmin = GarminHealth(licenseKey: 'your-key');
/// await garmin.initialize();
///
/// garmin.scannedDevicesStream.listen((devices) {
///   print('Found ${devices.length} devices');
/// });
/// await garmin.startScanning();
///
/// final paired = await garmin.pairDevice(scannedDevice);
/// final metrics = await garmin.readMetrics();
/// ```
class GarminHealth {
  final String _licenseKey;
  bool _isInitialized = false;

  /// Create a GarminHealth instance with a Garmin SDK license key
  GarminHealth({required String licenseKey}) : _licenseKey = licenseKey;

  // ============================================
  // Lifecycle
  // ============================================

  /// Initialize the Garmin SDK
  ///
  /// Must be called before any other operations.
  /// Throws [UnsupportedError] — RTS requires the companion SDK.
  Future<void> initialize() async {
    assert(_licenseKey.isNotEmpty, 'licenseKey must not be empty');
    _isInitialized = true;
  }

  /// Whether the SDK is initialized
  bool get isInitialized => _isInitialized;

  /// Dispose all resources
  void dispose() {
    _isInitialized = false;
  }

  /// Internal adapter for registration with [SynheartWear]
  WearAdapter get adapter => _GarminStubAdapter();

  // ============================================
  // Scanning
  // ============================================

  /// Start scanning for Garmin devices
  ///
  /// Throws [UnsupportedError] — RTS requires the companion SDK.
  Future<void> startScanning({int timeoutSeconds = 30}) {
    throw UnsupportedError('Garmin RTS requires companion SDK');
  }

  /// Stop scanning for devices
  Future<void> stopScanning() async {}

  /// Stream of discovered devices during scanning
  ///
  /// Returns an empty stream — RTS requires the companion SDK.
  Stream<List<ScannedDevice>> get scannedDevicesStream =>
      const Stream.empty();

  // ============================================
  // Pairing
  // ============================================

  /// Pair with a discovered device
  ///
  /// Throws [UnsupportedError] — RTS requires the companion SDK.
  Future<PairedDevice> pairDevice(ScannedDevice device) {
    throw UnsupportedError('Garmin RTS requires companion SDK');
  }

  /// Forget (unpair) a device
  ///
  /// Throws [UnsupportedError] — RTS requires the companion SDK.
  Future<void> forgetDevice(PairedDevice device) {
    throw UnsupportedError('Garmin RTS requires companion SDK');
  }

  /// Get list of paired devices
  ///
  /// Returns an empty list — RTS requires the companion SDK.
  Future<List<PairedDevice>> getPairedDevices() async => [];

  // ============================================
  // Connection
  // ============================================

  /// Stream of connection state changes
  ///
  /// Returns an empty stream — RTS requires the companion SDK.
  Stream<DeviceConnectionEvent> get connectionStateStream =>
      const Stream.empty();

  /// Get connection state for a device
  ///
  /// Returns [DeviceConnectionState.disconnected] — RTS requires the companion SDK.
  Future<DeviceConnectionState> getConnectionState(PairedDevice device) async =>
      DeviceConnectionState.disconnected;

  // ============================================
  // Sync
  // ============================================

  /// Request a sync operation with a device
  ///
  /// Throws [UnsupportedError] — RTS requires the companion SDK.
  Future<void> requestSync(PairedDevice device) {
    throw UnsupportedError('Garmin RTS requires companion SDK');
  }

  // ============================================
  // Streaming
  // ============================================

  /// Start real-time data streaming
  ///
  /// Throws [UnsupportedError] — RTS requires the companion SDK.
  Future<void> startStreaming({PairedDevice? device}) {
    throw UnsupportedError('Garmin RTS requires companion SDK');
  }

  /// Stop real-time data streaming
  Future<void> stopStreaming({PairedDevice? device}) async {}

  /// Stream of real-time data as unified [WearMetrics]
  ///
  /// Returns an empty stream — RTS requires the companion SDK.
  Stream<WearMetrics> get realTimeStream => const Stream.empty();

  // ============================================
  // Metrics
  // ============================================

  /// Read unified metrics from Garmin device
  ///
  /// Returns null — RTS requires the companion SDK.
  Future<WearMetrics?> readMetrics({
    DateTime? startTime,
    DateTime? endTime,
  }) async =>
      null;
}

/// Stub adapter that returns no data
class _GarminStubAdapter implements WearAdapter {
  @override
  String get id => 'garmin_sdk';

  @override
  Set<PermissionType> get supportedPermissions => const {};

  @override
  Set<PermissionType> getPlatformSupportedPermissions() => const {};

  @override
  Future<WearMetrics?> readSnapshot({
    bool isRealTime = true,
    DateTime? startTime,
    DateTime? endTime,
  }) async =>
      null;
}
