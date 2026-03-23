// Synheart RAMEN Service — Protobuf enums (ramen.v1)

import 'dart:core' as $core;
import 'package:protobuf/protobuf.dart' as $pb;

class AckStatus extends $pb.ProtobufEnum {
  static const AckStatus ACK_STATUS_UNSPECIFIED = AckStatus._(0, 'ACK_STATUS_UNSPECIFIED');
  static const AckStatus ACK_STATUS_SUCCESS = AckStatus._(1, 'ACK_STATUS_SUCCESS');
  static const AckStatus ACK_STATUS_FAILED = AckStatus._(2, 'ACK_STATUS_FAILED');
  static const AckStatus ACK_STATUS_SKIPPED = AckStatus._(3, 'ACK_STATUS_SKIPPED');

  static const $core.List<AckStatus> values = <AckStatus>[
    ACK_STATUS_UNSPECIFIED,
    ACK_STATUS_SUCCESS,
    ACK_STATUS_FAILED,
    ACK_STATUS_SKIPPED,
  ];

  static final $core.Map<$core.int, AckStatus> _byValue = $pb.ProtobufEnum.initByValue(values);
  static AckStatus? valueOf($core.int value) => _byValue[value];

  const AckStatus._($core.int v, $core.String n) : super(v, n);
}

class ErrorCode extends $pb.ProtobufEnum {
  static const ErrorCode ERROR_CODE_UNSPECIFIED = ErrorCode._(0, 'ERROR_CODE_UNSPECIFIED');
  static const ErrorCode ERROR_CODE_AUTH_FAILED = ErrorCode._(1, 'ERROR_CODE_AUTH_FAILED');
  static const ErrorCode ERROR_CODE_RATE_LIMITED = ErrorCode._(2, 'ERROR_CODE_RATE_LIMITED');
  static const ErrorCode ERROR_CODE_INTERNAL = ErrorCode._(3, 'ERROR_CODE_INTERNAL');
  static const ErrorCode ERROR_CODE_STREAM_CLOSED = ErrorCode._(4, 'ERROR_CODE_STREAM_CLOSED');

  static const $core.List<ErrorCode> values = <ErrorCode>[
    ERROR_CODE_UNSPECIFIED,
    ERROR_CODE_AUTH_FAILED,
    ERROR_CODE_RATE_LIMITED,
    ERROR_CODE_INTERNAL,
    ERROR_CODE_STREAM_CLOSED,
  ];

  static final $core.Map<$core.int, ErrorCode> _byValue = $pb.ProtobufEnum.initByValue(values);
  static ErrorCode? valueOf($core.int value) => _byValue[value];

  const ErrorCode._($core.int v, $core.String n) : super(v, n);
}
