// SPDX-License-Identifier: Apache-2.0
//
// RamenEventDispatcher — materializes a RAMEN event into a payload
// regardless of capability flavor.
//
// Apps consuming the streaming layer get [RamenEvent]s with three
// possible delivery hints:
//
//   - stream:  full payload arrived inline (Whoop)
//   - ping:    only a notification arrived; need a follow-up REST pull
//              (Garmin / Oura / Fitbit)
//   - unknown: REST-only vendor or older RAMEN deploy without the hint
//
// Calling code wants a single materialized payload either way. This
// dispatcher inspects [RamenEvent.deliveryHint] and either returns
// the inline payload or performs the REST pull for the caller.
//
// Usage:
//
//   final dispatcher = RamenEventDispatcher(
//     wearClientFactory: ({required vendor, required userId}) =>
//       WearServiceClient.synheart(vendor: vendor, userId: userId, ...),
//   );
//   final payload = await dispatcher.materialize(event);
//   if (payload != null) myApp.handleEvent(event, payload);

import 'dart:async';

import 'wear_service_client.dart';
import 'ramen_event.dart';

/// Builds a [WearServiceClient] for `(vendor, userId)`. Apps inject
/// this so the dispatcher doesn't need to know the app's auth
/// configuration.
typedef WearServiceClientFactory =
    WearServiceClient Function({
      required String vendor,
      required String userId,
    });

/// Performs the actual REST fetch given a `WearServiceClient` + a
/// raw record id. Pulled out so tests can stub it without spinning
/// up a real HTTP server.
typedef RecordFetcher =
    Future<Map<String, dynamic>?> Function(
      WearServiceClient client,
      String rawId,
    );

/// Default fetcher: calls `WearServiceClient.fetchRecord(rawId)`.
/// Apps with a non-standard endpoint shape can supply their own.
Future<Map<String, dynamic>?> _defaultFetchRecord(
  WearServiceClient client,
  String rawId,
) async {
  // WearServiceClient doesn't yet expose a generic fetchRecord; the
  // closest stable surface is a JSON GET against the Synheart Wear API.
  // We delegate to the client's `getJson` if present; otherwise
  // return null so callers know to retry via vendor-specific path.
  // Apps that need full control can swap the fetcher entirely.
  try {
    // ignore: avoid_dynamic_calls
    final dyn = client as dynamic;
    final result = await dyn.getJson(rawId);
    if (result is Map<String, dynamic>) return result;
    return null;
  } catch (_) {
    return null;
  }
}

class RamenEventDispatcher {
  RamenEventDispatcher({
    required this.wearClientFactory,
    RecordFetcher? recordFetcher,
  }) : _recordFetcher = recordFetcher ?? _defaultFetchRecord;

  final WearServiceClientFactory wearClientFactory;
  final RecordFetcher _recordFetcher;

  /// Resolve a [RamenEvent] into a materialized payload map.
  ///
  /// Decision tree:
  ///   stream  → return inline payload (or null if absent)
  ///   ping    → REST pull via WearServiceClient using event.rawId
  ///   unknown → prefer inline payload, fall back to REST if rawId
  ///             is set and the inline body is empty
  ///
  /// Returns null when the event has no actionable payload (the
  /// caller should typically log + skip).
  Future<Map<String, dynamic>?> materialize(RamenEvent event) async {
    switch (event.deliveryHint) {
      case DeliveryHint.stream:
        return event.payloadAsMap;

      case DeliveryHint.ping:
        return _pull(event);

      case DeliveryHint.unknown:
        // Try inline first; if it's empty AND we have a rawId,
        // attempt the pull as a best-effort fallback.
        final inline = event.payloadAsMap;
        if (inline != null && inline.isNotEmpty) return inline;
        if (event.rawId.isEmpty) return inline;
        return _pull(event);
    }
  }

  Future<Map<String, dynamic>?> _pull(RamenEvent event) async {
    if (event.userId.isEmpty || event.rawId.isEmpty) {
      return null;
    }
    final client = wearClientFactory(
      vendor: event.provider,
      userId: event.userId,
    );
    return _recordFetcher(client, event.rawId);
  }
}
