// Synheart RAMEN Service — gRPC client stubs (ramen.v1)

import 'dart:async' as $async;
import 'dart:core' as $core;

import 'package:grpc/service_api.dart' as $grpc;
import 'ramen.pb.dart' as $0;

export 'ramen.pb.dart';

class RAMENServiceClient extends $grpc.Client {
  static final _$subscribe =
      $grpc.ClientMethod<$0.ClientMessage, $0.ServerMessage>(
    '/ramen.v1.RAMENService/Subscribe',
    ($0.ClientMessage value) => value.writeToBuffer(),
    ($core.List<$core.int> value) => $0.ServerMessage.fromBuffer(value),
  );

  static final _$replay =
      $grpc.ClientMethod<$0.ReplayRequest, $0.ReplayResponse>(
    '/ramen.v1.RAMENService/Replay',
    ($0.ReplayRequest value) => value.writeToBuffer(),
    ($core.List<$core.int> value) => $0.ReplayResponse.fromBuffer(value),
  );

  RAMENServiceClient($grpc.ClientChannel channel,
      {$grpc.CallOptions? options,
      $core.Iterable<$grpc.ClientInterceptor>? interceptors})
      : super(channel, options: options, interceptors: interceptors);

  /// Bidirectional streaming — Subscribe to real-time events.
  $grpc.ResponseStream<$0.ServerMessage> subscribe(
    $async.Stream<$0.ClientMessage> request, {
    $grpc.CallOptions? options,
  }) {
    return $createStreamingCall(_$subscribe, request, options: options);
  }

  /// Unary — Fetch historical events after a given sequence.
  $grpc.ResponseFuture<$0.ReplayResponse> replay(
    $0.ReplayRequest request, {
    $grpc.CallOptions? options,
  }) {
    return $createUnaryCall(_$replay, request, options: options);
  }
}
