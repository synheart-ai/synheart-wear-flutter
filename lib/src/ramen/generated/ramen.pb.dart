// Synheart RAMEN Service — Protobuf messages (ramen.v1)
// Field numbers match the server proto exactly.

import 'dart:core' as $core;
import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;
import 'google_protobuf_timestamp.pb.dart' as $wk;
import 'ramen.pbenum.dart';

export 'ramen.pbenum.dart';

const _pkg = $pb.PackageName('ramen.v1');

// ─── SubscribeRequest ────────────────────────────────────────────────────────
// 1=token, 2=device_id, 3=app_id, 4=user_id, 5=last_seq, 6=providers, 7=event_types

class SubscribeRequest extends $pb.GeneratedMessage {
  factory SubscribeRequest() => create();
  SubscribeRequest._() : super();
  factory SubscribeRequest.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);

  static final $pb.BuilderInfo _i =
      $pb.BuilderInfo('SubscribeRequest', package: _pkg, createEmptyInstance: create)
        ..aOS(1, 'token')
        ..aOS(2, 'deviceId')
        ..aOS(3, 'appId')
        ..aOS(4, 'userId')
        ..aInt64(5, 'lastSeq')
        ..pPS(6, 'providers')
        ..pPS(7, 'eventTypes')
        ..hasRequiredFields = false;

  $pb.BuilderInfo get info_ => _i;
  static SubscribeRequest create() => SubscribeRequest._();
  SubscribeRequest createEmptyInstance() => create();
  SubscribeRequest clone() => SubscribeRequest()..mergeFromMessage(this);
  static SubscribeRequest getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SubscribeRequest>(create);
  static SubscribeRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get token => $_getSZ(0);
  @$pb.TagNumber(1)
  set token($core.String v) => $_setString(0, v);

  @$pb.TagNumber(2)
  $core.String get deviceId => $_getSZ(1);
  @$pb.TagNumber(2)
  set deviceId($core.String v) => $_setString(1, v);

  @$pb.TagNumber(3)
  $core.String get appId => $_getSZ(2);
  @$pb.TagNumber(3)
  set appId($core.String v) => $_setString(2, v);

  @$pb.TagNumber(4)
  $core.String get userId => $_getSZ(3);
  @$pb.TagNumber(4)
  set userId($core.String v) => $_setString(3, v);

  @$pb.TagNumber(5)
  $fixnum.Int64 get lastSeq => $_getI64(4);
  @$pb.TagNumber(5)
  set lastSeq($fixnum.Int64 v) => $_setInt64(4, v);

  @$pb.TagNumber(6)
  $core.List<$core.String> get providers => $_getList(5);

  @$pb.TagNumber(7)
  $core.List<$core.String> get eventTypes => $_getList(6);
}

// ─── Ack ─────────────────────────────────────────────────────────────────────

class Ack extends $pb.GeneratedMessage {
  factory Ack() => create();
  Ack._() : super();
  factory Ack.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);

  static final $pb.BuilderInfo _i =
      $pb.BuilderInfo('Ack', package: _pkg, createEmptyInstance: create)
        ..aInt64(1, 'seq')
        ..e<AckStatus>(2, 'status', $pb.PbFieldType.OE,
            defaultOrMaker: AckStatus.ACK_STATUS_UNSPECIFIED,
            valueOf: AckStatus.valueOf,
            enumValues: AckStatus.values)
        ..hasRequiredFields = false;

  $pb.BuilderInfo get info_ => _i;
  static Ack create() => Ack._();
  Ack createEmptyInstance() => create();
  Ack clone() => Ack()..mergeFromMessage(this);
  static Ack getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Ack>(create);
  static Ack? _defaultInstance;

  @$pb.TagNumber(1)
  $fixnum.Int64 get seq => $_getI64(0);
  @$pb.TagNumber(1)
  set seq($fixnum.Int64 v) => $_setInt64(0, v);

  @$pb.TagNumber(2)
  AckStatus get status => $_getN(1);
  @$pb.TagNumber(2)
  set status(AckStatus v) => setField(2, v);
}

// ─── Heartbeat ───────────────────────────────────────────────────────────────

class Heartbeat extends $pb.GeneratedMessage {
  factory Heartbeat() => create();
  Heartbeat._() : super();
  factory Heartbeat.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);

  static final $pb.BuilderInfo _i =
      $pb.BuilderInfo('Heartbeat', package: _pkg, createEmptyInstance: create)
        ..aOM<$wk.Timestamp>(1, 'timestamp', subBuilder: $wk.Timestamp.create)
        ..hasRequiredFields = false;

  $pb.BuilderInfo get info_ => _i;
  static Heartbeat create() => Heartbeat._();
  Heartbeat createEmptyInstance() => create();
  Heartbeat clone() => Heartbeat()..mergeFromMessage(this);
  static Heartbeat getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Heartbeat>(create);
  static Heartbeat? _defaultInstance;

  @$pb.TagNumber(1)
  $wk.Timestamp get timestamp => $_getN(0);
  @$pb.TagNumber(1)
  set timestamp($wk.Timestamp v) => setField(1, v);
}

