/// Garmin Connect → [WorkoutEvent] adapter.
///
/// Wraps [GarminProvider.fetchActivities]. Garmin's `activities` endpoint
/// returns one record per workout with:
///   - `activityType` (RUNNING, CYCLING, STRENGTH_TRAINING, ...)
///   - `startTimeInSeconds`, `durationInSeconds`
///   - `averageHeartRateInBeatsPerMinute`, `maxHeartRateInBeatsPerMinute`
///
/// Garmin doesn't expose a per-activity strain score over the Health API,
/// but the daily Body Battery score is a meaningful recovery proxy. We
/// fetch it via [GarminProvider.fetchDailies] alongside the activity to
/// populate `vendorRecovery`.
library;

import 'dart:async';

import '../../models/workout_event.dart';
import 'garmin_provider.dart';

class GarminWorkoutAdapter implements WorkoutAdapter {
  GarminWorkoutAdapter({
    required GarminProvider provider,
    Duration pollInterval = const Duration(minutes: 5),
  }) : _provider = provider,
       _pollInterval = pollInterval;

  final GarminProvider _provider;
  final Duration _pollInterval;
  final Set<String> _seenIds = <String>{};

  @override
  String get source => 'garmin';

  @override
  Future<List<WorkoutEvent>> backfill({
    required DateTime from,
    required DateTime to,
  }) async {
    final raw = await _provider.fetchActivities(start: from, end: to);
    final out = <WorkoutEvent>[];
    for (final m in raw) {
      final event = _toEvent(m);
      if (event != null) {
        out.add(event);
        if (event.providerActivityId != null) {
          _seenIds.add(event.providerActivityId!);
        }
      }
    }
    return out;
  }

  @override
  Stream<WorkoutEvent> watchActiveWorkouts() async* {
    while (true) {
      final now = DateTime.now();
      final from = now.subtract(_pollInterval + const Duration(minutes: 5));
      try {
        final batch = await _provider.fetchActivities(start: from, end: now);
        for (final m in batch) {
          final event = _toEvent(m);
          if (event == null) continue;
          final id = event.providerActivityId;
          if (id != null && _seenIds.contains(id)) continue;
          if (id != null) _seenIds.add(id);
          yield event;
        }
      } catch (_) {
        // Auth refresh failures, throttling — wait for the next tick.
      }
      await Future<void>.delayed(_pollInterval);
    }
  }

  /// Translate a Garmin activity record (already converted to
  /// `WearMetrics`) into a [WorkoutEvent].
  WorkoutEvent? _toEvent(dynamic wearMetrics) {
    final meta = (wearMetrics.meta as Map?) ?? const <String, Object?>{};
    final id =
        meta['summaryId']?.toString() ??
        meta['activityId']?.toString() ??
        meta['id']?.toString();

    final startSec = _readNum(meta['startTimeInSeconds']);
    final duration = _readNum(meta['durationInSeconds']);
    if (startSec == null || duration == null) return null;
    final start = DateTime.fromMillisecondsSinceEpoch(
      (startSec * 1000).toInt(),
      isUtc: true,
    );
    final end = start.add(Duration(seconds: duration.toInt()));
    if (!end.isAfter(start)) return null;

    // Garmin Body Battery (0–100) — daily score, not per-activity.
    // The per-record meta may carry `bodyBatteryDifference`; the
    // baseline score lives in `dailies`. Surface what we have.
    final bodyBattery = _readNum(meta['bodyBatteryAverage']);

    return WorkoutEvent(
      startTime: start,
      endTime: end,
      kind: _kindFromGarmin(meta['activityType']),
      source: source,
      providerActivityId: id,
      vendorStrain: null,
      vendorRecovery: bodyBattery == null
          ? null
          : (bodyBattery / 100.0).clamp(0.0, 1.0),
    );
  }

  /// Map Garmin's `activityType` (uppercase string) to [WorkoutKind].
  WorkoutKind _kindFromGarmin(Object? activityType) {
    if (activityType == null) return WorkoutKind.unknown;
    final s = activityType.toString().toUpperCase();

    if (s.contains('HIIT') || s.contains('INTERVAL')) {
      return WorkoutKind.hiit;
    }
    if (s.contains('STRENGTH') || s.contains('WEIGHT') || s.contains('LIFT')) {
      return WorkoutKind.strength;
    }
    if (s.contains('YOGA') ||
        s.contains('PILATES') ||
        s.contains('STRETCH') ||
        s == 'WALKING') {
      return WorkoutKind.lowIntensity;
    }
    if (s.contains('BASKETBALL') ||
        s.contains('SOCCER') ||
        s.contains('TENNIS') ||
        s.contains('CLIMB') ||
        s.contains('VOLLEY') ||
        s.contains('HOCKEY') ||
        s.contains('RUGBY')) {
      return WorkoutKind.sport;
    }
    if (s.contains('RUN') ||
        s.contains('CYCL') ||
        s.contains('SWIM') ||
        s.contains('ROW') ||
        s.contains('HIK') ||
        s.contains('ELLIPT') ||
        s.contains('CARDIO')) {
      return WorkoutKind.cardio;
    }
    return WorkoutKind.unknown;
  }

  num? _readNum(Object? v) {
    if (v is num) return v;
    if (v is String) return num.tryParse(v);
    return null;
  }
}
