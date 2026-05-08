import '../adapters/health_adapter.dart';
import '../core/models.dart';
import 'logger.dart';

/// Consent status for data access permissions
enum ConsentStatus {
  /// Permission has not been requested yet
  notRequested,

  /// Permission has been granted by the user
  granted,

  /// Permission has been denied by the user
  denied,

  /// Permission was previously granted but has been revoked
  revoked,
}

/// Permission types for different health data access levels
enum PermissionType {
  /// Heart rate data (beats per minute)
  heartRate,

  /// Heart rate variability data (RMSSD or SDNN)
  heartRateVariability,

  /// Step count data
  steps,

  /// Calories burned data
  calories,

  /// Distance traveled data (kilometers)
  distance,

  /// Sleep data
  sleep,

  /// Stress level data
  stress,

  /// All available permissions
  all,
}

/// Consent management for wearable data access
class ConsentManager {
  static final Map<PermissionType, ConsentStatus> _permissions = {};
  static final Map<String, DateTime> _consentTimestamps = {};

  /// Request consent for specific permission types
  ///
  /// If all requested permissions are already granted (from a prior call),
  /// returns the cached status without triggering another native dialog.
  static Future<Map<PermissionType, ConsentStatus>> requestConsent(
    Set<PermissionType> permissions, {
    String? reason,
  }) async {
    final results = <PermissionType, ConsentStatus>{};

    // Short-circuit: if every requested permission is already granted, skip
    // the native dialog to avoid duplicate HealthKit authorization prompts.
    //
    // Only short-circuit if those cached grants are still "valid" according
    // to our expiry policy. Otherwise, fall through and refresh the platform
    // authorization call (which typically won't re-prompt if already granted)
    // and refresh timestamps.
    final allAlreadyGranted = permissions.every((p) {
      return _permissions[p] == ConsentStatus.granted && isConsentValid(p);
    });
    if (allAlreadyGranted) {
      for (final permission in permissions) {
        results[permission] = ConsentStatus.granted;
      }
      return results;
    }

    try {
      // Use health package for real permission requests
      final granted = await HealthAdapter.requestPermissions(permissions);

      for (final permission in permissions) {
        final status = granted ? ConsentStatus.granted : ConsentStatus.denied;
        _permissions[permission] = status;
        _consentTimestamps[permission.name] = DateTime.now();
        results[permission] = status;
      }
    } catch (e) {
      // Handle errors by marking all permissions as denied
      for (final permission in permissions) {
        _permissions[permission] = ConsentStatus.denied;
        results[permission] = ConsentStatus.denied;
      }
    }

    return results;
  }

  /// Check if consent is granted for specific permission
  static bool hasConsent(PermissionType permission) {
    return _permissions[permission] == ConsentStatus.granted ||
        _permissions[PermissionType.all] == ConsentStatus.granted;
  }

  /// Check if consent is granted for any of the specified permissions
  static bool hasAnyConsent(Set<PermissionType> permissions) {
    return permissions.any((p) => hasConsent(p));
  }

  /// Revoke consent for specific permission
  static Future<void> revokeConsent(PermissionType permission) async {
    _permissions[permission] = ConsentStatus.revoked;
    _consentTimestamps.remove(permission.name);
  }

  /// Revoke all consents
  static Future<void> revokeAllConsents() async {
    for (final permission in _permissions.keys) {
      await revokeConsent(permission);
    }
  }

  /// Get consent status for all permissions
  static Map<PermissionType, ConsentStatus> getAllConsents() {
    return Map.from(_permissions);
  }

  /// Sync consent status with actual platform permissions
  /// This checks the real permission status from the health package
  static Future<Map<PermissionType, ConsentStatus>> syncWithPlatform(
    Set<PermissionType> permissions,
  ) async {
    try {
      final platformStatus = await HealthAdapter.getPermissionStatus(
        permissions,
      );
      final results = <PermissionType, ConsentStatus>{};

      for (final entry in platformStatus.entries) {
        final status = entry.value
            ? ConsentStatus.granted
            : ConsentStatus.denied;
        _permissions[entry.key] = status;
        if (entry.value) {
          _consentTimestamps[entry.key.name] = DateTime.now();
        }
        results[entry.key] = status;
      }

      return results;
    } catch (e) {
      logError('Error syncing with platform', e);
      return {};
    }
  }

  /// Get consent timestamp for a permission
  static DateTime? getConsentTimestamp(PermissionType permission) {
    return _consentTimestamps[permission.name];
  }

  /// Check if consent is still valid (not expired)
  static bool isConsentValid(PermissionType permission) {
    final timestamp = getConsentTimestamp(permission);
    if (timestamp == null) return false;

    // Consent expires after 30 days
    final expiry = timestamp.add(const Duration(days: 30));
    return DateTime.now().isBefore(expiry);
  }

  /// Validate that required consents are in place before data collection
  /// Only validates permissions that were actually requested and granted
  static void validateConsents(Set<PermissionType> requiredPermissions) {
    final missingConsents = <PermissionType>[];

    for (final permission in requiredPermissions) {
      // Only validate if we have a consent status for this permission
      // AND the consent is granted. This handles cases where:
      // 1. Permissions weren't requested (e.g., HRV on Android) - skip validation
      // 2. Permissions were requested but denied - include in missing consents
      if (_permissions.containsKey(permission)) {
        if (!hasConsent(permission) || !isConsentValid(permission)) {
          missingConsents.add(permission);
        }
      }
      // If permission is not in _permissions, it means it wasn't requested
      // (e.g., HRV on Android), so we skip validation for it
    }

    if (missingConsents.isNotEmpty) {
      throw PermissionDeniedError(
        'Missing or expired consents for: ${missingConsents.map((p) => p.name).join(', ')}',
      );
    }
  }
}