// ─── ClientMessage ───────────────────────────────────────────────────────────
// oneof message: 1=subscribe, 2=ack, 3=heartbeat

enum ClientMessage_Message { subscribe, ack, heartbeat, notSet }

class ClientMessage extends $pb.GeneratedMessage {
  factory ClientMessage() => create();
  ClientMessage._() : super();
  factory ClientMessage.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);

  static const $core.Map<$core.int, ClientMessage_Message> _byTag = {
    1: ClientMessage_Message.subscribe,
    2: ClientMessage_Message.ack,
    3: ClientMessage_Message.heartbeat,
    0: ClientMessage_Message.notSet,
  };

  static final $pb.BuilderInfo _i =
      $pb.BuilderInfo('ClientMessage', package: _pkg, createEmptyInstance: create)
        ..oo(0, [1, 2, 3])
        ..aOM<SubscribeRequest>(1, 'subscribe', subBuilder: SubscribeRequest.create)
        ..aOM<Ack>(2, 'ack', subBuilder: Ack.create)
        ..aOM<Heartbeat>(3, 'heartbeat', subBuilder: Heartbeat.create)
        ..hasRequiredFields = false;

  $pb.BuilderInfo get info_ => _i;
  static ClientMessage create() => ClientMessage._();
  ClientMessage createEmptyInstance() => create();
  ClientMessage clone() => ClientMessage()..mergeFromMessage(this);
  static ClientMessage getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ClientMessage>(create);
  static ClientMessage? _defaultInstance;

  ClientMessage_Message whichMessage() => _byTag[$_whichOneof(0)]!;
  void clearMessage() => clearField($_whichOneof(0));

  @$pb.TagNumber(1)
  SubscribeRequest get subscribe => $_getN(0);
  @$pb.TagNumber(1)
  set subscribe(SubscribeRequest v) => setField(1, v);
  @$pb.TagNumber(1)
  SubscribeRequest ensureSubscribe() => $_ensure(0);

  @$pb.TagNumber(2)
  Ack get ack => $_getN(1);
  @$pb.TagNumber(2)
  set ack(Ack v) => setField(2, v);
  @$pb.TagNumber(2)
  Ack ensureAck() => $_ensure(1);

  @$pb.TagNumber(3)
  Heartbeat get heartbeat => $_getN(2);
  @$pb.TagNumber(3)
  set heartbeat(Heartbeat v) => setField(3, v);
  @$pb.TagNumber(3)
  Heartbeat ensureHeartbeat() => $_ensure(2);
}

// ─── SubscribeResponse ───────────────────────────────────────────────────────
// 1=connection_id, 2=expires_at, 3=heartbeat_interval_seconds, 4=current_seq

class SubscribeResponse extends $pb.GeneratedMessage {
  factory SubscribeResponse() => create();
  SubscribeResponse._() : super();
  factory SubscribeResponse.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);

  static final $pb.BuilderInfo _i =
      $pb.BuilderInfo('SubscribeResponse', package: _pkg, createEmptyInstance: create)
        ..aOS(1, 'connectionId')
        ..aOM<$wk.Timestamp>(2, 'expiresAt', subBuilder: $wk.Timestamp.create)
        ..a<$core.int>(3, 'heartbeatIntervalSeconds', $pb.PbFieldType.O3)
        ..aInt64(4, 'currentSeq')
        ..hasRequiredFields = false;

  $pb.BuilderInfo get info_ => _i;
  static SubscribeResponse create() => SubscribeResponse._();
  SubscribeResponse createEmptyInstance() => create();
  SubscribeResponse clone() => SubscribeResponse()..mergeFromMessage(this);
  static SubscribeResponse getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<SubscribeResponse>(create);
  static SubscribeResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get connectionId => $_getSZ(0);
  @$pb.TagNumber(1)
  set connectionId($core.String v) => $_setString(0, v);

  @$pb.TagNumber(2)
  $wk.Timestamp get expiresAt => $_getN(1);
  @$pb.TagNumber(2)
  set expiresAt($wk.Timestamp v) => setField(2, v);
  @$pb.TagNumber(2)
  $core.bool hasExpiresAt() => $_has(1);

  @$pb.TagNumber(3)
  $core.int get heartbeatIntervalSeconds => $_getIZ(2);
  @$pb.TagNumber(3)
  set heartbeatIntervalSeconds($core.int v) => $_setSignedInt32(2, v);

  @$pb.TagNumber(4)
  $fixnum.Int64 get currentSeq => $_getI64(3);
  @$pb.TagNumber(4)
  set currentSeq($fixnum.Int64 v) => $_setInt64(3, v);
}

