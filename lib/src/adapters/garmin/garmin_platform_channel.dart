import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

import '../../models/garmin_connection_state.dart';
import '../../models/garmin_device.dart';
import 'garmin_errors.dart';

/// Platform channel abstraction for Garmin SDK communication
class GarminPlatformChannel {
  /// Method channel for invoking SDK methods
  static const MethodChannel _methodChannel = MethodChannel(
    'synheart_wear/garmin_sdk',
  );

  /// Event channel for connection state changes
  static const EventChannel _connectionStateChannel = EventChannel(
    'synheart_wear/garmin_sdk/connection_state',
  );

  /// Event channel for scanned devices
  static const EventChannel _scannedDevicesChannel = EventChannel(
    'synheart_wear/garmin_sdk/scanned_devices',
  );

  /// Event channel for real-time data
  static const EventChannel _realTimeDataChannel = EventChannel(
    'synheart_wear/garmin_sdk/real_time_data',
  );

  /// Event channel for sync progress
  static const EventChannel _syncProgressChannel = EventChannel(
    'synheart_wear/garmin_sdk/sync_progress',
  );

  /// Cached stream controllers for event channels
  static StreamController<GarminConnectionStateEvent>? _connectionStateController;
  static StreamController<List<GarminScannedDevice>>? _scannedDevicesController;
  static StreamController<Map<String, dynamic>>? _realTimeDataController;
  static StreamController<Map<String, dynamic>>? _syncProgressController;

  // ============================================
  // SDK Initialization
  // ============================================

