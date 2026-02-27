// Copyright 2025 Synheart. RAMEN gRPC client per SDK Integration Guide.

import 'dart:async';
import 'dart:convert';

import 'package:fixnum/fixnum.dart';
import 'package:flutter/foundation.dart';
import 'package:grpc/grpc.dart';
import 'generated/google_protobuf_timestamp.pb.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'generated/ramen.pbgrpc.dart';

const String _lastSeqKey = 'ramen_last_acknowledged_seq';

/// Connection state for RAMEN. Use [connectionState] to know when the
/// connection is actually established (first server message) or lost.
enum RamenConnectionState {
  /// Connecting: stream started, waiting for first server message.
  connecting,

  /// Connected: at least one Event or HeartbeatAck received from server.
  connected,

  /// Stream ended or error; client may be reconnecting.
  disconnected,

  /// Reconnecting: backoff delay before next connect().
  reconnecting,
}

/// Parsed event from RAMEN (payload is JSON).
class RamenEvent {
  RamenEvent({
    required this.eventId,
    required this.seq,
    required this.payloadJson,
    this.payload,
  });

  final String eventId;
  final Int64 seq;
  final String payloadJson;
  final Map<String, dynamic>? payload;

  static RamenEvent fromEnvelope(EventEnvelope envelope) {
    Map<String, dynamic>? payload;
    try {
      if (envelope.payload.isNotEmpty) {
        payload = jsonDecode(envelope.payload) as Map<String, dynamic>?;
      }
    } catch (_) {
      /* leave payload null */
    }
    return RamenEvent(
      eventId: envelope.eventId,
      seq: envelope.seq,
      payloadJson: envelope.payload,
      payload: payload,
    );
  }
}

/// RAMEN gRPC client: connection to Synheart RAMEN with last_acknowledged_seq,
/// device_id, user_id; security headers (X-app-id, X-api-key) on every request;
/// seq saved in local storage; heartbeat every 30s, force-close after 2 missed.
///
/// Set [logResponses] to true to log every response from the RAMEN service
/// (subscribe_response, event, heartbeat_ack, error) to the console via [debugPrint].
class RamenClient {
  RamenClient({
    required this.host,
    this.port = 443,
    this.appId = '',
    this.apiKey = '',
    required this.deviceId,
    this.userId = '',
    this.useTls = true,
    this.heartbeatInterval = const Duration(seconds: 30),
    this.heartbeatMissedAttempts = 2,
    this.logResponses = false,
  });

  final String host;
  final int port;
  final String appId;
  final String apiKey;
  final String deviceId;
  /// User identifier sent in SubscribeRequest (in addition to X-app-id and X-api-key).
  final String userId;
  final bool useTls;
  final Duration heartbeatInterval;
  final int heartbeatMissedAttempts;
  /// When true, logs every server message (subscribe_response, event, heartbeat_ack, error) via the SDK logger.
  final bool logResponses;

  ClientChannel? _channel;
  RamenServiceClient? _client;
  StreamSubscription<ServerMessage>? _subscription;
  StreamController<ClientMessage>? _requestController;
  final StreamController<RamenEvent> _eventController =
      StreamController<RamenEvent>.broadcast();
  final StreamController<RamenConnectionState> _stateController =
      StreamController<RamenConnectionState>.broadcast();
  final StreamController<Error> _errorController =
      StreamController<Error>.broadcast();
  Timer? _heartbeatTimer;
  int _heartbeatsWithoutAck = 0;
  bool _closed = false;
  int _backoffSeconds = 1;
  bool _hasEmittedConnected = false;

  /// Stream of connection state. Emits [RamenConnectionState.connected] when
  /// the first Event or HeartbeatAck is received (connection is successful).
  /// Emits [RamenConnectionState.disconnected] on stream error/done.
  Stream<RamenConnectionState> get connectionState => _stateController.stream;

  /// Stream of parsed events (payload as JSON). Process and Ack(seq) is done
  /// inside; use [lastSeq] for idempotency if needed.
  Stream<RamenEvent> get events => _eventController.stream;

