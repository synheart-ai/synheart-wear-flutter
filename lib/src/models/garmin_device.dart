import 'garmin_connection_state.dart';

/// Types of Garmin devices
enum GarminDeviceType {
  /// Unknown device type
  unknown,

  /// Fitness band/tracker (e.g., Vivosmart, Vivomove)
  fitnessTracker,

  /// Running/multisport watch (e.g., Forerunner, Fenix)
  runningWatch,

  /// Cycling computer (e.g., Edge)
  cyclingComputer,

  /// Outdoor/adventure watch (e.g., Instinct, Epix)
  outdoorWatch,

  /// Golf watch/device
  golfWatch,

  /// Diving watch (e.g., Descent)
  divingWatch,

  /// Aviation watch (e.g., D2)
  aviationWatch,

  /// Legacy device
  legacy,
}

/// Extension methods for GarminDeviceType
extension GarminDeviceTypeExtension on GarminDeviceType {
  /// Convert to string for display
  String get displayName {
    switch (this) {
      case GarminDeviceType.unknown:
        return 'Unknown';
      case GarminDeviceType.fitnessTracker:
        return 'Fitness Tracker';
      case GarminDeviceType.runningWatch:
        return 'Running Watch';
      case GarminDeviceType.cyclingComputer:
        return 'Cycling Computer';
      case GarminDeviceType.outdoorWatch:
        return 'Outdoor Watch';
      case GarminDeviceType.golfWatch:
        return 'Golf Watch';
      case GarminDeviceType.divingWatch:
        return 'Diving Watch';
      case GarminDeviceType.aviationWatch:
        return 'Aviation Watch';
      case GarminDeviceType.legacy:
        return 'Legacy Device';
    }
  }

  /// Whether device supports real-time streaming
  bool get supportsRealTimeStreaming {
    switch (this) {
      case GarminDeviceType.fitnessTracker:
      case GarminDeviceType.runningWatch:
      case GarminDeviceType.outdoorWatch:
        return true;
      default:
        return false;
    }
  }
}

/// Parse device type from string (from platform channel)
GarminDeviceType parseGarminDeviceType(String? type) {
  if (type == null) return GarminDeviceType.unknown;

  switch (type.toLowerCase()) {
    case 'fitness_tracker':
    case 'fitnesstracker':
    case 'vivosmart':
    case 'vivomove':
    case 'venu':
      return GarminDeviceType.fitnessTracker;
    case 'running_watch':
    case 'runningwatch':
    case 'forerunner':
      return GarminDeviceType.runningWatch;
    case 'cycling_computer':
    case 'cyclingcomputer':
    case 'edge':
      return GarminDeviceType.cyclingComputer;
    case 'outdoor_watch':
    case 'outdoorwatch':
    case 'fenix':
    case 'instinct':
    case 'epix':
      return GarminDeviceType.outdoorWatch;
    case 'golf_watch':
    case 'golfwatch':
    case 'approach':
      return GarminDeviceType.golfWatch;
    case 'diving_watch':
    case 'divingwatch':
    case 'descent':
      return GarminDeviceType.divingWatch;
    case 'aviation_watch':
    case 'aviationwatch':
    case 'd2':
      return GarminDeviceType.aviationWatch;
    case 'legacy':
      return GarminDeviceType.legacy;
    default:
      return GarminDeviceType.unknown;
  }
}

/// A discovered Garmin device during scanning
class GarminScannedDevice {
  /// Bluetooth identifier (UUID on iOS, MAC on Android)
  final String identifier;

  /// Device name
  final String name;

  /// Device type
  final GarminDeviceType type;

  /// Received signal strength indicator (RSSI)
  final int? rssi;

  /// Whether this device is already paired
  final bool isPaired;

  /// Device model name if available
  final String? modelName;

  /// Firmware version if available
  final String? firmwareVersion;

  /// Timestamp when device was discovered
  final DateTime discoveredAt;

  GarminScannedDevice({
    required this.identifier,
    required this.name,
    this.type = GarminDeviceType.unknown,
    this.rssi,
    this.isPaired = false,
    this.modelName,
    this.firmwareVersion,
    DateTime? discoveredAt,
  }) : discoveredAt = discoveredAt ?? DateTime.now();

