// SPDX-License-Identifier: Apache-2.0

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:synheart_wear/synheart_wear.dart' show DeliveryHint, RamenEvent;

void main() {
  group('DeliveryHint wire compatibility', () {
    test('wire names are pinned (must match server constants)', () {
      // These strings are the canonical RAMEN delivery-hint wire
      // names. Renaming requires a coordinated change with the
      // server (see `proto/ramen.proto`).
      expect(DeliveryHint.stream.wireName, 'stream');
      expect(DeliveryHint.ping.wireName, 'ping');
      expect(DeliveryHint.unknown.wireName, 'unknown');
    });

    test('fromWire round-trips every variant', () {
      for (final h in DeliveryHint.values) {
        expect(DeliveryHint.fromWire(h.wireName), h);
      }
    });

    test('fromWire returns unknown for null', () {
      expect(DeliveryHint.fromWire(null), DeliveryHint.unknown);
    });

    test('fromWire returns unknown for empty string', () {
      expect(DeliveryHint.fromWire(''), DeliveryHint.unknown);
    });

    test('fromWire returns unknown for unrecognized strings', () {
      expect(DeliveryHint.fromWire('garbage'), DeliveryHint.unknown);
      expect(
        DeliveryHint.fromWire('STREAM'),
        DeliveryHint.unknown,
        reason: 'wire is case-sensitive',
      );
    });
  });

  group('RamenEvent.fromJson', () {
    test('parses a stream-flavor event', () {
      final j = {
        'event_id': 'evt-1',
        'seq': 42,
        'app_id': 'app',
        'user_id': 'user-abc',
        'provider': 'whoop',
        'event_type': 'sleep.updated',
        'delivery_hint': 'stream',
        'raw_id': 'raw-xyz',
        'created_at': '2026-04-29T22:14:33Z',
        'attempt': 1,
        'is_replay': false,
      };
      final e = RamenEvent.fromJson(j);
      expect(e.eventId, 'evt-1');
      expect(e.seq, 42);
      expect(e.provider, 'whoop');
      expect(e.deliveryHint, DeliveryHint.stream);
      expect(e.requiresPull, isFalse);
      expect(e.createdAt, DateTime.utc(2026, 4, 29, 22, 14, 33));
    });

    test('parses a ping-flavor event with requiresPull=true', () {
      final j = {
        'event_id': 'evt-2',
        'seq': 1,
        'app_id': 'app',
        'user_id': 'user-abc',
        'provider': 'oura',
        'event_type': 'daily_sleep.create',
        'delivery_hint': 'ping',
        'raw_id': 'oura-record-id',
      };
      final e = RamenEvent.fromJson(j);
      expect(e.deliveryHint, DeliveryHint.ping);
      expect(
        e.requiresPull,
        isTrue,
        reason: 'ping flavor should signal "pull required"',
      );
    });

    test('parses an unknown-flavor event without crashing', () {
      final j = {
        'event_id': 'evt-3',
        'seq': 7,
        'app_id': 'app',
        'user_id': 'user-abc',
        'provider': 'future-vendor',
        'event_type': 'something.new',
        'delivery_hint': 'never-heard-of-it',
      };
      final e = RamenEvent.fromJson(j);
      expect(e.deliveryHint, DeliveryHint.unknown);
      expect(
        e.requiresPull,
        isFalse,
        reason: 'unknown defaults to not pulling',
      );
    });

    test('tolerates missing delivery_hint by treating as unknown', () {
      final j = {
        'event_id': 'evt-4',
        'seq': 1,
        'app_id': 'app',
        'user_id': 'u',
        'provider': 'whoop',
        'event_type': 'sleep.updated',
        // delivery_hint absent (older RAMEN deploy that hasn't yet
        // shipped capability-flavored delivery)
      };
      final e = RamenEvent.fromJson(j);
      expect(e.deliveryHint, DeliveryHint.unknown);
    });

    test('tolerates missing optional fields', () {
      final j = <String, dynamic>{
        'event_id': 'evt-5',
        'app_id': 'app',
        'user_id': 'u',
        'provider': 'oura',
        'event_type': 'x',
      };
      final e = RamenEvent.fromJson(j);
      expect(e.eventId, 'evt-5');
      expect(e.seq, 0);
      expect(e.rawId, '');
      expect(e.payload, isNull);
      expect(e.createdAt, isNull);
      expect(e.firstSentAt, isNull);
      expect(e.attempt, 0);
      expect(e.isReplay, isFalse);
    });
  });

  group('RamenEvent payload decoding', () {
    test('decodes a base64-encoded inline payload (Go []byte JSON shape)', () {
      final payloadJson = '{"hr":58,"hrv":42}';
      final j = {
        'event_id': 'evt-1',
        'seq': 1,
        'app_id': 'app',
        'user_id': 'u',
        'provider': 'whoop',
        'event_type': 'sleep.updated',
        'delivery_hint': 'stream',
        'payload': base64Encode(utf8.encode(payloadJson)),
      };
      final e = RamenEvent.fromJson(j);
      expect(e.payload, isNotNull);
      expect(utf8.decode(e.payload!), payloadJson);
      expect(e.payloadAsMap, equals({'hr': 58, 'hrv': 42}));
    });

    test('payloadAsMap returns null when payload is absent', () {
      final j = {
        'event_id': 'evt-1',
        'seq': 1,
        'app_id': 'app',
        'user_id': 'u',
        'provider': 'whoop',
        'event_type': 'sleep.updated',
        'delivery_hint': 'stream',
      };
      expect(RamenEvent.fromJson(j).payloadAsMap, isNull);
    });

    test('payloadAsMap returns null when payload is not valid JSON', () {
      final j = {
        'event_id': 'evt-1',
        'seq': 1,
        'app_id': 'app',
        'user_id': 'u',
        'provider': 'whoop',
        'event_type': 'sleep.updated',
        'delivery_hint': 'stream',
        'payload': base64Encode(utf8.encode('not-json-bytes')),
      };
      expect(RamenEvent.fromJson(j).payloadAsMap, isNull);
    });
  });

  group('RamenEvent.requiresPull semantics', () {
    test('only ping flavor signals pull-required', () {
      RamenEvent build(DeliveryHint h) => RamenEvent(
        eventId: 'e',
        seq: 0,
        appId: 'a',
        userId: 'u',
        provider: 'p',
        eventType: 't',
        deliveryHint: h,
      );
      expect(build(DeliveryHint.stream).requiresPull, isFalse);
      expect(build(DeliveryHint.ping).requiresPull, isTrue);
      expect(build(DeliveryHint.unknown).requiresPull, isFalse);
    });
  });

  group('RamenEvent.fromRuntimeJson', () {
    // Mirrors the JSON shape emitted by the native runtime's
    // `synheart_core_set_stream_callback` FFI export. Differences vs cloud wire:
    //   - `payload_json` (decoded UTF-8 string) instead of base64 `payload`
    //   - `delivery_attempt` instead of `attempt`
    //   - no `app_id` / `user_id` / `created_at` / `first_sent_at`
    test('parses runtime stream-flavor event and re-encodes payload', () {
      final j = {
        'event_id': 'evt-1',
        'seq': 42,
        'provider': 'whoop',
        'event_type': 'sleep.updated',
        'raw_id': 'raw-xyz',
        'payload_json': '{"hr":58,"hrv":42}',
        'is_replay': false,
        'delivery_attempt': 2,
        'delivery_hint': 'stream',
      };
      final e = RamenEvent.fromRuntimeJson(
        j,
        appId: 'pulse-focus',
        userId: 'user-abc',
      );
      expect(e.eventId, 'evt-1');
      expect(e.seq, 42);
      expect(e.appId, 'pulse-focus');
      expect(e.userId, 'user-abc');
      expect(e.provider, 'whoop');
      expect(e.deliveryHint, DeliveryHint.stream);
      expect(e.attempt, 2);
      expect(e.requiresPull, isFalse);
      // payload_json is re-encoded so payloadAsMap keeps working
      expect(e.payloadAsMap, equals({'hr': 58, 'hrv': 42}));
    });

    test('parses runtime ping-flavor event without inline payload', () {
      final j = {
        'event_id': 'evt-2',
        'seq': 1,
        'provider': 'oura',
        'event_type': 'daily_sleep.create',
        'raw_id': 'oura-record-id',
        'payload_json': '',
        'delivery_hint': 'ping',
      };
      final e = RamenEvent.fromRuntimeJson(j, userId: 'u');
      expect(e.deliveryHint, DeliveryHint.ping);
      expect(e.requiresPull, isTrue);
      expect(e.payload, isNull);
      expect(e.rawId, 'oura-record-id');
    });

    test('treats missing delivery_hint as unknown (older runtime build)', () {
      final e = RamenEvent.fromRuntimeJson({
        'event_id': 'evt-3',
        'seq': 1,
        'provider': 'whoop',
        'event_type': 'sleep.updated',
        'payload_json': '{}',
      });
      expect(e.deliveryHint, DeliveryHint.unknown);
      expect(e.appId, '');
      expect(e.userId, '');
    });
  });

  group('RamenEvent.toString', () {
    test('includes the key fields a developer needs at a glance', () {
      final e = RamenEvent.fromJson({
        'event_id': 'evt-x',
        'seq': 99,
        'app_id': 'a',
        'user_id': 'u',
        'provider': 'oura',
        'event_type': 'daily_sleep.create',
        'delivery_hint': 'ping',
      });
      final s = e.toString();
      expect(s, contains('evt-x'));
      expect(s, contains('99'));
      expect(s, contains('oura'));
      expect(s, contains('ping'));
    });
  });
}
