/// Workout adapter for Apple HealthKit (iOS) and Health Connect (Android),
/// both surfaced through the cross-platform `package:health`.
///
/// Reads workout records via [Health.getHealthDataFromTypes] for the
/// `WORKOUT` data type, then translates each record into a normalized
/// [WorkoutEvent].
///
/// Live streaming is approximated with polling — `package:health` doesn't
/// expose a live `HKWorkoutSession` event, so apps that want real-time
/// modulation during a workout should use the watch / phone companion
/// modules. Backfill via [backfill] handles historical workouts.
library;

import 'dart:async';
import 'dart:io' show Platform;

import 'package:health/health.dart';

import '../models/workout_event.dart';

/// Cross-platform workout adapter (HealthKit on iOS, Health Connect on
/// Android). Identifies the platform via [Platform.isIOS] / [Platform.isAndroid]
/// for the [WorkoutEvent.source] tag.
class HealthWorkoutAdapter implements WorkoutAdapter {
  HealthWorkoutAdapter({
    Health? health,
    Duration pollInterval = const Duration(minutes: 2),
  }) : _health = health ?? Health(),
       _pollInterval = pollInterval;

  final Health _health;
  final Duration _pollInterval;
  final Set<String> _seen = <String>{};

  @override
  String get source => Platform.isIOS
      ? 'healthkit'
      : (Platform.isAndroid ? 'healthconnect' : 'health');

  @override
  Future<List<WorkoutEvent>> backfill({
    required DateTime from,
    required DateTime to,
  }) async {
    final records = await _readWorkouts(from, to);
    final out = <WorkoutEvent>[];
    for (final point in records) {
      final event = _toEvent(point);
      if (event == null) continue;
      out.add(event);
      if (event.providerActivityId != null) {
        _seen.add(event.providerActivityId!);
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
        final batch = await _readWorkouts(from, now);
        for (final point in batch) {
          final event = _toEvent(point);
          if (event == null) continue;
          final id = event.providerActivityId;
          if (id != null && _seen.contains(id)) continue;
          if (id != null) _seen.add(id);
          yield event;
        }
      } catch (_) {
        // Permissions not granted yet, transient error — wait and retry.
      }
      await Future<void>.delayed(_pollInterval);
    }
  }

  Future<List<HealthDataPoint>> _readWorkouts(
    DateTime from,
    DateTime to,
  ) async {
    return _health.getHealthDataFromTypes(
      types: const [HealthDataType.WORKOUT],
      startTime: from,
      endTime: to,
    );
  }

  /// Translate a single `HealthDataPoint` (workout record) into a
  /// [WorkoutEvent]. Returns null when the record's value isn't a
  /// workout payload (defensive — `package:health` versions vary).
  WorkoutEvent? _toEvent(HealthDataPoint point) {
    final value = point.value;
    if (value is! WorkoutHealthValue) return null;

    final start = point.dateFrom;
    final end = point.dateTo;
    if (!end.isAfter(start)) return null;

    final activity = value.workoutActivityType;

    // package:health on iOS exposes `HKWorkoutEffortScore` / energy fields
    // via WorkoutHealthValue's totalEnergyBurned + totalDistance etc., but
    // not a direct strain or recovery scalar. Leave both null and let the
    // engine's signal-only path handle the window — task_type=Movement is
    // the meaningful contribution here.
    return WorkoutEvent(
      startTime: start,
      endTime: end,
      kind: _kindFromActivityType(activity),
      source: source,
      providerActivityId: point.uuid,
      vendorStrain: null,
      vendorRecovery: null,
    );
  }

  /// Coarse map from `HealthWorkoutActivityType` to [WorkoutKind].
  WorkoutKind _kindFromActivityType(HealthWorkoutActivityType type) {
    switch (type) {
      // Cardio
      case HealthWorkoutActivityType.RUNNING:
      case HealthWorkoutActivityType.RUNNING_TREADMILL:
      case HealthWorkoutActivityType.WALKING:
      case HealthWorkoutActivityType.BIKING:
      case HealthWorkoutActivityType.SWIMMING:
      case HealthWorkoutActivityType.ROWING:
      case HealthWorkoutActivityType.ELLIPTICAL:
      case HealthWorkoutActivityType.STAIR_CLIMBING:
      case HealthWorkoutActivityType.HIKING:
      case HealthWorkoutActivityType.CROSS_COUNTRY_SKIING:
        return WorkoutKind.cardio;

      // Strength
      case HealthWorkoutActivityType.STRENGTH_TRAINING:
      case HealthWorkoutActivityType.WEIGHTLIFTING:
      case HealthWorkoutActivityType.TRADITIONAL_STRENGTH_TRAINING:
        return WorkoutKind.strength;

      // High intensity
      case HealthWorkoutActivityType.HIGH_INTENSITY_INTERVAL_TRAINING:
      case HealthWorkoutActivityType.MIXED_CARDIO:
        return WorkoutKind.hiit;

      // Low intensity
      case HealthWorkoutActivityType.YOGA:
      case HealthWorkoutActivityType.PILATES:
      case HealthWorkoutActivityType.MIND_AND_BODY:
      case HealthWorkoutActivityType.FLEXIBILITY:
      case HealthWorkoutActivityType.COOLDOWN:
        return WorkoutKind.lowIntensity;

      // Sport (mixed cardio + neuromuscular + cognitive)
      case HealthWorkoutActivityType.BASKETBALL:
      case HealthWorkoutActivityType.SOCCER:
      case HealthWorkoutActivityType.TENNIS:
      case HealthWorkoutActivityType.AMERICAN_FOOTBALL:
      case HealthWorkoutActivityType.VOLLEYBALL:
      case HealthWorkoutActivityType.HOCKEY:
      case HealthWorkoutActivityType.RUGBY:
      case HealthWorkoutActivityType.CLIMBING:
      case HealthWorkoutActivityType.MARTIAL_ARTS:
      case HealthWorkoutActivityType.BOXING:
        return WorkoutKind.sport;

      default:
        return WorkoutKind.unknown;
    }
  }
}
