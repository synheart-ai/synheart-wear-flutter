//
//  Generated code. Do not modify.
//  source: ramen.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:async' as $async;
import 'dart:core' as $core;

import 'package:grpc/service_api.dart' as $grpc;

import 'ramen.pb.dart' as $0;

export 'ramen.pb.dart';

// GrpcServiceName omitted for protobuf 2.x compatibility (exists in protobuf 6.x only)
class RamenServiceClient extends $grpc.Client {
  static final _$subscribe = $grpc.ClientMethod<$0.ClientMessage, $0.ServerMessage>(
      '/ramen.v1.RAMENService/Subscribe',
      ($0.ClientMessage value) => value.writeToBuffer(),
      ($core.List<$core.int> value) => $0.ServerMessage.fromBuffer(value));

  RamenServiceClient($grpc.ClientChannel channel,
      {$grpc.CallOptions? options,
      $core.Iterable<$grpc.ClientInterceptor>? interceptors})
      : super(channel, options: options,
        interceptors: interceptors);

  $grpc.ResponseStream<$0.ServerMessage> subscribe($async.Stream<$0.ClientMessage> request, {$grpc.CallOptions? options}) {
    return $createStreamingCall(_$subscribe, request, options: options);
  }
}

abstract class RamenServiceBase extends $grpc.Service {
  $core.String get $name => 'ramen.v1.RAMENService';

  RamenServiceBase() {
    $addMethod($grpc.ServiceMethod<$0.ClientMessage, $0.ServerMessage>(
        'subscribe',
        subscribe,
        true,
        true,
        ($core.List<$core.int> value) => $0.ClientMessage.fromBuffer(value),
        ($0.ServerMessage value) => value.writeToBuffer()));
  }

  $async.Stream<$0.ServerMessage> subscribe($grpc.ServiceCall call, $async.Stream<$0.ClientMessage> request);
}
