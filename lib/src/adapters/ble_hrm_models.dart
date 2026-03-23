import 'package:meta/meta.dart';

/// Error codes for BLE HRM operations.
enum BleHrmErrorCode {
  permissionDenied,
  bluetoothOff,
  deviceNotFound,
  subscribeFailed,
  disconnected,
}

/// Exception thrown by BLE HRM operations.
class BleHrmError implements Exception {
  const BleHrmError(this.code, [this.message]);

  final BleHrmErrorCode code;
  final String? message;

  @override
  String toString() =>
      'BleHrmError(${code.name}${message != null ? ': $message' : ''})';
}

/// A discovered BLE heart rate monitor device.
@immutable
class BleHrmDevice {
  const BleHrmDevice({
    required this.deviceId,
    required this.name,
    required this.rssi,
  });

  factory BleHrmDevice.fromMap(Map<dynamic, dynamic> map) {
    return BleHrmDevice(
      deviceId: map['deviceId'] as String,
      name: map['name'] as String? ?? '',
      rssi: map['rssi'] as int? ?? 0,
    );
  }

  final String deviceId;
  final String name;
  final int rssi;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BleHrmDevice && deviceId == other.deviceId;

  @override
  int get hashCode => deviceId.hashCode;

  @override
  String toString() => 'BleHrmDevice($name [$deviceId] rssi=$rssi)';
}

/// A single heart rate sample from a BLE HRM device.
@immutable
class HeartRateSample {
  const HeartRateSample({
    required this.tsMs,
    required this.bpm,
    required this.source,
    this.deviceId,
    this.deviceName,
    this.sessionId,
    this.rrIntervalsMs = const [],
  });

  factory HeartRateSample.fromMap(Map<dynamic, dynamic> map) {
    return HeartRateSample(
      tsMs: map['tsMs'] as int,
      bpm: (map['bpm'] as num).toDouble(),
      source: map['source'] as String? ?? 'ble_hrm',
      deviceId: map['deviceId'] as String?,
      deviceName: map['deviceName'] as String?,
      sessionId: map['sessionId'] as String?,
      rrIntervalsMs: (map['rrIntervalsMs'] as List<dynamic>?)
              ?.map((e) => (e as num).toDouble())
              .toList() ??
          const [],
    );
  }

  final int tsMs;
  final double bpm;
  final String source;
  final String? deviceId;
  final String? deviceName;
  final String? sessionId;
  final List<double> rrIntervalsMs;

  @override
  String toString() => 'HeartRateSample(bpm=$bpm, ts=$tsMs, rr=${rrIntervalsMs.length})';
}
