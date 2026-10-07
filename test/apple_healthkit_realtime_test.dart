import 'package:flutter_test/flutter_test.dart';
import 'package:synheart_wear/src/adapters/apple_healthkit.dart';

void main() {
  group('AppleHealthKitAdapter.realtimeWindow', () {
    final now = DateTime.utc(2026, 10, 7, 12, 0, 0);

    test('first tick reads the recent lookback, not 30 days', () {
      final window = AppleHealthKitAdapter.realtimeWindow(now, null)!;
      expect(window.end, now);
      expect(
        window.start,
        now.subtract(AppleHealthKitAdapter.iosRealtimeLookback),
      );
      expect(now.difference(window.start), lessThan(const Duration(days: 1)));
    });

    test('ticks inside the minimum interval are skipped', () {
      final last = now.subtract(const Duration(seconds: 1));
      expect(AppleHealthKitAdapter.realtimeWindow(now, last), isNull);
    });

    test('a tick at the minimum interval reads again', () {
      final last = now.subtract(AppleHealthKitAdapter.iosRealtimeMinInterval);
      expect(AppleHealthKitAdapter.realtimeWindow(now, last), isNotNull);
    });

    test('a 1 s stream reads HealthKit at most once per interval', () {
      DateTime? last;
      var reads = 0;
      for (var s = 0; s < 60; s++) {
        final t = now.add(Duration(seconds: s));
        if (AppleHealthKitAdapter.realtimeWindow(t, last) != null) {
          reads++;
          last = t;
        }
      }
      expect(
        reads,
        60 ~/ AppleHealthKitAdapter.iosRealtimeMinInterval.inSeconds,
      );
    });
  });
}
