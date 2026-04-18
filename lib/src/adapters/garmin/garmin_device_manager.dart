import 'dart:async';

import '../../core/logger.dart';
import '../../models/garmin_connection_state.dart';
import '../../models/garmin_device.dart';
import 'garmin_errors.dart';
import 'garmin_platform_channel.dart';

/// Real-time data types that can be streamed from Garmin devices
enum GarminRealTimeType {
  /// Heart rate in BPM
  heartRate,

  /// Stress level (0-100)
  stress,

  /// HRV (Heart Rate Variability)
  hrv,

  /// Beat-to-beat intervals
  bbi,

  /// Step count
  steps,

  /// SpO2 (Blood oxygen)
  spo2,

  /// Respiration rate
  respiration,

  /// Accelerometer data
  accelerometer,

  /// Body battery
  bodyBattery,
}

/// Manager for Garmin device lifecycle operations
///
/// Handles device scanning, pairing, connection state, and data retrieval.
class GarminDeviceManager {
  bool _isInitialized = false;
  final String _licenseKey;

  StreamSubscription<GarminConnectionStateEvent>? _connectionStateSubscription;
  StreamSubscription<List<GarminScannedDevice>>? _scannedDevicesSubscription;

  final StreamController<GarminConnectionStateEvent> _connectionStateController =
      StreamController<GarminConnectionStateEvent>.broadcast();
  final StreamController<List<GarminScannedDevice>> _scannedDevicesController =
      StreamController<List<GarminScannedDevice>>.broadcast();

  /// Create a new GarminDeviceManager with a license key
  GarminDeviceManager({required String licenseKey}) : _licenseKey = licenseKey;

  /// Whether the SDK is initialized
  bool get isInitialized => _isInitialized;

  /// Stream of connection state changes
  Stream<GarminConnectionStateEvent> get connectionStateStream =>
      _connectionStateController.stream;

  /// Stream of scanned devices during discovery
  Stream<List<GarminScannedDevice>> get scannedDevicesStream =>
      _scannedDevicesController.stream;

  // ============================================
  // Initialization
  // ============================================

  /// Initialize the Garmin SDK
  ///
  /// Must be called before any other operations.
  /// Throws [GarminInitializationError] if initialization fails.
  ///
  /// If the native SDK is already initialized (e.g. another screen in the
  /// host app already owns it), the second `initializeSDK` call would fail
  /// with `LICENSE_ALREADY_REGISTERED`. We probe `isInitialized()` first and
  /// skip the licence handshake in that case so the manager can attach event
  /// subscriptions and become usable without throwing.
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final available = await GarminPlatformChannel.isAvailable();
      if (!available) {
        throw GarminInitializationError(
          'Garmin SDK is not available on this platform',
        );
      }

      final alreadyInitialized = await GarminPlatformChannel.isInitialized();
      if (alreadyInitialized) {
        logInfo(
          'Garmin SDK already initialized natively; reusing existing session',
        );
      } else {
        final success = await GarminPlatformChannel.initializeSDK(_licenseKey);
        if (!success) {
          throw GarminLicenseError('Failed to initialize with license key');
        }
      }

