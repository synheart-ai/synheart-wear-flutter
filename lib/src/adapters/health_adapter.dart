import 'dart:async';
import 'package:health/health.dart';
import '../core/consent_manager.dart';
import '../core/models.dart';
import '../core/logger.dart';
import 'dart:io';

/// Adapter for the health package to handle HealthKit and Health Connect integration
/// Supports health package v13.2.1 API
class HealthAdapter {
  static final Health _health = Health();
  static bool _configured = false;
  // Serializes concurrent requestAuthorization calls to prevent duplicate
  // HealthKit dialogs (iOS crashes when two present simultaneously).
  static Completer<bool>? _permissionCompleter;
  static Set<PermissionType>? _inFlightPermissions;

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
          healthTypes.add(HealthDataType.SLEEP_IN_BED);
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
            HealthDataType.SLEEP_IN_BED,
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

  /// Read health data and convert to WearMetrics in one step
  static Future<WearMetrics?> readMetrics(
    Set<PermissionType> permissions, {
    DateTime? startTime,
    DateTime? endTime,
    String? deviceId,
    String? source,
  }) async {
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
        case HealthDataType.SLEEP_IN_BED:
          // Sum sleep duration (convert to hours)
          final duration = point.dateTo.difference(point.dateFrom);
          sleepHoursSum += duration.inMinutes / 60.0;
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
    if (sleepHoursSum > 0) {
      metrics['sleep_hours'] = sleepHoursSum;
      metricTimestamps['sleep_hours'] = latestTimestamp ?? DateTime.now();
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
}
