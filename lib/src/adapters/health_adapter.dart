import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:health/health.dart';

import '../core/consent_manager.dart';
import '../core/logger.dart';
import '../core/models.dart';

/// Adapter for the health package to handle HealthKit and Health Connect integration
/// Supports health package v13.2.1 API
class HealthAdapter {
  static final Health _health = Health();
  static bool _configured = false;
  // Serializes concurrent requestAuthorization calls to prevent duplicate
  // HealthKit dialogs (iOS crashes when two present simultaneously).
  static Completer<bool>? _permissionCompleter;
  static Set<PermissionType>? _inFlightPermissions;

  /// Last successful `readMetrics` call timestamp on Android. Used by
  /// the platform rate-limiter — Android Health Connect enforces a
  /// per-app quota (~1 call/sec sustained) and any caller that bursts
  /// past it triggers `HealthConnectException: API call quota
  /// exceeded`. Acting as a last line of defense regardless of which
  /// upstream path issues the request.
  static DateTime? _lastReadAt;

  /// Minimum interval between back-to-back Android `readMetrics`
  /// calls. 10s leaves plenty of headroom under HC's quota and is
  /// well within the staleness tolerance for ambient context reads
  /// (sleep, daily steps, weekly HRV trends). Real-time HR streaming
  /// should never go through HC anyway — see `apple_healthkit.dart`.
  static const Duration _androidMinInterval = Duration(seconds: 10);

  /// Override the throttle (callers that genuinely need a fresh read
  /// after a wipe / consent change can pass `bypassThrottle: true`).
  static bool _shouldThrottleAndroid({required bool bypass}) {
    if (bypass || !Platform.isAndroid) return false;
    final last = _lastReadAt;
    if (last == null) return false;
    return DateTime.now().difference(last) < _androidMinInterval;
  }

  /// Configure the health package (required before any operations)
  static Future<void> _ensureConfigured() async {
    if (!_configured) {
      try {
        await _health.configure();
        _configured = true;
      } catch (e) {
        logError('Health package configuration error', e);
        rethrow;
      }
    }
  }