// ─── DeliveryMeta ────────────────────────────────────────────────────────────
// 1=attempt, 2=first_sent_at, 3=is_replay

class DeliveryMeta extends $pb.GeneratedMessage {
  factory DeliveryMeta() => create();
  DeliveryMeta._() : super();
  factory DeliveryMeta.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);

  static final $pb.BuilderInfo _i =
      $pb.BuilderInfo('DeliveryMeta', package: _pkg, createEmptyInstance: create)
        ..a<$core.int>(1, 'attempt', $pb.PbFieldType.O3)
        ..aOM<$wk.Timestamp>(2, 'firstSentAt', subBuilder: $wk.Timestamp.create)
        ..aOB(3, 'isReplay')
        ..hasRequiredFields = false;

  $pb.BuilderInfo get info_ => _i;
  static DeliveryMeta create() => DeliveryMeta._();
  DeliveryMeta createEmptyInstance() => create();
  DeliveryMeta clone() => DeliveryMeta()..mergeFromMessage(this);
  static DeliveryMeta getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<DeliveryMeta>(create);
  static DeliveryMeta? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get attempt => $_getIZ(0);
  @$pb.TagNumber(1)
  set attempt($core.int v) => $_setSignedInt32(0, v);

  @$pb.TagNumber(2)
  $wk.Timestamp get firstSentAt => $_getN(1);
  @$pb.TagNumber(2)
  set firstSentAt($wk.Timestamp v) => setField(2, v);

  @$pb.TagNumber(3)
  $core.bool get isReplay => $_getBF(2);
  @$pb.TagNumber(3)
  set isReplay($core.bool v) => $_setBool(2, v);
}

// ─── EventEnvelope ───────────────────────────────────────────────────────────
// 1=event_id, 2=seq, 3=provider, 4=event_type, 5=raw_id,
// 6=payload(bytes), 7=created_at, 8=delivery

class EventEnvelope extends $pb.GeneratedMessage {
  factory EventEnvelope() => create();
  EventEnvelope._() : super();
  factory EventEnvelope.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);

  static final $pb.BuilderInfo _i =
      $pb.BuilderInfo('EventEnvelope', package: _pkg, createEmptyInstance: create)
        ..aOS(1, 'eventId')
        ..aInt64(2, 'seq')
        ..aOS(3, 'provider')
        ..aOS(4, 'eventType')
        ..aOS(5, 'rawId')
        ..a<$core.List<$core.int>>(6, 'payload', $pb.PbFieldType.OY)
        ..aOM<$wk.Timestamp>(7, 'createdAt', subBuilder: $wk.Timestamp.create)
        ..aOM<DeliveryMeta>(8, 'delivery', subBuilder: DeliveryMeta.create)
        ..hasRequiredFields = false;

  $pb.BuilderInfo get info_ => _i;
  static EventEnvelope create() => EventEnvelope._();
  EventEnvelope createEmptyInstance() => create();
  EventEnvelope clone() => EventEnvelope()..mergeFromMessage(this);
  static EventEnvelope getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<EventEnvelope>(create);
  static EventEnvelope? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get eventId => $_getSZ(0);
  @$pb.TagNumber(1)
  set eventId($core.String v) => $_setString(0, v);

  @$pb.TagNumber(2)
  $fixnum.Int64 get seq => $_getI64(1);
  @$pb.TagNumber(2)
  set seq($fixnum.Int64 v) => $_setInt64(1, v);

  @$pb.TagNumber(3)
  $core.String get provider => $_getSZ(2);
  @$pb.TagNumber(3)
  set provider($core.String v) => $_setString(2, v);

  @$pb.TagNumber(4)
  $core.String get eventType => $_getSZ(3);
  @$pb.TagNumber(4)
  set eventType($core.String v) => $_setString(3, v);

  @$pb.TagNumber(5)
  $core.String get rawId => $_getSZ(4);
  @$pb.TagNumber(5)
  set rawId($core.String v) => $_setString(4, v);

  @$pb.TagNumber(6)
  $core.List<$core.int> get payload => $_getN(5);
  @$pb.TagNumber(6)
  set payload($core.List<$core.int> v) => $_setBytes(5, v);
  @$pb.TagNumber(6)
  $core.bool hasPayload() => $_has(5);

  @$pb.TagNumber(7)
  $wk.Timestamp get createdAt => $_getN(6);
  @$pb.TagNumber(7)
  set createdAt($wk.Timestamp v) => setField(7, v);

  @$pb.TagNumber(8)
  DeliveryMeta get delivery => $_getN(7);
  @$pb.TagNumber(8)
  set delivery(DeliveryMeta v) => setField(8, v);
  @$pb.TagNumber(8)
  $core.bool hasDelivery() => $_has(7);
}

