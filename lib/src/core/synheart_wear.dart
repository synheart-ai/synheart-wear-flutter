import 'dart:async';
import 'package:flutter/foundation.dart';

import '../adapters/wear_adapter.dart';
import 'models.dart';
import '../normalization/normalizer.dart';
import '../adapters/apple_healthkit.dart';
import '../adapters/garmin/garmin_health.dart';
import 'config.dart';
import 'consent_manager.dart';
import 'local_cache.dart';
import 'logger.dart';

/// Main SynheartWear SDK class implementing RFC specifications
class SynheartWear {
  bool _initialized = false;
  final SynheartWearConfig config;
  final Normalizer _normalizer;
  StreamController<WearMetrics>? _hrStreamController;
  StreamController<WearMetrics>? _hrvStreamController;
  Timer? _streamTimer;

  final Map<DeviceAdapter, WearAdapter> _adapterRegistry;

  Timer? _hrvTimer; // Separate timer for HRV

  GarminHealth? _garminHealth;

  SynheartWear({
    SynheartWearConfig? config,
    Map<DeviceAdapter, WearAdapter>? adapters,
    GarminHealth? garminHealth,
  }) : config = config ?? const SynheartWearConfig(),
       _normalizer = Normalizer(),
       _garminHealth = garminHealth,
       _adapterRegistry =
           adapters ??
           {
             // Cloud-based vendor providers (Fitbit, Whoop, Oura) are
             // configured separately via their `*Provider` classes; only
             // direct-device adapters are registered here by default.
             DeviceAdapter.platformHealth: AppleHealthKitAdapter(),
           } {
    // Register GarminHealth adapter if provided
    if (_garminHealth != null) {
      _adapterRegistry[DeviceAdapter.garmin] = _garminHealth!.adapter;
    }
  }

  /// Access the Garmin Health facade for device-specific operations
  ///
  /// Returns null if GarminHealth was not configured.
  GarminHealth? get garminHealth => _garminHealth;

