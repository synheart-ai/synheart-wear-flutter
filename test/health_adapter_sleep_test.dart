import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';
import 'package:synheart_wear/src/adapters/health_adapter.dart';

HealthDataPoint _seg(HealthDataType type, DateTime from, DateTime to) =>
    HealthDataPoint(
      uuid: '',
      value: NumericHealthValue(numericValue: 0),
      type: type,
      unit: HealthDataUnit.MINUTE,
      dateFrom: from,
      dateTo: to,
      sourcePlatform: HealthPlatformType.googleHealthConnect,
      sourceDeviceId: 'test',
      sourceId: 'test',
      sourceName: 'test',
    );

DateTime _t(int day, int hour, [int minute = 0]) =>
    DateTime(2026, 10, day, hour, minute);

void main() {
  group('HealthAdapter.summarizeSleepNights', () {
    // 23:00 on the 28th → 07:00 on the 29th, awake 03:00–03:20.
    final night = [
      _seg(HealthDataType.SLEEP_LIGHT, _t(28, 23), _t(29, 1)),
      _seg(HealthDataType.SLEEP_DEEP, _t(29, 1), _t(29, 3)),
      _seg(HealthDataType.SLEEP_AWAKE, _t(29, 3), _t(29, 3, 20)),
      _seg(HealthDataType.SLEEP_REM, _t(29, 3, 20), _t(29, 7)),
    ];

    test('keeps a night that crosses midnight whole, on its wake day', () {
      final out = HealthAdapter.summarizeSleepNights(night);
      expect(out.keys, [DateTime(2026, 10, 29)]);
      final s = out.values.single;
      expect(s.lightMinutes, 120);
      expect(s.deepMinutes, 120);
      expect(s.remMinutes, 220);
      expect(s.totalAsleepMinutes, 460);
      expect(s.awakeMinutes, 20);
      expect(s.sleepStart, _t(28, 23));
      expect(s.sleepEnd, _t(29, 7));
    });

    test('a nap on the wake day does not replace the night', () {
      final out = HealthAdapter.summarizeSleepNights([
        ...night,
        _seg(HealthDataType.SLEEP_LIGHT, _t(29, 14), _t(29, 14, 40)),
      ]);
      final s = out[DateTime(2026, 10, 29)]!;
      expect(s.totalAsleepMinutes, 460);
      expect(s.sleepEnd, _t(29, 7));
    });

    test('an asleep-only source gives its span and total', () {
      final out = HealthAdapter.summarizeSleepNights([
        _seg(HealthDataType.SLEEP_ASLEEP, _t(28, 22, 30), _t(29, 6, 30)),
      ]);
      final s = out.values.single;
      expect(s.totalAsleepMinutes, 480);
      expect(s.deepMinutes, isNull);
      expect(s.sleepStart, _t(28, 22, 30));
      expect(s.sleepEnd, _t(29, 6, 30));
    });

    test('in-bed time does not add to asleep time', () {
      final out = HealthAdapter.summarizeSleepNights([
        _seg(HealthDataType.SLEEP_IN_BED, _t(28, 22, 30), _t(29, 6, 30)),
        _seg(HealthDataType.SLEEP_ASLEEP, _t(28, 23), _t(29, 6)),
      ]);
      expect(out.values.single.totalAsleepMinutes, 420);
    });

    test('in-bed time counts only when nothing says asleep', () {
      final out = HealthAdapter.summarizeSleepNights([
        _seg(HealthDataType.SLEEP_IN_BED, _t(28, 23), _t(29, 7)),
      ]);
      expect(out.values.single.totalAsleepMinutes, 480);
    });

    test('stages win over unstaged asleep and in-bed time', () {
      final out = HealthAdapter.summarizeSleepNights([
        _seg(HealthDataType.SLEEP_IN_BED, _t(28, 22, 30), _t(29, 7, 30)),
        _seg(HealthDataType.SLEEP_ASLEEP, _t(28, 23), _t(29, 7)),
        ...night,
      ]);
      expect(out.values.single.totalAsleepMinutes, 460);
    });

    test('an in-bed-only source gives the in-bed span', () {
      final out = HealthAdapter.summarizeSleepNights([
        _seg(HealthDataType.SLEEP_IN_BED, _t(28, 23), _t(29, 7)),
      ]);
      final s = out.values.single;
      expect(s.sleepStart, _t(28, 23));
      expect(s.sleepEnd, _t(29, 7));
    });

    test('latency is the gap from in-bed to the first asleep stage', () {
      final out = HealthAdapter.summarizeSleepNights([
        _seg(HealthDataType.SLEEP_AWAKE, _t(28, 22, 40), _t(28, 23)),
        ...night,
      ]);
      expect(out.values.single.sleepLatencyMinutes, 20);
      // The asleep span starts at sleep onset, not lights-out.
      expect(out.values.single.sleepStart, _t(28, 23));
    });
  });

  group('HealthAdapter.asleepMeanHr', () {
    final night = SleepNightSummary(
      totalAsleepMinutes: 480,
      awakeMinutes: 0,
      sleepStart: _t(28, 23),
      sleepEnd: _t(29, 7),
    );

    test('averages only the samples inside the asleep span', () {
      final samples = [
        (_t(28, 20), 95.0), // evening, awake
        for (var h = 0; h < 6; h++) (_t(29, h), 50.0 + h),
        (_t(29, 12), 110.0), // midday
      ];
      expect(HealthAdapter.asleepMeanHr(samples, night), closeTo(52.5, 1e-9));
    });

    test('is null with too few samples or no span', () {
      final few = [for (var h = 0; h < 5; h++) (_t(29, h), 50.0)];
      expect(HealthAdapter.asleepMeanHr(few, night), isNull);
      expect(
        HealthAdapter.asleepMeanHr([
          for (var h = 0; h < 6; h++) (_t(29, h), 50.0),
        ], const SleepNightSummary(totalAsleepMinutes: 480, awakeMinutes: 0)),
        isNull,
      );
      expect(HealthAdapter.asleepMeanHr(few, null), isNull);
    });
  });

  group('HealthAdapter.activeMinutesByDay', () {
    test('sums each record per local day', () {
      final out = HealthAdapter.activeMinutesByDay([
        _seg(HealthDataType.WORKOUT, _t(29, 7), _t(29, 7, 45)),
        _seg(HealthDataType.WORKOUT, _t(29, 18), _t(29, 18, 30)),
      ]);
      expect(out, {DateTime(2026, 10, 29): 75.0});
    });

    test('splits a session that crosses midnight', () {
      final out = HealthAdapter.activeMinutesByDay([
        _seg(HealthDataType.WORKOUT, _t(28, 23, 30), _t(29, 0, 20)),
      ]);
      expect(out, {DateTime(2026, 10, 28): 30.0, DateTime(2026, 10, 29): 20.0});
    });

    test('a day with no record is absent, not zero', () {
      expect(HealthAdapter.activeMinutesByDay(const []), isEmpty);
    });
  });
}
