/// Sleep data record from WHOOP API
class SleepRecord {
  final DateTime? createdAt;
  final int? cycleId;
  final DateTime? end;
  final String? id;
  final bool? nap;
  final SleepScore? score;
  final String? scoreState;
  final DateTime? start;
  final String? timezoneOffset;
  final DateTime? updatedAt;
  final int? userId;
  final String? v1Id;

  SleepRecord({
    this.createdAt,
    this.cycleId,
    this.end,
    this.id,
    this.nap,
    this.score,
    this.scoreState,
    this.start,
    this.timezoneOffset,
    this.updatedAt,
    this.userId,
    this.v1Id,
  });

  factory SleepRecord.fromJson(Map<String, dynamic> json) {
    return SleepRecord(
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      cycleId: json['cycle_id'] as int?,
      end:
          json['end'] != null ? DateTime.tryParse(json['end'] as String) : null,
      id: json['id'] as String?,
      nap: json['nap'] as bool?,
      score: json['score'] != null
          ? SleepScore.fromJson(json['score'] as Map<String, dynamic>)
          : null,
      scoreState: json['score_state'] as String?,
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
      if (cycleId != null) 'cycle_id': cycleId,
      if (end != null) 'end': end!.toIso8601String(),
      if (id != null) 'id': id,
      if (nap != null) 'nap': nap,
      if (score != null) 'score': score!.toJson(),
      if (scoreState != null) 'score_state': scoreState,
      if (start != null) 'start': start!.toIso8601String(),
      if (timezoneOffset != null) 'timezone_offset': timezoneOffset,
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
      if (userId != null) 'user_id': userId,
      if (v1Id != null) 'v1_id': v1Id,
    };
  }
}

/// Sleep score nested object
class SleepScore {
  final double? respiratoryRate;
  final double? sleepConsistencyPercentage;
  final double? sleepEfficiencyPercentage;
  final SleepNeeded? sleepNeeded;
  final double? sleepPerformancePercentage;
  final StageSummary? stageSummary;

  SleepScore({
    this.respiratoryRate,
    this.sleepConsistencyPercentage,
    this.sleepEfficiencyPercentage,
    this.sleepNeeded,
    this.sleepPerformancePercentage,
    this.stageSummary,
  });

  factory SleepScore.fromJson(Map<String, dynamic> json) {
    return SleepScore(
      respiratoryRate: (json['respiratory_rate'] as num?)?.toDouble(),
      sleepConsistencyPercentage:
          (json['sleep_consistency_percentage'] as num?)?.toDouble(),
      sleepEfficiencyPercentage:
          (json['sleep_efficiency_percentage'] as num?)?.toDouble(),
      sleepNeeded: json['sleep_needed'] != null
          ? SleepNeeded.fromJson(json['sleep_needed'] as Map<String, dynamic>)
          : null,
      sleepPerformancePercentage:
          (json['sleep_performance_percentage'] as num?)?.toDouble(),
      stageSummary: json['stage_summary'] != null
          ? StageSummary.fromJson(json['stage_summary'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (respiratoryRate != null) 'respiratory_rate': respiratoryRate,
      if (sleepConsistencyPercentage != null)
        'sleep_consistency_percentage': sleepConsistencyPercentage,
      if (sleepEfficiencyPercentage != null)
        'sleep_efficiency_percentage': sleepEfficiencyPercentage,
      if (sleepNeeded != null) 'sleep_needed': sleepNeeded!.toJson(),
      if (sleepPerformancePercentage != null)
        'sleep_performance_percentage': sleepPerformancePercentage,
      if (stageSummary != null) 'stage_summary': stageSummary!.toJson(),
    };
  }
}

/// Sleep needed nested object
class SleepNeeded {
  final int? baselineMilli;
  final int? needFromRecentNapMilli;
  final int? needFromRecentStrainMilli;
  final int? needFromSleepDebtMilli;

  SleepNeeded({
    this.baselineMilli,
    this.needFromRecentNapMilli,
    this.needFromRecentStrainMilli,
    this.needFromSleepDebtMilli,
  });

  factory SleepNeeded.fromJson(Map<String, dynamic> json) {
    return SleepNeeded(
      baselineMilli: json['baseline_milli'] as int?,
      needFromRecentNapMilli: json['need_from_recent_nap_milli'] as int?,
      needFromRecentStrainMilli: json['need_from_recent_strain_milli'] as int?,
      needFromSleepDebtMilli: json['need_from_sleep_debt_milli'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (baselineMilli != null) 'baseline_milli': baselineMilli,
      if (needFromRecentNapMilli != null)
        'need_from_recent_nap_milli': needFromRecentNapMilli,
      if (needFromRecentStrainMilli != null)
        'need_from_recent_strain_milli': needFromRecentStrainMilli,
      if (needFromSleepDebtMilli != null)
        'need_from_sleep_debt_milli': needFromSleepDebtMilli,
    };
  }
}

/// Stage summary nested object
class StageSummary {
  final int? disturbanceCount;
  final int? sleepCycleCount;
  final int? totalAwakeTimeMilli;
  final int? totalInBedTimeMilli;
  final int? totalLightSleepTimeMilli;
  final int? totalNoDataTimeMilli;
  final int? totalRemSleepTimeMilli;
  final int? totalSlowWaveSleepTimeMilli;

  StageSummary({
    this.disturbanceCount,
    this.sleepCycleCount,
    this.totalAwakeTimeMilli,
    this.totalInBedTimeMilli,
    this.totalLightSleepTimeMilli,
    this.totalNoDataTimeMilli,
    this.totalRemSleepTimeMilli,
    this.totalSlowWaveSleepTimeMilli,
  });

  factory StageSummary.fromJson(Map<String, dynamic> json) {
    return StageSummary(
      disturbanceCount: json['disturbance_count'] as int?,
      sleepCycleCount: json['sleep_cycle_count'] as int?,
      totalAwakeTimeMilli: json['total_awake_time_milli'] as int?,
      totalInBedTimeMilli: json['total_in_bed_time_milli'] as int?,
      totalLightSleepTimeMilli: json['total_light_sleep_time_milli'] as int?,
      totalNoDataTimeMilli: json['total_no_data_time_milli'] as int?,
      totalRemSleepTimeMilli: json['total_rem_sleep_time_milli'] as int?,
      totalSlowWaveSleepTimeMilli:
          json['total_slow_wave_sleep_time_milli'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (disturbanceCount != null) 'disturbance_count': disturbanceCount,
      if (sleepCycleCount != null) 'sleep_cycle_count': sleepCycleCount,
      if (totalAwakeTimeMilli != null)
        'total_awake_time_milli': totalAwakeTimeMilli,
      if (totalInBedTimeMilli != null)
        'total_in_bed_time_milli': totalInBedTimeMilli,
      if (totalLightSleepTimeMilli != null)
        'total_light_sleep_time_milli': totalLightSleepTimeMilli,
      if (totalNoDataTimeMilli != null)
        'total_no_data_time_milli': totalNoDataTimeMilli,
      if (totalRemSleepTimeMilli != null)
        'total_rem_sleep_time_milli': totalRemSleepTimeMilli,
      if (totalSlowWaveSleepTimeMilli != null)
        'total_slow_wave_sleep_time_milli': totalSlowWaveSleepTimeMilli,
    };
  }
}
