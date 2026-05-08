// SPDX-License-Identifier: Apache-2.0
//
// Public types for the Apple Health XML backfill import path.
//
// Mirrors `synheart-wear-swift`'s `AppleHealthXmlTypes.swift` so that
// idempotency keys computed on either platform are bit-for-bit
// identical and the runtime never sees a duplicate just because the
// same export was imported from two devices.

import 'package:meta/meta.dart';

/// Subset of HealthKit identifiers we import in v1.
///
/// The string form (`raw`) is also the canonical metric identifier
/// used in the SHA-256 idempotency key. It must not change without a
/// migration.
enum AppleHealthMetric {
  heartRate('heart_rate'),
  // Apple's vendor-computed daily resting HR. Distinct from
  // `heartRate` (which is the per-second/per-minute stream): Apple's
  // sleep classifier picks the lowest stable HR window per night and
  // publishes it as a single `HKQuantityTypeIdentifierRestingHeartRate`
  // sample. When we have these, prefer them over the proxy filter
  // (lowest 10% of `heartRate`) for the SRM `resting_hr` baseline.
  restingHeartRate('resting_heart_rate'),
  hrvSdnn('hrv_sdnn'),
  steps('steps'),
  calories('calories'),
  spo2('spo2'),
  temperature('temperature'),
  sleepStage('sleep_stage');

  const AppleHealthMetric(this.raw);

  final String raw;

  /// Map an Apple `type` attribute to our metric. Returns `null` for
  /// identifiers we don't import in v1 (workouts, ECG, etc.).
  static AppleHealthMetric? fromAppleIdentifier(String id) {
    switch (id) {
      case 'HKQuantityTypeIdentifierHeartRate':
        return AppleHealthMetric.heartRate;
      case 'HKQuantityTypeIdentifierRestingHeartRate':
        return AppleHealthMetric.restingHeartRate;
      case 'HKQuantityTypeIdentifierHeartRateVariabilitySDNN':
        return AppleHealthMetric.hrvSdnn;
      case 'HKQuantityTypeIdentifierStepCount':
        return AppleHealthMetric.steps;
      case 'HKQuantityTypeIdentifierActiveEnergyBurned':
        return AppleHealthMetric.calories;
      case 'HKQuantityTypeIdentifierOxygenSaturation':
        return AppleHealthMetric.spo2;
      case 'HKQuantityTypeIdentifierBodyTemperature':
        return AppleHealthMetric.temperature;
      case 'HKCategoryTypeIdentifierSleepAnalysis':
        return AppleHealthMetric.sleepStage;
      default:
        return null;
    }
  }
}

/// Sleep stage values. Apple has revised these enums multiple times;
/// we accept the union of known values.
enum SleepStage {
  inBed('inBed'),
  asleep('asleep'),
  awake('awake'),
  light('light'),
  deep('deep'),
  rem('rem');

  const SleepStage(this.raw);

  final String raw;

  static SleepStage? fromAppleValue(String s) {
    switch (s) {
      case 'HKCategoryValueSleepAnalysisInBed':
        return SleepStage.inBed;
      case 'HKCategoryValueSleepAnalysisAsleep':
      case 'HKCategoryValueSleepAnalysisAsleepUnspecified':
        return SleepStage.asleep;
      case 'HKCategoryValueSleepAnalysisAwake':
        return SleepStage.awake;
      case 'HKCategoryValueSleepAnalysisAsleepCore':
        return SleepStage.light;
      case 'HKCategoryValueSleepAnalysisAsleepDeep':
        return SleepStage.deep;
      case 'HKCategoryValueSleepAnalysisAsleepREM':
        return SleepStage.rem;
      default:
        return null;
    }
  }
}

/// Sealed-ish value union for the `value` attribute of a record.
@immutable
sealed class SampleValue {
  const SampleValue();
}

class QuantityValue extends SampleValue {
  const QuantityValue(this.value);
  final double value;

  @override
  bool operator ==(Object other) =>
      other is QuantityValue && other.value == value;

  @override
  int get hashCode => value.hashCode;
}

class SleepStageValue extends SampleValue {
  const SleepStageValue(this.stage);
  final SleepStage stage;

  @override
  bool operator ==(Object other) =>
      other is SleepStageValue && other.stage == stage;

  @override
  int get hashCode => stage.hashCode;
}

/// A single sample parsed from `export.xml`.
///
/// Crosses the boundary from the Dart parser into the runtime
/// (eventually via FFI). Values are normalized to ms-precision unix
/// timestamps and SI units.
@immutable
class AppleHealthSample {
  const AppleHealthSample({
    required this.metric,
    required this.source,
    required this.startMs,
    required this.endMs,
    required this.value,
  });

  final AppleHealthMetric metric;
  final String source;
  final int startMs;
  final int endMs;
  final SampleValue value;

  @override
  bool operator ==(Object other) =>
      other is AppleHealthSample &&
      other.metric == metric &&
      other.source == source &&
      other.startMs == startMs &&
      other.endMs == endMs &&
      other.value == value;

  @override
  int get hashCode => Object.hash(metric, source, startMs, endMs, value);
}

/// Result returned to the calling app at the end of an import.
@immutable
class ImportResult {
  const ImportResult({
    required this.importId,
    required this.totalSamples,
    required this.inserted,
    required this.skippedAsDuplicate,
    required this.skippedAsUnknown,
    required this.durationMs,
  });

  final String importId;
  final int totalSamples;
  final int inserted;
  final int skippedAsDuplicate;
  final int skippedAsUnknown;
  final int durationMs;
}

/// Errors thrown by the public import API.
sealed class AppleHealthXmlError implements Exception {
  const AppleHealthXmlError(this.message);
  final String message;

  @override
  String toString() => 'AppleHealthXmlError: $message';
}

class ZipReadFailed extends AppleHealthXmlError {
  const ZipReadFailed(super.message);
}

class XmlNotFound extends AppleHealthXmlError {
  const XmlNotFound() : super('export.xml not found in archive');
}

class ParseFailed extends AppleHealthXmlError {
  const ParseFailed(this.line, this.column, super.message);
  final int line;
  final int column;
}

class IngestFailed extends AppleHealthXmlError {
  const IngestFailed(super.message);
}

class ImportCancelled extends AppleHealthXmlError {
  const ImportCancelled() : super('import was cancelled');
}
