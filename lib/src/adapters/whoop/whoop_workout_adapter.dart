/// Whoop → [WorkoutEvent] adapter.
///
/// Wraps [WhoopProvider.fetchWorkouts] and translates each entry into a
/// normalized [WorkoutEvent]. Whoop's strain score (0–21) and recovery
/// score (0–100) are scaled into `[0, 1]`.
library;

import 'dart:async';

import '../../models/workout_event.dart';
import 'whoop_provider.dart';

/// Adapter that emits [WorkoutEvent]s from a connected Whoop account.
///
/// Whoop does not push workout events in real time over the public REST
/// API, so [watchActiveWorkouts] polls at a host-supplied interval. The
/// adapter dedupes by Whoop's per-workout `id` so multiple polls don't
/// cause double-counting.
class WhoopWorkoutAdapter implements WorkoutAdapter {
  WhoopWorkoutAdapter({
    required WhoopProvider provider,
    Duration pollInterval = const Duration(minutes: 5),
  }) : _provider = provider,
       _pollInterval = pollInterval;

  final WhoopProvider _provider;
  final Duration _pollInterval;
  final Set<String> _seenIds = <String>{};

  @override
  String get source => 'whoop';

  @override
  Future<List<WorkoutEvent>> backfill({
    required DateTime from,
    required DateTime to,
  }) async {
    final raw = await _provider.fetchWorkouts(start: from, end: to, limit: 200);
    final out = <WorkoutEvent>[];
    for (final w in raw) {
      final event = _toEvent(w);
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
      // Look back one poll interval + a small slack window so a workout
      // that ended right between polls still gets picked up.
      final from = now.subtract(_pollInterval + const Duration(minutes: 5));
      try {
        final batch = await _provider.fetchWorkouts(
          start: from,
          end: now,
          limit: 50,
        );
        for (final w in batch) {
          final event = _toEvent(w);
          if (event == null) continue;
          final id = event.providerActivityId;
          if (id != null && _seenIds.contains(id)) continue;
          if (id != null) _seenIds.add(id);
          yield event;
        }
      } catch (_) {
        // Network blips are transient — wait for the next tick.
      }
      await Future<void>.delayed(_pollInterval);
    }
  }

  /// Translate a single Whoop workout entry (already in `WearMetrics`
  /// shape via the provider) into a [WorkoutEvent].
  ///
  /// Returns `null` if the entry lacks a usable `start`/`end` window —
  /// the engine needs both to scope the `Movement` task.
  WorkoutEvent? _toEvent(dynamic wearMetrics) {
    // Whoop's provider serializes per-record metadata into `meta`.
    // We pull the timestamps and strain/recovery scores from there.
    final meta = (wearMetrics.meta as Map?) ?? const <String, Object?>{};
    final id = meta['id']?.toString() ?? meta['workout_id']?.toString();
    final startStr =
        meta['start']?.toString() ?? meta['start_time']?.toString();
    final endStr = meta['end']?.toString() ?? meta['end_time']?.toString();
    if (startStr == null || endStr == null) return null;
    DateTime start;
    DateTime end;
    try {
      start = DateTime.parse(startStr);
      end = DateTime.parse(endStr);
    } catch (_) {
      return null;
    }
    if (!end.isAfter(start)) return null;

    final rawStrain = _readNum(meta['strain_score'] ?? meta['strain']);
    final rawRecovery = _readNum(meta['recovery_score'] ?? meta['recovery']);

    return WorkoutEvent(
      startTime: start,
      endTime: end,
      kind: _kindFromWhoop(meta['sport_id'] ?? meta['sport_name']),
      source: source,
      providerActivityId: id,
      vendorStrain: rawStrain == null
          ? null
          : (rawStrain / 21.0).clamp(0.0, 1.0),
      vendorRecovery: rawRecovery == null
          ? null
          : (rawRecovery / 100.0).clamp(0.0, 1.0),
    );
  }

  /// Map Whoop's `sport_id` / `sport_name` into a [WorkoutKind]. The
  /// mapping is intentionally coarse — Whoop has dozens of sport ids; we
  /// only need to distinguish cardio / strength / hiit / lowIntensity /
  /// sport.
  WorkoutKind _kindFromWhoop(Object? sport) {
    if (sport == null) return WorkoutKind.unknown;
    final s = sport.toString().toLowerCase();
    if (s.contains('hiit') || s.contains('crossfit')) return WorkoutKind.hiit;
    if (s.contains('strength') ||
        s.contains('weight') ||
        s.contains('lift') ||
        s.contains('powerlift')) {
      return WorkoutKind.strength;
    }
    if (s.contains('walk') ||
        s.contains('yoga') ||
        s.contains('stretch') ||
        s.contains('pilates') ||
        s.contains('meditation')) {
      return WorkoutKind.lowIntensity;
    }
    if (s.contains('basketball') ||
        s.contains('soccer') ||
        s.contains('tennis') ||
        s.contains('climb') ||
        s.contains('rugby') ||
        s.contains('hockey') ||
        s.contains('volleyball')) {
      return WorkoutKind.sport;
    }
    if (s.contains('run') ||
        s.contains('cycle') ||
        s.contains('cycl') ||
        s.contains('row') ||
        s.contains('swim') ||
        s.contains('elliptical') ||
        s.contains('cardio')) {
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
