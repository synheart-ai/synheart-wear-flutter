import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:synheart_wear/src/adapters/ble_motion_models.dart';

Uint8List _header({int type = 0x02, int frameType = 0x01, int deviceNs = 0}) {
  final b = ByteData(10);
  b.setUint8(0, type);
  b.setUint64(1, deviceNs, Endian.little);
  b.setUint8(9, frameType);
  return b.buffer.asUint8List();
}

Uint8List _int16le(List<int> values) {
  final b = ByteData(values.length * 2);
  for (var i = 0; i < values.length; i++) {
    b.setInt16(i * 2, values[i], Endian.little);
  }
  return b.buffer.asUint8List();
}

/// Pack signed deltas of [bits] width, LSB first, into a byte stream.
Uint8List _packDeltas(List<int> deltas, int bits) {
  final total = deltas.length * bits;
  final out = Uint8List((total + 7) ~/ 8);
  var pos = 0;
  for (final d in deltas) {
    final u = d & ((1 << bits) - 1);
    for (var b = 0; b < bits; b++) {
      if ((u >> b) & 1 == 1) out[pos >> 3] |= 1 << (pos & 7);
      pos++;
    }
  }
  return out;
}

void main() {
  group('PolarPmdAccel', () {
    test('start command carries rate, 16-bit resolution and 8 g range', () {
      final cmd = PolarPmdAccel.startCommand(sampleRateHz: 200);
      expect(cmd, [
        0x02, 0x02, //
        0x00, 0x01, 0xC8, 0x00, //
        0x01, 0x01, 0x10, 0x00, //
        0x02, 0x01, 0x08, 0x00,
      ]);
      expect(
        PolarPmdAccel.isStartAck(Uint8List.fromList([0xF0, 0x02, 0x02, 0x00])),
        isTrue,
      );
      expect(
        PolarPmdAccel.isStartAck(Uint8List.fromList([0xF0, 0x02, 0x02, 0x05])),
        isFalse,
      );
    });

    test('plain 16-bit frame: samples in m/s², times back from arrival', () {
      // Three samples of a still strap: gravity on z (1000 mg).
      final frame = Uint8List.fromList([
        ..._header(deviceNs: 5_000_000_000), // 5 s after the device epoch
        ..._int16le([0, 0, 1000, 10, -10, 1000, 0, 0, 1005]),
      ]);
      final batch = PolarPmdAccel.parseFrame(
        frame,
        arrivalMs: 1_700_000_000_000,
        sampleRateHz: 50,
      );
      expect(batch, isNotNull);
      expect(batch!.samples.length, 3);
      expect(batch.compressed, isFalse);
      expect(
        batch.deviceTimestampMs,
        PolarPmdAccel.deviceEpochOffsetMs + 5_000,
      );
      expect(batch.samples.last.tsMs, 1_700_000_000_000);
      expect(batch.samples.first.tsMs, 1_700_000_000_000 - 40);
      expect(batch.samples.first.z, closeTo(9.80665, 1e-9));
      expect(batch.samples[1].x, closeTo(0.0980665, 1e-9));
      expect(batch.samples.first.magnitude, closeTo(9.80665, 1e-9));
    });

    test('delta-compressed frame decodes reference plus signed deltas', () {
      // Reference (12, -7, 1000), then two blocks: 4-bit deltas × 2 samples,
      // 6-bit deltas × 1 sample.
      final deltasA = [
        1,
        -2,
        3,
        -8,
        7,
        0,
      ]; // sample 1: (+1,-2,+3), sample 2: (-8,+7,0)
      final deltasB = [-31, 31, -1];
      final frame = Uint8List.fromList([
        ..._header(frameType: 0x81),
        ..._int16le([12, -7, 1000]),
        4,
        2,
        ..._packDeltas(deltasA, 4),
        6,
        1,
        ..._packDeltas(deltasB, 6),
      ]);
      final batch = PolarPmdAccel.parseFrame(
        frame,
        arrivalMs: 10_000,
        sampleRateHz: 25,
      );
      expect(batch, isNotNull);
      expect(batch!.compressed, isTrue);
      final mg = batch.samples
          .map(
            (s) => [
              (s.x / (9.80665 / 1000)).round(),
              (s.y / (9.80665 / 1000)).round(),
              (s.z / (9.80665 / 1000)).round(),
            ],
          )
          .toList();
      expect(mg, [
        [12, -7, 1000],
        [13, -9, 1003],
        [5, -2, 1003],
        [-26, 29, 1002],
      ]);
      expect(batch.samples.map((s) => s.tsMs).toList(), [
        9_880,
        9_920,
        9_960,
        10_000,
      ]);
    });

    test('other measurement types and short frames are ignored', () {
      expect(
        PolarPmdAccel.parseFrame(
          Uint8List.fromList([0x00, 1, 2]),
          arrivalMs: 0,
          sampleRateHz: 50,
        ),
        isNull,
      );
      final ecg = Uint8List.fromList([..._header(type: 0x00), 1, 2, 3]);
      expect(
        PolarPmdAccel.parseFrame(ecg, arrivalMs: 0, sampleRateHz: 50),
        isNull,
      );
      final unknown = Uint8List.fromList([
        ..._header(frameType: 0x05),
        1,
        2,
        3,
        4,
        5,
        6,
      ]);
      expect(
        PolarPmdAccel.parseFrame(unknown, arrivalMs: 0, sampleRateHz: 50),
        isNull,
      );
    });
  });
}
