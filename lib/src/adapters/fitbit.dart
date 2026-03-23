import '../core/consent_manager.dart';
import '../core/models.dart';
import 'wear_adapter.dart';

/// Adapter for Fitbit devices via Fitbit Web API
///
/// Supports heart rate, steps, and calories metrics.
/// Requires OAuth 2.0 authentication (implementation in progress).
class FitbitAdapter implements WearAdapter {
  @override
  String get id => 'fitbit';

  @override
  Set<PermissionType> get supportedPermissions => const {
    PermissionType.heartRate,
    PermissionType.steps,
    PermissionType.calories,
  };

  @override
  Set<PermissionType> getPlatformSupportedPermissions() {
    // Fitbit supports all its declared permissions on all platforms
    return supportedPermissions;
  }

  @override
  Future<WearMetrics?> readSnapshot({
    bool isRealTime = false,
    DateTime? startTime,
    DateTime? endTime,
  }) async {
    // TODO: Fitbit Web API call.
    return null; // if unavailable
  }
}