      _setupEventSubscriptions();
      _isInitialized = true;
      logInfo('Garmin SDK ready');
    } catch (e) {
      if (e is GarminSDKError) rethrow;
      throw GarminInitializationError(
        'Failed to initialize Garmin SDK: $e',
        originalException: e is Exception ? e : null,
      );
    }
  }

  void _setupEventSubscriptions() {
    // Forward connection state events
    _connectionStateSubscription = GarminPlatformChannel.connectionStateStream
        .listen(
          (event) => _connectionStateController.add(event),
          onError: (e) => _connectionStateController.addError(e),
        );

    // Forward scanned devices events
    _scannedDevicesSubscription = GarminPlatformChannel.scannedDevicesStream
        .listen(
          (devices) => _scannedDevicesController.add(devices),
          onError: (e) => _scannedDevicesController.addError(e),
        );
  }

  // ============================================
  // Device Scanning
  // ============================================

  /// Start scanning for Garmin devices
  ///
  /// [deviceTypes] - Optional filter for specific device types
  /// [timeoutSeconds] - Scan timeout in seconds (default: 30)
  ///
  /// Listen to [scannedDevicesStream] to receive discovered devices.
  Future<void> startScanning({
    List<GarminDeviceType>? deviceTypes,
    int timeoutSeconds = 30,
  }) async {
    _ensureInitialized();

    try {
      await GarminPlatformChannel.startScanning(
        deviceTypes: deviceTypes,
        timeoutSeconds: timeoutSeconds,
      );
      logDebug('Started scanning for Garmin devices');
    } catch (e) {
      if (e is GarminSDKError) rethrow;
      throw GarminScanError(
        'Failed to start scanning: $e',
        originalException: e is Exception ? e : null,
      );
    }
  }

  /// Stop scanning for devices
  Future<void> stopScanning() async {
    try {
      await GarminPlatformChannel.stopScanning();
      logDebug('Stopped scanning for Garmin devices');
    } catch (e) {
      if (e is GarminSDKError) rethrow;
      throw GarminScanError(
        'Failed to stop scanning: $e',
        originalException: e is Exception ? e : null,
      );
    }
  }

  // ============================================
  // Device Pairing
  // ============================================

  /// Pair with a discovered device
  ///
  /// Returns the paired [GarminDevice] on success.
  /// Throws [GarminPairingError] if pairing fails.
  Future<GarminDevice> pairDevice(GarminScannedDevice device) async {
    _ensureInitialized();

    try {
      logInfo('Pairing with device: ${device.name} (${device.identifier})');
      final pairedDevice = await GarminPlatformChannel.pairDevice(
        device.identifier,
      );
      logInfo('Successfully paired with: ${pairedDevice.name}');
      return pairedDevice;
    } catch (e) {
      if (e is GarminSDKError) rethrow;
      throw GarminPairingError(
        'Failed to pair with device: $e',
        deviceIdentifier: device.identifier,
        originalException: e is Exception ? e : null,
      );
    }
  }

  /// Cancel an ongoing pairing operation
  Future<void> cancelPairing() async {
    try {
      await GarminPlatformChannel.cancelPairing();
      logDebug('Pairing cancelled');
    } catch (e) {
      if (e is GarminSDKError) rethrow;
      throw GarminPairingError(
        'Failed to cancel pairing: $e',
        originalException: e is Exception ? e : null,
      );
    }
  }

  /// Forget (unpair) a device
  ///
  /// [deleteData] - If true, also deletes locally stored data for the device
  Future<void> forgetDevice(GarminDevice device, {bool deleteData = false}) async {
    _ensureInitialized();

    try {
      await GarminPlatformChannel.forgetDevice(
        device.unitId,
        deleteData: deleteData,
      );
      logInfo('Forgot device: ${device.name}');
    } catch (e) {
      if (e is GarminSDKError) rethrow;
      throw GarminConnectionError(
        'Failed to forget device: $e',
        deviceId: device.unitId,
        originalException: e is Exception ? e : null,
      );
    }
  }

  /// Get list of paired devices
  Future<List<GarminDevice>> getPairedDevices() async {
    _ensureInitialized();

    try {
      return await GarminPlatformChannel.getPairedDevices();
    } catch (e) {
      if (e is GarminSDKError) rethrow;
      throw GarminSDKError(
        'Failed to get paired devices: $e',
        originalException: e is Exception ? e : null,
      );
    }
  }

  // ============================================
  // Connection & Sync
  // ============================================

  /// Get connection state for a device
  Future<GarminConnectionState> getConnectionState(GarminDevice device) async {
    _ensureInitialized();

    try {
      return await GarminPlatformChannel.getConnectionState(device.unitId);
    } catch (e) {
      if (e is GarminSDKError) rethrow;
      return GarminConnectionState.unknown;
    }
  }

  /// Request a sync operation with a device
  ///
  /// Listen to [syncProgressStream] for progress updates.
  Future<void> requestSync(GarminDevice device) async {
    _ensureInitialized();

    try {
      await GarminPlatformChannel.requestSync(device.unitId);
      logInfo('Requested sync with device: ${device.name}');
    } catch (e) {
      if (e is GarminSDKError) rethrow;
      throw GarminSyncError(
        'Failed to request sync: $e',
        deviceId: device.unitId,
        originalException: e is Exception ? e : null,
      );
    }
  }

  /// Get battery level for a device
  ///
  /// Returns battery percentage (0-100) or null if unavailable.
  Future<int?> getBatteryLevel(GarminDevice device) async {
    _ensureInitialized();

    try {
      return await GarminPlatformChannel.getBatteryLevel(device.unitId);
    } catch (e) {
      logWarning('Failed to get battery level', e);
      return null;
    }
  }

  /// Stream of sync progress events
  Stream<Map<String, dynamic>> get syncProgressStream =>
      GarminPlatformChannel.syncProgressStream;

  // ============================================
  // Real-Time Streaming
  // ============================================

  /// Start real-time data streaming from a device
  ///
  /// [device] - The device to stream from (optional, uses first connected)
  /// [dataTypes] - Set of data types to stream (optional, streams all available)
  ///
  /// Listen to [realTimeStream] to receive data.
  Future<void> startStreaming({
    GarminDevice? device,
    Set<GarminRealTimeType>? dataTypes,
  }) async {
    _ensureInitialized();

    try {
      await GarminPlatformChannel.startStreaming(
        deviceId: device?.unitId,
        dataTypes: dataTypes?.map((t) => t.name).toSet(),
      );
      logInfo('Started real-time streaming');
    } catch (e) {
      if (e is GarminSDKError) rethrow;
      throw GarminStreamingError(
        'Failed to start streaming: $e',
        originalException: e is Exception ? e : null,
      );
    }
  }

  /// Stop real-time data streaming
  Future<void> stopStreaming({GarminDevice? device}) async {
    try {
      await GarminPlatformChannel.stopStreaming(deviceId: device?.unitId);
      logDebug('Stopped real-time streaming');
    } catch (e) {
      if (e is GarminSDKError) rethrow;
      throw GarminStreamingError(
        'Failed to stop streaming: $e',
        originalException: e is Exception ? e : null,
      );
    }
  }

  /// Stream of real-time data from connected device
  Stream<Map<String, dynamic>> get realTimeStream =>
      GarminPlatformChannel.realTimeDataStream;

  // ============================================
  // Logged Data Access
  // ============================================

  /// Read logged heart rate data from device
  Future<List<GarminLoggedHeartRate>> readLoggedHeartRate({
    GarminDevice? device,
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    _ensureInitialized();

    try {
      final data = await GarminPlatformChannel.readLoggedHeartRate(
        deviceId: device?.unitId,
        startTime: startTime,
        endTime: endTime,
      );
      return data.map((m) => GarminLoggedHeartRate.fromMap(m)).toList();
    } catch (e) {
      if (e is GarminSDKError) rethrow;
      throw GarminDataError(
        'Failed to read logged heart rate: $e',
        originalException: e is Exception ? e : null,
      );
    }
  }

  /// Read logged stress data from device
  Future<List<GarminLoggedStress>> readLoggedStress({
    GarminDevice? device,
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    _ensureInitialized();

    try {
      final data = await GarminPlatformChannel.readLoggedStress(
        deviceId: device?.unitId,
        startTime: startTime,
        endTime: endTime,
      );
      return data.map((m) => GarminLoggedStress.fromMap(m)).toList();
    } catch (e) {
      if (e is GarminSDKError) rethrow;
      throw GarminDataError(
        'Failed to read logged stress: $e',
        originalException: e is Exception ? e : null,
      );
    }
  }

  /// Read logged respiration data from device
  Future<List<GarminLoggedRespiration>> readLoggedRespiration({
    GarminDevice? device,
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    _ensureInitialized();

    try {
      final data = await GarminPlatformChannel.readLoggedRespiration(
        deviceId: device?.unitId,
        startTime: startTime,
        endTime: endTime,
      );
      return data.map((m) => GarminLoggedRespiration.fromMap(m)).toList();
    } catch (e) {
      if (e is GarminSDKError) rethrow;
      throw GarminDataError(
        'Failed to read logged respiration: $e',
        originalException: e is Exception ? e : null,
      );
    }
  }

  // ============================================
  // WiFi Operations
  // ============================================

  /// Scan for WiFi access points (for WiFi sync feature)
  Future<List<GarminAccessPoint>> scanAccessPoints(GarminDevice device) async {
    _ensureInitialized();

    try {
      final data = await GarminPlatformChannel.scanAccessPoints(device.unitId);
      return data.map((m) => GarminAccessPoint.fromMap(m)).toList();
    } catch (e) {
      if (e is GarminSDKError) rethrow;
      throw GarminSDKError(
        'Failed to scan access points: $e',
        originalException: e is Exception ? e : null,
      );
    }
  }

  /// Store WiFi access point credentials on device
  Future<void> storeAccessPoint({
    required GarminDevice device,
    required GarminAccessPoint accessPoint,
    required String password,
  }) async {
    _ensureInitialized();

    try {
      await GarminPlatformChannel.storeAccessPoint(
        unitId: device.unitId,
        ssid: accessPoint.ssid,
        password: password,
      );
    } catch (e) {
      if (e is GarminSDKError) rethrow;
      throw GarminSDKError(
        'Failed to store access point: $e',
        originalException: e is Exception ? e : null,
      );
    }
  }

  // ============================================
  // Cleanup
  // ============================================

  /// Dispose all resources
  void dispose() {
    _connectionStateSubscription?.cancel();
    _scannedDevicesSubscription?.cancel();
    _connectionStateController.close();
    _scannedDevicesController.close();
    GarminPlatformChannel.dispose();
    _isInitialized = false;
  }

  void _ensureInitialized() {
    if (!_isInitialized) {
      throw GarminInitializationError('Garmin SDK not initialized. Call initialize() first.');
    }
  }
}

// ============================================
// Logged Data Models
// ============================================

/// Data status for logged samples
enum GarminDataStatus {
  /// Valid measurement
  valid,

  /// Invalid or unknown measurement
  invalid,

  /// Data point during sleep
  sleep,

  /// Data point during off-wrist period
  offWrist,
}

/// Logged heart rate sample
class GarminLoggedHeartRate {
  final DateTime timestamp;
  final int heartRate;
  final GarminDataStatus status;

  GarminLoggedHeartRate({
    required this.timestamp,
    required this.heartRate,
    this.status = GarminDataStatus.valid,
  });

  factory GarminLoggedHeartRate.fromMap(Map<String, dynamic> map) {
    return GarminLoggedHeartRate(
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
      heartRate: map['heartRate'] as int,
      status: _parseDataStatus(map['status'] as String?),
    );
  }

  Map<String, dynamic> toMap() => {
    'timestamp': timestamp.millisecondsSinceEpoch,
    'heartRate': heartRate,
    'status': status.name,
  };
}

/// Logged stress sample
class GarminLoggedStress {
  final DateTime timestamp;
  final int stress;
  final GarminDataStatus status;

  GarminLoggedStress({
    required this.timestamp,
    required this.stress,
    this.status = GarminDataStatus.valid,
  });

  factory GarminLoggedStress.fromMap(Map<String, dynamic> map) {
    return GarminLoggedStress(
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
      stress: map['stress'] as int,
      status: _parseDataStatus(map['status'] as String?),
    );
  }

  Map<String, dynamic> toMap() => {
    'timestamp': timestamp.millisecondsSinceEpoch,
    'stress': stress,
    'status': status.name,
  };
}

/// Logged respiration sample
class GarminLoggedRespiration {
  final DateTime timestamp;
  final int breathsPerMinute;
  final GarminDataStatus status;

  GarminLoggedRespiration({
    required this.timestamp,
    required this.breathsPerMinute,
    this.status = GarminDataStatus.valid,
  });

  factory GarminLoggedRespiration.fromMap(Map<String, dynamic> map) {
    return GarminLoggedRespiration(
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
      breathsPerMinute: map['breathsPerMinute'] as int,
      status: _parseDataStatus(map['status'] as String?),
    );
  }

  Map<String, dynamic> toMap() => {
    'timestamp': timestamp.millisecondsSinceEpoch,
    'breathsPerMinute': breathsPerMinute,
    'status': status.name,
  };
}

/// WiFi access point information
class GarminAccessPoint {
  final String ssid;
  final int signalStrength;
  final bool isSecured;
  final bool isStored;

  GarminAccessPoint({
    required this.ssid,
    this.signalStrength = 0,
    this.isSecured = true,
    this.isStored = false,
  });

  factory GarminAccessPoint.fromMap(Map<String, dynamic> map) {
    return GarminAccessPoint(
      ssid: map['ssid'] as String,
      signalStrength: map['signalStrength'] as int? ?? 0,
      isSecured: map['isSecured'] as bool? ?? true,
      isStored: map['isStored'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
    'ssid': ssid,
    'signalStrength': signalStrength,
    'isSecured': isSecured,
    'isStored': isStored,
  };
}

GarminDataStatus _parseDataStatus(String? status) {
  if (status == null) return GarminDataStatus.valid;
  switch (status.toLowerCase()) {
    case 'valid':
      return GarminDataStatus.valid;
    case 'invalid':
      return GarminDataStatus.invalid;
    case 'sleep':
      return GarminDataStatus.sleep;
    case 'off_wrist':
    case 'offwrist':
      return GarminDataStatus.offWrist;
    default:
      return GarminDataStatus.valid;
  }
}