  /// Map Synheart permission types to Health package types
  static List<HealthDataType> _mapPermissions(Set<PermissionType> permissions) {
    final healthTypes = <HealthDataType>[];

    for (final permission in permissions) {
      switch (permission) {
        case PermissionType.heartRate:
          healthTypes.add(HealthDataType.HEART_RATE);
          // HealthKit exposes a separate `RESTING_HEART_RATE` quantity;
          // bundle it under heartRate so the auth dialog asks once and
          // [fetchOvernightPhysiology] can read RHR without a second
          // round-trip. Health Connect does not have a stable resting
          // HR type today, so Android skips it.
          if (Platform.isIOS) {
            healthTypes.add(HealthDataType.RESTING_HEART_RATE);
          }
          break;
        case PermissionType.heartRateVariability:
          // Use platform-specific HRV types
          if (Platform.isAndroid) {
            healthTypes.add(HealthDataType.HEART_RATE_VARIABILITY_RMSSD);
          } else {
            healthTypes.add(HealthDataType.HEART_RATE_VARIABILITY_SDNN);
          }
          break;
        case PermissionType.steps:
          healthTypes.add(HealthDataType.STEPS);
          break;
        case PermissionType.calories:
          healthTypes.add(HealthDataType.ACTIVE_ENERGY_BURNED);
          break;
        case PermissionType.distance:
          // Health Connect (Android) uses DISTANCE_DELTA
          // HealthKit (iOS) uses DISTANCE_WALKING_RUNNING
          if (Platform.isAndroid) {
            healthTypes.add(HealthDataType.DISTANCE_DELTA);
          } else {
            healthTypes.add(HealthDataType.DISTANCE_WALKING_RUNNING);
          }
          break;
        case PermissionType.sleep:
          // Both Health Connect (Android) and HealthKit (iOS) expose
          // per-stage sleep types. We request the full set so the
          // engine's quality component can score real deep / REM
          // proportions instead of falling back to duration-only.
          //
          // - SLEEP_ASLEEP (Android) / SLEEP_IN_BED (iOS) is the
          //   coarse total fallback when stage data isn't recorded.
          // - SLEEP_DEEP / SLEEP_REM / SLEEP_LIGHT / SLEEP_AWAKE are
          //   the per-stage segments. Granted-only — devices/apps
          //   that don't write stage data simply return empty
          //   ranges, which we account for downstream.
          if (Platform.isAndroid) {
            healthTypes.addAll([
              HealthDataType.SLEEP_ASLEEP,
              HealthDataType.SLEEP_DEEP,
              HealthDataType.SLEEP_LIGHT,
              HealthDataType.SLEEP_REM,
              HealthDataType.SLEEP_AWAKE,
            ]);
          } else {
            healthTypes.addAll([
              HealthDataType.SLEEP_IN_BED,
              HealthDataType.SLEEP_DEEP,
              HealthDataType.SLEEP_LIGHT,
              HealthDataType.SLEEP_REM,
              HealthDataType.SLEEP_AWAKE,
            ]);
          }
          break;
        case PermissionType.stress:
          // Note: Stress is not directly available in Health package
          // You might need to calculate from HRV or use other metrics
          break;
        case PermissionType.all:
          // Request all available types
          healthTypes.addAll([
            HealthDataType.HEART_RATE,
            Platform.isAndroid
                ? HealthDataType.HEART_RATE_VARIABILITY_RMSSD
                : HealthDataType.HEART_RATE_VARIABILITY_SDNN,
            HealthDataType.STEPS,
            HealthDataType.ACTIVE_ENERGY_BURNED,
            if (Platform.isAndroid)
              HealthDataType.DISTANCE_DELTA, // Android distance
            if (!Platform.isAndroid)
              HealthDataType.DISTANCE_WALKING_RUNNING, // iOS only
            if (Platform.isAndroid)
              HealthDataType
                  .SLEEP_ASLEEP // Health Connect total
            else
              HealthDataType.SLEEP_IN_BED, // HealthKit total
            // Per-stage sleep types (both platforms).
            HealthDataType.SLEEP_DEEP,
            HealthDataType.SLEEP_LIGHT,
            HealthDataType.SLEEP_REM,
            HealthDataType.SLEEP_AWAKE,
          ]);
          break;
      }
    }

    return healthTypes;
  }

  /// Request permissions using health package (v13.2.1 API)
  /// Always requests READ_WRITE access for all types.
  ///
  /// Serializes concurrent calls — if a request is already in flight,
  /// subsequent callers wait for the same result instead of triggering a
  /// second native dialog (which crashes iOS with "Attempt to present on...").
  static Future<bool> requestPermissions(
    Set<PermissionType> permissions,
  ) async {
    // If a permission request is already in flight, wait for it.
    if (_permissionCompleter != null) {
      final inFlight = _inFlightPermissions ?? const <PermissionType>{};
      // If the caller is asking for a subset of what is already being
      // requested, just await the in-flight result.
      if (permissions.difference(inFlight).isEmpty) {
        return _permissionCompleter!.future;
      }

      // Otherwise, wait for the in-flight request to finish, then request
      // again for the full set. This avoids returning "granted" for a smaller
      // authorization request when the caller needs additional types.
      await _permissionCompleter!.future;
      return requestPermissions(permissions);
    }

    final healthTypes = _mapPermissions(permissions);
    if (healthTypes.isEmpty) return false;

    _permissionCompleter = Completer<bool>();
    _inFlightPermissions = permissions;

    try {
      await _ensureConfigured();

      final defaultPermissions = List<HealthDataAccess>.filled(
        healthTypes.length,
        HealthDataAccess.READ_WRITE,
      );
      final granted = await _health.requestAuthorization(
        healthTypes,
        permissions: defaultPermissions,
      );
      _permissionCompleter!.complete(granted);
      return granted;
    } catch (e) {
      logError('Health permission request error', e);
      _permissionCompleter!.complete(false);
      return false;
    } finally {
      _permissionCompleter = null;
      _inFlightPermissions = null;
    }
  }

