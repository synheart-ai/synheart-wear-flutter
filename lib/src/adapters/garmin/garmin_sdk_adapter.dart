import 'dart:async';

import '../../core/consent_manager.dart';
import '../../core/logger.dart';
import '../../core/models.dart';
import '../../models/garmin_connection_state.dart';
import '../../models/garmin_device.dart';
import '../../models/garmin_realtime_data.dart';
import '../../models/garmin_wellness_data.dart';
import '../../models/garmin_sleep_data.dart';
import '../../models/garmin_activity_data.dart';
import '../ble_hrm_bridge.dart';
import '../wear_adapter.dart';
import 'garmin_device_manager.dart';
import 'garmin_errors.dart';
import 'garmin_platform_channel.dart';

/// Garmin SDK adapter implementing WearAdapter interface
///
/// Provides access to Garmin wearable devices via the native Garmin Health SDK.
/// Requires a valid Garmin SDK license key for initialization.
class GarminAdapter implements WearAdapter {
  /// License key for Garmin SDK
  final String licenseKey;

  /// Device manager for device lifecycle operations
  late final GarminDeviceManager _deviceManager;

  bool _initialized = false;

  StreamController<GarminRealTimeData>? _realTimeStreamController;
  StreamSubscription<Map<String, dynamic>>? _realTimeSubscription;

  /// Create a new GarminAdapter with a license key
  GarminAdapter({required this.licenseKey}) {
    _deviceManager = GarminDeviceManager(licenseKey: licenseKey);
  }

  @override
  String get id => 'garmin_sdk';

  @override
  Set<PermissionType> get supportedPermissions => const {
    PermissionType.heartRate,
    PermissionType.heartRateVariability,
    PermissionType.steps,
    PermissionType.calories,
    PermissionType.distance,
    PermissionType.stress,
    PermissionType.sleep,
  };

  @override
  Set<PermissionType> getPlatformSupportedPermissions() {
    // Garmin SDK supports the same permissions on both platforms
    return supportedPermissions;
  }

  /// Get the device manager for device operations
  GarminDeviceManager get deviceManager => _deviceManager;

  /// Whether the adapter is initialized
  bool get isInitialized => _initialized;

  /// Stream of connection state changes
  Stream<GarminConnectionStateEvent> get connectionStateStream =>
      _deviceManager.connectionStateStream;

  /// Stream of real-time data from connected device
  Stream<GarminRealTimeData> get realTimeStream {
    _realTimeStreamController ??= StreamController<GarminRealTimeData>.broadcast(
      onListen: _setupRealTimeStream,
      onCancel: _teardownRealTimeStream,
    );
    return _realTimeStreamController!.stream;
  }

  // ============================================
  // WearAdapter Implementation
  // ============================================

  /// Initialize the Garmin SDK
  ///
  /// Must be called before any other operations.
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Warm the native BLE stack — Garmin SDK can report "no supported
      // real-time types" if it runs before CoreBluetooth/BluetoothAdapter
      // has been touched by anything else in the process.
      await BleHrmProvider()
          .warmAdapter()
          .timeout(const Duration(seconds: 2), onTimeout: () {});

