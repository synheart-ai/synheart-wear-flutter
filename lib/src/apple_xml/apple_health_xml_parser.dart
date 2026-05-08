// SPDX-License-Identifier: Apache-2.0
//
// Streaming XML parser for Apple Health's `export.xml`.
//
// Why streaming: a 5-year export.xml can be 500MB+ unzipped. Loading
// it as a DOM blows past the 200MB memory budget quoted in the RFC.
//
// Uses `package:xml`'s `XmlEventDecoder` so we never materialize the
// whole tree. Parses Apple's `2026-04-29 22:14:33 -0700` timestamps
// without `intl` (which would balloon the dependency footprint).

import 'dart:async';
import 'dart:convert';

import 'package:xml/xml.dart' show XmlParserException;
import 'package:xml/xml_events.dart';

import 'apple_health_xml_types.dart';

/// Callback invoked for each successfully-mapped sample.
typedef SampleHandler = void Function(AppleHealthSample sample);

/// Callback invoked when an element was a known record type but
/// could not be mapped (unknown sleep enum, missing required
/// attribute). Useful for diagnostics.
typedef UnknownHandler = void Function(String type, String reason);

/// Streaming parser for Apple Health `export.xml`.
///
/// Single-shot: create one instance per import.
class AppleHealthXmlParser {
  AppleHealthXmlParser({required this.onSample, this.onUnknown});

  final SampleHandler onSample;
  final UnknownHandler? onUnknown;

  /// Total `<Record>` elements observed (including those skipped).
  int get recordsSeen => _recordsSeen;
  int _recordsSeen = 0;

  /// Records emitted to [onSample].
  int get samplesEmitted => _samplesEmitted;
  int _samplesEmitted = 0;

  /// Records skipped because the type was unknown or the record was
  /// malformed.
  int get samplesSkipped => _samplesSkipped;
  int _samplesSkipped = 0;

  /// Parse an `export.xml` byte stream. The stream is consumed
  /// element-by-element; backpressure is preserved so the caller can
  /// throttle ingest if needed.
  ///
  /// Throws [ParseFailed] on malformed XML.
  Future<void> parse(Stream<List<int>> bytes) async {
    final eventStream = bytes
        .transform(utf8.decoder)
        .toXmlEvents()
        .normalizeEvents()
        .selectSubtreeEvents((event) => event.name == 'Record')
        .flatten();

    try {
      await for (final event in eventStream) {
        if (event is XmlStartElementEvent && event.name == 'Record') {
          _handleRecord(event);
        }
      }
    } on XmlParserException catch (e) {
      throw ParseFailed(e.line, e.column, e.message);
    }
  }

  void _handleRecord(XmlStartElementEvent event) {
    _recordsSeen += 1;

    final attrs = <String, String>{
      for (final a in event.attributes) a.name: a.value,
    };

    final typeStr = attrs['type'];
    if (typeStr == null) {
      _samplesSkipped += 1;
      onUnknown?.call('<missing type>', 'no type attribute');
      return;
    }

    final metric = AppleHealthMetric.fromAppleIdentifier(typeStr);
    if (metric == null) {
      // Most exports contain dozens of HK identifiers we deliberately
      // ignore. Skipping silently to keep onUnknown signal-rich.
      _samplesSkipped += 1;
      return;
    }

    final startStr = attrs['startDate'];
    final endStr = attrs['endDate'];
    final startMs = startStr == null ? null : _parseAppleDate(startStr);
    final endMs = endStr == null ? null : _parseAppleDate(endStr);
    if (startMs == null || endMs == null) {
      _samplesSkipped += 1;
      onUnknown?.call(typeStr, 'unparseable startDate/endDate');
      return;
    }

    final source = attrs['sourceName'] ?? 'unknown';

    final SampleValue value;
    if (metric == AppleHealthMetric.sleepStage) {
      final raw = attrs['value'];
      final stage = raw == null ? null : SleepStage.fromAppleValue(raw);
      if (stage == null) {
        _samplesSkipped += 1;
        onUnknown?.call(typeStr, 'unknown sleep value: ${raw ?? "<nil>"}');
        return;
      }
      value = SleepStageValue(stage);
    } else {
      final raw = attrs['value'];
      final v = raw == null ? null : double.tryParse(raw);
      if (v == null || !v.isFinite) {
        _samplesSkipped += 1;
        onUnknown?.call(
          typeStr,
          'unparseable numeric value: ${raw ?? "<nil>"}',
        );
        return;
      }
      value = QuantityValue(v);
    }

    _samplesEmitted += 1;
    onSample(
      AppleHealthSample(
        metric: metric,
        source: source,
        startMs: startMs,
        endMs: endMs,
        value: value,
      ),
    );
  }

  /// Parse Apple's date format: `yyyy-MM-dd HH:mm:ss ±HHMM`.
  /// Returns unix epoch milliseconds, or `null` on parse failure.
  ///
  /// Hand-rolled because pulling in `intl` for one date format is
  /// overkill, and `DateTime.tryParse` doesn't accept the trailing
  /// `±HHMM` zone form.
  static int? _parseAppleDate(String s) {
    // Expected length: "2026-04-29 22:14:33 -0700" → 25 chars.
    // Be tolerant of single-digit timezone offsets just in case.
    if (s.length < 24) return null;

    final year = int.tryParse(s.substring(0, 4));
    final month = int.tryParse(s.substring(5, 7));
    final day = int.tryParse(s.substring(8, 10));
    final hour = int.tryParse(s.substring(11, 13));
    final minute = int.tryParse(s.substring(14, 16));
    final second = int.tryParse(s.substring(17, 19));
    if (year == null ||
        month == null ||
        day == null ||
        hour == null ||
        minute == null ||
        second == null) {
      return null;
    }

    // Timezone: `[20..]` should be "+HHMM" or "-HHMM".
    final tzSection = s.substring(20).trim();
    if (tzSection.length < 5) return null;
    final sign = tzSection[0] == '-' ? -1 : 1;
    final tzHours = int.tryParse(tzSection.substring(1, 3));
    final tzMinutes = int.tryParse(tzSection.substring(3, 5));
    if (tzHours == null || tzMinutes == null) return null;
    final tzOffsetMin = sign * (tzHours * 60 + tzMinutes);

    final utcMs = DateTime.utc(
      year,
      month,
      day,
      hour,
      minute,
      second,
    ).millisecondsSinceEpoch;
    return utcMs - tzOffsetMin * 60 * 1000;
  }
}