  /// Check if health data is available on the platform
  /// Returns true if HealthKit (iOS) or Health Connect (Android) is available
  static Future<bool> isAvailable() async {
    try {
      await _ensureConfigured();
      // The health package will throw if not available, so if we get here, it's available
      return true;
    } catch (e) {
      logDebug('Health data not available: $e');
      return false;
    }
  }

  /// Read health data and convert to WearMetrics in one step.
  ///
  /// On Android the call is throttled to one read per
  /// [_androidMinInterval] (default 10s) to stay under Health
  /// Connect's per-app quota. Throttled calls return `null` quickly
  /// instead of hammering HC and producing
  /// `HealthConnectException: API call quota exceeded` errors.
  /// Pass [bypassThrottle] to override (e.g. user-driven Pull now
  /// after a wipe). iOS HealthKit is not throttled — Apple's API has
  /// no per-app quota.
  static Future<WearMetrics?> readMetrics(
    Set<PermissionType> permissions, {
    DateTime? startTime,
    DateTime? endTime,
    String? deviceId,
    String? source,
    bool bypassThrottle = false,
  }) async {
    if (_shouldThrottleAndroid(bypass: bypassThrottle)) {
      logDebug(
        'HealthAdapter.readMetrics throttled — last read '
        '${DateTime.now().difference(_lastReadAt!).inMilliseconds}ms ago',
      );
      return null;
    }
    final healthTypes = _mapPermissions(permissions);
    if (healthTypes.isEmpty) return null;

    final start =
        startTime ?? DateTime.now().subtract(const Duration(seconds: 2));
    final end = endTime ?? DateTime.now();

    List<HealthDataPoint> dataPoints;
    try {
      await _ensureConfigured();
      dataPoints = await _health.getHealthDataFromTypes(
        startTime: start,
        endTime: end,
        types: healthTypes,
      );
    } catch (e) {
      logError('Health data read error', e);
      return null;
    }

    if (dataPoints.isEmpty) return null;

    final metrics = <String, num?>{};
    final meta = <String, Object?>{};
    final metricTimestamps =
        <String, DateTime>{}; // Track individual metric timestamps

    // Accumulators for summing metrics over the time period
    double stepsSum = 0.0;
    double caloriesSum = 0.0;
    double distanceSum = 0.0; // in meters
    double sleepHoursSum = 0.0;
    // Per-stage sleep accumulators in minutes. When the host has
    // recorded staged data, these populate; otherwise they stay 0
    // and the consumer can fall back to `sleep_hours`.
    double deepSleepMinSum = 0.0;
    double lightSleepMinSum = 0.0;
    double remSleepMinSum = 0.0;
    double awakeMinSum = 0.0;

    // Accumulators for averaging HR and HRV
    double hrSum = 0.0;
    int hrCount = 0;
    double hrvSum = 0.0;
    int hrvCount = 0;
    HealthDataType? hrvType; // Track which HRV type we're averaging
    DateTime? latestTimestamp;

    // Process all data points to sum/add values
    for (final point in dataPoints) {
      // Track the latest timestamp overall
      if (latestTimestamp == null || point.dateTo.isAfter(latestTimestamp)) {
        latestTimestamp = point.dateTo;
      }

      if (point.value is! NumericHealthValue) continue;

      final value = (point.value as NumericHealthValue).numericValue;

      switch (point.type) {
        case HealthDataType.HEART_RATE:
          // Sum all heart rate values for averaging
          hrSum += value;
          hrCount++;
          break;
        case HealthDataType.HEART_RATE_VARIABILITY_SDNN:
        case HealthDataType.HEART_RATE_VARIABILITY_RMSSD:
          // Sum all HRV values for averaging
          hrvSum += value;
          hrvCount++;
          // Track the HRV type (use the first one encountered, or prefer RMSSD)
          if (hrvType == null) {
            hrvType = point.type;
          } else if (point.type ==
              HealthDataType.HEART_RATE_VARIABILITY_RMSSD) {
            hrvType = point.type; // Prefer RMSSD if available
          }
          break;
        case HealthDataType.STEPS:
          // Sum all steps
          stepsSum += value;
          break;
        case HealthDataType.ACTIVE_ENERGY_BURNED:
          // Sum all calories
          caloriesSum += value;
          break;
        case HealthDataType.DISTANCE_WALKING_RUNNING:
          // HealthKit (iOS) uses DISTANCE_WALKING_RUNNING
          distanceSum += value;
          break;
        case HealthDataType.DISTANCE_DELTA:
          // Sum all distance
          // HealthKit/Health Connect typically returns distance in meters
          // But check the unit to be safe and convert if needed
          num distanceInMeters = value;
          final unit = point.unit.toString().toUpperCase();

          // Convert to meters if needed
          if (unit.contains('MILE') || unit.contains('MI')) {
            // Convert miles to meters (1 mile = 1609.34 meters)
            distanceInMeters = value * 1609.34;
          } else if (unit.contains('KM') || unit.contains('KILOMETER')) {
            // Convert km to meters
            distanceInMeters = value * 1000.0;
          } else if (unit.contains('FOOT') || unit.contains('FT')) {
            // Convert feet to meters (1 foot = 0.3048 meters)
            distanceInMeters = value * 0.3048;
          } else if (unit.contains('YARD') || unit.contains('YD')) {
            // Convert yards to meters (1 yard = 0.9144 meters)
            distanceInMeters = value * 0.9144;
          }
          // If already in meters or METER, use as-is

          distanceSum += distanceInMeters;
          break;
        case HealthDataType.SLEEP_ASLEEP:
        case HealthDataType.SLEEP_IN_BED:
          // Sum sleep duration (convert to hours)
          final duration = point.dateTo.difference(point.dateFrom);
          sleepHoursSum += duration.inMinutes / 60.0;
          break;
        case HealthDataType.SLEEP_DEEP:
          deepSleepMinSum += point.dateTo.difference(point.dateFrom).inMinutes;
          break;
        case HealthDataType.SLEEP_LIGHT:
          lightSleepMinSum += point.dateTo.difference(point.dateFrom).inMinutes;
          break;
        case HealthDataType.SLEEP_REM:
          remSleepMinSum += point.dateTo.difference(point.dateFrom).inMinutes;
          break;
        case HealthDataType.SLEEP_AWAKE:
          awakeMinSum += point.dateTo.difference(point.dateFrom).inMinutes;
          break;
        default:
          break;
      }
    }

    // Set the summed metrics
    if (stepsSum > 0) {
      metrics['steps'] = stepsSum;
      metricTimestamps['steps'] = latestTimestamp ?? DateTime.now();
    }
    if (caloriesSum > 0) {
      metrics['calories'] = caloriesSum;
      metricTimestamps['calories'] = latestTimestamp ?? DateTime.now();
    }
    if (distanceSum > 0) {
      metrics['distance'] = distanceSum / 1000.0; // Convert meters to km
      metricTimestamps['distance'] = latestTimestamp ?? DateTime.now();
    } else if (Platform.isAndroid && stepsSum > 0) {
      // Fallback: If no distance data from Health Connect, estimate from steps
      // This is an approximation and may not be accurate for all users
      const averageStepLengthMeters = 0.762; // ~2.5 feet per step
      final estimatedDistanceMeters = stepsSum * averageStepLengthMeters;
      metrics['distance'] = estimatedDistanceMeters / 1000.0; // Convert to km
      metricTimestamps['distance'] = latestTimestamp ?? DateTime.now();
      // Add metadata to indicate this is an estimate
      meta['distance_estimated'] = true;
      meta['distance_estimation_method'] = 'steps_based';
    }
    // If the host recorded per-stage sleep, prefer that as the
    // "total asleep" denominator (deep + light + rem). Otherwise
    // fall back to whatever SLEEP_ASLEEP / SLEEP_IN_BED reported.
    final stageTotalMin = deepSleepMinSum + lightSleepMinSum + remSleepMinSum;
    if (stageTotalMin > 0) {
      metrics['sleep_hours'] = stageTotalMin / 60.0;
      metricTimestamps['sleep_hours'] = latestTimestamp ?? DateTime.now();
    } else if (sleepHoursSum > 0) {
      metrics['sleep_hours'] = sleepHoursSum;
      metricTimestamps['sleep_hours'] = latestTimestamp ?? DateTime.now();
    }
    if (deepSleepMinSum > 0) {
      metrics['deep_sleep_minutes'] = deepSleepMinSum;
      metricTimestamps['deep_sleep_minutes'] =
          latestTimestamp ?? DateTime.now();
    }
    if (lightSleepMinSum > 0) {
      metrics['light_sleep_minutes'] = lightSleepMinSum;
      metricTimestamps['light_sleep_minutes'] =
          latestTimestamp ?? DateTime.now();
    }
    if (remSleepMinSum > 0) {
      metrics['rem_sleep_minutes'] = remSleepMinSum;
      metricTimestamps['rem_sleep_minutes'] = latestTimestamp ?? DateTime.now();
    }
    if (awakeMinSum > 0) {
      metrics['awake_minutes'] = awakeMinSum;
      metricTimestamps['awake_minutes'] = latestTimestamp ?? DateTime.now();
    }

    // Set the averaged heart rate
    if (hrCount > 0) {
      final avgHR = hrSum / hrCount;
      metrics['hr'] = avgHR;
      metricTimestamps['hr'] = latestTimestamp ?? DateTime.now();
    }

    // Set the averaged HRV
    if (hrvCount > 0 && hrvType != null) {
      final avgHRV = hrvSum / hrvCount;
      if (hrvType == HealthDataType.HEART_RATE_VARIABILITY_RMSSD) {
        metrics['hrv_rmssd'] = avgHRV;
        metrics['hrv_sdnn'] = avgHRV; // Also store as SDNN for compatibility
        metricTimestamps['hrv_rmssd'] = latestTimestamp ?? DateTime.now();
        metricTimestamps['hrv_sdnn'] = latestTimestamp ?? DateTime.now();
      } else {
        metrics['hrv_sdnn'] = avgHRV;
        metrics['hrv_rmssd'] = avgHRV; // Also store as RMSSD for compatibility
        metricTimestamps['hrv_sdnn'] = latestTimestamp ?? DateTime.now();
        metricTimestamps['hrv_rmssd'] = latestTimestamp ?? DateTime.now();
      }
    }

    // Get the most recent data point overall for main timestamp
    final latestPoint = latestTimestamp ?? dataPoints.first.dateTo;

    // Add metadata
    meta['source'] = source ?? 'health_package';
    meta['data_points_count'] = dataPoints.length;
    meta['summed'] = true; // Steps, calories, distance, sleep are summed
    meta['averaged'] = true; // HR and HRV are averaged
    if (hrCount > 0) meta['hr_data_points'] = hrCount;
    if (hrvCount > 0) meta['hrv_data_points'] = hrvCount;
    meta['synced'] = true;
    // Store individual metric timestamps in metadata
    meta['metric_timestamps'] = metricTimestamps.map(
      (key, value) => MapEntry(key, value.toIso8601String()),
    );

    // Stamp the throttle clock only after a successful read so that
    // failed/empty reads don't lock callers out for the full
    // `_androidMinInterval`.
    if (Platform.isAndroid) _lastReadAt = DateTime.now();

    return WearMetrics(
      timestamp: latestPoint,
      deviceId: deviceId ?? 'health_${DateTime.now().millisecondsSinceEpoch}',
      source: source ?? 'health_package',
      metrics: metrics,
      meta: meta,
    );
  }

