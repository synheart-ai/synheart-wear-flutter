/// Activity/workout summary data from Garmin device
class GarminActivitySummary {
  /// Unique activity ID
  final String? activityId;

  /// Start time of the activity
  final DateTime startTime;

  /// End time of the activity
  final DateTime endTime;

  /// Device that recorded this activity
  final int? deviceId;

  /// Activity type
  final GarminActivityType activityType;

  /// Activity name/title
  final String? name;

  /// Total duration in seconds
  final int? durationSeconds;

  /// Distance traveled (meters)
  final double? distance;

  /// Active calories burned
  final double? activeCalories;

  /// Total calories burned
  final double? totalCalories;

  /// Average heart rate
  final int? averageHeartRate;

  /// Maximum heart rate
  final int? maxHeartRate;

  /// Minimum heart rate
  final int? minHeartRate;

  /// Average speed (m/s)
  final double? averageSpeed;

  /// Maximum speed (m/s)
  final double? maxSpeed;

  /// Average pace (seconds per kilometer)
  final int? averagePace;

  /// Best pace (seconds per kilometer)
  final int? bestPace;

  /// Total ascent (meters)
  final double? totalAscent;

  /// Total descent (meters)
  final double? totalDescent;

  /// Average cadence (steps/strokes per minute)
  final int? averageCadence;

  /// Maximum cadence
  final int? maxCadence;

  /// Training effect (aerobic)
  final double? aerobicTrainingEffect;

  /// Training effect (anaerobic)
  final double? anaerobicTrainingEffect;

  /// VO2 max estimate
  final double? vo2Max;

  /// Recovery time (hours)
  final int? recoveryTimeHours;

  /// Average stress
  final int? averageStress;

  /// Lap summaries
  final List<GarminActivityLap>? laps;

  GarminActivitySummary({
    this.activityId,
    required this.startTime,
    required this.endTime,
    this.deviceId,
    this.activityType = GarminActivityType.unknown,
    this.name,
    this.durationSeconds,
    this.distance,
    this.activeCalories,
    this.totalCalories,
    this.averageHeartRate,
    this.maxHeartRate,
    this.minHeartRate,
    this.averageSpeed,
    this.maxSpeed,
    this.averagePace,
    this.bestPace,
    this.totalAscent,
    this.totalDescent,
    this.averageCadence,
    this.maxCadence,
    this.aerobicTrainingEffect,
    this.anaerobicTrainingEffect,
    this.vo2Max,
    this.recoveryTimeHours,
    this.averageStress,
    this.laps,
  });

