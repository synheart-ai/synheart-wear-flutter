/// Cross-adapter contract for workout / exercise events.
///
/// Adapters (HealthKit, Health Connect, Whoop, Garmin, BLE companions, ...)
/// normalize their provider-specific workout records into [WorkoutEvent]
/// instances. The host app then forwards each event to the Synheart core
/// engine via `SynheartEngine.pushWorkoutEvent(...)`.
///
/// Discriminant integers ([WorkoutKind.discriminant]) match the engine FFI
/// contract:
/// `0=unknown, 1=cardio, 2=strength, 3=hiit, 4=lowIntensity, 5=sport`.
library;

/// Sub-classification of a [WorkoutEvent]. Each kind drives a different
/// per-`HsvType` confidence modulation table in the engine's
/// personalization runtime — strength training, for example, dampens
/// `Strain` confidence because HR doesn't track neuromuscular load well.
enum WorkoutKind {
  unknown(0),
  cardio(1),
  strength(2),
  hiit(3),
  lowIntensity(4),
  sport(5);

  const WorkoutKind(this.discriminant);

  /// Stable integer matching the C ABI in the native runtime.
  final int discriminant;

  /// Decode an FFI-side discriminant. Unknown values fall back to
  /// [WorkoutKind.unknown].
  static WorkoutKind fromDiscriminant(int value) {
    return WorkoutKind.values.firstWhere(
      (k) => k.discriminant == value,
      orElse: () => WorkoutKind.unknown,
    );
  }
}

/// Normalized workout event produced by a [WorkoutAdapter] and consumed by
/// the Synheart core engine. All vendor scalars are normalized to `[0, 1]`
/// by the adapter, never by the host app.
class WorkoutEvent {
  WorkoutEvent({
    required this.startTime,
    required this.endTime,
    required this.kind,
    required this.source,
    this.vendorStrain,
    this.vendorRecovery,
    this.providerActivityId,
  });

  /// Inclusive start of the workout window.
  final DateTime startTime;

  /// Inclusive end of the workout window. Used by the engine to decay the
  /// `Movement` task back to `Unknown`.
  final DateTime endTime;

  /// Sub-classification used for per-kind confidence modulation.
  final WorkoutKind kind;

  /// Originating adapter / provider. Free-form, used only for logging and
  /// provenance — examples: `"healthkit"`, `"healthconnect"`, `"whoop"`,
  /// `"garmin"`, `"garmin-companion"`, `"ble"`.
  final String source;

  /// Physiological exertion score, normalized to `[0, 1]`.
  /// Whoop strain ÷ 21, Garmin training-load mapped, etc.
  /// `null` when the provider doesn't expose it.
  final double? vendorStrain;

  /// Recovery score, normalized to `[0, 1]`.
  /// Whoop recovery, `HKWorkoutEffortScore` normalized, Garmin Body
  /// Battery ÷ 100, etc.
  final double? vendorRecovery;

  /// Provider-side activity identifier when available (Whoop workout id,
  /// Garmin activity id, HealthKit UUID). Used for de-duplication when
  /// the same activity is observed from multiple adapters.
  final String? providerActivityId;

  /// Encode `vendorStrain` for the FFI: returns the value if in `[0, 1]`,
  /// `-1.0` otherwise (the FFI's "skip" sentinel).
  double get vendorStrainForFfi =>
      (vendorStrain != null && vendorStrain! >= 0.0 && vendorStrain! <= 1.0)
      ? vendorStrain!
      : -1.0;

  /// Encode `vendorRecovery` for the FFI: returns the value if in `[0, 1]`,
  /// `-1.0` otherwise.
  double get vendorRecoveryForFfi =>
      (vendorRecovery != null &&
          vendorRecovery! >= 0.0 &&
          vendorRecovery! <= 1.0)
      ? vendorRecovery!
      : -1.0;

  Map<String, Object?> toJson() => {
    'startTime': startTime.toUtc().toIso8601String(),
    'endTime': endTime.toUtc().toIso8601String(),
    'kind': kind.name,
    'source': source,
    if (vendorStrain != null) 'vendorStrain': vendorStrain,
    if (vendorRecovery != null) 'vendorRecovery': vendorRecovery,
    if (providerActivityId != null) 'providerActivityId': providerActivityId,
  };

  @override
  String toString() =>
      'WorkoutEvent(${kind.name}, ${startTime.toIso8601String()} → ${endTime.toIso8601String()}, source=$source)';
}

/// A provider-specific source of [WorkoutEvent]s. Implemented by each
/// adapter (`HealthKitWorkoutAdapter`, `HealthConnectWorkoutAdapter`,
/// `WhoopWorkoutAdapter`, `GarminWorkoutAdapter`, ...).
abstract class WorkoutAdapter {
  /// Stable identifier for the adapter, e.g. `"healthkit"`. Used as
  /// [WorkoutEvent.source] when adapters don't override per-event.
  String get source;

  /// Backfill historical workouts from `from` to `to` (inclusive). Used on
  /// app start to populate recent activity context before any live stream
  /// arrives.
  Future<List<WorkoutEvent>> backfill({
    required DateTime from,
    required DateTime to,
  });

  /// Stream of newly-observed workouts. Adapters should debounce
  /// duplicates by [WorkoutEvent.providerActivityId] when available.
  ///
  /// Implementations may emit a single event when a session starts (with
  /// `endTime == startTime + estimatedDuration`) and re-emit when it ends
  /// with the corrected `endTime`. The engine's decay logic tolerates
  /// later updates because each call to `pushWorkoutEvent` simply resets
  /// `task_type_until_ms`.
  Stream<WorkoutEvent> watchActiveWorkouts();
}
