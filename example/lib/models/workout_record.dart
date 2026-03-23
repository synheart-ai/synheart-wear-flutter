/// Workout data record from WHOOP API
class WorkoutRecord {
  final DateTime? createdAt;
  final DateTime? end;
  final String? id;
  final WorkoutScore? score;
  final String? scoreState;
  final int? sportId;
  final String? sportName;
  final DateTime? start;
  final String? timezoneOffset;
  final DateTime? updatedAt;
  final int? userId;
  final String? v1Id;

  WorkoutRecord({
    this.createdAt,
    this.end,
    this.id,
    this.score,
    this.scoreState,
    this.sportId,
    this.sportName,
    this.start,
    this.timezoneOffset,
    this.updatedAt,
    this.userId,
    this.v1Id,
  });

  factory WorkoutRecord.fromJson(Map<String, dynamic> json) {
    return WorkoutRecord(
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      end:
          json['end'] != null ? DateTime.tryParse(json['end'] as String) : null,
      id: json['id'] as String?,
      score: json['score'] != null
          ? WorkoutScore.fromJson(json['score'] as Map<String, dynamic>)
          : null,
      scoreState: json['score_state'] as String?,
      sportId: json['sport_id'] as int?,
      sportName: json['sport_name'] as String?,
      start: json['start'] != null
          ? DateTime.tryParse(json['start'] as String)
          : null,
      timezoneOffset: json['timezone_offset'] as String?,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
      userId: json['user_id'] as int?,
      v1Id: json['v1_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (end != null) 'end': end!.toIso8601String(),
      if (id != null) 'id': id,
      if (score != null) 'score': score!.toJson(),
      if (scoreState != null) 'score_state': scoreState,
      if (sportId != null) 'sport_id': sportId,
      if (sportName != null) 'sport_name': sportName,
      if (start != null) 'start': start!.toIso8601String(),
      if (timezoneOffset != null) 'timezone_offset': timezoneOffset,
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
      if (userId != null) 'user_id': userId,
      if (v1Id != null) 'v1_id': v1Id,
    };
  }
}

/// Workout score nested object
class WorkoutScore {
  final int? altitudeChangeMeter;
  final int? altitudeGainMeter;
  final int? averageHeartRate;
  final int? distanceMeter;
  final double? kilojoule;
  final int? maxHeartRate;
  final double? percentRecorded;
  final double? strain;
  final ZoneDurations? zoneDurations;

  WorkoutScore({
    this.altitudeChangeMeter,
    this.altitudeGainMeter,
    this.averageHeartRate,
    this.distanceMeter,
    this.kilojoule,
    this.maxHeartRate,
    this.percentRecorded,
    this.strain,
    this.zoneDurations,
  });

  factory WorkoutScore.fromJson(Map<String, dynamic> json) {
    return WorkoutScore(
      altitudeChangeMeter: json['altitude_change_meter'] as int?,
      altitudeGainMeter: json['altitude_gain_meter'] as int?,
      averageHeartRate: json['average_heart_rate'] as int?,
      distanceMeter: json['distance_meter'] as int?,
      kilojoule: (json['kilojoule'] as num?)?.toDouble(),
      maxHeartRate: json['max_heart_rate'] as int?,
      percentRecorded: (json['percent_recorded'] as num?)?.toDouble(),
      strain: (json['strain'] as num?)?.toDouble(),
      zoneDurations: json['zone_durations'] != null
          ? ZoneDurations.fromJson(
              json['zone_durations'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (altitudeChangeMeter != null)
        'altitude_change_meter': altitudeChangeMeter,
      if (altitudeGainMeter != null) 'altitude_gain_meter': altitudeGainMeter,
      if (averageHeartRate != null) 'average_heart_rate': averageHeartRate,
      if (distanceMeter != null) 'distance_meter': distanceMeter,
      if (kilojoule != null) 'kilojoule': kilojoule,
      if (maxHeartRate != null) 'max_heart_rate': maxHeartRate,
      if (percentRecorded != null) 'percent_recorded': percentRecorded,
      if (strain != null) 'strain': strain,
      if (zoneDurations != null) 'zone_durations': zoneDurations!.toJson(),
    };
  }
}

/// Zone durations nested object
class ZoneDurations {
  final int? zoneFiveMilli;
  final int? zoneFourMilli;
  final int? zoneOneMilli;
  final int? zoneThreeMilli;
  final int? zoneTwoMilli;
  final int? zoneZeroMilli;

  ZoneDurations({
    this.zoneFiveMilli,
    this.zoneFourMilli,
    this.zoneOneMilli,
    this.zoneThreeMilli,
    this.zoneTwoMilli,
    this.zoneZeroMilli,
  });

  factory ZoneDurations.fromJson(Map<String, dynamic> json) {
    return ZoneDurations(
      zoneFiveMilli: json['zone_five_milli'] as int?,
      zoneFourMilli: json['zone_four_milli'] as int?,
      zoneOneMilli: json['zone_one_milli'] as int?,
      zoneThreeMilli: json['zone_three_milli'] as int?,
      zoneTwoMilli: json['zone_two_milli'] as int?,
      zoneZeroMilli: json['zone_zero_milli'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (zoneFiveMilli != null) 'zone_five_milli': zoneFiveMilli,
      if (zoneFourMilli != null) 'zone_four_milli': zoneFourMilli,
      if (zoneOneMilli != null) 'zone_one_milli': zoneOneMilli,
      if (zoneThreeMilli != null) 'zone_three_milli': zoneThreeMilli,
      if (zoneTwoMilli != null) 'zone_two_milli': zoneTwoMilli,
      if (zoneZeroMilli != null) 'zone_zero_milli': zoneZeroMilli,
    };
  }
}
