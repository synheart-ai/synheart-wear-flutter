/// Sleep session data from Garmin device
class GarminSleepSession {
  /// Start time of sleep session
  final DateTime startTime;

  /// End time of sleep session
  final DateTime endTime;

  /// Device that recorded this session
  final int? deviceId;

  /// Total sleep duration in seconds
  final int? totalSleepSeconds;

  /// Deep sleep duration in seconds
  final int? deepSleepSeconds;

  /// Light sleep duration in seconds
  final int? lightSleepSeconds;

  /// REM sleep duration in seconds
  final int? remSleepSeconds;

  /// Awake duration in seconds
  final int? awakeSeconds;

  /// Number of awakenings
  final int? awakenings;

  /// Sleep score (0-100)
  final int? sleepScore;

  /// Average SpO2 during sleep
  final int? averageSpo2;

  /// Minimum SpO2 during sleep
  final int? minSpo2;

  /// Average respiration rate during sleep
  final int? averageRespirationRate;

  /// Average HRV during sleep (RMSSD)
  final int? averageHrv;

  /// Resting heart rate
  final int? restingHeartRate;

  /// Sleep stages breakdown
  final List<GarminSleepStage>? stages;

  /// Overall sleep quality
  final GarminSleepQuality? quality;

  GarminSleepSession({
    required this.startTime,
    required this.endTime,
    this.deviceId,
    this.totalSleepSeconds,
    this.deepSleepSeconds,
    this.lightSleepSeconds,
    this.remSleepSeconds,
    this.awakeSeconds,
    this.awakenings,
    this.sleepScore,
    this.averageSpo2,
    this.minSpo2,
    this.averageRespirationRate,
    this.averageHrv,
    this.restingHeartRate,
    this.stages,
    this.quality,
  });

  factory GarminSleepSession.fromMap(Map<String, dynamic> map) {
    return GarminSleepSession(
      startTime: DateTime.fromMillisecondsSinceEpoch(map['startTime'] as int),
      endTime: DateTime.fromMillisecondsSinceEpoch(map['endTime'] as int),
      deviceId: map['deviceId'] as int?,
      totalSleepSeconds: map['totalSleepSeconds'] as int?,
      deepSleepSeconds: map['deepSleepSeconds'] as int?,
      lightSleepSeconds: map['lightSleepSeconds'] as int?,
      remSleepSeconds: map['remSleepSeconds'] as int?,
      awakeSeconds: map['awakeSeconds'] as int?,
      awakenings: map['awakenings'] as int?,
      sleepScore: map['sleepScore'] as int?,
      averageSpo2: map['averageSpo2'] as int?,
      minSpo2: map['minSpo2'] as int?,
      averageRespirationRate: map['averageRespirationRate'] as int?,
      averageHrv: map['averageHrv'] as int?,
      restingHeartRate: map['restingHeartRate'] as int?,
      stages: (map['stages'] as List?)
          ?.map((e) => GarminSleepStage.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
      quality: _parseSleepQuality(map['quality'] as String?),
    );
  }

  Map<String, dynamic> toMap() => {
    'startTime': startTime.millisecondsSinceEpoch,
    'endTime': endTime.millisecondsSinceEpoch,
    if (deviceId != null) 'deviceId': deviceId,
    if (totalSleepSeconds != null) 'totalSleepSeconds': totalSleepSeconds,
    if (deepSleepSeconds != null) 'deepSleepSeconds': deepSleepSeconds,
    if (lightSleepSeconds != null) 'lightSleepSeconds': lightSleepSeconds,
    if (remSleepSeconds != null) 'remSleepSeconds': remSleepSeconds,
    if (awakeSeconds != null) 'awakeSeconds': awakeSeconds,
    if (awakenings != null) 'awakenings': awakenings,
    if (sleepScore != null) 'sleepScore': sleepScore,
    if (averageSpo2 != null) 'averageSpo2': averageSpo2,
    if (minSpo2 != null) 'minSpo2': minSpo2,
    if (averageRespirationRate != null)
      'averageRespirationRate': averageRespirationRate,
    if (averageHrv != null) 'averageHrv': averageHrv,
    if (restingHeartRate != null) 'restingHeartRate': restingHeartRate,
    if (stages != null) 'stages': stages!.map((s) => s.toMap()).toList(),
    if (quality != null) 'quality': quality!.name,
  };

  /// Total duration of sleep session
  Duration get duration => endTime.difference(startTime);

  /// Total sleep duration (excluding awake time)
  Duration? get totalSleepDuration =>
      totalSleepSeconds != null ? Duration(seconds: totalSleepSeconds!) : null;

  /// Deep sleep percentage
  double? get deepSleepPercentage {
    if (deepSleepSeconds == null || totalSleepSeconds == null || totalSleepSeconds == 0) {
      return null;
    }
    return (deepSleepSeconds! / totalSleepSeconds!) * 100;
  }

  /// REM sleep percentage
  double? get remSleepPercentage {
    if (remSleepSeconds == null || totalSleepSeconds == null || totalSleepSeconds == 0) {
      return null;
    }
    return (remSleepSeconds! / totalSleepSeconds!) * 100;
  }

  /// Sleep efficiency (time asleep / time in bed)
  double? get sleepEfficiency {
    if (totalSleepSeconds == null) return null;
    final totalInBed = duration.inSeconds;
    if (totalInBed == 0) return null;
    return (totalSleepSeconds! / totalInBed) * 100;
  }
}

/// Individual sleep stage within a session
class GarminSleepStage {
  /// Start time of this stage
  final DateTime startTime;

