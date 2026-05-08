/// Connection state for Garmin devices
enum GarminConnectionState {
  /// Device is not connected
  disconnected,

  /// Device is in the process of connecting
  connecting,

  /// Device is connected and ready
  connected,

  /// Connection attempt failed
  failed,

  /// Connection state is unknown
  unknown,
}

/// Extension methods for GarminConnectionState
extension GarminConnectionStateExtension on GarminConnectionState {
  /// Whether the device is currently connected
  bool get isConnected => this == GarminConnectionState.connected;

  /// Whether the device is in a connecting state
  bool get isConnecting => this == GarminConnectionState.connecting;

  /// Whether the connection has failed
  bool get hasFailed => this == GarminConnectionState.failed;

  /// Convert to string for display
  String get displayName {
    switch (this) {
      case GarminConnectionState.disconnected:
        return 'Disconnected';
      case GarminConnectionState.connecting:
        return 'Connecting';
      case GarminConnectionState.connected:
        return 'Connected';
      case GarminConnectionState.failed:
        return 'Failed';
      case GarminConnectionState.unknown:
        return 'Unknown';
    }
  }
}

/// Parse connection state from string (from platform channel)
GarminConnectionState parseGarminConnectionState(String? state) {
  if (state == null) return GarminConnectionState.unknown;

  switch (state.toLowerCase()) {
    case 'disconnected':
    case 'not_connected':
      return GarminConnectionState.disconnected;
    case 'connecting':
      return GarminConnectionState.connecting;
    case 'connected':
      return GarminConnectionState.connected;
    case 'failed':
    case 'error':
      return GarminConnectionState.failed;
    default:
      return GarminConnectionState.unknown;
  }
}

/// Connection state event from platform channel
class GarminConnectionStateEvent {
  /// The current connection state
  final GarminConnectionState state;

  /// The device ID if applicable
  final int? deviceId;

  /// Error message if state is failed
  final String? error;

  /// Timestamp of the event
  final DateTime timestamp;

  GarminConnectionStateEvent({
    required this.state,
    this.deviceId,
    this.error,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Create from platform channel map
  factory GarminConnectionStateEvent.fromMap(Map<String, dynamic> map) {
    return GarminConnectionStateEvent(
      state: parseGarminConnectionState(map['state'] as String?),
      deviceId: map['deviceId'] as int?,
      error: map['error'] as String?,
      timestamp: map['timestamp'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int)
          : null,
    );
  }

  /// Convert to map for platform channel
  Map<String, dynamic> toMap() => {
    'state': state.name,
    if (deviceId != null) 'deviceId': deviceId,
    if (error != null) 'error': error,
    'timestamp': timestamp.millisecondsSinceEpoch,
  };

  @override
  String toString() {
    return 'GarminConnectionStateEvent(state: $state, deviceId: $deviceId, error: $error)';
  }
}
