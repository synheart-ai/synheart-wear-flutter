/// Recovery data record from WHOOP API
class RecoveryRecord {
  final DateTime? createdAt;
  final int? cycleId;
  final RecoveryScore? score;
  final String? scoreState;
  final String? sleepId;
  final DateTime? updatedAt;
  final int? userId;

  RecoveryRecord({
    this.createdAt,
    this.cycleId,
    this.score,
    this.scoreState,
    this.sleepId,
    this.updatedAt,
    this.userId,
  });

  factory RecoveryRecord.fromJson(Map<String, dynamic> json) {
    return RecoveryRecord(
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      cycleId: json['cycle_id'] as int?,
      score: json['score'] != null
          ? RecoveryScore.fromJson(json['score'] as Map<String, dynamic>)
          : null,
      scoreState: json['score_state'] as String?,
      sleepId: json['sleep_id'] as String?,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
      userId: json['user_id'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (cycleId != null) 'cycle_id': cycleId,
      if (score != null) 'score': score!.toJson(),
      if (scoreState != null) 'score_state': scoreState,
      if (sleepId != null) 'sleep_id': sleepId,
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
      if (userId != null) 'user_id': userId,
    };
  }
}

/// Recovery score nested object
class RecoveryScore {
  final double? hrvRmssdMilli;
  final int? recoveryScore;
  final int? restingHeartRate;
  final double? skinTempCelsius;
  final double? spo2Percentage;
  final bool? userCalibrating;

  RecoveryScore({
    this.hrvRmssdMilli,
    this.recoveryScore,
    this.restingHeartRate,
    this.skinTempCelsius,
    this.spo2Percentage,
    this.userCalibrating,
  });

  factory RecoveryScore.fromJson(Map<String, dynamic> json) {
    return RecoveryScore(
      hrvRmssdMilli: (json['hrv_rmssd_milli'] as num?)?.toDouble(),
      recoveryScore: json['recovery_score'] as int?,
      restingHeartRate: json['resting_heart_rate'] as int?,
      skinTempCelsius: (json['skin_temp_celsius'] as num?)?.toDouble(),
      spo2Percentage: (json['spo2_percentage'] as num?)?.toDouble(),
      userCalibrating: json['user_calibrating'] as bool?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (hrvRmssdMilli != null) 'hrv_rmssd_milli': hrvRmssdMilli,
      if (recoveryScore != null) 'recovery_score': recoveryScore,
      if (restingHeartRate != null) 'resting_heart_rate': restingHeartRate,
      if (skinTempCelsius != null) 'skin_temp_celsius': skinTempCelsius,
      if (spo2Percentage != null) 'spo2_percentage': spo2Percentage,
      if (userCalibrating != null) 'user_calibrating': userCalibrating,
    };
  }
}
