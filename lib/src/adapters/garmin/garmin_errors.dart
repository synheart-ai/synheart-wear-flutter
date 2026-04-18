import '../../core/models.dart';

/// Base error class for Garmin SDK operations
class GarminSDKError extends SynheartWearError {
  GarminSDKError(String message, {String? code, Exception? originalException})
      : super(message, code: code ?? 'GARMIN_SDK_ERROR', originalException: originalException);
}

/// Error thrown when SDK initialization fails
class GarminInitializationError extends GarminSDKError {
  GarminInitializationError(String message, {Exception? originalException})
      : super(message, code: 'GARMIN_INIT_ERROR', originalException: originalException);
}

/// Error thrown when license key is invalid or missing
class GarminLicenseError extends GarminSDKError {
  GarminLicenseError(String message)
      : super(message, code: 'GARMIN_LICENSE_ERROR');
}

/// Error thrown when device scanning fails
class GarminScanError extends GarminSDKError {
  GarminScanError(String message, {Exception? originalException})
      : super(message, code: 'GARMIN_SCAN_ERROR', originalException: originalException);
}

/// Error thrown when device pairing fails
class GarminPairingError extends GarminSDKError {
  final String? deviceIdentifier;

  GarminPairingError(String message, {this.deviceIdentifier, Exception? originalException})
      : super(message, code: 'GARMIN_PAIRING_ERROR', originalException: originalException);

  @override
  String toString() {
    final deviceInfo = deviceIdentifier != null ? ' (device: $deviceIdentifier)' : '';
    return 'GarminPairingError: $message$deviceInfo';
  }
}

/// Error thrown when device connection fails
class GarminConnectionError extends GarminSDKError {
  final int? deviceId;

  GarminConnectionError(String message, {this.deviceId, Exception? originalException})
      : super(message, code: 'GARMIN_CONNECTION_ERROR', originalException: originalException);

  @override
  String toString() {
    final deviceInfo = deviceId != null ? ' (deviceId: $deviceId)' : '';
    return 'GarminConnectionError: $message$deviceInfo';
  }
}

/// Error thrown when real-time streaming fails
class GarminStreamingError extends GarminSDKError {
  GarminStreamingError(String message, {Exception? originalException})
      : super(message, code: 'GARMIN_STREAMING_ERROR', originalException: originalException);
}

/// Error thrown when sync operations fail
class GarminSyncError extends GarminSDKError {
  final int? deviceId;

  GarminSyncError(String message, {this.deviceId, Exception? originalException})
      : super(message, code: 'GARMIN_SYNC_ERROR', originalException: originalException);
}

/// Error thrown when data access fails
class GarminDataError extends GarminSDKError {
  GarminDataError(String message, {Exception? originalException})
      : super(message, code: 'GARMIN_DATA_ERROR', originalException: originalException);
}

/// Error thrown when platform channel communication fails
class GarminPlatformError extends GarminSDKError {
  GarminPlatformError(String message, {Exception? originalException})
      : super(message, code: 'GARMIN_PLATFORM_ERROR', originalException: originalException);
}

/// Error thrown when Bluetooth is unavailable or disabled
class GarminBluetoothError extends GarminSDKError {
  GarminBluetoothError(String message)
      : super(message, code: 'GARMIN_BLUETOOTH_ERROR');
}

/// Error thrown when no device is connected
class GarminNoDeviceError extends GarminSDKError {
  GarminNoDeviceError(String message)
      : super(message, code: 'GARMIN_NO_DEVICE');
}

/// Error thrown when operation times out
class GarminTimeoutError extends GarminSDKError {
  final Duration? timeout;

  GarminTimeoutError(String message, {this.timeout, Exception? originalException})
      : super(message, code: 'GARMIN_TIMEOUT', originalException: originalException);
}

/// Convert platform channel error to appropriate Garmin error
GarminSDKError garminErrorFromPlatformException(
  dynamic error, {
  String? defaultMessage,
}) {
  if (error is Exception) {
    final errorString = error.toString();

    // Parse error codes from platform
    if (errorString.contains('LICENSE_INVALID') ||
        errorString.contains('LICENSE_ERROR')) {
      return GarminLicenseError(
        defaultMessage ?? 'Invalid or missing Garmin SDK license key',
      );
    }

    if (errorString.contains('BLUETOOTH_DISABLED') ||
        errorString.contains('BLUETOOTH_UNAVAILABLE')) {
      return GarminBluetoothError(
        defaultMessage ?? 'Bluetooth is disabled or unavailable',
      );
    }

    if (errorString.contains('NOT_INITIALIZED')) {
      return GarminInitializationError(
        defaultMessage ?? 'Garmin SDK not initialized',
        originalException: error,
      );
    }

    if (errorString.contains('NO_DEVICE')) {
      return GarminNoDeviceError(
        defaultMessage ?? 'No Garmin device connected',
      );
    }

    if (errorString.contains('CONNECTION_FAILED') ||
        errorString.contains('DISCONNECTED')) {
      return GarminConnectionError(
        defaultMessage ?? 'Device connection failed',
        originalException: error,
      );
    }

    if (errorString.contains('PAIRING_FAILED') ||
        errorString.contains('PAIRING_CANCELLED')) {
      return GarminPairingError(
        defaultMessage ?? 'Device pairing failed',
        originalException: error,
      );
    }

    if (errorString.contains('SCAN_FAILED')) {
      return GarminScanError(
        defaultMessage ?? 'Device scan failed',
        originalException: error,
      );
    }

    if (errorString.contains('TIMEOUT')) {
      return GarminTimeoutError(
        defaultMessage ?? 'Operation timed out',
        originalException: error,
      );
    }

    if (errorString.contains('SYNC_FAILED')) {
      return GarminSyncError(
        defaultMessage ?? 'Sync operation failed',
        originalException: error,
      );
    }

    return GarminSDKError(
      defaultMessage ?? errorString,
      originalException: error,
    );
  }

  return GarminSDKError(defaultMessage ?? error.toString());
}
