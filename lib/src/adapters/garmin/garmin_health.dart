import 'dart:async';

import '../../core/consent_manager.dart';
import '../../core/models.dart';
import '../../models/wearable_device.dart';
import '../wear_adapter.dart';

/// Public facade for Garmin Health SDK integration.
///
/// **Important:** the Garmin Health SDK real-time streaming (RTS) capability
/// requires a separate license from Garmin. This stub is included in the
/// open-source SDK so that consumer code stays portable; the real
/// implementation lives in the private `synheart-wear-garmin-companion`
/// repository and is overlaid into this package at build time.
///
/// To enable RTS support, run `make build-with-garmin` from the package root.
/// It will (a) clone the companion repo into `.garmin/` and (b) symlink the
/// licensed Dart, model, and Android-bridge files over these stubs. See
/// `GARMIN_SETUP.md` for the full guide.
///
/// Without the overlay, every method on this class except [initialize],
/// [isInitialized], [dispose], and [adapter] either throws [UnsupportedError]
/// or returns an empty value. Non-Garmin adapters (Apple HealthKit, Health
/// Connect, Whoop, BLE HRM, …) are unaffected.
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

  /// Create a GarminHealth instance with a Garmin SDK license key.
  GarminHealth({required String licenseKey}) : _licenseKey = licenseKey;

  // ============================================
  // Lifecycle
  // ============================================

  /// Initialize the Garmin SDK.
  ///
  /// In stub mode this only validates the license key is non-empty and flips
  /// [isInitialized]. The companion overlay replaces this with a real
  /// initialization call into the native Garmin SDK.
  Future<void> initialize() async {
    assert(_licenseKey.isNotEmpty, 'licenseKey must not be empty');
    _isInitialized = true;
  }

  /// Whether the SDK is initialized.
  bool get isInitialized => _isInitialized;

  /// Dispose all resources.
  void dispose() {
    _isInitialized = false;
  }

  /// Internal adapter for registration with `SynheartWear`.
  WearAdapter get adapter => _GarminStubAdapter();

  // ============================================
  // Scanning
  // ============================================

  /// Start scanning for Garmin devices.
  ///
  /// Throws [UnsupportedError] in stub mode — RTS requires the companion SDK.
  Future<void> startScanning({int timeoutSeconds = 30}) {
    throw UnsupportedError('Garmin RTS requires companion SDK');
  }

  /// Stop scanning for devices.
  Future<void> stopScanning() async {}

  /// Stream of discovered devices during scanning.
  ///
  /// Returns an empty stream in stub mode.
  Stream<List<ScannedDevice>> get scannedDevicesStream =>
      const Stream.empty();

  // ============================================
  // Pairing
  // ============================================

  /// Pair with a discovered device.
  ///
  /// Throws [UnsupportedError] in stub mode — RTS requires the companion SDK.
  Future<PairedDevice> pairDevice(ScannedDevice device) {
    throw UnsupportedError('Garmin RTS requires companion SDK');
  }

  /// Forget (unpair) a device.
  ///
  /// Throws [UnsupportedError] in stub mode — RTS requires the companion SDK.
  Future<void> forgetDevice(PairedDevice device) {
    throw UnsupportedError('Garmin RTS requires companion SDK');
  }

  /// Get list of paired devices.
  ///
  /// Returns an empty list in stub mode.
  Future<List<PairedDevice>> getPairedDevices() async => [];

  // ============================================
  // Connection
  // ============================================

  /// Stream of connection state changes.
  ///
  /// Returns an empty stream in stub mode.
  Stream<DeviceConnectionEvent> get connectionStateStream =>
      const Stream.empty();

  /// Get connection state for a device.
  ///
  /// Returns [DeviceConnectionState.disconnected] in stub mode.
  Future<DeviceConnectionState> getConnectionState(PairedDevice device) async =>
      DeviceConnectionState.disconnected;

  // ============================================
  // Sync
  // ============================================

  /// Request a sync operation with a device.
  ///
  /// Throws [UnsupportedError] in stub mode — RTS requires the companion SDK.
  Future<void> requestSync(PairedDevice device) {
    throw UnsupportedError('Garmin RTS requires companion SDK');
  }

  // ============================================
  // Streaming
  // ============================================

  /// Start real-time data streaming.
  ///
  /// Throws [UnsupportedError] in stub mode — RTS requires the companion SDK.
  Future<void> startStreaming({PairedDevice? device}) {
    throw UnsupportedError('Garmin RTS requires companion SDK');
  }

  /// Stop real-time data streaming.
  Future<void> stopStreaming({PairedDevice? device}) async {}

  /// Stream of real-time data as unified `WearMetrics`.
  ///
  /// Returns an empty stream in stub mode.
  Stream<WearMetrics> get realTimeStream => const Stream.empty();

  // ============================================
  // Metrics
  // ============================================

  /// Read unified metrics from a Garmin device.
  ///
  /// Returns null in stub mode.
  Future<WearMetrics?> readMetrics({
    DateTime? startTime,
    DateTime? endTime,
  }) async =>
      null;
}

/// Stub adapter that returns no data.
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
