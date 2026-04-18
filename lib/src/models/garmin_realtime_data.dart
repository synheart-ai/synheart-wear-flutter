import 'dart:math';

/// Real-time streaming data from Garmin devices
class GarminRealTimeData {
  /// Timestamp of the data point
  final DateTime timestamp;

  /// Device ID that produced this data
  final int? deviceId;

  /// Heart rate in BPM
  final int? heartRate;

  /// Stress level (0-100)
  final int? stress;

  /// Heart rate variability (RMSSD in ms)
  final int? hrv;

  /// Beat-to-beat intervals in milliseconds
  final List<double>? bbiIntervals;

  /// Step count
  final int? steps;

  /// SpO2 percentage (0-100)
  final int? spo2;

  /// Respiration rate (breaths per minute)
  final int? respiration;

  /// Body battery level (0-100)
  final int? bodyBattery;

  /// Accelerometer data
  final GarminAccelerometerData? accelerometer;

  GarminRealTimeData({
    required this.timestamp,
    this.deviceId,
    this.heartRate,
    this.stress,
    this.hrv,
    this.bbiIntervals,
    this.steps,
    this.spo2,
    this.respiration,
    this.bodyBattery,
    this.accelerometer,
  });

  /// Create from platform channel map
  factory GarminRealTimeData.fromMap(Map<String, dynamic> map) {
    return GarminRealTimeData(
      timestamp: map['timestamp'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int)
          : DateTime.now(),
      deviceId: map['deviceId'] as int?,
      heartRate: map['heartRate'] as int?,
      stress: map['stress'] as int?,
      hrv: map['hrv'] as int?,
      bbiIntervals: (map['bbiIntervals'] as List?)
          ?.map((e) => (e as num).toDouble())
          .toList(),
      steps: map['steps'] as int?,
      spo2: map['spo2'] as int?,
      respiration: map['respiration'] as int?,
      bodyBattery: map['bodyBattery'] as int?,
      accelerometer: map['accelerometer'] != null
          ? GarminAccelerometerData.fromMap(
              Map<String, dynamic>.from(map['accelerometer'] as Map),
            )
          : null,
    );
  }

  /// Convert to map for platform channel
  Map<String, dynamic> toMap() => {
    'timestamp': timestamp.millisecondsSinceEpoch,
    if (deviceId != null) 'deviceId': deviceId,
    if (heartRate != null) 'heartRate': heartRate,
    if (stress != null) 'stress': stress,
    if (hrv != null) 'hrv': hrv,
    if (bbiIntervals != null) 'bbiIntervals': bbiIntervals,
    if (steps != null) 'steps': steps,
    if (spo2 != null) 'spo2': spo2,
    if (respiration != null) 'respiration': respiration,
    if (bodyBattery != null) 'bodyBattery': bodyBattery,
    if (accelerometer != null) 'accelerometer': accelerometer!.toMap(),
  };

  /// Check if this data contains any valid metrics
  bool get hasValidData =>
      heartRate != null ||
      stress != null ||
      hrv != null ||
      bbiIntervals != null ||
      steps != null ||
      spo2 != null ||
      respiration != null ||
      bodyBattery != null;

  @override
  String toString() {
    final parts = <String>[];
    if (heartRate != null) parts.add('HR: $heartRate');
    if (stress != null) parts.add('Stress: $stress');
    if (hrv != null) parts.add('HRV: $hrv');
    if (steps != null) parts.add('Steps: $steps');
    if (spo2 != null) parts.add('SpO2: $spo2%');
    if (respiration != null) parts.add('Resp: $respiration');
    return 'GarminRealTimeData(${parts.join(', ')})';
  }
}

/// Accelerometer data from Garmin device
class GarminAccelerometerData {
  /// X-axis acceleration (mg)
  final double x;

  /// Y-axis acceleration (mg)
  final double y;

  /// Z-axis acceleration (mg)
  final double z;

  /// Sample timestamp
  final DateTime timestamp;

  GarminAccelerometerData({
    required this.x,
    required this.y,
    required this.z,
    required this.timestamp,
  });

  factory GarminAccelerometerData.fromMap(Map<String, dynamic> map) {
    return GarminAccelerometerData(
      x: (map['x'] as num).toDouble(),
      y: (map['y'] as num).toDouble(),
      z: (map['z'] as num).toDouble(),
      timestamp: map['timestamp'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'x': x,
    'y': y,
    'z': z,
    'timestamp': timestamp.millisecondsSinceEpoch,
  };

  /// Get the magnitude of acceleration (Euclidean distance)
  double get magnitude {
    return sqrt(x * x + y * y + z * z);
  }

  @override
  String toString() => 'Accel(x: $x, y: $y, z: $z)';
}
