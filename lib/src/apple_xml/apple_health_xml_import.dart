// SPDX-License-Identifier: Apache-2.0
//
// Top-level orchestrator for Apple Health XML backfill on Dart.
//
// Mirrors `AppleHealthXmlImport.swift` in `synheart-wear-swift`. The
// orchestrator drives the streaming parser, batches samples, and
// hands them to an `AppleXmlIngestSink` (typically a runtime FFI
// bridge in production; a recording sink in tests).
//
// Stays decoupled from FFI via the `AppleXmlIngestSink` abstract
// class so unit tests don't need to link the runtime.

import 'dart:async';

import 'package:meta/meta.dart';
import 'package:uuid/uuid.dart';

import 'apple_health_xml_parser.dart';
import 'apple_health_xml_types.dart';
import 'idempotency_key.dart';

/// Result of a sink batch.
@immutable
class BatchResult {
  const BatchResult({required this.inserted, required this.skipped});
  final int inserted;
  final int skipped;
}

/// Receives batches of parsed samples. Concrete implementations push
/// into the runtime; the test sink just records.
abstract class AppleXmlIngestSink {
  Future<void> open(String importId);
  Future<BatchResult> insertBatch(List<AppleHealthSample> samples);
  Future<ImportResult> finalize();
}

/// Top-level entry point. Apps construct this with a stream of
/// `export.xml` bytes (from `dart:io`'s `File.openRead()` or
/// equivalent) and a sink, then call `parse()`.
///
/// The orchestrator does not handle zip extraction — that lives in
/// platform-specific glue so this file stays free of platform deps
/// and is unit-testable with raw XML byte streams.
class AppleHealthXmlImport {
  AppleHealthXmlImport({
    required this.xmlBytes,
    required this.sink,
    String? importId,
  }) : importId = importId ?? const Uuid().v4();

  /// Stream of bytes for `export.xml`.
  final Stream<List<int>> xmlBytes;
  final AppleXmlIngestSink sink;
  final String importId;

  static const int _batchSize = 1000;

  /// Parse, batch, and ingest. Returns the runtime's tally (with our
  /// own counts as a fallback if the sink under-reports).
  Future<ImportResult> parse({
    void Function(double progress)? onProgress,
  }) async {
    final stopwatch = Stopwatch()..start();
    await sink.open(importId);

    var batch = <AppleHealthSample>[];
    var totalInserted = 0;
    var totalSkipped = 0;
    var totalSeen = 0;
    Object? sinkError;

    final parser = AppleHealthXmlParser(
      onSample: (sample) {
        if (sinkError != null) return;
        batch.add(sample);
        totalSeen += 1;
      },
    );

    try {
      // Drive the parse to completion. We can't flush mid-parse from
      // a synchronous callback, so we rely on the in-memory batch
      // building up and flush whenever it crosses the threshold —
      // here we do it after the parse completes, and rely on memory
      // headroom for very large exports. (Streaming flush mid-parse
      // would require Stream-based iteration; v1 is "parse then
      // batch-flush" since the SAX events are already streamed and
      // memory cost is one parsed sample at a time.)
      await parser.parse(xmlBytes);

      // Flush in chunks of `_batchSize`.
      while (batch.length >= _batchSize && sinkError == null) {
        final chunk = batch.sublist(0, _batchSize);
        batch = batch.sublist(_batchSize);
        try {
          final r = await sink.insertBatch(chunk);
          totalInserted += r.inserted;
          totalSkipped += r.skipped;
        } catch (e) {
          sinkError = e;
        }
      }
      // Flush the tail.
      if (batch.isNotEmpty && sinkError == null) {
        try {
          final r = await sink.insertBatch(batch);
          totalInserted += r.inserted;
          totalSkipped += r.skipped;
          batch = <AppleHealthSample>[];
        } catch (e) {
          sinkError = e;
        }
      }
    } catch (e) {
      sinkError = e;
    }

    final runtimeResult = await sink.finalize();
    if (sinkError != null) {
      throw sinkError;
    }

    onProgress?.call(1.0);

    final inserted = runtimeResult.inserted >= totalInserted
        ? runtimeResult.inserted
        : totalInserted;
    final skipped = runtimeResult.skippedAsDuplicate >= totalSkipped
        ? runtimeResult.skippedAsDuplicate
        : totalSkipped;
    final total = runtimeResult.totalSamples >= totalSeen
        ? runtimeResult.totalSamples
        : totalSeen;

    return ImportResult(
      importId: runtimeResult.importId,
      totalSamples: total,
      inserted: inserted,
      skippedAsDuplicate: skipped,
      skippedAsUnknown: parser.samplesSkipped,
      durationMs: stopwatch.elapsedMilliseconds,
    );
  }
}

/// Captures every batch in memory. For unit tests that want to
/// verify the orchestrator without linking the runtime.
class RecordingIngestSink implements AppleXmlIngestSink {
  RecordingIngestSink();

  String? openedImportId;
  final List<List<AppleHealthSample>> batches = [];
  bool finalized = false;

  @override
  Future<void> open(String importId) async {
    openedImportId = importId;
  }

  @override
  Future<BatchResult> insertBatch(List<AppleHealthSample> samples) async {
    batches.add(List.unmodifiable(samples));
    // Return all-inserted; the orchestrator unit tests don't depend
    // on per-batch dedupe counts (those are tested in the runtime).
    return BatchResult(inserted: samples.length, skipped: 0);
  }

  @override
  Future<ImportResult> finalize() async {
    finalized = true;
    final total = batches.fold<int>(0, (acc, b) => acc + b.length);
    return ImportResult(
      importId: openedImportId ?? '',
      totalSamples: total,
      inserted: total,
      skippedAsDuplicate: 0,
      skippedAsUnknown: 0,
      durationMs: 0,
    );
  }

  /// Sum of unique canonical keys across all recorded batches.
  /// Useful for tests verifying the parser produced the expected
  /// number of distinct samples.
  int get distinctKeyCount {
    final seen = <String>{};
    for (final batch in batches) {
      for (final s in batch) {
        seen.add(IdempotencyKey.hexForSample(s));
      }
    }
    return seen.length;
  }
}
