import 'dart:async';

import 'package:flutter/services.dart';
import 'package:synheart_wear/src/adapters/ble_hrm_models.dart';
import 'package:synheart_wear/src/adapters/ble_motion_models.dart';
import 'package:synheart_wear/src/core/logger.dart';

/// Platform bridge for BLE Heart Rate Monitor operations.
///
/// Uses Flutter platform channels to communicate with native BLE code:
/// - MethodChannel for scan/connect/disconnect/isConnected
/// - EventChannel for streaming heart rate samples
class BleHrmProvider {
  BleHrmProvider()
    : _method = const MethodChannel('synheart_wear/ble_hrm/method'),
      _events = const EventChannel('synheart_wear/ble_hrm/events');

  final MethodChannel _method;
  final EventChannel _events;

  StreamSubscription<dynamic>? _eventSubscription;
  final StreamController<HeartRateSample> _hrController =
      StreamController<HeartRateSample>.broadcast();
  final StreamController<BleMotionBatch> _motionController =
      StreamController<BleMotionBatch>.broadcast();
  int _motionSampleRateHz = 50;

  bool _listening = false;

  /// Request Bluetooth permission from the OS.
  ///
  /// On iOS, this triggers the system Bluetooth permission dialog by
  /// creating a [CBCentralManager]. Returns `"granted"` or `"denied"`.
  Future<String> requestPermission() async {
    try {
      final result = await _method.invokeMethod<String>('requestPermission');
      return result ?? 'denied';
    } on PlatformException catch (e) {
      throw _mapError(e);
    }
  }

  /// Instantiate the native BLE central without requesting permission or
  /// scanning. Prevents the Garmin SDK's "No supported real-time types"
  /// failure when it runs before anything else has touched CoreBluetooth.
  Future<void> warmAdapter() async {
    try {
      await _method.invokeMethod<void>('warmAdapter');
    } on PlatformException {
      // Best effort — callers treat failure as non-fatal.
    }
  }

  /// Scan for nearby BLE heart rate monitor devices.
  ///
  /// [timeoutMs] — scan duration in milliseconds (default 5000).
  /// [namePrefix] — optional filter by device name prefix.
  Future<List<BleHrmDevice>> scan({
    int timeoutMs = 5000,
    String? namePrefix,
  }) async {
    try {
      final result = await _method.invokeMethod<List<dynamic>>('scan', {
        'timeoutMs': timeoutMs,
        if (namePrefix != null) 'namePrefix': namePrefix,
      });
      if (result == null) return [];
      return result
          .cast<Map<dynamic, dynamic>>()
          .map(BleHrmDevice.fromMap)
          .toList();
    } on PlatformException catch (e) {
      throw _mapError(e);
    }
  }

  /// Get already-bonded BLE heart rate devices (no scanning needed).
  Future<List<BleHrmDevice>> getBondedHrDevices() async {
    try {
      final result = await _method.invokeMethod<List<dynamic>>(
        'getBondedHrDevices',
      );
      if (result == null) return [];
      return result
          .cast<Map<dynamic, dynamic>>()
          .map(BleHrmDevice.fromMap)
          .toList();
    } on PlatformException catch (e) {
      throw _mapError(e);
    }
  }

  /// Connect to a BLE heart rate monitor and start receiving samples.
  ///
  /// [deviceId] — the device to connect to (from [scan] results).
  /// [sessionId] — optional session ID to tag samples with.
  /// [enableBattery] — whether to request battery level notifications.
  /// [enableMotion] — also start the strap's accelerometer when the device
  /// exposes the measurement-data service (Polar chest straps); frames
  /// arrive on [onMotion]. Devices without the service ignore the request.
  /// [motionSampleRateHz] — 25, 50, 100 or 200 on the H10.
  Future<void> connect({
    required String deviceId,
    String? sessionId,
    bool enableBattery = false,
    bool enableMotion = false,
    int motionSampleRateHz = 50,
  }) async {
    logInfo('[BLE] connecting deviceId=$deviceId session=$sessionId');
    _motionSampleRateHz = motionSampleRateHz;
    try {
      await _method.invokeMethod<void>('connect', {
        'deviceId': deviceId,
        'sessionId': sessionId,
        'enableBattery': enableBattery,
        'enableMotion': enableMotion,
        'motionSampleRateHz': motionSampleRateHz,
      });
      _ensureListening();
      logInfo('[BLE] connected deviceId=$deviceId');
    } on PlatformException catch (e) {
      final mapped = _mapError(e);
      logError(
        '[BLE] connect failed deviceId=$deviceId: ${mapped.message}',
        mapped,
      );
      throw mapped;
    }
  }

  /// Disconnect from the current BLE heart rate monitor.
  Future<void> disconnect() async {
    try {
      await _method.invokeMethod<void>('disconnect');
      logInfo('[BLE] disconnected');
    } on PlatformException catch (e) {
      throw _mapError(e);
    }
  }

  /// Check if a BLE heart rate monitor is currently connected.
  Future<bool> isConnected() async {
    try {
      final result = await _method.invokeMethod<bool>('isConnected');
      return result ?? false;
    } on PlatformException catch (e) {
      throw _mapError(e);
    }
  }

  /// Stream of heart rate samples from the connected device.
  Stream<HeartRateSample> get onHeartRate => _hrController.stream;

  /// Accelerometer frames from the connected strap, when [connect] asked
  /// for motion and the device supports it.
  Stream<BleMotionBatch> get onMotion => _motionController.stream;

  /// Start listening to the event channel if not already.
  void _ensureListening() {
    if (_listening) return;
    _listening = true;

    _eventSubscription = _events.receiveBroadcastStream().listen(
      (dynamic event) {
        if (event is! Map) return;
        switch (event['type']) {
          case 'pmd_data':
            final bytes = event['bytes'];
            if (bytes is! Uint8List) return;
            final batch = PolarPmdAccel.parseFrame(
              bytes,
              arrivalMs:
                  (event['arrivalMs'] as num?)?.toInt() ??
                  DateTime.now().millisecondsSinceEpoch,
              sampleRateHz: _motionSampleRateHz,
            );
            if (batch != null) _motionController.add(batch);
          case 'pmd_control':
            final bytes = event['bytes'];
            if (bytes is Uint8List && PolarPmdAccel.isStartAck(bytes)) {
              logInfo('[BLE] motion stream started at $_motionSampleRateHz Hz');
            } else {
              logInfo('[BLE] motion control response: $bytes');
            }
          default:
            _hrController.add(HeartRateSample.fromMap(event));
        }
      },
      onError: (Object error) {
        final mapped = error is PlatformException ? _mapError(error) : error;
        logError('[BLE] stream error: $mapped', mapped);
        _hrController.addError(mapped);
      },
    );
  }

  /// Release resources.
  void dispose() {
    _eventSubscription?.cancel();
    _eventSubscription = null;
    _listening = false;
    _hrController.close();
    _motionController.close();
  }

  /// Map a [PlatformException] to a typed [BleHrmError].
  static BleHrmError _mapError(PlatformException e) {
    final code = switch (e.code) {
      'PERMISSION_DENIED' => BleHrmErrorCode.permissionDenied,
      'BLUETOOTH_OFF' => BleHrmErrorCode.bluetoothOff,
      'DEVICE_NOT_FOUND' => BleHrmErrorCode.deviceNotFound,
      'SUBSCRIBE_FAILED' => BleHrmErrorCode.subscribeFailed,
      'DISCONNECTED' => BleHrmErrorCode.disconnected,
      _ => BleHrmErrorCode.subscribeFailed,
    };
    return BleHrmError(code, e.message);
  }
}
