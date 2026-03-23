// google.protobuf.Timestamp — wire-format compatible with server (seconds + nanos).

import 'dart:core' as $core;
import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;

class Timestamp extends $pb.GeneratedMessage {
  factory Timestamp() => create();
  Timestamp._() : super();
  factory Timestamp.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo('Timestamp',
      package: const $pb.PackageName('google.protobuf'),
      createEmptyInstance: create)
    ..aInt64(1, 'seconds')
    ..aInt64(2, 'nanos')
    ..hasRequiredFields = false;

  $pb.BuilderInfo get info_ => _i;
  static Timestamp create() => Timestamp._();
  Timestamp createEmptyInstance() => create();
  Timestamp clone() => Timestamp()..mergeFromMessage(this);
  static $pb.PbList<Timestamp> createRepeated() => $pb.PbList<Timestamp>();
  static Timestamp getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Timestamp>(create);
  static Timestamp? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get seconds => $_getI64(0);
  @$pb.TagNumber(1)
  set seconds($fixnum.Int64 v) => $_setInt64(0, v);

  @$pb.TagNumber(2)
  $core.int get nanos => $_getI64(1).toInt();
  @$pb.TagNumber(2)
  set nanos($core.int v) => $_setInt64(1, $fixnum.Int64(v));

  /// Creates a Timestamp from [dateTime]. Uses UTC.
  static Timestamp fromDateTime($core.DateTime dateTime) {
    final utc = dateTime.toUtc();
    final millis = utc.millisecondsSinceEpoch;
    return Timestamp()
      ..seconds = $fixnum.Int64(millis ~/ 1000)
      ..nanos = (millis % 1000) * 1000000;
  }

  /// Converts this Timestamp to DateTime (UTC).
  $core.DateTime toDateTime() {
    final millis = seconds.toInt() * 1000 + (nanos / 1000000).floor();
    return $core.DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
  }
}
