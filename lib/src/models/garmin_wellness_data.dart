/// Wellness epoch data (typically 15-minute intervals)
class GarminWellnessEpoch {
  /// Start time of the epoch
  final DateTime startTime;

  /// End time of the epoch
  final DateTime endTime;

  /// Device that recorded this epoch
  final int? deviceId;

  /// Average heart rate during epoch
  final int? averageHeartRate;

  /// Minimum heart rate during epoch
  final int? minHeartRate;

  /// Maximum heart rate during epoch
  final int? maxHeartRate;

  /// Resting heart rate
  final int? restingHeartRate;

  /// Average stress level
  final int? averageStress;

  /// Maximum stress level
  final int? maxStress;

  /// Steps taken during epoch
  final int? steps;

  /// Distance traveled (meters)
  final double? distance;

  /// Active calories burned
  final double? activeCalories;

  /// Intensity minutes earned
  final int? intensityMinutes;

  /// Floors climbed
  final int? floorsClimbed;

  /// Respiration rate
  final int? respirationRate;

  /// SpO2 average
  final int? averageSpo2;

  /// Activity level during epoch
  final GarminActivityLevel? activityLevel;

  GarminWellnessEpoch({
    required this.startTime,
    required this.endTime,
    this.deviceId,
    this.averageHeartRate,
    this.minHeartRate,
    this.maxHeartRate,
    this.restingHeartRate,
    this.averageStress,
    this.maxStress,
    this.steps,
    this.distance,
    this.activeCalories,
    this.intensityMinutes,
    this.floorsClimbed,
    this.respirationRate,
    this.averageSpo2,
    this.activityLevel,
  });

  factory GarminWellnessEpoch.fromMap(Map<String, dynamic> map) {
    return GarminWellnessEpoch(
      startTime: DateTime.fromMillisecondsSinceEpoch(map['startTime'] as int),
      endTime: DateTime.fromMillisecondsSinceEpoch(map['endTime'] as int),
      deviceId: map['deviceId'] as int?,
      averageHeartRate: map['averageHeartRate'] as int?,
      minHeartRate: map['minHeartRate'] as int?,
      maxHeartRate: map['maxHeartRate'] as int?,
      restingHeartRate: map['restingHeartRate'] as int?,
      averageStress: map['averageStress'] as int?,
      maxStress: map['maxStress'] as int?,
      steps: map['steps'] as int?,
      distance: (map['distance'] as num?)?.toDouble(),
      activeCalories: (map['activeCalories'] as num?)?.toDouble(),
      intensityMinutes: map['intensityMinutes'] as int?,
      floorsClimbed: map['floorsClimbed'] as int?,
      respirationRate: map['respirationRate'] as int?,
      averageSpo2: map['averageSpo2'] as int?,
      activityLevel: _parseActivityLevel(map['activityLevel'] as String?),
    );
  }

  Map<String, dynamic> toMap() => {
    'startTime': startTime.millisecondsSinceEpoch,
    'endTime': endTime.millisecondsSinceEpoch,
    if (deviceId != null) 'deviceId': deviceId,
    if (averageHeartRate != null) 'averageHeartRate': averageHeartRate,
    if (minHeartRate != null) 'minHeartRate': minHeartRate,
    if (maxHeartRate != null) 'maxHeartRate': maxHeartRate,
    if (restingHeartRate != null) 'restingHeartRate': restingHeartRate,
    if (averageStress != null) 'averageStress': averageStress,
    if (maxStress != null) 'maxStress': maxStress,
    if (steps != null) 'steps': steps,
    if (distance != null) 'distance': distance,
    if (activeCalories != null) 'activeCalories': activeCalories,
    if (intensityMinutes != null) 'intensityMinutes': intensityMinutes,
    if (floorsClimbed != null) 'floorsClimbed': floorsClimbed,
    if (respirationRate != null) 'respirationRate': respirationRate,
    if (averageSpo2 != null) 'averageSpo2': averageSpo2,
    if (activityLevel != null) 'activityLevel': activityLevel!.name,
  };

  /// Duration of this epoch
  Duration get duration => endTime.difference(startTime);
}

/// Daily wellness summary
class GarminWellnessSummary {
  /// Calendar date for this summary
  final DateTime date;

  /// Device that recorded this summary
  final int? deviceId;

  /// Total steps for the day
  final int? totalSteps;

  /// Step goal
  final int? stepGoal;

  /// Total distance (meters)
  final double? totalDistance;

  /// Total active calories
  final double? activeCalories;

  /// Total calories (active + BMR)
  final double? totalCalories;

  /// Resting heart rate
  final int? restingHeartRate;

  /// Minimum heart rate
  final int? minHeartRate;

  /// Maximum heart rate
  final int? maxHeartRate;

  /// Average stress level
  final int? averageStress;

  /// Maximum stress level
  final int? maxStress;

  /// Total intensity minutes
  final int? intensityMinutes;

  /// Moderate intensity minutes
  final int? moderateIntensityMinutes;

  /// Vigorous intensity minutes
  final int? vigorousIntensityMinutes;

  /// Floors climbed
  final int? floorsClimbed;

  /// Floors climbed goal
  final int? floorsClimbedGoal;