  factory GarminActivitySummary.fromMap(Map<String, dynamic> map) {
    return GarminActivitySummary(
      activityId: map['activityId'] as String?,
      startTime: DateTime.fromMillisecondsSinceEpoch(map['startTime'] as int),
      endTime: DateTime.fromMillisecondsSinceEpoch(map['endTime'] as int),
      deviceId: map['deviceId'] as int?,
      activityType: _parseActivityType(map['activityType'] as String?),
      name: map['name'] as String?,
      durationSeconds: map['durationSeconds'] as int?,
      distance: (map['distance'] as num?)?.toDouble(),
      activeCalories: (map['activeCalories'] as num?)?.toDouble(),
      totalCalories: (map['totalCalories'] as num?)?.toDouble(),
      averageHeartRate: map['averageHeartRate'] as int?,
      maxHeartRate: map['maxHeartRate'] as int?,
      minHeartRate: map['minHeartRate'] as int?,
      averageSpeed: (map['averageSpeed'] as num?)?.toDouble(),
      maxSpeed: (map['maxSpeed'] as num?)?.toDouble(),
      averagePace: map['averagePace'] as int?,
      bestPace: map['bestPace'] as int?,
      totalAscent: (map['totalAscent'] as num?)?.toDouble(),
      totalDescent: (map['totalDescent'] as num?)?.toDouble(),
      averageCadence: map['averageCadence'] as int?,
      maxCadence: map['maxCadence'] as int?,
      aerobicTrainingEffect: (map['aerobicTrainingEffect'] as num?)?.toDouble(),
      anaerobicTrainingEffect: (map['anaerobicTrainingEffect'] as num?)?.toDouble(),
      vo2Max: (map['vo2Max'] as num?)?.toDouble(),
      recoveryTimeHours: map['recoveryTimeHours'] as int?,
      averageStress: map['averageStress'] as int?,
      laps: (map['laps'] as List?)
          ?.map((e) => GarminActivityLap.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }

  Map<String, dynamic> toMap() => {
    if (activityId != null) 'activityId': activityId,
    'startTime': startTime.millisecondsSinceEpoch,
    'endTime': endTime.millisecondsSinceEpoch,
    if (deviceId != null) 'deviceId': deviceId,
    'activityType': activityType.name,
    if (name != null) 'name': name,
    if (durationSeconds != null) 'durationSeconds': durationSeconds,
    if (distance != null) 'distance': distance,
    if (activeCalories != null) 'activeCalories': activeCalories,
    if (totalCalories != null) 'totalCalories': totalCalories,
    if (averageHeartRate != null) 'averageHeartRate': averageHeartRate,
    if (maxHeartRate != null) 'maxHeartRate': maxHeartRate,
    if (minHeartRate != null) 'minHeartRate': minHeartRate,
    if (averageSpeed != null) 'averageSpeed': averageSpeed,
    if (maxSpeed != null) 'maxSpeed': maxSpeed,
    if (averagePace != null) 'averagePace': averagePace,
    if (bestPace != null) 'bestPace': bestPace,
    if (totalAscent != null) 'totalAscent': totalAscent,
    if (totalDescent != null) 'totalDescent': totalDescent,
    if (averageCadence != null) 'averageCadence': averageCadence,
    if (maxCadence != null) 'maxCadence': maxCadence,
    if (aerobicTrainingEffect != null) 'aerobicTrainingEffect': aerobicTrainingEffect,
    if (anaerobicTrainingEffect != null) 'anaerobicTrainingEffect': anaerobicTrainingEffect,
    if (vo2Max != null) 'vo2Max': vo2Max,
    if (recoveryTimeHours != null) 'recoveryTimeHours': recoveryTimeHours,
    if (averageStress != null) 'averageStress': averageStress,
    if (laps != null) 'laps': laps!.map((l) => l.toMap()).toList(),
  };

  /// Total duration
  Duration get duration => endTime.difference(startTime);

  /// Distance in kilometers
  double? get distanceKm => distance != null ? distance! / 1000 : null;

  /// Average speed in km/h
  double? get averageSpeedKmh =>
      averageSpeed != null ? averageSpeed! * 3.6 : null;

  /// Format pace as minutes:seconds per kilometer
  String? get formattedPace {
    if (averagePace == null) return null;
    final minutes = averagePace! ~/ 60;
    final seconds = averagePace! % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}/km';
  }
}

/// Activity lap data
class GarminActivityLap {
  /// Lap number (1-indexed)
  final int lapNumber;

  /// Start time
  final DateTime startTime;

  /// End time
  final DateTime endTime;

  /// Duration in seconds
  final int? durationSeconds;

  /// Distance (meters)
  final double? distance;

  /// Average heart rate
  final int? averageHeartRate;

  /// Maximum heart rate
  final int? maxHeartRate;

  /// Calories burned
  final double? calories;

  /// Average speed (m/s)
  final double? averageSpeed;

  /// Average cadence
  final int? averageCadence;

  GarminActivityLap({
    required this.lapNumber,
    required this.startTime,
    required this.endTime,
    this.durationSeconds,
    this.distance,
    this.averageHeartRate,
    this.maxHeartRate,
    this.calories,
    this.averageSpeed,
    this.averageCadence,
  });

  factory GarminActivityLap.fromMap(Map<String, dynamic> map) {
    return GarminActivityLap(
      lapNumber: map['lapNumber'] as int? ?? 1,
      startTime: DateTime.fromMillisecondsSinceEpoch(map['startTime'] as int),
      endTime: DateTime.fromMillisecondsSinceEpoch(map['endTime'] as int),
      durationSeconds: map['durationSeconds'] as int?,
      distance: (map['distance'] as num?)?.toDouble(),
      averageHeartRate: map['averageHeartRate'] as int?,
      maxHeartRate: map['maxHeartRate'] as int?,
      calories: (map['calories'] as num?)?.toDouble(),
      averageSpeed: (map['averageSpeed'] as num?)?.toDouble(),
      averageCadence: map['averageCadence'] as int?,
    );
  }

  Map<String, dynamic> toMap() => {
    'lapNumber': lapNumber,
    'startTime': startTime.millisecondsSinceEpoch,
    'endTime': endTime.millisecondsSinceEpoch,
    if (durationSeconds != null) 'durationSeconds': durationSeconds,
    if (distance != null) 'distance': distance,
    if (averageHeartRate != null) 'averageHeartRate': averageHeartRate,
    if (maxHeartRate != null) 'maxHeartRate': maxHeartRate,
    if (calories != null) 'calories': calories,
    if (averageSpeed != null) 'averageSpeed': averageSpeed,
    if (averageCadence != null) 'averageCadence': averageCadence,
  };

