import 'dart:io';
import '../../synheart_wear.dart';
import 'wear_adapter.dart';

/// Adapter for Apple HealthKit (iOS) and Health Connect (Android)
///
/// Provides unified access to health data on both platforms:
/// - iOS: Uses HealthKit API for all metrics including RR intervals
/// - Android: Uses Health Connect API (supports HRV via RMSSD, distance via DELTA)
///
/// Supports heart rate, HRV, steps, calories, and distance metrics.
class AppleHealthKitAdapter implements WearAdapter {
  @override
  String get id => 'apple_healthkit';

  @override
  Set<PermissionType> get supportedPermissions => const {
    PermissionType.heartRate,
    PermissionType.heartRateVariability,
    PermissionType.steps,
    PermissionType.calories,
    PermissionType.distance,
  };

  /// Get permissions that are actually supported on the current platform
  Set<PermissionType> get _platformSupportedPermissions {
    return getPlatformSupportedPermissions();
  }

  @override
  Set<PermissionType> getPlatformSupportedPermissions() {
    if (Platform.isAndroid) {
      // Health Connect uses DISTANCE_DELTA instead of DISTANCE_WALKING_RUNNING
      return {
        PermissionType.heartRate,
        PermissionType.heartRateVariability, // RMSSD on Android
        PermissionType.steps,
        PermissionType.calories,
        PermissionType.distance, // Uses DISTANCE_DELTA on Android
      };
    } else {
      // iOS HealthKit supports all including distance
      return supportedPermissions;
    }
  }

  @override
  Future<WearMetrics?> readSnapshot({
    bool isRealTime = true,
    DateTime? startTime,
    DateTime? endTime,
  }) async {
    // Health Connect (Android) is a sync store, not a real-time
    // signal source. Polling it on the wear streaming timer cadence
    // (every 1–5 s during a game session) blows through Android's
    // per-app quota and produces stale data anyway — the platform
    // batches writes from Samsung Health / Pixel / etc with
    // seconds-to-minutes of latency.
    //
    // On Android we therefore decline `isRealTime: true` requests
    // entirely. Live HR for game sessions flows from BLE HRM /
    // vendor streams (the right real-time sources). HC remains
    // available for explicit on-demand reads — `isRealTime: false`
    // (Baselines pull, ambient snapshots) is honored normally.
    //
    // iOS HealthKit DOES deliver near-real-time samples from Apple
    // Watch and isn't quota-constrained, so the short-circuit only
    // applies to Android.
    if (Platform.isAndroid && isRealTime) {
      return null;
    }
    try {
      // Use provided time range or default to last 30 days
      final effectiveStartTime =
          startTime ?? DateTime.now().subtract(const Duration(days: 30));
      final effectiveEndTime = endTime ?? DateTime.now();

      // Read data and convert to WearMetrics in one step
      // Use platform-specific permissions (exclude HRV on Android)
      final metrics = await HealthAdapter.readMetrics(
        _platformSupportedPermissions,
        startTime: effectiveStartTime,
        endTime: effectiveEndTime,
        deviceId: 'applewatch_${DateTime.now().millisecondsSinceEpoch}',
        source: id,
      );

      if (metrics != null) {
        // Attempt to enrich with RR intervals via HealthKit heartbeat series (iOS only)
        if (Platform.isIOS) {
          try {
            final rr = await HealthKitRRChannel.fetchHeartbeatSeries(
              start: DateTime.now().subtract(const Duration(minutes: 30)),
              end: DateTime.now(),
            );
            if (rr.isNotEmpty) {
              return WearMetrics(
                timestamp: metrics.timestamp,
                deviceId: metrics.deviceId,
                source: metrics.source,
                metrics: metrics.metrics,
                meta: metrics.meta,
                rrIntervalsMs: rr,
              );
            }
          } catch (e) {
            // RR intervals are optional, continue without them
            logger.debug('Could not fetch RR intervals: $e');
          }
        }
      }

      return metrics;
    } catch (e) {
      logger.error('HealthKit read error', e);
      return null;
    }
  }
}