// ─── HeartbeatAck ────────────────────────────────────────────────────────────
// 1=server_time, 2=rtt_ms

class HeartbeatAck extends $pb.GeneratedMessage {
  factory HeartbeatAck() => create();
  HeartbeatAck._() : super();
  factory HeartbeatAck.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);

  static final $pb.BuilderInfo _i =
      $pb.BuilderInfo('HeartbeatAck', package: _pkg, createEmptyInstance: create)
        ..aOM<$wk.Timestamp>(1, 'serverTime', subBuilder: $wk.Timestamp.create)
        ..aInt64(2, 'rttMs')
        ..hasRequiredFields = false;

  $pb.BuilderInfo get info_ => _i;
  static HeartbeatAck create() => HeartbeatAck._();
  HeartbeatAck createEmptyInstance() => create();
  HeartbeatAck clone() => HeartbeatAck()..mergeFromMessage(this);
  static HeartbeatAck getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<HeartbeatAck>(create);
  static HeartbeatAck? _defaultInstance;

  @$pb.TagNumber(1)
  $wk.Timestamp get serverTime => $_getN(0);
  @$pb.TagNumber(1)
  set serverTime($wk.Timestamp v) => setField(1, v);

  @$pb.TagNumber(2)
  $fixnum.Int64 get rttMs => $_getI64(1);
  @$pb.TagNumber(2)
  set rttMs($fixnum.Int64 v) => $_setInt64(1, v);
}

// ─── Error ───────────────────────────────────────────────────────────────────

class Error extends $pb.GeneratedMessage {
  factory Error() => create();
  Error._() : super();
  factory Error.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);

  static final $pb.BuilderInfo _i =
      $pb.BuilderInfo('Error', package: _pkg, createEmptyInstance: create)
        ..e<ErrorCode>(1, 'code', $pb.PbFieldType.OE,
            defaultOrMaker: ErrorCode.ERROR_CODE_UNSPECIFIED,
            valueOf: ErrorCode.valueOf,
            enumValues: ErrorCode.values)
        ..aOS(2, 'message')
        ..aOB(3, 'fatal')
        ..hasRequiredFields = false;

  $pb.BuilderInfo get info_ => _i;
  static Error create() => Error._();
  Error createEmptyInstance() => create();
  Error clone() => Error()..mergeFromMessage(this);
  static Error getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Error>(create);
  static Error? _defaultInstance;

  @$pb.TagNumber(1)
  ErrorCode get code => $_getN(0);
  @$pb.TagNumber(1)
  set code(ErrorCode v) => setField(1, v);

  @$pb.TagNumber(2)
  $core.String get message => $_getSZ(1);
  @$pb.TagNumber(2)
  set message($core.String v) => $_setString(1, v);

  @$pb.TagNumber(3)
  $core.bool get fatal => $_getBF(2);
  @$pb.TagNumber(3)
  set fatal($core.bool v) => $_setBool(2, v);
}

// ─── ServerMessage ───────────────────────────────────────────────────────────
// oneof message: 1=subscribe_response, 2=event, 3=heartbeat_ack, 4=error

enum ServerMessage_Message { subscribeResponse, event, heartbeatAck, error, notSet }