  Duration get duration => endTime.difference(startTime);
}

/// Activity types
enum GarminActivityType {
  running,
  cycling,
  swimming,
  walking,
  hiking,
  strength,
  cardio,
  yoga,
  pilates,
  elliptical,
  stairClimbing,
  rowing,
  golf,
  skiing,
  snowboarding,
  multisport,
  other,
  unknown,
}

GarminActivityType _parseActivityType(String? type) {
  if (type == null) return GarminActivityType.unknown;
  switch (type.toLowerCase()) {
    case 'running':
    case 'run':
    case 'treadmill_running':
    case 'trail_running':
      return GarminActivityType.running;
    case 'cycling':
    case 'biking':
    case 'indoor_cycling':
    case 'road_biking':
    case 'mountain_biking':
      return GarminActivityType.cycling;
    case 'swimming':
    case 'pool_swimming':
    case 'open_water_swimming':
      return GarminActivityType.swimming;
    case 'walking':
    case 'walk':
      return GarminActivityType.walking;
    case 'hiking':
    case 'hike':
      return GarminActivityType.hiking;
    case 'strength':
    case 'strength_training':
    case 'weight_training':
      return GarminActivityType.strength;
    case 'cardio':
    case 'fitness_equipment':
      return GarminActivityType.cardio;
    case 'yoga':
      return GarminActivityType.yoga;
    case 'pilates':
      return GarminActivityType.pilates;
    case 'elliptical':
      return GarminActivityType.elliptical;
    case 'stair_climbing':
    case 'stair_stepper':
      return GarminActivityType.stairClimbing;
    case 'rowing':
    case 'indoor_rowing':
      return GarminActivityType.rowing;
    case 'golf':
      return GarminActivityType.golf;
    case 'skiing':
    case 'resort_skiing_snowboarding':
      return GarminActivityType.skiing;
    case 'snowboarding':
      return GarminActivityType.snowboarding;
    case 'multisport':
    case 'triathlon':
      return GarminActivityType.multisport;
    case 'other':
      return GarminActivityType.other;
    default:
      return GarminActivityType.unknown;
  }
}

extension GarminActivityTypeExtension on GarminActivityType {
  String get displayName {
    switch (this) {
      case GarminActivityType.running:
        return 'Running';
      case GarminActivityType.cycling:
        return 'Cycling';
      case GarminActivityType.swimming:
        return 'Swimming';
      case GarminActivityType.walking:
        return 'Walking';
      case GarminActivityType.hiking:
        return 'Hiking';
      case GarminActivityType.strength:
        return 'Strength Training';
      case GarminActivityType.cardio:
        return 'Cardio';
      case GarminActivityType.yoga:
        return 'Yoga';
      case GarminActivityType.pilates:
        return 'Pilates';
      case GarminActivityType.elliptical:
        return 'Elliptical';
      case GarminActivityType.stairClimbing:
        return 'Stair Climbing';
      case GarminActivityType.rowing:
        return 'Rowing';
      case GarminActivityType.golf:
        return 'Golf';
      case GarminActivityType.skiing:
        return 'Skiing';
      case GarminActivityType.snowboarding:
        return 'Snowboarding';
      case GarminActivityType.multisport:
        return 'Multisport';
      case GarminActivityType.other:
        return 'Other';
      case GarminActivityType.unknown:
        return 'Unknown';
    }
  }

  /// Icon name suggestion for the activity type
  String get iconName {
    switch (this) {
      case GarminActivityType.running:
        return 'directions_run';
      case GarminActivityType.cycling:
        return 'directions_bike';
      case GarminActivityType.swimming:
        return 'pool';
      case GarminActivityType.walking:
        return 'directions_walk';
      case GarminActivityType.hiking:
        return 'terrain';
      case GarminActivityType.strength:
        return 'fitness_center';
      case GarminActivityType.cardio:
        return 'favorite';
      case GarminActivityType.yoga:
        return 'self_improvement';
      case GarminActivityType.pilates:
        return 'self_improvement';
      case GarminActivityType.elliptical:
        return 'fitness_center';
      case GarminActivityType.stairClimbing:
        return 'stairs';
      case GarminActivityType.rowing:
        return 'rowing';
      case GarminActivityType.golf:
        return 'golf_course';
      case GarminActivityType.skiing:
        return 'downhill_skiing';
      case GarminActivityType.snowboarding:
        return 'snowboarding';
      case GarminActivityType.multisport:
        return 'sports';
      case GarminActivityType.other:
      case GarminActivityType.unknown:
        return 'sports';
    }
  }
}
