import 'dart:io';

import 'package:flutter/services.dart';

import '../models/health_profile_snapshot.dart';

/// Reads demographic / anthropometric values from the device's native health
/// store so a host app can prefill an "About you" form instead of asking the
/// user to retype values they already entered in Apple Health or Health
/// Connect.
///
/// The dispatch is platform-aware:
///  - iOS  → `synheart_wear/healthkit_profile` (HKHealthStore characteristics
///           + latest height/weight/body-fat samples).
///  - Android → `synheart_wear/health_connect_profile` (Health Connect only
///              exposes height/weight/body-fat — sex/DOB/blood type are not
///              characteristics on HC, so those fields come back null).
///
/// All methods return safe defaults on failure (false / empty snapshot) — the
/// caller treats this as best-effort prefill, never a hard requirement.
class HealthProfileChannel {
  static const MethodChannel _iosChannel = MethodChannel(
    'synheart_wear/healthkit_profile',
  );
  static const MethodChannel _androidChannel = MethodChannel(
    'synheart_wear/health_connect_profile',
  );

  static MethodChannel? get _channel {
    if (Platform.isIOS) return _iosChannel;
    if (Platform.isAndroid) return _androidChannel;
    return null;
  }

  /// True when the platform health store is reachable and the plugin has a
  /// handler registered. Cheap call — does not request authorization.
  static Future<bool> isAvailable() async {
    final channel = _channel;
    if (channel == null) return false;
    try {
      final result = await channel.invokeMethod<bool>('isAvailable');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Trigger the platform's read-permission prompt for profile fields. On iOS
  /// this opens the HealthKit sheet for DOB / sex / blood type / height /
  /// weight / body fat; on Android it routes to the Health Connect permission
  /// activity.
  ///
  /// Returns true if the call completed without an exception. The user may
  /// still have denied any subset of permissions — confirm by calling
  /// [readProfile] and inspecting which fields came back populated.
  static Future<bool> requestAuthorization() async {
    final channel = _channel;
    if (channel == null) return false;
    try {
      final result = await channel.invokeMethod<bool>('requestAuthorization');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Read the current snapshot. Always returns a snapshot (possibly empty);
  /// callers should check individual fields for null rather than treating
  /// failure as an exception.
  static Future<HealthProfileSnapshot> readProfile() async {
    final channel = _channel;
    if (channel == null) return HealthProfileSnapshot.empty;
    try {
      final raw = await channel.invokeMethod<Map<dynamic, dynamic>>(
        'readProfile',
      );
      if (raw == null) return HealthProfileSnapshot.empty;
      return HealthProfileSnapshot.fromMap(raw);
    } catch (_) {
      return HealthProfileSnapshot.empty;
    }
  }
}
