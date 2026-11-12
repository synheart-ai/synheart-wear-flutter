import 'package:flutter_test/flutter_test.dart';
import 'package:synheart_wear/src/adapters/apple_healthkit.dart';
import 'package:synheart_wear/src/adapters/wear_adapter.dart';
import 'package:synheart_wear/synheart_wear.dart';

void main() {
  group('HealthAdapter.throttleDecision', () {
    final t0 = DateTime(2026, 11, 12, 12);
    const perms = {PermissionType.heartRate, PermissionType.steps};
    final start = t0.subtract(const Duration(days: 30));
    final previous = (at: t0, permissions: perms, start: start, end: t0);

    test('reads at once when nothing was read before', () {
      final d = HealthAdapter.throttleDecision(
        now: t0,
        lastReadAt: null,
        previous: null,
        permissions: perms,
        start: start,
        end: t0,
      );
      expect(d.reuse, isFalse);
      expect(d.wait, Duration.zero);
    });

    test('reuses a recent read of the same types and window', () {
      final now = t0.add(const Duration(seconds: 3));
      final d = HealthAdapter.throttleDecision(
        now: now,
        lastReadAt: t0,
        previous: previous,
        permissions: {PermissionType.steps, PermissionType.heartRate},
        start: now.subtract(const Duration(days: 30)),
        end: now,
      );
      expect(d.reuse, isTrue);
    });

    test('waits out the interval for a different window', () {
      final now = t0.add(const Duration(seconds: 3));
      final d = HealthAdapter.throttleDecision(
        now: now,
        lastReadAt: t0,
        previous: previous,
        permissions: perms,
        start: now.subtract(const Duration(days: 1)),
        end: now,
      );
      expect(d.reuse, isFalse);
      expect(d.wait, const Duration(seconds: 7));
    });

    test('waits out the interval for different types', () {
      final now = t0.add(const Duration(seconds: 4));
      final d = HealthAdapter.throttleDecision(
        now: now,
        lastReadAt: t0,
        previous: previous,
        permissions: {PermissionType.heartRate},
        start: start,
        end: now,
      );
      expect(d.reuse, isFalse);
      expect(d.wait, const Duration(seconds: 6));
    });

    test('reads at once after the interval has passed', () {
      final now = t0.add(const Duration(seconds: 10));
      final d = HealthAdapter.throttleDecision(
        now: now,
        lastReadAt: t0,
        previous: previous,
        permissions: perms,
        start: start,
        end: now,
      );
      expect(d.reuse, isFalse);
      expect(d.wait, Duration.zero);
    });
  });

  group('WearAdapter Interface Tests', () {
    test('AppleHealthKitAdapter implements WearAdapter correctly', () {
      final adapter = AppleHealthKitAdapter();

      expect(adapter.id, equals('apple_healthkit'));
      expect(adapter.supportedPermissions, contains(PermissionType.heartRate));
      expect(
        adapter.supportedPermissions,
        contains(PermissionType.heartRateVariability),
      );
      expect(adapter.supportedPermissions, contains(PermissionType.steps));
      expect(adapter.supportedPermissions, contains(PermissionType.calories));
    });

    test('history access has no limit to lift off Android', () async {
      // Tests run on the host, not Android: no platform call is made.
      expect(await HealthAdapter.isHistoryAvailable(), isFalse);
      expect(await HealthAdapter.isHistoryAuthorized(), isTrue);
      expect(await HealthAdapter.requestHistoryAuthorization(), isTrue);
    });

    test('labels data by the store it came from', () {
      expect(
        AppleHealthKitAdapter.sourceFor(isAndroid: true),
        'health_connect',
      );
      expect(
        AppleHealthKitAdapter.sourceFor(isAndroid: false),
        'apple_healthkit',
      );
    });
  });

  group('Mock Adapter Tests', () {
    test('MockWearAdapter works correctly', () async {
      final mockAdapter = MockWearAdapter();

      expect(mockAdapter.id, equals('mock_adapter'));
      expect(
        mockAdapter.supportedPermissions,
        contains(PermissionType.heartRate),
      );

      final metrics = await mockAdapter.readSnapshot();
      expect(metrics, isNotNull);
      expect(metrics!.source, equals('mock_adapter'));
      expect(metrics.getMetric(MetricType.hr), equals(75));
      expect(mockAdapter.readSnapshotCalled, isTrue);
    });

    test('FailingWearAdapter throws correctly', () async {
      final failingAdapter = FailingWearAdapter();

      expect(failingAdapter.id, equals('failing_adapter'));
      expect(
        failingAdapter.supportedPermissions,
        contains(PermissionType.heartRate),
      );

      expect(
        () async => await failingAdapter.readSnapshot(),
        throwsA(isA<UnimplementedError>()),
      );
    });
  });

  // Note: Integration tests that require HealthKit or actual device access
  // are disabled for CI compatibility. These should be run on actual devices.
}

// Mock adapter for testing
class MockWearAdapter implements WearAdapter {
  bool readSnapshotCalled = false;

  @override
  String get id => 'mock_adapter';

  @override
  Set<PermissionType> get supportedPermissions => {PermissionType.heartRate};

  @override
  Future<WearMetrics?> readSnapshot({
    bool isRealTime = false,
    DateTime? startTime,
    DateTime? endTime,
  }) async {
    readSnapshotCalled = true;
    return WearMetrics(
      timestamp: DateTime.now(),
      deviceId: 'mock_device',
      source: id,
      metrics: {'hr': 75},
    );
  }

  @override
  Set<PermissionType> getPlatformSupportedPermissions() {
    return supportedPermissions;
  }
}

// Failing adapter for error testing
class FailingWearAdapter implements WearAdapter {
  @override
  String get id => 'failing_adapter';

  @override
  Set<PermissionType> get supportedPermissions => {PermissionType.heartRate};

  @override
  Future<WearMetrics?> readSnapshot({
    bool isRealTime = false,
    DateTime? startTime,
    DateTime? endTime,
  }) {
    throw UnimplementedError();
  }

  @override
  Set<PermissionType> getPlatformSupportedPermissions() {
    return supportedPermissions;
  }
}