  /// Get permission status for specific types (v13.2.1 feature)
  /// Returns a map of permission types to their granted status
  static Future<Map<PermissionType, bool>> getPermissionStatus(
    Set<PermissionType> permissions,
  ) async {
    final results = <PermissionType, bool>{};

    try {
      await _ensureConfigured();

      // Create a map of permission to health type for accurate checking
      final permissionToHealthType = <PermissionType, HealthDataType>{};
      for (final permission in permissions) {
        final healthTypes = _mapPermissions({permission});
        if (healthTypes.isNotEmpty) {
          permissionToHealthType[permission] = healthTypes.first;
        }
      }

      // Check permissions for each mapped type
      for (final entry in permissionToHealthType.entries) {
        try {
          final hasPermission = await _health.hasPermissions([entry.value]);
          results[entry.key] = hasPermission ?? false;
        } catch (e) {
          logWarning('Error checking permission for ${entry.key}', e);
          results[entry.key] = false;
        }
      }

      // Mark unmapped permissions (like stress) as false
      for (final permission in permissions) {
        if (!results.containsKey(permission)) {
          results[permission] = false;
        }
      }
    } catch (e) {
      logError('Error getting permission status', e);
      // Mark all as false on error
      for (final permission in permissions) {
        results[permission] = false;
      }
    }

    return results;
  }

