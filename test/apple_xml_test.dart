// SPDX-License-Identifier: Apache-2.0

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:synheart_wear/synheart_wear.dart';

void main() {
  group('AppleHealthMetric.fromAppleIdentifier', () {
    test('maps known identifiers', () {
      expect(
        AppleHealthMetric.fromAppleIdentifier(
          'HKQuantityTypeIdentifierHeartRate',
        ),
        AppleHealthMetric.heartRate,
      );
      expect(
        AppleHealthMetric.fromAppleIdentifier(
          'HKQuantityTypeIdentifierHeartRateVariabilitySDNN',
        ),
        AppleHealthMetric.hrvSdnn,
      );
      expect(
        AppleHealthMetric.fromAppleIdentifier(
          'HKCategoryTypeIdentifierSleepAnalysis',
        ),
        AppleHealthMetric.sleepStage,
      );
    });

    test('returns null for unknown identifiers', () {
      expect(
        AppleHealthMetric.fromAppleIdentifier('HKWorkoutTypeIdentifier'),
        isNull,
      );
      expect(AppleHealthMetric.fromAppleIdentifier('garbage'), isNull);
    });

    test('raw values are pinned (do not change without migration)', () {
      // These strings are part of the SHA-256 idempotency key.
      // Renaming requires a backfill migration.
      expect(AppleHealthMetric.heartRate.raw, 'heart_rate');
      expect(AppleHealthMetric.hrvSdnn.raw, 'hrv_sdnn');
      expect(AppleHealthMetric.sleepStage.raw, 'sleep_stage');
    });
  });

  group('SleepStage.fromAppleValue', () {
    test('maps every known stage', () {
      expect(
        SleepStage.fromAppleValue('HKCategoryValueSleepAnalysisInBed'),
        SleepStage.inBed,
      );
      expect(
        SleepStage.fromAppleValue('HKCategoryValueSleepAnalysisAwake'),
        SleepStage.awake,
      );
      expect(
        SleepStage.fromAppleValue('HKCategoryValueSleepAnalysisAsleepCore'),
        SleepStage.light,
      );
      expect(
        SleepStage.fromAppleValue('HKCategoryValueSleepAnalysisAsleepDeep'),
        SleepStage.deep,
      );
      expect(
        SleepStage.fromAppleValue('HKCategoryValueSleepAnalysisAsleepREM'),
        SleepStage.rem,
      );
    });

    test('legacy and unspecified collapse to asleep', () {
      expect(
        SleepStage.fromAppleValue('HKCategoryValueSleepAnalysisAsleep'),
        SleepStage.asleep,
      );
      expect(
        SleepStage.fromAppleValue(
          'HKCategoryValueSleepAnalysisAsleepUnspecified',
        ),
        SleepStage.asleep,
      );
    });

    test('unknown enums return null', () {
      expect(SleepStage.fromAppleValue('HKCategoryValueFutureUnknown'), isNull);
    });
  });

  group('AppleHealthXmlParser', () {
    test('emits HR record from minimal valid XML', () async {
      const xml = '''<?xml version="1.0" encoding="UTF-8"?>
<HealthData locale="en_US">
  <Record type="HKQuantityTypeIdentifierHeartRate"
          sourceName="Apple Watch"
          unit="count/min"
          startDate="2026-04-29 22:14:33 -0700"
          endDate="2026-04-29 22:14:33 -0700"
          value="58"/>
</HealthData>''';

      final samples = <AppleHealthSample>[];
      final parser = AppleHealthXmlParser(onSample: samples.add);
      await parser.parse(Stream.value(utf8.encode(xml)));

      expect(parser.recordsSeen, 1);
      expect(parser.samplesEmitted, 1);
      expect(parser.samplesSkipped, 0);
      expect(samples, hasLength(1));

      final s = samples.single;
      expect(s.metric, AppleHealthMetric.heartRate);
      expect(s.source, 'Apple Watch');
      expect(s.value, const QuantityValue(58.0));
      // 2026-04-29 22:14:33 -0700 == 2026-04-30 05:14:33 UTC
      final expected = DateTime.utc(
        2026,
        4,
        30,
        5,
        14,
        33,
      ).millisecondsSinceEpoch;
      expect(s.startMs, expected);
    });

    test('emits sleep-stage record', () async {
      const xml = '''
<HealthData>
  <Record type="HKCategoryTypeIdentifierSleepAnalysis"
          sourceName="Apple Watch"
          startDate="2026-04-29 02:33:00 -0700"
          endDate="2026-04-29 03:14:00 -0700"
          value="HKCategoryValueSleepAnalysisAsleepREM"/>
</HealthData>''';

      final samples = <AppleHealthSample>[];
      final parser = AppleHealthXmlParser(onSample: samples.add);
      await parser.parse(Stream.value(utf8.encode(xml)));

      expect(samples.single.metric, AppleHealthMetric.sleepStage);
      expect(samples.single.value, const SleepStageValue(SleepStage.rem));
    });

    test('skips unknown record types silently', () async {
      const xml = '''
<HealthData>
  <Record type="HKWorkoutTypeIdentifier"
          startDate="2026-04-29 22:14:33 -0700"
          endDate="2026-04-29 22:14:33 -0700"
          value="42"/>
</HealthData>''';

      final samples = <AppleHealthSample>[];
      final unknowns = <String>[];
      final parser = AppleHealthXmlParser(
        onSample: samples.add,
        onUnknown: (t, _) => unknowns.add(t),
      );
      await parser.parse(Stream.value(utf8.encode(xml)));

      expect(samples, isEmpty);
      expect(parser.samplesSkipped, 1);
      expect(
        unknowns,
        isEmpty,
        reason: 'unmapped HK identifiers should not trigger onUnknown',
      );
    });

    test('reports unknown sleep stage via callback', () async {
      const xml = '''
<HealthData>
  <Record type="HKCategoryTypeIdentifierSleepAnalysis"
          startDate="2026-04-29 02:33:00 -0700"
          endDate="2026-04-29 03:14:00 -0700"
          value="HKCategoryValueSleepAnalysisFutureFunkyStage"/>
</HealthData>''';

      final samples = <AppleHealthSample>[];
      final unknowns = <(String, String)>[];
      final parser = AppleHealthXmlParser(
        onSample: samples.add,
        onUnknown: (t, r) => unknowns.add((t, r)),
      );
      await parser.parse(Stream.value(utf8.encode(xml)));

      expect(samples, isEmpty);
      expect(unknowns, hasLength(1));
      expect(unknowns.single.$2, contains('FutureFunkyStage'));
    });

    test('skips records with missing dates', () async {
      const xml = '''
<HealthData>
  <Record type="HKQuantityTypeIdentifierHeartRate" value="58"/>
</HealthData>''';

      final parser = AppleHealthXmlParser(onSample: (_) {});
      await parser.parse(Stream.value(utf8.encode(xml)));
      expect(parser.samplesSkipped, 1);
      expect(parser.samplesEmitted, 0);
    });

    test('handles multiple records in one document', () async {
      const xml = '''
<HealthData>
  <Record type="HKQuantityTypeIdentifierHeartRate"
          startDate="2026-04-29 22:14:33 -0700"
          endDate="2026-04-29 22:14:33 -0700"
          value="58"/>
  <Record type="HKQuantityTypeIdentifierHeartRate"
          startDate="2026-04-29 22:15:33 -0700"
          endDate="2026-04-29 22:15:33 -0700"
          value="60"/>
  <Record type="HKQuantityTypeIdentifierStepCount"
          startDate="2026-04-29 22:00:00 -0700"
          endDate="2026-04-29 22:30:00 -0700"
          value="143"/>
</HealthData>''';

      final samples = <AppleHealthSample>[];
      final parser = AppleHealthXmlParser(onSample: samples.add);
      await parser.parse(Stream.value(utf8.encode(xml)));

      expect(samples, hasLength(3));
      expect(parser.recordsSeen, 3);
      expect(parser.samplesEmitted, 3);
    });

    test('handles negative timezone offsets', () async {
      const xml = '''
<HealthData>
  <Record type="HKQuantityTypeIdentifierHeartRate"
          startDate="2026-04-29 22:14:33 -0500"
          endDate="2026-04-29 22:14:33 -0500"
          value="58"/>
</HealthData>''';

      final samples = <AppleHealthSample>[];
      final parser = AppleHealthXmlParser(onSample: samples.add);
      await parser.parse(Stream.value(utf8.encode(xml)));

      // -0500 → 5 hours behind UTC, so local 22:14:33 = UTC 03:14:33 next day
      final expected = DateTime.utc(
        2026,
        4,
        30,
        3,
        14,
        33,
      ).millisecondsSinceEpoch;
      expect(samples.single.startMs, expected);
    });
  });

  group('IdempotencyKey', () {
    test('same sample → same key', () {
      const sample = AppleHealthSample(
        metric: AppleHealthMetric.heartRate,
        source: 'Apple Watch',
        startMs: 1714435000000,
        endMs: 1714435000000,
        value: QuantityValue(58.0),
      );

      final k1 = IdempotencyKey.forSample(sample);
      final k2 = IdempotencyKey.forSample(sample);
      expect(k1, k2);
      expect(k1.length, 32, reason: 'SHA-256 must be 32 bytes');
    });

    test('different timestamp → different key', () {
      const a = AppleHealthSample(
        metric: AppleHealthMetric.heartRate,
        source: 'Apple Watch',
        startMs: 1714435000000,
        endMs: 1714435000000,
        value: QuantityValue(58.0),
      );
      const b = AppleHealthSample(
        metric: AppleHealthMetric.heartRate,
        source: 'Apple Watch',
        startMs: 1714435060000,
        endMs: 1714435060000,
        value: QuantityValue(58.0),
      );
      expect(IdempotencyKey.forSample(a), isNot(IdempotencyKey.forSample(b)));
    });

    test('different value → different key', () {
      const a = AppleHealthSample(
        metric: AppleHealthMetric.heartRate,
        source: 'Apple Watch',
        startMs: 1714435000000,
        endMs: 1714435000000,
        value: QuantityValue(58.0),
      );
      const b = AppleHealthSample(
        metric: AppleHealthMetric.heartRate,
        source: 'Apple Watch',
        startMs: 1714435000000,
        endMs: 1714435000000,
        value: QuantityValue(59.0),
      );
      expect(IdempotencyKey.forSample(a), isNot(IdempotencyKey.forSample(b)));
    });

    test('hex form has 64 lowercase chars', () {
      const sample = AppleHealthSample(
        metric: AppleHealthMetric.sleepStage,
        source: 'Apple Watch',
        startMs: 1714435000000,
        endMs: 1714437000000,
        value: SleepStageValue(SleepStage.deep),
      );
      final hex = IdempotencyKey.hexForSample(sample);
      expect(hex.length, 64);
      expect(RegExp(r'^[0-9a-f]+$').hasMatch(hex), isTrue);
    });

    test('orchestrator opens, batches, and finalizes', () async {
      const xml = '''
<HealthData>
  <Record type="HKQuantityTypeIdentifierHeartRate"
          sourceName="Apple Watch"
          startDate="2026-04-29 22:14:33 -0700"
          endDate="2026-04-29 22:14:33 -0700"
          value="58"/>
  <Record type="HKQuantityTypeIdentifierStepCount"
          sourceName="iPhone"
          startDate="2026-04-29 22:00:00 -0700"
          endDate="2026-04-29 22:30:00 -0700"
          value="143"/>
</HealthData>''';

      final sink = RecordingIngestSink();
      final importer = AppleHealthXmlImport(
        xmlBytes: Stream.value(utf8.encode(xml)),
        sink: sink,
        importId: 'test-orch-001',
      );
      final result = await importer.parse();

      expect(sink.openedImportId, 'test-orch-001');
      expect(sink.finalized, isTrue);
      expect(result.importId, 'test-orch-001');
      expect(result.totalSamples, 2);
      expect(result.inserted, 2);
      expect(sink.distinctKeyCount, 2);
    });

    test('orchestrator reports final progress 1.0', () async {
      const xml = '''
<HealthData>
  <Record type="HKQuantityTypeIdentifierHeartRate"
          startDate="2026-04-29 22:14:33 -0700"
          endDate="2026-04-29 22:14:33 -0700"
          value="58"/>
</HealthData>''';
      final sink = RecordingIngestSink();
      final importer = AppleHealthXmlImport(
        xmlBytes: Stream.value(utf8.encode(xml)),
        sink: sink,
        importId: 'test-progress',
      );
      double last = -1;
      await importer.parse(onProgress: (p) => last = p);
      expect(last, 1.0);
    });

    test('orchestrator autogenerates importId when not given', () async {
      final sink = RecordingIngestSink();
      final importer = AppleHealthXmlImport(
        xmlBytes: Stream.value(utf8.encode('<HealthData></HealthData>')),
        sink: sink,
      );
      expect(importer.importId, isNotEmpty);
      expect(importer.importId.length, 36, reason: 'UUIDv4 = 36 chars');
    });

    test('canonical key for a fixed sample is pinned cross-platform', () {
      // If this hash drifts, the Swift implementation MUST drift in
      // lockstep — they have to agree byte-for-byte, otherwise the
      // same export.zip imported on iOS vs Android would create
      // duplicate runtime artifacts.
      //
      // Canonical input string:
      //   "heart_rate|Apple Watch|1714435000000|1714435000000|58.000000"
      const sample = AppleHealthSample(
        metric: AppleHealthMetric.heartRate,
        source: 'Apple Watch',
        startMs: 1714435000000,
        endMs: 1714435000000,
        value: QuantityValue(58.0),
      );
      const expected =
          'c041fb8df9fd751704ade89b8f07368393182bd97e2cbcbeb05fc37eb48e88d9';
      expect(IdempotencyKey.hexForSample(sample), expected);
    });
  });
}