  /// End time of this stage
  final DateTime endTime;

  /// Sleep stage type
  final GarminSleepStageType stage;

  GarminSleepStage({
    required this.startTime,
    required this.endTime,
    required this.stage,
  });

  factory GarminSleepStage.fromMap(Map<String, dynamic> map) {
    return GarminSleepStage(
      startTime: DateTime.fromMillisecondsSinceEpoch(map['startTime'] as int),
      endTime: DateTime.fromMillisecondsSinceEpoch(map['endTime'] as int),
      stage: _parseSleepStageType(map['stage'] as String?),
    );
  }

  Map<String, dynamic> toMap() => {
    'startTime': startTime.millisecondsSinceEpoch,
    'endTime': endTime.millisecondsSinceEpoch,
    'stage': stage.name,
  };

  /// Duration of this stage
  Duration get duration => endTime.difference(startTime);
}

/// Sleep stage types
enum GarminSleepStageType {
  /// Deep sleep (N3)
  deep,

  /// Light sleep (N1, N2)
  light,

  /// REM sleep
  rem,

  /// Awake
  awake,

  /// Unknown stage
  unknown,
}

GarminSleepStageType _parseSleepStageType(String? stage) {
  if (stage == null) return GarminSleepStageType.unknown;
  switch (stage.toLowerCase()) {
    case 'deep':
    case 'n3':
      return GarminSleepStageType.deep;
    case 'light':
    case 'n1':
    case 'n2':
      return GarminSleepStageType.light;
    case 'rem':
      return GarminSleepStageType.rem;
    case 'awake':
    case 'wake':
      return GarminSleepStageType.awake;
    default:
      return GarminSleepStageType.unknown;
  }
}

/// Sleep quality classification
enum GarminSleepQuality {
  /// Poor sleep quality
  poor,

  /// Fair sleep quality
  fair,

  /// Good sleep quality
  good,

  /// Excellent sleep quality
  excellent,

  /// Unknown quality
  unknown,
}

GarminSleepQuality _parseSleepQuality(String? quality) {
  if (quality == null) return GarminSleepQuality.unknown;
  switch (quality.toLowerCase()) {
    case 'poor':
    case 'bad':
      return GarminSleepQuality.poor;
    case 'fair':
    case 'moderate':
      return GarminSleepQuality.fair;
    case 'good':
      return GarminSleepQuality.good;
    case 'excellent':
    case 'great':
      return GarminSleepQuality.excellent;
    default:
      return GarminSleepQuality.unknown;
  }
}

extension GarminSleepQualityExtension on GarminSleepQuality {
  String get displayName {
    switch (this) {
      case GarminSleepQuality.poor:
        return 'Poor';
      case GarminSleepQuality.fair:
        return 'Fair';
      case GarminSleepQuality.good:
        return 'Good';
      case GarminSleepQuality.excellent:
        return 'Excellent';
      case GarminSleepQuality.unknown:
        return 'Unknown';
    }
  }
}
