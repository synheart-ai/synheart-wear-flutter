import 'dart:io';
import 'package:flutter/services.dart';

/// Helper class for Android Health Connect utilities
/// Provides methods to detect Samsung Health and provide user guidance
class AndroidHealthHelper {
  static const MethodChannel _channel = MethodChannel(
    'synheart_wear/android_health',
  );

  /// Check if Samsung Health is installed on the device
  static Future<bool> isSamsungHealthInstalled() async {
    if (!Platform.isAndroid) {
      return false;
    }
    try {
      final bool result =
          await _channel.invokeMethod<bool>('isSamsungHealthInstalled') ??
          false;
      return result;
    } catch (e) {
      // If method channel fails, assume not available
      return false;
    }
  }

  /// Open Samsung Health app (user can then navigate to Settings → Health Connect)
  static Future<void> openSamsungHealthSettings() async {
    if (!Platform.isAndroid) {
      throw UnsupportedError('openSamsungHealthSettings only works on Android');
    }
    try {
      await _channel.invokeMethod('openSamsungHealthSettings');
    } catch (e) {
      throw Exception('Failed to open Samsung Health: $e');
    }
  }

  /// Get Android SDK version (e.g., 34 for Android 14, 35 for Android 15)
  static Future<int> getAndroidVersion() async {
    if (!Platform.isAndroid) {
      return 0;
    }
    try {
      final int version =
          await _channel.invokeMethod<int>('getAndroidVersion') ?? 0;
      return version;
    } catch (e) {
      return 0;
    }
  }

  /// Get user-friendly guidance message when steps data is missing
  /// Returns a message explaining how to sync Samsung Health with Health Connect
  static Future<String> getStepsDataGuidance({
    required bool stepsPermissionGranted,
    required bool stepsDataNull,
  }) async {
    if (!Platform.isAndroid || !stepsPermissionGranted || !stepsDataNull) {
      return '';
    }

    final samsungHealthInstalled = await isSamsungHealthInstalled();
    final androidVersion = await getAndroidVersion();

    if (samsungHealthInstalled) {
      final message = StringBuffer();
      message.writeln('⚠️ Steps permission granted but no step data found');
      message.writeln();
      message.writeln('📱 Samsung Health detected!');
      message.writeln('💡 Sync required: Samsung Health → Health Connect');

      if (androidVersion < 35) {
        // Android 15 and below
        message.writeln();
        message.writeln('🔧 On Android < 16: Manual sync required');
        message.writeln('   1. Open Samsung Health app');
        message.writeln('   2. Go to: My Page → ⚙️ Settings → Health Connect');
        message.writeln(
          '   3. Enable data sharing for Steps, Heart Rate, etc.',
        );
        message.writeln('   4. Wait for sync, then refresh this app');
      } else {
        // Android 16+
        message.writeln();
        message.writeln('💡 On Android 16+, sync should be automatic');
        message.writeln(
          '   If not working, check Samsung Health → Settings → Health Connect',
        );
      }

      return message.toString();
    } else {
      return '⚠️ Steps permission granted but no step data found\n\n'
          '📱 Samsung Health not found\n'
          '💡 Install Samsung Health or use another fitness app\n'
          '   that syncs with Health Connect';
    }
  }
}
