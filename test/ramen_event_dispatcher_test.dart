// SPDX-License-Identifier: Apache-2.0

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:synheart_wear/synheart_wear.dart'
    show DeliveryHint, RamenEvent, RamenEventDispatcher, WearServiceClient;

WearServiceClient _fakeClient({
  required String vendor,
  required String userId,
}) {
  // The client is never actually invoked because we always inject
  // a recordFetcher in tests; just return a real instance so the
  // typedef matches.
  return WearServiceClient.synheart(vendor: vendor, userId: userId);
}

RamenEvent _stream({Map<String, dynamic>? payload}) => RamenEvent(
  eventId: 'e-stream',
  seq: 1,
  appId: 'app',
  userId: 'u',
  provider: 'whoop',
  eventType: 'sleep.updated',
  deliveryHint: DeliveryHint.stream,
  payload: payload == null ? null : utf8.encode(jsonEncode(payload)),
);

RamenEvent _ping({String rawId = 'raw-1', String userId = 'u'}) => RamenEvent(
  eventId: 'e-ping',
  seq: 2,
  appId: 'app',
  userId: userId,
  provider: 'oura',
  eventType: 'daily_sleep.create',
  deliveryHint: DeliveryHint.ping,
  rawId: rawId,
);

RamenEvent _unknown({Map<String, dynamic>? payload, String rawId = ''}) =>
    RamenEvent(
      eventId: 'e-unknown',
      seq: 3,
      appId: 'app',
      userId: 'u',
      provider: 'future-vendor',
      eventType: 'something.new',
      deliveryHint: DeliveryHint.unknown,
      rawId: rawId,
      payload: payload == null ? null : utf8.encode(jsonEncode(payload)),
    );

void main() {
  group('RamenEventDispatcher.materialize — stream flavor', () {
    test('returns the inline payload as-is', () async {
      final dispatcher = RamenEventDispatcher(
        wearClientFactory: _fakeClient,
        recordFetcher: (_, __) async => fail('stream should not pull'),
      );
      final result = await dispatcher.materialize(
        _stream(payload: {'hr': 58, 'hrv': 42}),
      );
      expect(result, equals({'hr': 58, 'hrv': 42}));
    });

    test('returns null when stream payload is absent', () async {
      final dispatcher = RamenEventDispatcher(
        wearClientFactory: _fakeClient,
        recordFetcher: (_, __) async => fail('stream should not pull'),
      );
      expect(await dispatcher.materialize(_stream()), isNull);
    });
  });

  group('RamenEventDispatcher.materialize — ping flavor', () {
    test('pulls via the injected recordFetcher', () async {
      var fetched = false;
      String? observedRawId;
      final dispatcher = RamenEventDispatcher(
        wearClientFactory: _fakeClient,
        recordFetcher: (_, rawId) async {
          fetched = true;
          observedRawId = rawId;
          return {'pulled': true, 'value': 99};
        },
      );

      final result = await dispatcher.materialize(_ping(rawId: 'oura-rec-x'));
      expect(fetched, isTrue, reason: 'ping must trigger a pull');
      expect(observedRawId, 'oura-rec-x');
      expect(result, equals({'pulled': true, 'value': 99}));
    });

    test('returns null when ping has no rawId to pull', () async {
      var fetched = false;
      final dispatcher = RamenEventDispatcher(
        wearClientFactory: _fakeClient,
        recordFetcher: (_, __) async {
          fetched = true;
          return {'unreachable': true};
        },
      );
      final result = await dispatcher.materialize(_ping(rawId: ''));
      expect(fetched, isFalse);
      expect(result, isNull);
    });

    test('returns null when ping has no userId', () async {
      var fetched = false;
      final dispatcher = RamenEventDispatcher(
        wearClientFactory: _fakeClient,
        recordFetcher: (_, __) async {
          fetched = true;
          return {'x': 1};
        },
      );
      final result = await dispatcher.materialize(
        _ping(rawId: 'r1', userId: ''),
      );
      expect(fetched, isFalse);
      expect(result, isNull);
    });

    test('returns null when the fetcher itself returns null', () async {
      final dispatcher = RamenEventDispatcher(
        wearClientFactory: _fakeClient,
        recordFetcher: (_, __) async => null,
      );
      expect(await dispatcher.materialize(_ping()), isNull);
    });
  });

  group('RamenEventDispatcher.materialize — unknown flavor', () {
    test('uses inline payload when present and non-empty', () async {
      var fetched = false;
      final dispatcher = RamenEventDispatcher(
        wearClientFactory: _fakeClient,
        recordFetcher: (_, __) async {
          fetched = true;
          return {'unreachable': true};
        },
      );
      final result = await dispatcher.materialize(
        _unknown(payload: {'hr': 60}, rawId: 'r1'),
      );
      expect(
        fetched,
        isFalse,
        reason: 'unknown should prefer inline when non-empty',
      );
      expect(result, equals({'hr': 60}));
    });

    test(
      'falls back to REST pull when inline is missing and rawId present',
      () async {
        var fetched = false;
        final dispatcher = RamenEventDispatcher(
          wearClientFactory: _fakeClient,
          recordFetcher: (_, rawId) async {
            fetched = true;
            return {'fetched_for': rawId};
          },
        );
        final result = await dispatcher.materialize(_unknown(rawId: 'r1'));
        expect(fetched, isTrue);
        expect(result, equals({'fetched_for': 'r1'}));
      },
    );

    test('returns null when inline is missing and no rawId', () async {
      var fetched = false;
      final dispatcher = RamenEventDispatcher(
        wearClientFactory: _fakeClient,
        recordFetcher: (_, __) async {
          fetched = true;
          return {'unreachable': true};
        },
      );
      expect(await dispatcher.materialize(_unknown()), isNull);
      expect(fetched, isFalse);
    });
  });

  group('RamenEventDispatcher uses the right client per event', () {
    test('passes vendor + userId from event into the factory', () async {
      String? observedVendor;
      String? observedUserId;
      final dispatcher = RamenEventDispatcher(
        wearClientFactory: ({required vendor, required userId}) {
          observedVendor = vendor;
          observedUserId = userId;
          return WearServiceClient.synheart(vendor: vendor, userId: userId);
        },
        recordFetcher: (_, __) async => {'ok': true},
      );
      await dispatcher.materialize(_ping(rawId: 'r1'));
      expect(observedVendor, 'oura');
      expect(observedUserId, 'u');
    });
  });
}
