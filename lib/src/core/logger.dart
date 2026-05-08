import 'package:flutter/foundation.dart';

/// Log levels for SDK logging
enum LogLevel { debug, info, warning, error }

/// Logger interface for SDK logging
/// Allows consumers to provide their own logger implementation
abstract class SynheartLogger {
  void log(
    LogLevel level,
    String message, [
    Object? error,
    StackTrace? stackTrace,
  ]);

  void debug(String message) => log(LogLevel.debug, message);
  void info(String message) => log(LogLevel.info, message);
  void warning(String message, [Object? error]) =>
      log(LogLevel.warning, message, error);
  void error(String message, [Object? error, StackTrace? stackTrace]) =>
      log(LogLevel.error, message, error, stackTrace);
}

/// Default logger implementation
/// Only logs in debug mode unless it's an error
class DefaultLogger implements SynheartLogger {
  final bool enableDebugLogs;
  final bool enableInfoLogs;
  final bool enableWarningLogs;
  final bool enableErrorLogs;

  const DefaultLogger({
    this.enableDebugLogs = false,
    this.enableInfoLogs = false,
    this.enableWarningLogs = true,
    this.enableErrorLogs = true,
  });

  @override
  void log(
    LogLevel level,
    String message, [
    Object? error,
    StackTrace? stackTrace,
  ]) {
    // Only log in debug mode, except for errors which should always be logged
    if (!kDebugMode && level != LogLevel.error) {
      return;
    }

    // Check if this log level is enabled
    switch (level) {
      case LogLevel.debug:
        if (!enableDebugLogs) return;
        break;
      case LogLevel.info:
        if (!enableInfoLogs) return;
        break;
      case LogLevel.warning:
        if (!enableWarningLogs) return;
        break;
      case LogLevel.error:
        if (!enableErrorLogs) return;
        break;
    }

    final prefix = _getPrefix(level);
    final output = error != null
        ? '$prefix $message\nError: $error${stackTrace != null ? '\n$stackTrace' : ''}'
        : '$prefix $message';

    // Use debugPrint in debug mode to avoid overwhelming logs
    if (kDebugMode) {
      debugPrint(output);
    } else {
      // In release mode, only print errors
      if (level == LogLevel.error) {
        print(output);
      }
    }
  }

  String _getPrefix(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return '🔍 [SynheartWear DEBUG]';
      case LogLevel.info:
        return 'ℹ️ [SynheartWear INFO]';
      case LogLevel.warning:
        return '⚠️ [SynheartWear WARNING]';
      case LogLevel.error:
        return '❌ [SynheartWear ERROR]';
    }
  }

  @override
  void debug(String message) => log(LogLevel.debug, message);

  @override
  void info(String message) => log(LogLevel.info, message);

  @override
  void warning(String message, [Object? error]) =>
      log(LogLevel.warning, message, error);

  @override
  void error(String message, [Object? error, StackTrace? stackTrace]) =>
      log(LogLevel.error, message, error, stackTrace);
}

/// Global logger instance
/// Can be replaced by consumers with their own logger
SynheartLogger _logger = const DefaultLogger(
  enableDebugLogs: false,
  enableInfoLogs: false,
  enableWarningLogs: true,
  enableErrorLogs: true,
);

/// Set a custom logger for the SDK
void setLogger(SynheartLogger logger) {
  _logger = logger;
}

/// Get the current logger
SynheartLogger get logger => _logger;

/// Convenience functions for logging
void logDebug(String message) => logger.debug(message);
void logInfo(String message) => logger.info(message);
void logWarning(String message, [Object? error]) =>
    logger.warning(message, error);
void logError(String message, [Object? error, StackTrace? stackTrace]) =>
    logger.error(message, error, stackTrace);
