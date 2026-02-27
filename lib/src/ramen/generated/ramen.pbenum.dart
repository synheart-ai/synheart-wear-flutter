//
//  Generated code. Do not modify.
//  source: ramen.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

class AckStatus extends $pb.ProtobufEnum {
  static const AckStatus ACK_STATUS_UNSPECIFIED = AckStatus._(0, _omitEnumNames ? '' : 'ACK_STATUS_UNSPECIFIED');
  static const AckStatus ACK_STATUS_SUCCESS = AckStatus._(1, _omitEnumNames ? '' : 'ACK_STATUS_SUCCESS');

  static const $core.List<AckStatus> values = <AckStatus>[
    ACK_STATUS_UNSPECIFIED,
    ACK_STATUS_SUCCESS,
  ];

  static final $core.Map<$core.int, AckStatus> _byValue = $pb.ProtobufEnum.initByValue(values);
  static AckStatus? valueOf($core.int value) => _byValue[value];

  const AckStatus._($core.int v, $core.String n) : super(v, n);
}

class ErrorCode extends $pb.ProtobufEnum {
  static const ErrorCode ERROR_CODE_UNSPECIFIED = ErrorCode._(0, _omitEnumNames ? '' : 'ERROR_CODE_UNSPECIFIED');
  static const ErrorCode ERROR_CODE_AUTH_FAILED = ErrorCode._(1, _omitEnumNames ? '' : 'ERROR_CODE_AUTH_FAILED');
  static const ErrorCode ERROR_CODE_INVALID_APP = ErrorCode._(2, _omitEnumNames ? '' : 'ERROR_CODE_INVALID_APP');
  static const ErrorCode ERROR_CODE_RATE_LIMITED = ErrorCode._(3, _omitEnumNames ? '' : 'ERROR_CODE_RATE_LIMITED');
  static const ErrorCode ERROR_CODE_INTERNAL = ErrorCode._(4, _omitEnumNames ? '' : 'ERROR_CODE_INTERNAL');

  static const $core.List<ErrorCode> values = <ErrorCode>[
    ERROR_CODE_UNSPECIFIED,
    ERROR_CODE_AUTH_FAILED,
    ERROR_CODE_INVALID_APP,
    ERROR_CODE_RATE_LIMITED,
    ERROR_CODE_INTERNAL,
  ];

  static final $core.Map<$core.int, ErrorCode> _byValue = $pb.ProtobufEnum.initByValue(values);
  static ErrorCode? valueOf($core.int value) => _byValue[value];

  const ErrorCode._($core.int v, $core.String n) : super(v, n);
}

const _omitEnumNames = $core.bool.fromEnvironment('protobuf.omit_enum_names');