  /// Initialize the SDK with permissions and setup
  ///
  /// This method will:
  /// 1. Request necessary permissions
  /// 2. Initialize adapters
  /// 3. Fetch and validate actual wearable data
  /// 4. Verify data is not empty and not stale
  ///
  /// Throws [SynheartWearError] if:
  /// - Permissions are denied
  /// - No wearable data is available
  /// - Latest data is stale (older than 24 hours)
  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    try {
      // Request necessary permissions (single call — handles all types)
      await _requestPermissions();

      final testData = <WearMetrics?>[];
      for (final adapter in _enabledAdapters()) {
        try {
          // Try to fetch recent data (last 7 days)
          final data = await adapter.readSnapshot(
            isRealTime: false,
            startTime: DateTime.now().subtract(const Duration(days: 7)),
            endTime: DateTime.now(),
          );
          if (data == null) {
            logDebug(
              'Initialization: ${adapter.id} returned no recent data snapshot.',
            );
          } else {
            logDebug(
              'Initialization: ${adapter.id} returned snapshot at ${data.timestamp.toIso8601String()}.',
            );
          }

          testData.add(data);
        } catch (e) {
          // Log warning but continue checking other adapters
          logWarning('Initialization: ${adapter.id} snapshot check failed', e);
        }
      }

      // Merge and validate the test data

      final mergedTestData = _normalizer.mergeSnapshots(testData);

      // Check if data is empty

      if (!mergedTestData.hasValidData || mergedTestData.metrics.isEmpty) {
        // if (mergedTestData.hasValidData || mergedTestData.metrics.isNotEmpty) {
        throw SynheartWearError(
          'No wearable data available. Please check if your wearable device is connected and syncing data.',
          code: 'NO_WEARABLE_DATA',
        );
      }

      // Check if data is stale (older than 24 hours)
      final dataAge = DateTime.now().difference(mergedTestData.timestamp);
      const maxStaleAge = Duration(
        hours: 24,
      ); // Stricter threshold for initialization

      // Handle timezone differences (data timestamp might be slightly in the future)
      final isFutureData = dataAge.isNegative;
      final absoluteAge = isFutureData ? -dataAge : dataAge;

      if (isFutureData) {
        logDebug(
          'Initialization: latest data timestamp is in the future by ${absoluteAge.inSeconds}s; treating age as absolute.',
        );
      }

      if (absoluteAge > maxStaleAge) {
        throw SynheartWearError(
          'Latest data is stale (${absoluteAge.inHours} hours old). Please check if your wearable device is connected to get latest data.',
          code: 'STALE_DATA',
        );
      }

      _initialized = true;
    } catch (e) {
      if (e is SynheartWearError) rethrow;
      throw SynheartWearError('Failed to initialize SynheartWear: $e');
    }
  }

  /// Read current metrics from all enabled adapters
  Future<WearMetrics> readMetrics({
    bool isRealTime = false,
    DateTime? startTime,
    DateTime? endTime,
  }) async {
    if (!_initialized) {
      await initialize();
    }

    try {
      // Validate consents
      ConsentManager.validateConsents(_getRequiredPermissions());

      // Gather data from enabled adapters
      final adapterData = <WearMetrics?>[];
      for (final adapter in _enabledAdapters()) {
        try {
          final data = await adapter.readSnapshot(
            isRealTime: isRealTime,
            startTime: startTime,
            endTime: endTime,
          );
          adapterData.add(data);
        } catch (e) {
          // Keep non-fatal, tag by adapter id
          logWarning('${adapter.id} adapter error', e);
        }
      }

      // Normalize and merge data
      final mergedData = _normalizer.mergeSnapshots(adapterData);

      // Validate data quality
      // Note: Data availability is validated during initialize(), but empty data
      // may still occur if device disconnects after initialization
      if (mergedData.metrics.isNotEmpty &&
          !_normalizer.validateMetrics(mergedData)) {
        throw SynheartWearError('Invalid metrics data received');
      }

      // If no data is available, return empty metrics
      // This may occur if device disconnected after initialization

      // Cache data if enabled
      if (config.enableLocalCaching) {
        await LocalCache.storeSession(
          mergedData,
          enableEncryption: config.enableEncryption,
        );
      }

      return mergedData;
    } catch (e) {
      if (e is SynheartWearError) rethrow;
      throw SynheartWearError('Failed to read metrics: $e');
    }
  }

  /// Stream real-time heart rate data
  Stream<WearMetrics> streamHR({Duration? interval}) {
    final actualInterval = interval ?? config.streamInterval;

    _hrStreamController ??= StreamController<WearMetrics>.broadcast();

    // Start timer when first listener subscribes
    if (!_hrStreamController!.hasListener) {
      _startStreaming(actualInterval);
    }

    return _hrStreamController!.stream;
  }

  /// Stream HRV data in configurable windows (RFC specification)
  Stream<WearMetrics> streamHRV({Duration? windowSize}) {
    final actualWindowSize = windowSize ?? config.hrvWindowSize;

    _hrvStreamController ??= StreamController<WearMetrics>.broadcast();

    // Start timer when first listener subscribes
    if (!_hrvStreamController!.hasListener) {
      _startHrvStreaming(actualWindowSize);
    }

    return _hrvStreamController!.stream;
  }

  /// Get cached sessions for analysis
  Future<List<WearMetrics>> getCachedSessions({
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
  }) async {
    if (!config.enableLocalCaching) {
      throw SynheartWearError('Local caching is disabled');
    }

    return await LocalCache.getCachedSessions(
      startDate: startDate,
      endDate: endDate,
      limit: limit,
    );
  }

  /// Get cache statistics
  Future<Map<String, Object?>> getCacheStats() async {
    if (!config.enableLocalCaching) {
      return {'enabled': false, 'encryption_enabled': false};
    }

    return await LocalCache.getCacheStats(
      encryptionEnabled: config.enableEncryption,
    );
  }

  /// Clear old cached data
  Future<void> clearOldCache({
    Duration maxAge = const Duration(days: 30),
  }) async {
    if (!config.enableLocalCaching) return;

    await LocalCache.clearOldData(maxAge: maxAge);
  }

  /// Request permissions for data access
  Future<Map<PermissionType, ConsentStatus>> requestPermissions({
    Set<PermissionType>? permissions,
    String? reason,
  }) async {
    final requiredPermissions = permissions ?? _getRequiredPermissions();
    return await ConsentManager.requestConsent(
      requiredPermissions,
      reason: reason,
    );
  }

  /// Check current permission status
  Map<PermissionType, ConsentStatus> getPermissionStatus() {
    return ConsentManager.getAllConsents();
  }

  /// Revoke all permissions
  Future<void> revokeAllPermissions() async {
    await ConsentManager.revokeAllConsents();
  }

  /// Dispose resources
  void dispose() {
    _streamTimer?.cancel();
    _streamTimer = null;
    _hrvTimer?.cancel();
    _hrvTimer = null;
    _hrStreamController?.close();
    _hrStreamController = null;
    _hrvStreamController?.close();
    _hrvStreamController = null;
    _garminHealth?.dispose();
    _initialized = false;
  }

  /// Request necessary permissions based on enabled adapters
  Future<void> _requestPermissions() async {
    final requiredPermissions = _getRequiredPermissions();
    await ConsentManager.requestConsent(requiredPermissions);
  }

  /// Get required permissions based on enabled adapters
  /// Uses platform-specific permissions (e.g., excludes HRV on Android)
  Set<PermissionType> _getRequiredPermissions() {
    final permissions = <PermissionType>{};
    for (final adapter in _enabledAdapters()) {
      // Use platform-specific permissions instead of all supported permissions
      permissions.addAll(adapter.getPlatformSupportedPermissions());
    }
    return permissions;
  }

  // Helper to get enabled adapter instances
  List<WearAdapter> _enabledAdapters() {
    return config.enabledAdapters
        .where(_adapterRegistry.containsKey)
        .map((d) => _adapterRegistry[d]!)
        .toList();
  }

  /// Start the streaming timer
  void _startStreaming(Duration interval) {
    _streamTimer?.cancel();
    _streamTimer = Timer.periodic(interval, (timer) async {
      // Check if we still have subscribers
      if (_hrStreamController?.hasListener != true) {
        _streamTimer?.cancel();
        _streamTimer = null;
        return;
      }

      final controller = _hrStreamController;
      if (controller == null || controller.isClosed) {
        _streamTimer?.cancel();
        _streamTimer = null;
        return;
      }

      try {
        final metrics = await readMetrics(isRealTime: true);
        if (!controller.isClosed) controller.add(metrics);
      } catch (e) {
        if (!controller.isClosed) controller.addError(e);
      }
    });
  }

  /// Start HRV streaming timer
  void _startHrvStreaming(Duration windowSize) {
    _hrvTimer?.cancel();
    _hrvTimer = Timer.periodic(windowSize, (timer) async {
      final controller = _hrvStreamController;
      if (controller == null || controller.isClosed) {
        _hrvTimer?.cancel();
        _hrvTimer = null;
        return;
      }

      // Check if we still have subscribers
      if (!controller.hasListener) {
        _hrvTimer?.cancel();
        _hrvTimer = null;
        return;
      }

      try {
        final metrics = await readMetrics(isRealTime: true);
        // Check for either HRV metric type (SDNN or RMSSD)
        final hrvSdnn = metrics.getMetric(MetricType.hrvSdnn);
        final hrvRmssd = metrics.getMetric(MetricType.hrvRmssd);

        // Emit metrics if any HRV data is present
        if (hrvSdnn != null || hrvRmssd != null) {
          if (!controller.isClosed) controller.add(metrics);
        }
      } catch (e) {
        if (!controller.isClosed) controller.addError(e);
      }
    });
  }

  /// Getter for testing timer state
  @visibleForTesting
  bool get isStreamTimerActive => _streamTimer?.isActive ?? false;

  @visibleForTesting
  bool get isHrvTimerActive => _hrvTimer?.isActive ?? false;
}
