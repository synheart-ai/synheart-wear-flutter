/// Supported device adapters for wearable data sources
enum DeviceAdapter {
  /// Apple HealthKit (iOS) and Health Connect (Android)
  appleHealthKit,

  /// Fitbit devices via Fitbit Web API
  fitbit,

  /// Garmin devices via Garmin Connect API
  garmin,

  /// Whoop devices via Whoop API
  whoop,

  /// Samsung Health devices
  samsungHealth,
}

/// Configuration for the SynheartWear SDK
class SynheartWearConfig {
  /// Set of device adapters to enable for data collection
  final Set<DeviceAdapter> enabledAdapters;

  /// Interval for heart rate streaming (default: 2 seconds)
  final Duration streamInterval;

  /// Window size for HRV streaming (default: 5 seconds)
  final Duration hrvWindowSize;

  /// Whether to enable local caching of health data
  final bool enableLocalCaching;

  /// Whether to encrypt cached data using AES-256
  final bool enableEncryption;

  /// Adapter-specific configuration map
  final Map<String, Object?> adapterConfig;

  /// Optional custom path for encryption key storage
  final String? encryptionKeyPath;

  const SynheartWearConfig({
    this.enabledAdapters = const {
      DeviceAdapter.appleHealthKit,
      DeviceAdapter.fitbit,
    },
    this.streamInterval = const Duration(seconds: 2),
    this.hrvWindowSize = const Duration(seconds: 5),
    this.enableLocalCaching = true,
    this.enableEncryption = true,
    this.encryptionKeyPath,
    this.adapterConfig = const {},
  });

  /// Create config with only specific adapters enabled
  SynheartWearConfig.withAdapters(Set<DeviceAdapter> adapters)
    : this(enabledAdapters: adapters);

  /// Create config for development/testing
  SynheartWearConfig.development()
    : this(
        enabledAdapters: const {DeviceAdapter.appleHealthKit},
        enableLocalCaching: false,
        enableEncryption: false,
      );

  /// Create config for production
  SynheartWearConfig.production()
    : this(
        enabledAdapters: const {
          DeviceAdapter.appleHealthKit,
          DeviceAdapter.fitbit,
          DeviceAdapter.garmin,
          DeviceAdapter.whoop,
          DeviceAdapter.samsungHealth,
        },
        enableLocalCaching: true,
        enableEncryption: true,
      );

  /// Check if a specific adapter is enabled
  bool isAdapterEnabled(DeviceAdapter adapter) {
    return enabledAdapters.contains(adapter);
  }

  /// Get configuration for a specific adapter
  Map<String, Object?> getAdapterConfig(DeviceAdapter adapter) {
    final adapterKey = adapter.name;
    return Map<String, Object?>.from(adapterConfig[adapterKey] as Map? ?? {});
  }

  /// Create a copy with modified settings
  SynheartWearConfig copyWith({
    Set<DeviceAdapter>? enabledAdapters,
    Duration? streamInterval,
    Duration? hrvWindowSize,
    bool? enableLocalCaching,
    bool? enableEncryption,
    Map<String, Object?>? adapterConfig,
  }) {
    return SynheartWearConfig(
      enabledAdapters: enabledAdapters ?? this.enabledAdapters,
      streamInterval: streamInterval ?? this.streamInterval,
      hrvWindowSize: hrvWindowSize ?? this.hrvWindowSize,
      enableLocalCaching: enableLocalCaching ?? this.enableLocalCaching,
      enableEncryption: enableEncryption ?? this.enableEncryption,
      adapterConfig: adapterConfig ?? this.adapterConfig,
    );
  }
}
