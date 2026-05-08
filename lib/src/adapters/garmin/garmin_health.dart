import 'dart:async';

import '../../core/config.dart';
import '../../core/models.dart';
import '../../models/garmin_connection_state.dart';
import '../../models/garmin_device.dart';
import '../../models/wearable_device.dart';
import '../wear_adapter.dart';
import 'garmin_sdk_adapter.dart';

/// Public facade for Garmin Health SDK integration
///
/// Wraps internal Garmin types and exposes only generic, SDK-owned types.
/// All method signatures use [ScannedDevice], [PairedDevice],
/// [DeviceConnectionState], [DeviceConnectionEvent], and [WearMetrics].
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
  final GarminAdapter _adapter;

  /// Create a GarminHealth instance with a Garmin SDK license key
  GarminHealth({required String licenseKey})
    : _adapter = GarminAdapter(licenseKey: licenseKey);

  // ============================================
  // Lifecycle
  // ============================================

  /// Initialize the Garmin SDK
  ///
  /// Must be called before any other operations.
  /// Throws [SynheartWearError] if initialization fails.
  Future<void> initialize() => _adapter.initialize();

  /// Whether the SDK is initialized
  bool get isInitialized => _adapter.isInitialized;

  /// Dispose all resources
  void dispose() => _adapter.dispose();

  /// Internal adapter for registration with [SynheartWear]
  WearAdapter get adapter => _adapter;

  // ============================================
  // Scanning
  // ============================================

  /// Start scanning for Garmin devices
  ///
  /// Listen to [scannedDevicesStream] to receive discovered devices.
  Future<void> startScanning({int timeoutSeconds = 30}) =>
      _adapter.deviceManager.startScanning(timeoutSeconds: timeoutSeconds);

  /// Stop scanning for devices
  Future<void> stopScanning() => _adapter.deviceManager.stopScanning();

  /// Stream of discovered devices during scanning
  ///
  /// Returns generic [ScannedDevice] instances, not Garmin-specific types.
  Stream<List<ScannedDevice>> get scannedDevicesStream => _adapter
      .deviceManager
      .scannedDevicesStream
      .map((devices) => devices.map(_toScannedDevice).toList());

  // ============================================
  // Pairing
  // ============================================

  /// Pair with a discovered device
  ///
  /// Returns a generic [PairedDevice] on success.
  /// Throws [SynheartWearError] if pairing fails.
  Future<PairedDevice> pairDevice(ScannedDevice device) async {
    final garminScanned = GarminScannedDevice(
      identifier: device.identifier,
      name: device.name,
      modelName: device.modelName,
      rssi: device.rssi,
      isPaired: device.isPaired,
    );
    final garminDevice = await _adapter.deviceManager.pairDevice(garminScanned);
    return _toPairedDevice(garminDevice);
  }

  /// Forget (unpair) a device
  Future<void> forgetDevice(PairedDevice device) async {
    final garminDevice = _toGarminDevice(device);
    await _adapter.deviceManager.forgetDevice(garminDevice);
  }

  /// Get list of paired devices
  Future<List<PairedDevice>> getPairedDevices() async {
    final devices = await _adapter.deviceManager.getPairedDevices();
    return devices.map(_toPairedDevice).toList();
  }

  // ============================================
  // Connection
  // ============================================

  /// Stream of connection state changes
  ///
  /// Returns generic [DeviceConnectionEvent] instances.
  Stream<DeviceConnectionEvent> get connectionStateStream =>
      _adapter.connectionStateStream.map(_toConnectionEvent);

  /// Get connection state for a device
  Future<DeviceConnectionState> getConnectionState(PairedDevice device) async {
    final garminDevice = _toGarminDevice(device);
    final state = await _adapter.deviceManager.getConnectionState(garminDevice);
    return _mapConnectionState(state);
  }

  // ============================================
  // Sync
  // ============================================

  /// Request a sync operation with a device
  Future<void> requestSync(PairedDevice device) async {
    final garminDevice = _toGarminDevice(device);
    await _adapter.deviceManager.requestSync(garminDevice);
  }

  // ============================================
  // Streaming
  // ============================================

  /// Start real-time data streaming
  ///
  /// Listen to [realTimeStream] to receive [WearMetrics] data.
  Future<void> startStreaming({PairedDevice? device}) async {
    GarminDevice? garminDevice;
    if (device != null) {
      garminDevice = _toGarminDevice(device);
    }
    await _adapter.startStreaming(device: garminDevice);
  }

  /// Stop real-time data streaming
  Future<void> stopStreaming({PairedDevice? device}) async {
    GarminDevice? garminDevice;
    if (device != null) {
      garminDevice = _toGarminDevice(device);
    }
    await _adapter.stopStreaming(device: garminDevice);
  }

  /// Stream of real-time data as unified [WearMetrics]
  ///
  /// Returns [WearMetrics] instances, not Garmin-specific real-time data.
  Stream<WearMetrics> get realTimeStream =>
      _adapter.realTimeStream.map(_adapter.convertRealTimeToMetrics);

  // ============================================
  // Metrics
  // ============================================

  /// Read unified metrics from Garmin device
  ///
  /// Returns [WearMetrics] aggregated from available Garmin data sources.
  Future<WearMetrics?> readMetrics({DateTime? startTime, DateTime? endTime}) =>
      _adapter.readSnapshot(
        isRealTime: false,
        startTime: startTime,
        endTime: endTime,
      );

  // ============================================
  // Private Converters
  // ============================================

  ScannedDevice _toScannedDevice(GarminScannedDevice garmin) {
    return ScannedDevice(
      identifier: garmin.identifier,
      name: garmin.name,
      modelName: garmin.modelName ?? garmin.type.displayName,
      rssi: garmin.rssi,
      isPaired: garmin.isPaired,
      adapter: DeviceAdapter.garmin,
      discoveredAt: garmin.discoveredAt,
    );
  }

  PairedDevice _toPairedDevice(GarminDevice garmin) {
    return PairedDevice(
      deviceId: garmin.unitId.toString(),
      identifier: garmin.identifier,
      name: garmin.name,
      modelName: garmin.modelName ?? garmin.type.displayName,
      connectionState: _mapConnectionState(garmin.connectionState),
      batteryLevel: garmin.batteryLevel,
      lastSyncTime: garmin.lastSyncTime,
      supportsStreaming: garmin.supportsStreaming,
      adapter: DeviceAdapter.garmin,
    );
  }

  GarminDevice _toGarminDevice(PairedDevice device) {
    return GarminDevice(
      unitId: int.parse(device.deviceId),
      identifier: device.identifier,
      name: device.name,
      connectionState: _reverseConnectionState(device.connectionState),
      batteryLevel: device.batteryLevel,
      lastSyncTime: device.lastSyncTime,
      supportsStreaming: device.supportsStreaming,
    );
  }

  DeviceConnectionEvent _toConnectionEvent(GarminConnectionStateEvent garmin) {
    return DeviceConnectionEvent(
      state: _mapConnectionState(garmin.state),
      deviceId: garmin.deviceId?.toString(),
      error: garmin.error,
      timestamp: garmin.timestamp,
    );
  }

  static DeviceConnectionState _mapConnectionState(
    GarminConnectionState state,
  ) {
    switch (state) {
      case GarminConnectionState.disconnected:
        return DeviceConnectionState.disconnected;
      case GarminConnectionState.connecting:
        return DeviceConnectionState.connecting;
      case GarminConnectionState.connected:
        return DeviceConnectionState.connected;
      case GarminConnectionState.failed:
        return DeviceConnectionState.failed;
      case GarminConnectionState.unknown:
        return DeviceConnectionState.unknown;
    }
  }

  static GarminConnectionState _reverseConnectionState(
    DeviceConnectionState state,
  ) {
    switch (state) {
      case DeviceConnectionState.disconnected:
        return GarminConnectionState.disconnected;
      case DeviceConnectionState.connecting:
        return GarminConnectionState.connecting;
      case DeviceConnectionState.connected:
        return GarminConnectionState.connected;
      case DeviceConnectionState.failed:
        return GarminConnectionState.failed;
      case DeviceConnectionState.unknown:
        return GarminConnectionState.unknown;
    }
  }
}
