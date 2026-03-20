import '../core/models.dart';
import '../core/consent_manager.dart';

/// Abstract base class for wearable device adapters
///
/// Implement this interface to add support for new wearable devices or
/// health data sources. Each adapter handles device-specific communication
/// and data normalization.
abstract class WearAdapter {
  /// Unique identifier for this adapter (e.g., 'apple_healthkit', 'fitbit')
  String get id;

  /// Set of permission types this adapter supports
  Set<PermissionType> get supportedPermissions;

  /// Get permissions that are actually supported on the current platform
  ///
  /// Default implementation returns all [supportedPermissions].
  /// Override in adapters that have platform-specific limitations.
  Set<PermissionType> getPlatformSupportedPermissions() {
    return supportedPermissions;
  }

  /// Read a snapshot of health metrics from the device
  ///
  /// [isRealTime] - If true, attempts to get the most recent real-time data
  /// [startTime] - Optional start time for historical data range
  /// [endTime] - Optional end time for historical data range
  ///
  /// Returns [WearMetrics] if data is available, null otherwise.
  Future<WearMetrics?> readSnapshot({
    bool isRealTime = true,
    DateTime? startTime,
    DateTime? endTime,
  });
}
