// SPDX-License-Identifier: Apache-2.0
//
// SHA-256 idempotency key for backfill samples.
//
// **MUST stay byte-for-byte compatible with**:
//   `synheart-wear-swift/Sources/AppleXmlImport/IdempotencyKey.swift`
//
// The same sample, hashed in either Swift or Dart, must produce the
// same 32-byte digest. Otherwise re-imports of the same export.zip
// from different platforms would create duplicates in the runtime.
//
// See the Apple Health XML import spec for the
// canonical key recipe.

import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import 'apple_health_xml_types.dart';

class IdempotencyKey {
  IdempotencyKey._();

  /// Compute the 32-byte SHA-256 idempotency key for a sample.
  static Uint8List forSample(AppleHealthSample sample) {
    final canonical = _canonicalString(sample);
    return Uint8List.fromList(sha256.convert(utf8.encode(canonical)).bytes);
  }

  /// Hex string for logs and debug. Avoid as the storage key — the
  /// raw bytes are half the size.
  static String hexForSample(AppleHealthSample sample) {
    final bytes = forSample(sample);
    final sb = StringBuffer();
    for (final b in bytes) {
      sb.write(b.toRadixString(16).padLeft(2, '0'));
    }
    return sb.toString();
  }

  static String _canonicalString(AppleHealthSample sample) {
    return '${sample.metric.raw}'
        '|${sample.source}'
        '|${sample.startMs}'
        '|${sample.endMs}'
        '|${_canonicalValue(sample.value)}';
  }

  static String _canonicalValue(SampleValue v) {
    if (v is QuantityValue) {
      return v.value.toStringAsFixed(6);
    } else if (v is SleepStageValue) {
      return v.stage.raw;
    }
    throw StateError('unhandled SampleValue: $v');
  }
}