  /// Body battery charged
  final int? bodyBatteryCharged;

  /// Body battery drained
  final int? bodyBatteryDrained;

  /// Average SpO2
  final int? averageSpo2;

  /// Average respiration rate
  final int? averageRespirationRate;

  GarminWellnessSummary({
    required this.date,
    this.deviceId,
    this.totalSteps,
    this.stepGoal,
    this.totalDistance,
    this.activeCalories,
    this.totalCalories,
    this.restingHeartRate,
    this.minHeartRate,
    this.maxHeartRate,
    this.averageStress,
    this.maxStress,
    this.intensityMinutes,
    this.moderateIntensityMinutes,
    this.vigorousIntensityMinutes,
    this.floorsClimbed,
    this.floorsClimbedGoal,
    this.bodyBatteryCharged,
    this.bodyBatteryDrained,
    this.averageSpo2,
    this.averageRespirationRate,
  });

  factory GarminWellnessSummary.fromMap(Map<String, dynamic> map) {
    return GarminWellnessSummary(
      date: DateTime.fromMillisecondsSinceEpoch(map['date'] as int),
      deviceId: map['deviceId'] as int?,
      totalSteps: map['totalSteps'] as int?,
      stepGoal: map['stepGoal'] as int?,
      totalDistance: (map['totalDistance'] as num?)?.toDouble(),
      activeCalories: (map['activeCalories'] as num?)?.toDouble(),
      totalCalories: (map['totalCalories'] as num?)?.toDouble(),
      restingHeartRate: map['restingHeartRate'] as int?,
      minHeartRate: map['minHeartRate'] as int?,
      maxHeartRate: map['maxHeartRate'] as int?,
      averageStress: map['averageStress'] as int?,
      maxStress: map['maxStress'] as int?,
      intensityMinutes: map['intensityMinutes'] as int?,
      moderateIntensityMinutes: map['moderateIntensityMinutes'] as int?,
      vigorousIntensityMinutes: map['vigorousIntensityMinutes'] as int?,
      floorsClimbed: map['floorsClimbed'] as int?,
      floorsClimbedGoal: map['floorsClimbedGoal'] as int?,
      bodyBatteryCharged: map['bodyBatteryCharged'] as int?,
      bodyBatteryDrained: map['bodyBatteryDrained'] as int?,
      averageSpo2: map['averageSpo2'] as int?,
      averageRespirationRate: map['averageRespirationRate'] as int?,
    );
  }

  Map<String, dynamic> toMap() => {
    'date': date.millisecondsSinceEpoch,
    if (deviceId != null) 'deviceId': deviceId,
    if (totalSteps != null) 'totalSteps': totalSteps,
    if (stepGoal != null) 'stepGoal': stepGoal,
    if (totalDistance != null) 'totalDistance': totalDistance,
    if (activeCalories != null) 'activeCalories': activeCalories,
    if (totalCalories != null) 'totalCalories': totalCalories,
    if (restingHeartRate != null) 'restingHeartRate': restingHeartRate,
    if (minHeartRate != null) 'minHeartRate': minHeartRate,
    if (maxHeartRate != null) 'maxHeartRate': maxHeartRate,
    if (averageStress != null) 'averageStress': averageStress,
    if (maxStress != null) 'maxStress': maxStress,
    if (intensityMinutes != null) 'intensityMinutes': intensityMinutes,
    if (moderateIntensityMinutes != null)
      'moderateIntensityMinutes': moderateIntensityMinutes,
    if (vigorousIntensityMinutes != null)
      'vigorousIntensityMinutes': vigorousIntensityMinutes,
    if (floorsClimbed != null) 'floorsClimbed': floorsClimbed,
    if (floorsClimbedGoal != null) 'floorsClimbedGoal': floorsClimbedGoal,
    if (bodyBatteryCharged != null) 'bodyBatteryCharged': bodyBatteryCharged,
    if (bodyBatteryDrained != null) 'bodyBatteryDrained': bodyBatteryDrained,
    if (averageSpo2 != null) 'averageSpo2': averageSpo2,
    if (averageRespirationRate != null)
      'averageRespirationRate': averageRespirationRate,
  };

  /// Calculate step goal completion percentage
  double? get stepGoalPercentage {
    if (totalSteps == null || stepGoal == null || stepGoal == 0) return null;
    return (totalSteps! / stepGoal!) * 100;
  }
}

/// Activity level classifications
enum GarminActivityLevel {
  /// Sedentary/inactive
  sedentary,

  /// Light activity
  light,

  /// Moderate activity
  moderate,

  /// Vigorous/high intensity
  vigorous,

  /// Unknown activity level
  unknown,
}

GarminActivityLevel _parseActivityLevel(String? level) {
  if (level == null) return GarminActivityLevel.unknown;
  switch (level.toLowerCase()) {
    case 'sedentary':
    case 'inactive':
      return GarminActivityLevel.sedentary;
    case 'light':
    case 'lightly_active':
      return GarminActivityLevel.light;
    case 'moderate':
    case 'moderately_active':
      return GarminActivityLevel.moderate;
    case 'vigorous':
    case 'highly_active':
    case 'active':
      return GarminActivityLevel.vigorous;
    default:
      return GarminActivityLevel.unknown;
  }
}