  /// Check if Garmin SDK is available on this platform
  static Future<bool> isAvailable() async {
    if (!Platform.isIOS && !Platform.isAndroid) {
      return false;
    }
    try {
      final result = await _methodChannel.invokeMethod<bool>('isAvailable');
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Initialize the Garmin SDK with a license key
  static Future<bool> initializeSDK(String licenseKey) async {
    try {
      final result = await _methodChannel.invokeMethod<bool>(
        'initializeSDK',
        {'licenseKey': licenseKey},
      );
      return result ?? false;
    } on PlatformException catch (e) {
      throw garminErrorFromPlatformException(
        e,
        defaultMessage: 'Failed to initialize Garmin SDK: ${e.message}',
      );
    }
  }

  /// Check if SDK is initialized
  static Future<bool> isInitialized() async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('isInitialized');
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  // ============================================
  // Device Scanning
  // ============================================

  /// Start scanning for Garmin devices
  static Future<void> startScanning({
    List<GarminDeviceType>? deviceTypes,
    int? timeoutSeconds,
  }) async {
    try {
      await _methodChannel.invokeMethod<void>('startScanning', {
        if (deviceTypes != null)
          'deviceTypes': deviceTypes.map((t) => t.name).toList(),
        if (timeoutSeconds != null) 'timeout': timeoutSeconds,
      });
    } on PlatformException catch (e) {
      throw garminErrorFromPlatformException(
        e,
        defaultMessage: 'Failed to start scanning: ${e.message}',
      );
    }
  }

  /// Stop scanning for devices
  static Future<void> stopScanning() async {
    try {
      await _methodChannel.invokeMethod<void>('stopScanning');
    } on PlatformException catch (e) {
      throw garminErrorFromPlatformException(
        e,
        defaultMessage: 'Failed to stop scanning: ${e.message}',
      );
    }
  }

  /// Get stream of scanned devices
  static Stream<List<GarminScannedDevice>> get scannedDevicesStream {
    _scannedDevicesController ??= StreamController<List<GarminScannedDevice>>.broadcast(
      onListen: () {
        _scannedDevicesChannel.receiveBroadcastStream().listen(
          (data) {
            if (data is List) {
              final devices = data
                  .cast<Map<dynamic, dynamic>>()
                  .map((m) => GarminScannedDevice.fromMap(Map<String, dynamic>.from(m)))
                  .toList();
              _scannedDevicesController?.add(devices);
            }
          },
          onError: (error) {
            _scannedDevicesController?.addError(
              garminErrorFromPlatformException(error),
            );
          },
        );
      },
      onCancel: () {
        _scannedDevicesController?.close();
        _scannedDevicesController = null;
      },
    );
    return _scannedDevicesController!.stream;
  }

  // ============================================
  // Device Pairing
  // ============================================

  /// Pair with a discovered device
  static Future<GarminDevice> pairDevice(String identifier) async {
    try {
      final result = await _methodChannel.invokeMethod<Map<dynamic, dynamic>>(
        'pairDevice',
        {'identifier': identifier},
      );
      if (result == null) {
        throw GarminPairingError('Pairing returned no device data');
      }
      return GarminDevice.fromMap(Map<String, dynamic>.from(result));
    } on PlatformException catch (e) {
      throw garminErrorFromPlatformException(
        e,
        defaultMessage: 'Failed to pair device: ${e.message}',
      );
    }
  }

  /// Cancel ongoing pairing
  static Future<void> cancelPairing() async {
    try {
      await _methodChannel.invokeMethod<void>('cancelPairing');
    } on PlatformException catch (e) {
      throw garminErrorFromPlatformException(
        e,
        defaultMessage: 'Failed to cancel pairing: ${e.message}',
      );
    }
  }

  /// Forget (unpair) a device
  static Future<void> forgetDevice(int unitId, {bool deleteData = false}) async {
    try {
      await _methodChannel.invokeMethod<void>('forgetDevice', {
        'unitId': unitId,
        'deleteData': deleteData,
      });
    } on PlatformException catch (e) {
      throw garminErrorFromPlatformException(
        e,
        defaultMessage: 'Failed to forget device: ${e.message}',
      );
    }
  }

  /// Get list of paired devices
  static Future<List<GarminDevice>> getPairedDevices() async {
    try {
      final result = await _methodChannel.invokeMethod<List<dynamic>>('getPairedDevices');
      if (result == null) return [];
      return result
          .cast<Map<dynamic, dynamic>>()
          .map((m) => GarminDevice.fromMap(Map<String, dynamic>.from(m)))
          .toList();
    } on PlatformException catch (e) {
      throw garminErrorFromPlatformException(
        e,
        defaultMessage: 'Failed to get paired devices: ${e.message}',
      );
    }
  }

  // ============================================
  // Connection State
  // ============================================

  /// Get stream of connection state changes
  static Stream<GarminConnectionStateEvent> get connectionStateStream {
    _connectionStateController ??= StreamController<GarminConnectionStateEvent>.broadcast(
      onListen: () {
        _connectionStateChannel.receiveBroadcastStream().listen(
          (data) {
            if (data is Map) {
              final event = GarminConnectionStateEvent.fromMap(
                Map<String, dynamic>.from(data),
              );
              _connectionStateController?.add(event);
            }
          },
          onError: (error) {
            _connectionStateController?.addError(
              garminErrorFromPlatformException(error),
            );
          },
        );
      },
      onCancel: () {
        _connectionStateController?.close();
        _connectionStateController = null;
      },
    );
    return _connectionStateController!.stream;
  }

  /// Get current connection state for a device
  static Future<GarminConnectionState> getConnectionState(int unitId) async {
    try {
      final result = await _methodChannel.invokeMethod<String>(
        'getConnectionState',
        {'unitId': unitId},
      );
      return parseGarminConnectionState(result);
    } on PlatformException catch (e) {
      throw garminErrorFromPlatformException(
        e,
        defaultMessage: 'Failed to get connection state: ${e.message}',
      );
    }
  }

  // ============================================
  // Sync Operations
  // ============================================

  /// Request sync with device
  static Future<void> requestSync(int unitId) async {
    try {
      await _methodChannel.invokeMethod<void>('requestSync', {
        'unitId': unitId,
      });
    } on PlatformException catch (e) {
      throw garminErrorFromPlatformException(
        e,
        defaultMessage: 'Failed to request sync: ${e.message}',
      );
    }
  }

  /// Get battery level for device
  static Future<int?> getBatteryLevel(int unitId) async {
    try {
      final result = await _methodChannel.invokeMethod<int>(
        'getBatteryLevel',
        {'unitId': unitId},
      );
      return result;
    } on PlatformException catch (e) {
      throw garminErrorFromPlatformException(
        e,
        defaultMessage: 'Failed to get battery level: ${e.message}',
      );
    }
  }

  /// Get stream of sync progress
  static Stream<Map<String, dynamic>> get syncProgressStream {
    _syncProgressController ??= StreamController<Map<String, dynamic>>.broadcast(
      onListen: () {
        _syncProgressChannel.receiveBroadcastStream().listen(
          (data) {
            if (data is Map) {
              _syncProgressController?.add(Map<String, dynamic>.from(data));
            }
          },
          onError: (error) {
            _syncProgressController?.addError(
              garminErrorFromPlatformException(error),
            );
          },
        );
      },
      onCancel: () {
        _syncProgressController?.close();
        _syncProgressController = null;
      },
    );
    return _syncProgressController!.stream;
  }

  // ============================================
  // Real-Time Streaming
  // ============================================

  /// Start real-time streaming from device
  static Future<void> startStreaming({
    int? deviceId,
    Set<String>? dataTypes,
  }) async {
    try {
      await _methodChannel.invokeMethod<void>('startStreaming', {
        if (deviceId != null) 'deviceId': deviceId,
        if (dataTypes != null) 'dataTypes': dataTypes.toList(),
      });
    } on PlatformException catch (e) {
      throw garminErrorFromPlatformException(
        e,
        defaultMessage: 'Failed to start streaming: ${e.message}',
      );
    }
  }

  /// Stop real-time streaming
  static Future<void> stopStreaming({int? deviceId}) async {
    try {
      await _methodChannel.invokeMethod<void>('stopStreaming', {
        if (deviceId != null) 'deviceId': deviceId,
      });
    } on PlatformException catch (e) {
      throw garminErrorFromPlatformException(
        e,
        defaultMessage: 'Failed to stop streaming: ${e.message}',
      );
    }
  }

  /// Get stream of real-time data
  static Stream<Map<String, dynamic>> get realTimeDataStream {
    _realTimeDataController ??= StreamController<Map<String, dynamic>>.broadcast(
      onListen: () {
        _realTimeDataChannel.receiveBroadcastStream().listen(
          (data) {
            if (data is Map) {
              _realTimeDataController?.add(Map<String, dynamic>.from(data));
            }
          },
          onError: (error) {
            _realTimeDataController?.addError(
              garminErrorFromPlatformException(error),
            );
          },
        );
      },
      onCancel: () {
        _realTimeDataController?.close();
        _realTimeDataController = null;
      },
    );
    return _realTimeDataController!.stream;
  }

  // ============================================
  // Logged Data Reading
  // ============================================

  /// Read logged heart rate data
  static Future<List<Map<String, dynamic>>> readLoggedHeartRate({
    int? deviceId,
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    try {
      final result = await _methodChannel.invokeMethod<List<dynamic>>(
        'readLoggedHeartRate',
        {
          if (deviceId != null) 'deviceId': deviceId,
          'startTime': startTime.millisecondsSinceEpoch,
          'endTime': endTime.millisecondsSinceEpoch,
        },
      );
      if (result == null) return [];
      return result
          .cast<Map<dynamic, dynamic>>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
    } on PlatformException catch (e) {
      throw garminErrorFromPlatformException(
        e,
        defaultMessage: 'Failed to read logged heart rate: ${e.message}',
      );
    }
  }

  /// Read logged stress data
  static Future<List<Map<String, dynamic>>> readLoggedStress({
    int? deviceId,
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    try {
      final result = await _methodChannel.invokeMethod<List<dynamic>>(
        'readLoggedStress',
        {
          if (deviceId != null) 'deviceId': deviceId,
          'startTime': startTime.millisecondsSinceEpoch,
          'endTime': endTime.millisecondsSinceEpoch,
        },
      );
      if (result == null) return [];
      return result
          .cast<Map<dynamic, dynamic>>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
    } on PlatformException catch (e) {
      throw garminErrorFromPlatformException(
        e,
        defaultMessage: 'Failed to read logged stress: ${e.message}',
      );
    }
  }

  /// Read logged respiration data
  static Future<List<Map<String, dynamic>>> readLoggedRespiration({
    int? deviceId,
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    try {
      final result = await _methodChannel.invokeMethod<List<dynamic>>(
        'readLoggedRespiration',
        {
          if (deviceId != null) 'deviceId': deviceId,
          'startTime': startTime.millisecondsSinceEpoch,
          'endTime': endTime.millisecondsSinceEpoch,
        },
      );
      if (result == null) return [];
      return result
          .cast<Map<dynamic, dynamic>>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
    } on PlatformException catch (e) {
      throw garminErrorFromPlatformException(
        e,
        defaultMessage: 'Failed to read logged respiration: ${e.message}',
      );
    }
  }

  // ============================================
  // Wellness Data
  // ============================================

  /// Read wellness epochs
  static Future<List<Map<String, dynamic>>> readWellnessEpochs({
    int? deviceId,
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    try {
      final result = await _methodChannel.invokeMethod<List<dynamic>>(
        'readWellnessEpochs',
        {
          if (deviceId != null) 'deviceId': deviceId,
          'startTime': startTime.millisecondsSinceEpoch,
          'endTime': endTime.millisecondsSinceEpoch,
        },
      );
      if (result == null) return [];
      return result
          .cast<Map<dynamic, dynamic>>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
    } on PlatformException catch (e) {
      throw garminErrorFromPlatformException(
        e,
        defaultMessage: 'Failed to read wellness epochs: ${e.message}',
      );
    }
  }

  /// Read wellness summaries
  static Future<List<Map<String, dynamic>>> readWellnessSummaries({
    int? deviceId,
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    try {
      final result = await _methodChannel.invokeMethod<List<dynamic>>(
        'readWellnessSummaries',
        {
          if (deviceId != null) 'deviceId': deviceId,
          'startTime': startTime.millisecondsSinceEpoch,
          'endTime': endTime.millisecondsSinceEpoch,
        },
      );
      if (result == null) return [];
      return result
          .cast<Map<dynamic, dynamic>>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
    } on PlatformException catch (e) {
      throw garminErrorFromPlatformException(
        e,
        defaultMessage: 'Failed to read wellness summaries: ${e.message}',
      );
    }
  }

  // ============================================
  // Sleep Data
  // ============================================

  /// Read sleep sessions
  static Future<List<Map<String, dynamic>>> readSleepSessions({
    int? deviceId,
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    try {
      final result = await _methodChannel.invokeMethod<List<dynamic>>(
        'readSleepSessions',
        {
          if (deviceId != null) 'deviceId': deviceId,
          'startTime': startTime.millisecondsSinceEpoch,
          'endTime': endTime.millisecondsSinceEpoch,
        },
      );
      if (result == null) return [];
      return result
          .cast<Map<dynamic, dynamic>>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
    } on PlatformException catch (e) {
      throw garminErrorFromPlatformException(
        e,
        defaultMessage: 'Failed to read sleep sessions: ${e.message}',
      );
    }
  }

  // ============================================
  // Activity Data
  // ============================================

  /// Read activity summaries
  static Future<List<Map<String, dynamic>>> readActivitySummaries({
    int? deviceId,
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    try {
      final result = await _methodChannel.invokeMethod<List<dynamic>>(
        'readActivitySummaries',
        {
          if (deviceId != null) 'deviceId': deviceId,
          'startTime': startTime.millisecondsSinceEpoch,
          'endTime': endTime.millisecondsSinceEpoch,
        },
      );
      if (result == null) return [];
      return result
          .cast<Map<dynamic, dynamic>>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
    } on PlatformException catch (e) {
      throw garminErrorFromPlatformException(
        e,
        defaultMessage: 'Failed to read activity summaries: ${e.message}',
      );
    }
  }

  // ============================================
  // WiFi Sync (Optional Feature)
  // ============================================

  /// Scan for WiFi access points
  static Future<List<Map<String, dynamic>>> scanAccessPoints(int unitId) async {
    try {
      final result = await _methodChannel.invokeMethod<List<dynamic>>(
        'scanAccessPoints',
        {'unitId': unitId},
      );
      if (result == null) return [];
      return result
          .cast<Map<dynamic, dynamic>>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
    } on PlatformException catch (e) {
      throw garminErrorFromPlatformException(
        e,
        defaultMessage: 'Failed to scan access points: ${e.message}',
      );
    }
  }

  /// Store WiFi access point on device
  static Future<void> storeAccessPoint({
    required int unitId,
    required String ssid,
    required String password,
  }) async {
    try {
      await _methodChannel.invokeMethod<void>('storeAccessPoint', {
        'unitId': unitId,
        'ssid': ssid,
        'password': password,
      });
    } on PlatformException catch (e) {
      throw garminErrorFromPlatformException(
        e,
        defaultMessage: 'Failed to store access point: ${e.message}',
      );
    }
  }

  // ============================================
  // Cleanup
  // ============================================

  /// Dispose all resources
  static void dispose() {
    _connectionStateController?.close();
    _connectionStateController = null;
    _scannedDevicesController?.close();
    _scannedDevicesController = null;
    _realTimeDataController?.close();
    _realTimeDataController = null;
    _syncProgressController?.close();
    _syncProgressController = null;
  }
}