  /// Per-night sleep summary, used by hosts that want to bucket
  /// stage durations by calendar day without paying the per-day API
  /// cost of [readMetrics] in a loop.
  ///
  /// Health Connect throttles reads at ~1 call/sec/type — looping
  /// `readMetrics` over 7 days for 5 sleep types blew the quota in
  /// our pulse-focus integration. This method issues a single
  /// multi-day query per type (Health Connect is happy with that)
  /// and groups the resulting points by the calendar day the
  /// sleep session ended on.
  ///
  /// Returned map keys are local-time day-anchors (midnight) for
  /// the sleep session's end. Values are minutes — `total` is the
  /// asleep total (deep+light+rem when stages exist, else
  /// SLEEP_ASLEEP/SLEEP_IN_BED).
  static Future<Map<DateTime, SleepNightSummary>> fetchSleepNights({
    required DateTime start,
    required DateTime end,
    bool bypassThrottle = false,
  }) async {
    if (_shouldThrottleAndroid(bypass: bypassThrottle)) {
      logDebug('HealthAdapter.fetchSleepNights throttled');
      return const {};
    }
    await _ensureConfigured();
    final types = _mapPermissions({PermissionType.sleep});
    if (types.isEmpty) return const {};

    List<HealthDataPoint> points;
    try {
      points = await _health.getHealthDataFromTypes(
        startTime: start,
        endTime: end,
        types: types,
      );
    } catch (e) {
      logError('fetchSleepNights read failed', e);
      return const {};
    }
    if (Platform.isAndroid) _lastReadAt = DateTime.now();

    final out = <DateTime, _SleepAcc>{};
    DateTime dayKey(DateTime t) {
      final l = t.toLocal();
      return DateTime(l.year, l.month, l.day);
    }

    for (final p in points) {
      final mins = p.dateTo.difference(p.dateFrom).inMinutes.toDouble();
      if (mins <= 0) continue;
      final key = dayKey(p.dateTo);
      final acc = out.putIfAbsent(key, _SleepAcc.new);
      switch (p.type) {
        case HealthDataType.SLEEP_ASLEEP:
        case HealthDataType.SLEEP_IN_BED:
          acc.totalFallback += mins;
          break;
        case HealthDataType.SLEEP_DEEP:
          acc.deep += mins;
          break;
        case HealthDataType.SLEEP_LIGHT:
          acc.light += mins;
          break;
        case HealthDataType.SLEEP_REM:
          acc.rem += mins;
          break;
        case HealthDataType.SLEEP_AWAKE:
          acc.awake += mins;
          break;
        default:
          break;
      }
    }

    return out.map((day, acc) {
      final stageTotal = acc.deep + acc.light + acc.rem;
      final total = stageTotal > 0 ? stageTotal : acc.totalFallback;
      return MapEntry(
        day,
        SleepNightSummary(
          totalAsleepMinutes: total,
          deepMinutes: acc.deep > 0 ? acc.deep : null,
          lightMinutes: acc.light > 0 ? acc.light : null,
          remMinutes: acc.rem > 0 ? acc.rem : null,
          awakeMinutes: acc.awake,
        ),
      );
    });
  }

