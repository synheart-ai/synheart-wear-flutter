import 'dart:math' as math;
import 'dart:typed_data';

/// One accelerometer sample from a BLE chest strap, in m/s² (gravity
/// included), stamped on the phone clock.
class BleMotionSample {
  final int tsMs;
  final double x;
  final double y;
  final double z;

  const BleMotionSample({
    required this.tsMs,
    required this.x,
    required this.y,
    required this.z,
  });

  double get magnitude => math.sqrt(x * x + y * y + z * z);

  Map<String, dynamic> toMap() => {'tsMs': tsMs, 'x': x, 'y': y, 'z': z};

  @override
  String toString() => 'BleMotionSample(t=$tsMs, $x, $y, $z)';
}

/// One accelerometer frame as delivered by the strap: a batch of samples,
/// oldest first. Sample times are reconstructed from the frame's arrival
/// on the phone and the sampling rate (the last sample is stamped with the
/// arrival time), which keeps them on the same clock as the beat stream.
/// The strap's own timestamp travels alongside for diagnostics.
class BleMotionBatch {
  final List<BleMotionSample> samples;
  final int sampleRateHz;

  /// Phone clock, ms since epoch, when the frame arrived.
  final int arrivalMs;

  /// Strap clock for the last sample, ms since epoch, when the frame carries
  /// one; may drift from the phone by minutes and is not used for sample times.
  final int? deviceTimestampMs;

  /// Whether the frame was delta-compressed on the strap.
  final bool compressed;

  const BleMotionBatch({
    required this.samples,
    required this.sampleRateHz,
    required this.arrivalMs,
    this.deviceTimestampMs,
    this.compressed = false,
  });
}

/// Parser and commands for the measurement-data service that Polar chest
/// straps (H10, H9, Verity Sense) expose beside the standard heart-rate
/// service. Only the accelerometer stream is handled here.
///
/// Frame layout on the data characteristic: byte 0 measurement type,
/// bytes 1–8 device timestamp (uint64 LE, nanoseconds since 2000-01-01),
/// byte 9 frame type, then samples. Frame type 0x01 is three int16 per
/// sample (milli-g); 0x81 is the same with delta compression: one
/// reference sample, then blocks of (delta bit width, sample count, packed
/// little-endian signed deltas).
class PolarPmdAccel {
  PolarPmdAccel._();

  static const String serviceUuid = 'fb005c80-02e7-f387-1cad-8acd2d8df0c8';
  static const String controlPointUuid = 'fb005c81-02e7-f387-1cad-8acd2d8df0c8';
  static const String dataUuid = 'fb005c82-02e7-f387-1cad-8acd2d8df0c8';

  static const int measurementTypeAccel = 0x02;
  static const int _opStart = 0x02;
  static const int _opStop = 0x03;
  static const int _settingSampleRate = 0x00;
  static const int _settingResolution = 0x01;
  static const int _settingRange = 0x02;

  /// Milliseconds between the Unix epoch and 2000-01-01T00:00:00Z.
  static const int deviceEpochOffsetMs = 946684800000;

  static const double _milliGToMetersPerSecondSquared = 9.80665 / 1000.0;

  /// Control-point command starting the accelerometer at [sampleRateHz]
  /// (25, 50, 100 or 200 on the H10), 16-bit resolution, ±[rangeG] g.
  static Uint8List startCommand({int sampleRateHz = 50, int rangeG = 8}) {
    return Uint8List.fromList([
      _opStart,
      measurementTypeAccel,
      _settingSampleRate,
      0x01,
      sampleRateHz & 0xff,
      (sampleRateHz >> 8) & 0xff,
      _settingResolution,
      0x01,
      16,
      0x00,
      _settingRange,
      0x01,
      rangeG & 0xff,
      0x00,
    ]);
  }

  /// Control-point command stopping the accelerometer stream.
  static Uint8List stopCommand() =>
      Uint8List.fromList([_opStop, measurementTypeAccel]);

  /// Whether a control-point response acknowledges the start command.
  /// Response layout: 0xF0, op code, measurement type, status (0 = ok).
  static bool isStartAck(Uint8List response) =>
      response.length >= 4 &&
      response[0] == 0xF0 &&
      response[1] == _opStart &&
      response[2] == measurementTypeAccel &&
      response[3] == 0x00;