  /// Create from platform channel map
  factory GarminScannedDevice.fromMap(Map<String, dynamic> map) {
    return GarminScannedDevice(
      identifier: map['identifier'] as String,
      name: map['name'] as String? ?? 'Unknown Garmin',
      type: parseGarminDeviceType(map['type'] as String?),
      rssi: map['rssi'] as int?,
      isPaired: map['isPaired'] as bool? ?? false,
      modelName: map['modelName'] as String?,
      firmwareVersion: map['firmwareVersion'] as String?,
      discoveredAt: map['discoveredAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['discoveredAt'] as int)
          : null,
    );
  }

  /// Convert to map for platform channel
  Map<String, dynamic> toMap() => {
    'identifier': identifier,
    'name': name,
    'type': type.name,
    if (rssi != null) 'rssi': rssi,
    'isPaired': isPaired,
    if (modelName != null) 'modelName': modelName,
    if (firmwareVersion != null) 'firmwareVersion': firmwareVersion,
    'discoveredAt': discoveredAt.millisecondsSinceEpoch,
  };

  @override
  String toString() {
    return 'GarminScannedDevice(name: $name, identifier: $identifier, type: ${type.displayName}, rssi: $rssi)';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GarminScannedDevice &&
          runtimeType == other.runtimeType &&
          identifier == other.identifier;

  @override
  int get hashCode => identifier.hashCode;
}

/// A paired Garmin device
class GarminDevice {
  /// Unique unit ID assigned by Garmin
  final int unitId;

  /// Bluetooth identifier
  final String identifier;

  /// Device name
  final String name;

  /// Device type
  final GarminDeviceType type;

  /// Model name
  final String? modelName;

  /// Firmware version
  final String? firmwareVersion;

  /// Serial number if available
  final String? serialNumber;

  /// Current connection state
  final GarminConnectionState connectionState;

  /// Battery level (0-100)
  final int? batteryLevel;

  /// Last sync timestamp
  final DateTime? lastSyncTime;

  /// Whether the device supports real-time streaming
  final bool supportsStreaming;

  /// When the device was paired
  final DateTime? pairedAt;

  GarminDevice({
    required this.unitId,
    required this.identifier,
    required this.name,
    this.type = GarminDeviceType.unknown,
    this.modelName,
    this.firmwareVersion,
    this.serialNumber,
    this.connectionState = GarminConnectionState.disconnected,
    this.batteryLevel,
    this.lastSyncTime,
    this.supportsStreaming = false,
    this.pairedAt,
  });

  /// Whether the device is currently connected
  bool get isConnected => connectionState == GarminConnectionState.connected;

  /// Create from platform channel map
  factory GarminDevice.fromMap(Map<String, dynamic> map) {
    return GarminDevice(
      unitId: map['unitId'] as int,
      identifier: map['identifier'] as String,
      name: map['name'] as String? ?? 'Garmin Device',
      type: parseGarminDeviceType(map['type'] as String?),
      modelName: map['modelName'] as String?,
      firmwareVersion: map['firmwareVersion'] as String?,
      serialNumber: map['serialNumber'] as String?,
      connectionState: parseGarminConnectionState(map['connectionState'] as String?),
      batteryLevel: map['batteryLevel'] as int?,
      lastSyncTime: map['lastSyncTime'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['lastSyncTime'] as int)
          : null,
      supportsStreaming: map['supportsStreaming'] as bool? ?? false,
      pairedAt: map['pairedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['pairedAt'] as int)
          : null,
    );
  }

  /// Convert to map for platform channel
  Map<String, dynamic> toMap() => {
    'unitId': unitId,
    'identifier': identifier,
    'name': name,
    'type': type.name,
    if (modelName != null) 'modelName': modelName,
    if (firmwareVersion != null) 'firmwareVersion': firmwareVersion,
    if (serialNumber != null) 'serialNumber': serialNumber,
    'connectionState': connectionState.name,
    if (batteryLevel != null) 'batteryLevel': batteryLevel,
    if (lastSyncTime != null) 'lastSyncTime': lastSyncTime!.millisecondsSinceEpoch,
    'supportsStreaming': supportsStreaming,
    if (pairedAt != null) 'pairedAt': pairedAt!.millisecondsSinceEpoch,
  };

  /// Create a copy with updated fields
  GarminDevice copyWith({
    int? unitId,
    String? identifier,
    String? name,
    GarminDeviceType? type,
    String? modelName,
    String? firmwareVersion,
    String? serialNumber,
    GarminConnectionState? connectionState,
    int? batteryLevel,
    DateTime? lastSyncTime,
    bool? supportsStreaming,
    DateTime? pairedAt,
  }) {
    return GarminDevice(
      unitId: unitId ?? this.unitId,
      identifier: identifier ?? this.identifier,
      name: name ?? this.name,
      type: type ?? this.type,
      modelName: modelName ?? this.modelName,
      firmwareVersion: firmwareVersion ?? this.firmwareVersion,
      serialNumber: serialNumber ?? this.serialNumber,
      connectionState: connectionState ?? this.connectionState,
      batteryLevel: batteryLevel ?? this.batteryLevel,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      supportsStreaming: supportsStreaming ?? this.supportsStreaming,
      pairedAt: pairedAt ?? this.pairedAt,
    );
  }

  @override
  String toString() {
    return 'GarminDevice(unitId: $unitId, name: $name, type: ${type.displayName}, connected: $isConnected)';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GarminDevice &&
          runtimeType == other.runtimeType &&
          unitId == other.unitId;

  @override
  int get hashCode => unitId.hashCode;
}