  /// Stream of server-side errors. Fatal errors will also cancel the stream
  /// (no automatic reconnect).
  Stream<Error> get errors => _errorController.stream;

  /// Last acknowledged seq (from local storage). Used as last_acknowledged_seq
  /// in SubscribeRequest (0 if first time).
  Future<Int64> get lastSeq async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getInt(_lastSeqKey);
    return v != null ? Int64(v) : Int64.ZERO;
  }

  /// gRPC call options: X-app-id and X-api-key on every request (auth).
  /// Passed to subscribe() so the connection carries these headers.
  CallOptions _callOptions() {
    final meta = <String, String>{};
    if (appId.isNotEmpty) meta['x-app-id'] = appId;
    if (apiKey.isNotEmpty) meta['x-api-key'] = apiKey;
    return CallOptions(metadata: meta);
  }

  void _emitConnectedIfFirst() {
    if (!_hasEmittedConnected && !_closed) {
      _hasEmittedConnected = true;
      _backoffSeconds = 1; // reset backoff after successful connection
      _logConnection('established');
      _stateController.add(RamenConnectionState.connected);
    }
  }

  void _logResponse(String type, String detail) {
    if (logResponses) debugPrint('RAMEN $type: $detail');
  }

  void _logConnection(String message) {
    if (logResponses) debugPrint('RAMEN connection: $message');
  }

  /// Start the subscription loop. Sends SubscribeRequest with
  /// last_acknowledged_seq (from local storage, or 0 if first time), device_id,
  /// user_id, app_id; X-app-id and X-api-key are sent via [_callOptions] on the connection.
  /// On each Event, sends Ack(seq) and saves seq to local storage.
  /// Every 30s sends Heartbeat(timestamp=Timestamp.fromDateTime(utc)); if HeartbeatAck not received
  /// after 2 attempts, force-closes and reconnects.
  Future<void> connect() async {
    if (_closed) return;
    _hasEmittedConnected = false;
    _logConnection('connecting to $host:$port (tls=$useTls)');
    _stateController.add(RamenConnectionState.connecting);

    // Cleanup previous connection: cancel subscription and close previous request stream
    await _subscription?.cancel();
    await _requestController?.close();
    _requestController = StreamController<ClientMessage>(); // single-subscription, not broadcast

    _channel = useTls
        ? ClientChannel(host, port: port, options: const ChannelOptions(credentials: ChannelCredentials.secure()))
        : ClientChannel(host, port: port);
    _client = RamenServiceClient(_channel!);

    final lastAckSeq = await lastSeq;
    final subscribe = ClientMessage()
      ..subscribe = (SubscribeRequest()
        ..appId = appId
        ..lastSeq = lastAckSeq
        ..deviceId = deviceId
        ..userId = userId);
    // One SubscribeRequest per connection, then only Ack/Heartbeat on _requestController
    Stream<ClientMessage> buildRequestStream() async* {
      yield subscribe;
      yield* _requestController!.stream;
    }

    final responseStream = _client!.subscribe(
      buildRequestStream(),
      options: _callOptions(), // X-app-id and X-api-key on every request
    );

    _heartbeatsWithoutAck = 0;
    _startHeartbeatTimer();

    _subscription = responseStream.listen(
      (ServerMessage msg) {
        switch (msg.whichMessage()) {
          case ServerMessage_Message.subscribeResponse:
            _emitConnectedIfFirst();
            _onSubscribeResponse(msg.subscribeResponse);
            break;
          case ServerMessage_Message.event:
            _emitConnectedIfFirst();
            _onEvent(msg.event);
            break;
          case ServerMessage_Message.heartbeatAck:
            _emitConnectedIfFirst();
            _logResponse('heartbeat_ack', 'rtt_ms=${msg.heartbeatAck.rttMs}');
            _heartbeatsWithoutAck = 0;
            break;
          case ServerMessage_Message.error:
            _onServerError(msg.error);
            break;
          case ServerMessage_Message.notSet:
            break;
        }
      },
      onError: (e, st) {
        _logConnection('error: $e');
        _stopHeartbeatTimer();
        if (!_closed) _stateController.add(RamenConnectionState.disconnected);
        // Do not reconnect on UNIMPLEMENTED (wrong service/method path) - retrying won't help
        final isUnimplemented = e.toString().contains('UNIMPLEMENTED') ||
            e.toString().contains('unknown service');
        if (!isUnimplemented) _scheduleReconnect();
      },
      onDone: () {
        _logConnection('stream ended');
        _stopHeartbeatTimer();
        if (!_closed) {
          _stateController.add(RamenConnectionState.disconnected);
          _scheduleReconnect();
        }
      },
      cancelOnError: false,
    );
  }

  void _onSubscribeResponse(SubscribeResponse resp) {
    _logResponse('subscribe_response',
        'connection_id=${resp.connectionId} heartbeat_interval_seconds=${resp.heartbeatIntervalSeconds} expires_at=${resp.hasExpiresAt() ? resp.expiresAt : "n/a"}');
    if (resp.heartbeatIntervalSeconds > 0) {
      _heartbeatTimer?.cancel();
      final intervalSeconds = resp.heartbeatIntervalSeconds.clamp(5, 300);
      _heartbeatTimer = Timer.periodic(
        Duration(seconds: intervalSeconds),
        (_) => _sendHeartbeat(),
      );
    }
  }

  void _onEvent(EventEnvelope envelope) {
    _logResponse('event',
        'event_id=${envelope.eventId} seq=${envelope.seq} payload_length=${envelope.payload.length}');
    final ramenEvent = RamenEvent.fromEnvelope(envelope);
    _eventController.add(ramenEvent);
    _sendAck(envelope.seq);
    _persistLastSeq(envelope.seq);
  }

  void _onServerError(Error err) {
    _logResponse('error', 'code=${err.code} message=${err.message} fatal=${err.fatal}');
    _errorController.add(err);
    if (err.fatal) {
      _stopHeartbeatTimer();
      _subscription?.cancel();
      if (!_closed) _stateController.add(RamenConnectionState.disconnected);
    }
  }

  void _trySend(ClientMessage msg) {
    final c = _requestController;
    if (c != null && !c.isClosed) c.add(msg);
  }

  void _sendAck(Int64 seq) {
    _trySend(ClientMessage()
      ..ack = (Ack()
        ..seq = seq
        ..status = AckStatus.ACK_STATUS_SUCCESS));
  }

  /// Save seq to local storage for last_acknowledged_seq on next connection.
  Future<void> _persistLastSeq(Int64 seq) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastSeqKey, seq.toInt());
  }

  void _sendHeartbeat() {
    _heartbeatsWithoutAck++;
    if (_heartbeatsWithoutAck >= heartbeatMissedAttempts) {
      _stopHeartbeatTimer();
      _subscription?.cancel();
      _scheduleReconnect();
      return;
    }
    _trySend(ClientMessage()
      ..heartbeat = (Heartbeat()
        ..timestamp = Timestamp.fromDateTime(DateTime.now().toUtc())));
  }

  void _startHeartbeatTimer() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(heartbeatInterval, (_) => _sendHeartbeat());
  }

  void _stopHeartbeatTimer() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  void _scheduleReconnect() {
    if (_closed) return;
    _stopHeartbeatTimer();
    _logConnection('reconnecting in ${_backoffSeconds}s');
    _stateController.add(RamenConnectionState.reconnecting);
    final delay = _backoffSeconds;
    _backoffSeconds = _backoffSeconds > 32 ? 32 : _backoffSeconds * 2;
    Future.delayed(Duration(seconds: delay), () async {
      if (_closed) return;
      _logConnection('reconnecting now...');
      await _subscription?.cancel();
      await _requestController?.close();
      await _channel?.shutdown();
      await connect();
    });
  }

  /// Close the client and stop reconnecting.
  Future<void> close() async {
    _closed = true;
    _stopHeartbeatTimer();
    await _subscription?.cancel();
    await _requestController?.close();
    _requestController = null;
    await _channel?.shutdown();
    await _eventController.close();
    await _errorController.close();
    await _stateController.close();
  }
}