      await _deviceManager.initialize();
      _initialized = true;
      logInfo('GarminAdapter initialized successfully');
    } catch (e) {
      if (e is GarminSDKError) rethrow;
      throw GarminInitializationError(
        'Failed to initialize GarminAdapter: $e',
        originalException: e is Exception ? e : null,
      );
    }
  }

  @override
  Future<WearMetrics?> readSnapshot({
    bool isRealTime = true,
    DateTime? startTime,
    DateTime? endTime,
  }) async {
    if (!_initialized) {
      await initialize();
    }

    try {
      // Use provided time range or default to last 30 days
      final effectiveStartTime =
          startTime ?? DateTime.now().subtract(const Duration(days: 30));
      final effectiveEndTime = endTime ?? DateTime.now();

      // Get paired devices
      final devices = await _deviceManager.getPairedDevices();
      if (devices.isEmpty) {
        logWarning('No Garmin devices paired');
        return null;
      }

      // Try to read data from the first connected device
      final device = devices.first;

      // Read various data types
      final metrics = <String, num?>{};
      final meta = <String, Object?>{
        'device_name': device.name,
        'device_type': device.type.displayName,
      };

      // Read logged heart rate
      try {
        final hrData = await _deviceManager.readLoggedHeartRate(
          device: device,
          startTime: effectiveStartTime,
          endTime: effectiveEndTime,
        );
        if (hrData.isNotEmpty) {
          // Get the most recent heart rate
          final latest = hrData.last;
          metrics['hr'] = latest.heartRate;
        }
      } catch (e) {
        logWarning('Failed to read heart rate', e);
      }

      // Read logged stress
      try {
        final stressData = await _deviceManager.readLoggedStress(
          device: device,
          startTime: effectiveStartTime,
          endTime: effectiveEndTime,
        );
        if (stressData.isNotEmpty) {
          final latest = stressData.last;
          metrics['stress'] = latest.stress;
        }
      } catch (e) {
        logWarning('Failed to read stress', e);
      }

      // Read wellness summaries for steps/calories/distance
      try {
        final summaries = await readWellnessSummaries(
          device: device,
          startTime: effectiveStartTime,
          endTime: effectiveEndTime,
        );
        if (summaries.isNotEmpty) {
          final latest = summaries.last;
          if (latest.totalSteps != null) {
            metrics['steps'] = latest.totalSteps;
          }
          if (latest.activeCalories != null) {
            metrics['calories'] = latest.activeCalories;
          }
          if (latest.totalDistance != null) {
            // Convert meters to kilometers
            metrics['distance'] = latest.totalDistance! / 1000;
          }
          if (latest.restingHeartRate != null) {
            meta['resting_hr'] = latest.restingHeartRate;
          }
        }
      } catch (e) {
        logWarning('Failed to read wellness summaries', e);
      }

      // Get battery level
      try {
        final battery = await _deviceManager.getBatteryLevel(device);
        if (battery != null) {
          meta['battery'] = battery / 100.0; // Normalize to 0-1
        }
      } catch (e) {
        logWarning('Failed to read battery level', e);
      }

      if (metrics.isEmpty) {
        return null;
      }

      return WearMetrics(
        timestamp: DateTime.now(),
        deviceId: 'garmin_${device.unitId}',
        source: id,
        metrics: metrics,
        meta: meta,
      );
    } catch (e) {
      logError('Garmin readSnapshot error', e);
      return null;
    }
  }

  // ============================================
  // Extended Garmin-Specific Methods
  // ============================================

  /// Read wellness epochs (15-minute intervals)
  Future<List<GarminWellnessEpoch>> readWellnessEpochs({
    GarminDevice? device,
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    _ensureInitialized();

    try {
      final data = await GarminPlatformChannel.readWellnessEpochs(
        deviceId: device?.unitId,
        startTime: startTime,
        endTime: endTime,
      );
      return data.map((m) => GarminWellnessEpoch.fromMap(m)).toList();
    } catch (e) {
      if (e is GarminSDKError) rethrow;
      throw GarminDataError(
        'Failed to read wellness epochs: $e',
        originalException: e is Exception ? e : null,
      );
    }
  }

  /// Read wellness summaries (daily)
  Future<List<GarminWellnessSummary>> readWellnessSummaries({
    GarminDevice? device,
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    _ensureInitialized();

    try {
      final data = await GarminPlatformChannel.readWellnessSummaries(
        deviceId: device?.unitId,
        startTime: startTime,
        endTime: endTime,
      );
      return data.map((m) => GarminWellnessSummary.fromMap(m)).toList();
    } catch (e) {
      if (e is GarminSDKError) rethrow;
      throw GarminDataError(
        'Failed to read wellness summaries: $e',
        originalException: e is Exception ? e : null,
      );
    }
  }

  /// Read sleep sessions
  Future<List<GarminSleepSession>> readSleepSessions({
    GarminDevice? device,
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    _ensureInitialized();

    try {
      final data = await GarminPlatformChannel.readSleepSessions(
        deviceId: device?.unitId,
        startTime: startTime,
        endTime: endTime,
      );
      return data.map((m) => GarminSleepSession.fromMap(m)).toList();
    } catch (e) {
      if (e is GarminSDKError) rethrow;
      throw GarminDataError(
        'Failed to read sleep sessions: $e',
        originalException: e is Exception ? e : null,
      );
    }
  }

  /// Read activity summaries
  Future<List<GarminActivitySummary>> readActivitySummaries({
    GarminDevice? device,
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    _ensureInitialized();

    try {
      final data = await GarminPlatformChannel.readActivitySummaries(
        deviceId: device?.unitId,
        startTime: startTime,
        endTime: endTime,
      );
      return data.map((m) => GarminActivitySummary.fromMap(m)).toList();
    } catch (e) {
      if (e is GarminSDKError) rethrow;
      throw GarminDataError(
        'Failed to read activity summaries: $e',
        originalException: e is Exception ? e : null,
      );
    }
  }

  /// Start real-time streaming
  ///
  /// Listen to [realTimeStream] to receive data.
  Future<void> startStreaming({
    GarminDevice? device,
    Set<GarminRealTimeType>? dataTypes,
  }) async {
    _ensureInitialized();
    final target = device?.name ?? 'active device';
    logInfo('[Garmin] startStreaming target=$target '
        'types=${dataTypes?.map((t) => t.name).join(",") ?? "all"}');
    try {
      await _deviceManager.startStreaming(device: device, dataTypes: dataTypes);
      logInfo('[Garmin] startStreaming OK target=$target');
    } catch (e) {
      logError('[Garmin] startStreaming FAILED target=$target', e);
      rethrow;
    }
  }

  /// Stop real-time streaming
  Future<void> stopStreaming({GarminDevice? device}) async {
    await _deviceManager.stopStreaming(device: device);
    logInfo('[Garmin] stopStreaming target=${device?.name ?? "active"}');
  }

  /// Convert real-time data to WearMetrics
  WearMetrics convertRealTimeToMetrics(GarminRealTimeData data) {
    final metrics = <String, num?>{};

    if (data.heartRate != null) metrics['hr'] = data.heartRate;
    if (data.hrv != null) metrics['hrv_rmssd'] = data.hrv;
    if (data.stress != null) metrics['stress'] = data.stress;
    if (data.steps != null) metrics['steps'] = data.steps;

    return WearMetrics(
      timestamp: data.timestamp,
      deviceId: data.deviceId != null ? 'garmin_${data.deviceId}' : 'garmin_unknown',
      source: id,
      metrics: metrics,
      meta: {
        if (data.spo2 != null) 'spo2': data.spo2,
        if (data.respiration != null) 'respiration': data.respiration,
        if (data.bodyBattery != null) 'body_battery': data.bodyBattery,
      },
      rrIntervalsMs: data.bbiIntervals,
    );
  }

  // ============================================
  // Cleanup
  // ============================================

  /// Dispose all resources
  void dispose() {
    _realTimeSubscription?.cancel();
    _realTimeStreamController?.close();
    _deviceManager.dispose();
    _initialized = false;
  }

  // ============================================
  // Private Methods
  // ============================================

  void _ensureInitialized() {
    if (!_initialized) {
      throw GarminInitializationError(
        'GarminAdapter not initialized. Call initialize() first.',
      );
    }
  }

  void _setupRealTimeStream() {
    _realTimeSubscription = _deviceManager.realTimeStream.listen(
      (data) {
        final realTimeData = GarminRealTimeData.fromMap(data);
        _realTimeStreamController?.add(realTimeData);
      },
      onError: (e) {
        _realTimeStreamController?.addError(e);
      },
    );
  }

  void _teardownRealTimeStream() {
    _realTimeSubscription?.cancel();
    _realTimeSubscription = null;
  }
}
