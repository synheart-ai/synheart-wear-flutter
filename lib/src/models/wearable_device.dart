import '../core/config.dart';

/// Connection state for wearable devices
enum DeviceConnectionState {
  disconnected,
  connecting,
  connected,
  failed,
  unknown,
}

/// A discovered wearable device during scanning
class ScannedDevice {
  /// Platform BLE identifier (UUID on iOS, MAC on Android)
  final String identifier;

  /// Device name
  final String name;

  /// Model name if available
  final String? modelName;

  /// Received signal strength indicator (RSSI)
  final int? rssi;

  /// Whether this device is already paired
  final bool isPaired;

  /// Which adapter discovered this device
  final DeviceAdapter adapter;

  /// Timestamp when device was discovered
  final DateTime discoveredAt;

  ScannedDevice({
    required this.identifier,
    required this.name,
    this.modelName,
    this.rssi,
    this.isPaired = false,
    required this.adapter,
    DateTime? discoveredAt,
  }) : discoveredAt = discoveredAt ?? DateTime.now();

  @override
  String toString() {
    return 'ScannedDevice(name: $name, identifier: $identifier, adapter: ${adapter.name})';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ScannedDevice &&
          runtimeType == other.runtimeType &&
          identifier == other.identifier;

  @override
  int get hashCode => identifier.hashCode;
}

/// A paired wearable device
class PairedDevice {
  /// Adapter-specific device ID (e.g., Garmin unitId as string)
  final String deviceId;

  /// Platform BLE identifier
  final String identifier;

  /// Device name
  final String name;

  /// Model name if available
  final String? modelName;

  /// Current connection state
  final DeviceConnectionState connectionState;

  /// Battery level (0-100)
  final int? batteryLevel;

  /// Last sync timestamp
  final DateTime? lastSyncTime;

  /// Whether the device supports real-time streaming
  final bool supportsStreaming;

  /// Which adapter manages this device
  final DeviceAdapter adapter;

  PairedDevice({
    required this.deviceId,
    required this.identifier,
    required this.name,
    this.modelName,
    this.connectionState = DeviceConnectionState.disconnected,
    this.batteryLevel,
    this.lastSyncTime,
    this.supportsStreaming = false,
    required this.adapter,
  });

  /// Whether the device is currently connected
  bool get isConnected => connectionState == DeviceConnectionState.connected;

  @override
  String toString() {
    return 'PairedDevice(deviceId: $deviceId, name: $name, connected: $isConnected)';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PairedDevice &&
          runtimeType == other.runtimeType &&
          deviceId == other.deviceId;

  @override
  int get hashCode => deviceId.hashCode;
}

/// Connection state change event
class DeviceConnectionEvent {
  /// The current connection state
  final DeviceConnectionState state;

  /// The device ID if applicable
  final String? deviceId;

  /// Error message if state is failed
  final String? error;

  /// Timestamp of the event
  final DateTime timestamp;

  DeviceConnectionEvent({
    required this.state,
    this.deviceId,
    this.error,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  @override
  String toString() {
    return 'DeviceConnectionEvent(state: $state, deviceId: $deviceId, error: $error)';
  }
}