class ServerMessage extends $pb.GeneratedMessage {
  factory ServerMessage() => create();
  ServerMessage._() : super();
  factory ServerMessage.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);

  static const $core.Map<$core.int, ServerMessage_Message> _byTag = {
    1: ServerMessage_Message.subscribeResponse,
    2: ServerMessage_Message.event,
    3: ServerMessage_Message.heartbeatAck,
    4: ServerMessage_Message.error,
    0: ServerMessage_Message.notSet,
  };

  static final $pb.BuilderInfo _i =
      $pb.BuilderInfo('ServerMessage', package: _pkg, createEmptyInstance: create)
        ..oo(0, [1, 2, 3, 4])
        ..aOM<SubscribeResponse>(1, 'subscribeResponse', subBuilder: SubscribeResponse.create)
        ..aOM<EventEnvelope>(2, 'event', subBuilder: EventEnvelope.create)
        ..aOM<HeartbeatAck>(3, 'heartbeatAck', subBuilder: HeartbeatAck.create)
        ..aOM<Error>(4, 'error', subBuilder: Error.create)
        ..hasRequiredFields = false;

  $pb.BuilderInfo get info_ => _i;
  static ServerMessage create() => ServerMessage._();
  ServerMessage createEmptyInstance() => create();
  ServerMessage clone() => ServerMessage()..mergeFromMessage(this);
  static ServerMessage getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ServerMessage>(create);
  static ServerMessage? _defaultInstance;

  ServerMessage_Message whichMessage() => _byTag[$_whichOneof(0)]!;
  void clearMessage() => clearField($_whichOneof(0));

  @$pb.TagNumber(1)
  SubscribeResponse get subscribeResponse => $_getN(0);
  @$pb.TagNumber(1)
  set subscribeResponse(SubscribeResponse v) => setField(1, v);

  @$pb.TagNumber(2)
  EventEnvelope get event => $_getN(1);
  @$pb.TagNumber(2)
  set event(EventEnvelope v) => setField(2, v);

  @$pb.TagNumber(3)
  HeartbeatAck get heartbeatAck => $_getN(2);
  @$pb.TagNumber(3)
  set heartbeatAck(HeartbeatAck v) => setField(3, v);

  @$pb.TagNumber(4)
  Error get error => $_getN(3);
  @$pb.TagNumber(4)
  set error(Error v) => setField(4, v);
}

// ─── ReplayRequest ───────────────────────────────────────────────────────────

class ReplayRequest extends $pb.GeneratedMessage {
  factory ReplayRequest() => create();
  ReplayRequest._() : super();
  factory ReplayRequest.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);

  static final $pb.BuilderInfo _i =
      $pb.BuilderInfo('ReplayRequest', package: _pkg, createEmptyInstance: create)
        ..aOS(1, 'appId')
        ..aOS(2, 'userId')
        ..aInt64(3, 'afterSeq')
        ..a<$core.int>(4, 'limit', $pb.PbFieldType.O3)
        ..hasRequiredFields = false;

  $pb.BuilderInfo get info_ => _i;
  static ReplayRequest create() => ReplayRequest._();
  ReplayRequest createEmptyInstance() => create();
  ReplayRequest clone() => ReplayRequest()..mergeFromMessage(this);
  static ReplayRequest getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ReplayRequest>(create);
  static ReplayRequest? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get appId => $_getSZ(0);
  @$pb.TagNumber(1)
  set appId($core.String v) => $_setString(0, v);

  @$pb.TagNumber(2)
  $core.String get userId => $_getSZ(1);
  @$pb.TagNumber(2)
  set userId($core.String v) => $_setString(1, v);

  @$pb.TagNumber(3)
  $fixnum.Int64 get afterSeq => $_getI64(2);
  @$pb.TagNumber(3)
  set afterSeq($fixnum.Int64 v) => $_setInt64(2, v);

  @$pb.TagNumber(4)
  $core.int get limit => $_getIZ(3);
  @$pb.TagNumber(4)
  set limit($core.int v) => $_setSignedInt32(3, v);
}

// ─── ReplayResponse ──────────────────────────────────────────────────────────

class ReplayResponse extends $pb.GeneratedMessage {
  factory ReplayResponse() => create();
  ReplayResponse._() : super();
  factory ReplayResponse.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);

  static final $pb.BuilderInfo _i =
      $pb.BuilderInfo('ReplayResponse', package: _pkg, createEmptyInstance: create)
        ..pc<EventEnvelope>(1, 'events', $pb.PbFieldType.PM, subBuilder: EventEnvelope.create)
        ..aOB(2, 'hasMore')
        ..aInt64(3, 'highestSeq')
        ..hasRequiredFields = false;

  $pb.BuilderInfo get info_ => _i;
  static ReplayResponse create() => ReplayResponse._();
  ReplayResponse createEmptyInstance() => create();
  ReplayResponse clone() => ReplayResponse()..mergeFromMessage(this);
  static ReplayResponse getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ReplayResponse>(create);
  static ReplayResponse? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<EventEnvelope> get events => $_getList(0);

  @$pb.TagNumber(2)
  $core.bool get hasMore => $_getBF(1);
  @$pb.TagNumber(2)
  set hasMore($core.bool v) => $_setBool(1, v);

  @$pb.TagNumber(3)
  $fixnum.Int64 get highestSeq => $_getI64(2);
  @$pb.TagNumber(3)
  set highestSeq($fixnum.Int64 v) => $_setInt64(2, v);
}
