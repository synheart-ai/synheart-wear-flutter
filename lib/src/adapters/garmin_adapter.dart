import '../core/consent_manager.dart';
import '../core/models.dart';
import '../sources/garmin_cloud.dart';
import 'wear_adapter.dart';

/// Adapter for Garmin devices via Garmin Health API
///
/// Connects to Garmin Cloud via backend connector service.
/// OAuth authentication is handled separately by [GarminProvider].
/// Supports heart rate, HRV, steps, calories, distance, and stress metrics.
class GarminAdapter implements WearAdapter {
  final GarminProvider _provider;

  /// Create a GarminAdapter with an optional [GarminProvider].
  ///
  /// If no provider is given, a default [GarminProvider] is created internally.
  GarminAdapter({GarminProvider? provider})
      : _provider = provider ?? GarminProvider(loadFromStorage: false);

  /// Direct access to the underlying [GarminProvider] for OAuth, backfill, etc.
  GarminProvider get provider => _provider;

  @override
  String get id => 'garmin';

  @override
  Set<PermissionType> get supportedPermissions => const {
    PermissionType.heartRate,
    PermissionType.heartRateVariability,
    PermissionType.steps,
    PermissionType.calories,
    PermissionType.distance,
    PermissionType.stress,
  };

  @override
  Set<PermissionType> getPlatformSupportedPermissions() {
    // Garmin supports all its declared permissions on all platforms
    return supportedPermissions;
  }

  @override
  Future<WearMetrics?> readSnapshot({
    bool isRealTime = false,
    DateTime? startTime,
    DateTime? endTime,
  }) async {
    // Cannot fetch data without a connected user
    if (_provider.userId == null) {
      return null;
    }

    try {
      final dailies = await _provider.fetchDailies(
        start: startTime,
        end: endTime,
      );

      if (dailies.isEmpty) {
        return null;
      }

      // Return the most recent daily summary
      return dailies.last;
    } catch (e) {
      // Return null if data is unavailable (network error, stale data, etc.)
      return null;
    }
  }
}