  /// Per-night overnight physiology summary, used alongside
  /// [fetchSleepNights] to attach HRV / resting HR to the matching
  /// sleep ingest. Returns one entry per local-time day-anchor where
  /// at least one of HRV (RMSSD/SDNN) or resting HR was sampled.
  ///
  /// The platform-aware logic mirrors [readMetrics]: Apple Health
  /// exposes RMSSD natively and we fall back to SDNN; Health Connect
  /// only ships SDNN today and we surface the value as-if-RMSSD so
  /// downstream consumers don't have to special-case it.
  ///
  /// Both numbers are aggregated as the nightly median to suppress
  /// outlier samples (a single 200ms RR misread can blow up a mean).
  static Future<Map<DateTime, OvernightPhysiologySummary>>
  fetchOvernightPhysiology({
    required DateTime start,
    required DateTime end,
    bool bypassThrottle = false,
  }) async {
    if (_shouldThrottleAndroid(bypass: bypassThrottle)) {
      logDebug('HealthAdapter.fetchOvernightPhysiology throttled');
      return const {};
    }
    await _ensureConfigured();

    // HealthKit (iOS) exposes HRV under SDNN only — `RMSSD` is the
    // Android Health Connect path. Picking the wrong one here returns
    // `Not available on platform` and `fetchOvernightPhysiology` ends
    // up empty, which keeps Recovery / Readiness cards hidden.
    final types = <HealthDataType>[
      HealthDataType.HEART_RATE,
      if (Platform.isIOS)
        HealthDataType.HEART_RATE_VARIABILITY_SDNN
      else
        HealthDataType.HEART_RATE_VARIABILITY_RMSSD,
      // RestingHeartRate is iOS-only on the `health` package today;
      // Health Connect doesn't expose a stable type for it. We still
      // request it; if absent the fallback below derives it from the
      // overnight HR samples.
      if (Platform.isIOS) HealthDataType.RESTING_HEART_RATE,
      // Daily step total — feeds the engine's `motion.steps_est`
      // baseline. Available on both platforms.
      HealthDataType.STEPS,
    ];
    List<HealthDataPoint> points;
    try {
      points = await _health.getHealthDataFromTypes(
        startTime: start,
        endTime: end,
        types: types,
      );
    } catch (e) {
      logError('fetchOvernightPhysiology read failed', e);
      return const {};
    }
    if (Platform.isAndroid) _lastReadAt = DateTime.now();

    DateTime dayKey(DateTime t) {
      final l = t.toLocal();
      return DateTime(l.year, l.month, l.day);
    }

    final hrvByDay = <DateTime, List<double>>{};
    final rhrByDay = <DateTime, List<double>>{};
    final hrByDay = <DateTime, List<double>>{};
    final stepsByDay = <DateTime, double>{};

    for (final p in points) {
      final v = p.value;
      double? n;
      if (v is NumericHealthValue) {
        n = v.numericValue.toDouble();
      }
      if (n == null || n <= 0) continue;
      // Anchor every sample on its local-day key. Overnight samples
      // typically straddle midnight; using `dateTo` keeps the night
      // attached to the wake day, matching `fetchSleepNights`.
      final key = dayKey(p.dateTo);
      switch (p.type) {
        case HealthDataType.HEART_RATE_VARIABILITY_RMSSD:
        case HealthDataType.HEART_RATE_VARIABILITY_SDNN:
          hrvByDay.putIfAbsent(key, () => <double>[]).add(n);
          break;
        case HealthDataType.RESTING_HEART_RATE:
          rhrByDay.putIfAbsent(key, () => <double>[]).add(n);
          break;
        case HealthDataType.HEART_RATE:
          hrByDay.putIfAbsent(key, () => <double>[]).add(n);
          break;
        case HealthDataType.STEPS:
          // Steps are cumulative bucketed samples — sum, don't median.
          // Both HealthKit and Health Connect chunk the day into many
          // small intervals; we want the day total.
          stepsByDay[key] = (stepsByDay[key] ?? 0.0) + n;
          break;
        default:
          break;
      }
    }

    double? medianOf(List<double>? xs) {
      if (xs == null || xs.isEmpty) return null;
      final s = [...xs]..sort();
      final mid = s.length ~/ 2;
      return s.length.isOdd ? s[mid] : (s[mid - 1] + s[mid]) / 2.0;
    }

    /// Population std-dev of HR samples in bpm. Returns null when the
    /// sample count is below 30 (one full minute at 1Hz, not enough
    /// to estimate variance reliably).
    double? hrStdOf(List<double>? xs) {
      if (xs == null || xs.length < 30) return null;
      final mean = xs.reduce((a, b) => a + b) / xs.length;
      var sq = 0.0;
      for (final x in xs) {
        final d = x - mean;
        sq += d * d;
      }
      final variance = sq / xs.length;
      if (variance <= 0) return null;
      return math.sqrt(variance);
    }

    final allDays = <DateTime>{
      ...hrvByDay.keys,
      ...rhrByDay.keys,
      ...hrByDay.keys,
      ...stepsByDay.keys,
    };
    final out = <DateTime, OvernightPhysiologySummary>{};
    for (final day in allDays) {
      final hrv = medianOf(hrvByDay[day]);
      // Prefer a real RestingHeartRate sample; otherwise the median
      // of overnight HR samples is a reasonable proxy on platforms
      // that don't surface RHR natively.
      final rhr = medianOf(rhrByDay[day]) ?? medianOf(hrByDay[day]);
      // Std-bpm of the day's HR trace — feeds the engine's
      // `hrv.hr_std_bpm` baseline. Coarser sibling to RMSSD/SDNN that
      // works from a 1Hz HR trace alone.
      final hrStd = hrStdOf(hrByDay[day]);
      final steps = stepsByDay[day];
      if (hrv == null && rhr == null && hrStd == null && steps == null) {
        continue;
      }
      // iOS HealthKit only ships HRV under HKHeartRateVariabilitySDNN
      // (see the type-list selection above). Surface it explicitly
      // under `hrvSdnnMs` so the SDK can warm the engine's
      // `hrv.sdnn_ms` baseline without losing the legacy mapping that
      // also feeds `hrv.rmssd_ms` from the same sample (Recovery
      // formula reads RMSSD; the iOS sample is a close enough proxy
      // for short windows). On Android, Health Connect ships true
      // RMSSD — leave SDNN null so we don't mislabel it.
      final sdnn = Platform.isIOS ? hrv : null;
      out[day] = OvernightPhysiologySummary(
        hrvRmssdMs: hrv,
        hrvSdnnMs: sdnn,
        hrStdBpm: hrStd,
        stepsCount: steps,
        restingHrBpm: rhr,
      );
    }
    return out;
  }
}