  /// Parse one data-characteristic frame. Returns `null` for frames of
  /// other measurement types, unsupported frame types, or truncated data.
  static BleMotionBatch? parseFrame(
    Uint8List bytes, {
    required int arrivalMs,
    required int sampleRateHz,
  }) {
    if (bytes.length < 10 || bytes[0] != measurementTypeAccel) return null;
    final bd = ByteData.sublistView(bytes);
    final deviceNs = bd.getUint64(1, Endian.little);
    final deviceMs = deviceEpochOffsetMs + deviceNs ~/ 1000000;
    final frameType = bytes[9];
    final payload = Uint8List.sublistView(bytes, 10);
    final List<List<int>> raw; // milli-g triples
    final compressed = (frameType & 0x80) != 0;
    switch (frameType & 0x7f) {
      case 0x01:
        raw = compressed
            ? _decodeDelta(payload, channels: 3, bytesPerValue: 2)
            : _decodePlain(payload, channels: 3, bytesPerValue: 2);
        break;
      case 0x00:
        raw = compressed
            ? _decodeDelta(payload, channels: 3, bytesPerValue: 1)
            : _decodePlain(payload, channels: 3, bytesPerValue: 1);
        break;
      default:
        return null;
    }
    if (raw.isEmpty) return null;
    final periodMs = 1000.0 / sampleRateHz;
    final n = raw.length;
    final samples = List<BleMotionSample>.generate(n, (k) {
      final v = raw[k];
      return BleMotionSample(
        tsMs: (arrivalMs - (n - 1 - k) * periodMs).round(),
        x: v[0] * _milliGToMetersPerSecondSquared,
        y: v[1] * _milliGToMetersPerSecondSquared,
        z: v[2] * _milliGToMetersPerSecondSquared,
      );
    });
    return BleMotionBatch(
      samples: samples,
      sampleRateHz: sampleRateHz,
      arrivalMs: arrivalMs,
      deviceTimestampMs: deviceMs,
      compressed: compressed,
    );
  }

  static int _readSigned(Uint8List b, int offset, int bytes) {
    var v = 0;
    for (var i = 0; i < bytes; i++) {
      v |= b[offset + i] << (8 * i);
    }
    final bits = 8 * bytes;
    if (v & (1 << (bits - 1)) != 0) v -= 1 << bits;
    return v;
  }

  static List<List<int>> _decodePlain(
    Uint8List payload, {
    required int channels,
    required int bytesPerValue,
  }) {
    final stride = channels * bytesPerValue;
    final out = <List<int>>[];
    for (var o = 0; o + stride <= payload.length; o += stride) {
      out.add(
        List<int>.generate(
          channels,
          (c) => _readSigned(payload, o + c * bytesPerValue, bytesPerValue),
        ),
      );
    }
    return out;
  }

  /// Delta decoding: a reference sample, then blocks of
  /// [delta bit width][sample count][packed deltas]. Deltas are signed,
  /// packed least-significant bit first across a little-endian byte stream,
  /// channel by channel within a sample.
  static List<List<int>> _decodeDelta(
    Uint8List payload, {
    required int channels,
    required int bytesPerValue,
  }) {
    final refBytes = channels * bytesPerValue;
    if (payload.length < refBytes) return const [];
    var prev = List<int>.generate(
      channels,
      (c) => _readSigned(payload, c * bytesPerValue, bytesPerValue),
    );
    final out = <List<int>>[prev];
    var o = refBytes;
    while (o + 2 <= payload.length) {
      final deltaBits = payload[o];
      final count = payload[o + 1];
      o += 2;
      if (deltaBits == 0 || deltaBits > 32) break;
      final totalBits = deltaBits * channels * count;
      final totalBytes = (totalBits + 7) ~/ 8;
      if (o + totalBytes > payload.length) break;
      var bitPos = 0;
      for (var s = 0; s < count; s++) {
        final cur = List<int>.filled(channels, 0);
        for (var c = 0; c < channels; c++) {
          var d = 0;
          for (var b = 0; b < deltaBits; b++) {
            final abs = bitPos + b;
            final bit = (payload[o + (abs >> 3)] >> (abs & 7)) & 1;
            d |= bit << b;
          }
          bitPos += deltaBits;
          if (d & (1 << (deltaBits - 1)) != 0) d -= 1 << deltaBits;
          cur[c] = prev[c] + d;
        }
        out.add(cur);
        prev = cur;
      }
      o += totalBytes;
    }
    return out;
  }
}
