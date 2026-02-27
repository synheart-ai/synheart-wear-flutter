//
//  Generated code. Do not modify.
//  source: ramen.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use ackStatusDescriptor instead')
const AckStatus$json = {
  '1': 'AckStatus',
  '2': [
    {'1': 'ACK_STATUS_UNSPECIFIED', '2': 0},
    {'1': 'ACK_STATUS_SUCCESS', '2': 1},
  ],
};

@$core.Deprecated('Use errorCodeDescriptor instead')
const ErrorCode$json = {
  '1': 'ErrorCode',
  '2': [
    {'1': 'ERROR_CODE_UNSPECIFIED', '2': 0},
    {'1': 'ERROR_CODE_AUTH_FAILED', '2': 1},
    {'1': 'ERROR_CODE_INVALID_APP', '2': 2},
    {'1': 'ERROR_CODE_RATE_LIMITED', '2': 3},
    {'1': 'ERROR_CODE_INTERNAL', '2': 4},
  ],
};

@$core.Deprecated('Use subscribeRequestDescriptor instead')
const SubscribeRequest$json = {
  '1': 'SubscribeRequest',
  '2': [
    {'1': 'last_seq', '3': 1, '4': 1, '5': 3, '10': 'lastSeq'},
    {'1': 'device_id', '3': 2, '4': 1, '5': 9, '10': 'deviceId'},
    {'1': 'user_id', '3': 3, '4': 1, '5': 9, '10': 'userId'},
    {'1': 'app_id', '3': 4, '4': 1, '5': 9, '10': 'appId'},
  ],
};

@$core.Deprecated('Use ackDescriptor instead')
const Ack$json = {
  '1': 'Ack',
  '2': [
    {'1': 'seq', '3': 1, '4': 1, '5': 3, '10': 'seq'},
    {'1': 'status', '3': 2, '4': 1, '5': 14, '6': '.ramen.AckStatus', '10': 'status'},
  ],
};

@$core.Deprecated('Use heartbeatDescriptor instead')
const Heartbeat$json = {
  '1': 'Heartbeat',
  '2': [
    {'1': 'timestamp', '3': 1, '4': 1, '5': 11, '6': '.google.protobuf.Timestamp', '10': 'timestamp'},
  ],
};

@$core.Deprecated('Use clientMessageDescriptor instead')
const ClientMessage$json = {
  '1': 'ClientMessage',
  '2': [
    {'1': 'subscribe', '3': 1, '4': 1, '5': 11, '6': '.ramen.SubscribeRequest', '9': 0, '10': 'subscribe'},
    {'1': 'ack', '3': 2, '4': 1, '5': 11, '6': '.ramen.Ack', '9': 0, '10': 'ack'},
    {'1': 'heartbeat', '3': 3, '4': 1, '5': 11, '6': '.ramen.Heartbeat', '9': 0, '10': 'heartbeat'},
  ],
  '8': [
    {'1': 'message'},
  ],
};

@$core.Deprecated('Use subscribeResponseDescriptor instead')
const SubscribeResponse$json = {
  '1': 'SubscribeResponse',
  '2': [
    {'1': 'connection_id', '3': 1, '4': 1, '5': 9, '10': 'connectionId'},
    {'1': 'expires_at', '3': 2, '4': 1, '5': 11, '6': '.google.protobuf.Timestamp', '10': 'expiresAt'},
    {'1': 'heartbeat_interval_seconds', '3': 3, '4': 1, '5': 5, '10': 'heartbeatIntervalSeconds'},
  ],
};

@$core.Deprecated('Use eventEnvelopeDescriptor instead')
const EventEnvelope$json = {
  '1': 'EventEnvelope',
  '2': [
    {'1': 'event_id', '3': 1, '4': 1, '5': 9, '10': 'eventId'},
    {'1': 'seq', '3': 2, '4': 1, '5': 3, '10': 'seq'},
    {'1': 'payload', '3': 3, '4': 1, '5': 9, '10': 'payload'},
  ],
};

@$core.Deprecated('Use heartbeatAckDescriptor instead')
const HeartbeatAck$json = {
  '1': 'HeartbeatAck',
  '2': [
    {'1': 'rtt_ms', '3': 1, '4': 1, '5': 3, '10': 'rttMs'},
  ],
};

@$core.Deprecated('Use errorDescriptor instead')
const Error$json = {
  '1': 'Error',
  '2': [
    {'1': 'code', '3': 1, '4': 1, '5': 14, '6': '.ramen.ErrorCode', '10': 'code'},
    {'1': 'message', '3': 2, '4': 1, '5': 9, '10': 'message'},
    {'1': 'fatal', '3': 3, '4': 1, '5': 8, '10': 'fatal'},
  ],
};

@$core.Deprecated('Use serverMessageDescriptor instead')
const ServerMessage$json = {
  '1': 'ServerMessage',
  '2': [
    {'1': 'event', '3': 1, '4': 1, '5': 11, '6': '.ramen.EventEnvelope', '9': 0, '10': 'event'},
    {'1': 'heartbeat_ack', '3': 2, '4': 1, '5': 11, '6': '.ramen.HeartbeatAck', '9': 0, '10': 'heartbeatAck'},
    {'1': 'subscribe_response', '3': 3, '4': 1, '5': 11, '6': '.ramen.SubscribeResponse', '9': 0, '10': 'subscribeResponse'},
    {'1': 'error', '3': 4, '4': 1, '5': 11, '6': '.ramen.Error', '9': 0, '10': 'error'},
  ],
  '8': [
    {'1': 'message'},
  ],
};