/// Aggregate overnight physiology for one calendar day, derived from
/// HealthKit / Health Connect samples. Any field may be null when the
/// underlying samples aren't available.
///
/// `hrvRmssdMs` and `hrvSdnnMs` are populated independently:
///   * iOS HealthKit only ships SDNN — both fields carry the same
///     value (legacy mapping for downstream Recovery + new mapping
///     for the SDNN baseline).
///   * Android Health Connect ships RMSSD — `hrvRmssdMs` is set,
///     `hrvSdnnMs` stays null.
///
/// `hrStdBpm` is the population std-dev of the day's HR trace (works
/// from 1Hz samples; no beat-to-beat RR required). `stepsCount` is
/// the daily total. Both feed kinematic/HRV baselines that previously
/// only warmed during live wear sessions.
class OvernightPhysiologySummary {
  final double? hrvRmssdMs;
  final double? hrvSdnnMs;
  final double? hrStdBpm;
  final double? stepsCount;
  final double? restingHrBpm;
  const OvernightPhysiologySummary({
    this.hrvRmssdMs,
    this.hrvSdnnMs,
    this.hrStdBpm,
    this.stepsCount,
    this.restingHrBpm,
  });
}

/// Per-night sleep summary returned by [HealthAdapter.fetchSleepNights].
/// Stage minutes are nullable: present only when the host writer
/// recorded staged data (Samsung Health on Pixel does, Google Fit
/// usually doesn't).
class SleepNightSummary {
  final double totalAsleepMinutes;
  final double? deepMinutes;
  final double? lightMinutes;
  final double? remMinutes;
  final double awakeMinutes;

  const SleepNightSummary({
    required this.totalAsleepMinutes,
    this.deepMinutes,
    this.lightMinutes,
    this.remMinutes,
    required this.awakeMinutes,
  });
}

/// Mutable accumulator used while bucketing sleep data points by day.
class _SleepAcc {
  double deep = 0;
  double light = 0;
  double rem = 0;
  double awake = 0;
  double totalFallback = 0;
}
