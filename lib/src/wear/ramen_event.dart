// SPDX-License-Identifier: Apache-2.0
//
// Typed event shape for RAMEN-delivered vendor messages.
//
// App code that consumes the streaming layer can decode the JSON
// envelope into [RamenEvent] and branch on [DeliveryHint] to decide
// whether to render the inline payload immediately (stream) or
// schedule a follow-up REST pull (ping).
//
// Wire-name compatibility:
//   - Field names use snake_case to match the server's JSON tags
//     (see `proto/ramen.proto` for the canonical wire shape).
//   - DeliveryHint.fromWire pins the three values the cloud emits.

import 'dart:convert';

import 'package:meta/meta.dart';

/// Delivery flavor the cloud stamped on an event, derived from the
/// source vendor's webhook capability.
///
/// **Wire values must match the RAMEN delivery-filter constants
/// (see `proto/ramen.proto`) byte-for-byte.** Renaming requires a
/// coordinated change with the server.
enum DeliveryHint {
  /// Full payload arrived inline; no follow-up pull needed (Whoop).
  stream('stream'),

  /// Vendor only sent a notification; client should pull the
  /// full record via REST when it wants the body
  /// (Garmin / Oura / Fitbit).
  ping('ping'),

  /// Flavor not in the cloud's capability registry — typically a
  /// REST-only vendor that shouldn't be pushing events at all,
  /// or a vendor the registry hasn't seen yet. Treat as stream by
  /// default to avoid an unnecessary pull, but log it.
  unknown('unknown');

  const DeliveryHint(this.wireName);
  final String wireName;

  /// Parse the cloud's wire string. Returns [unknown] for null,
  /// empty, or unrecognized values so callers always get a usable
  /// enum without a separate null branch.
  static DeliveryHint fromWire(String? raw) {
    if (raw == null || raw.isEmpty) return DeliveryHint.unknown;
    for (final h in DeliveryHint.values) {
      if (h.wireName == raw) return h;
    }
    return DeliveryHint.unknown;
  }
}

/// Decoded RAMEN message envelope. Mirrors the canonical wire shape
/// in `proto/ramen.proto`; fields not all apps need are optional /
/// nullable.
@immutable
class RamenEvent {
  const RamenEvent({
    required this.eventId,
    required this.seq,
    required this.appId,
    required this.userId,
    required this.provider,
    required this.eventType,
    required this.deliveryHint,
    this.rawId = '',
    this.payload,
    this.createdAt,
    this.attempt = 0,
    this.firstSentAt,
    this.isReplay = false,
  });

  /// Unique event identifier.
  final String eventId;

  /// Monotonic per-user sequence number.
  final int seq;

  final String appId;
  final String userId;

  /// Source vendor (e.g. "whoop", "oura", "garmin", "fitbit").
  final String provider;

  /// Vendor-specific event type (e.g. "sleep.updated",
  /// "daily_sleep.create").
  final String eventType;

  /// How to interpret this event — see [DeliveryHint].
  final DeliveryHint deliveryHint;

  /// Reference to the raw payload in the Synheart Wear API backing store.
  /// Used by ping-flavored consumers to fetch full detail via REST.
  final String rawId;

  /// Inline payload bytes (small streams; absent on ping).
  final List<int>? payload;

  final DateTime? createdAt;
  final int attempt;
  final DateTime? firstSentAt;
  final bool isReplay;

  /// Decoded inline payload as a map. Returns null when [payload] is
  /// absent or not valid JSON.
  Map<String, dynamic>? get payloadAsMap {
    final p = payload;
    if (p == null || p.isEmpty) return null;
    try {
      final decoded = jsonDecode(utf8.decode(p));
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {
      return null;
    }
    return null;
  }

  /// Whether the consumer should perform a follow-up REST pull to
  /// get the full record. True only for ping-flavored deliveries.
  bool get requiresPull => deliveryHint == DeliveryHint.ping;

  /// Build from RAMEN's JSON envelope. Tolerates missing optional
  /// fields and unknown delivery hint values.
  factory RamenEvent.fromJson(Map<String, dynamic> j) {
    return RamenEvent(
      eventId: (j['event_id'] as String?) ?? '',
      seq: (j['seq'] as num?)?.toInt() ?? 0,
      appId: (j['app_id'] as String?) ?? '',
      userId: (j['user_id'] as String?) ?? '',
      provider: (j['provider'] as String?) ?? '',
      eventType: (j['event_type'] as String?) ?? '',
      deliveryHint: DeliveryHint.fromWire(j['delivery_hint'] as String?),
      rawId: (j['raw_id'] as String?) ?? '',
      payload: _decodePayload(j['payload']),
      createdAt: _parseTime(j['created_at']),
      attempt: (j['attempt'] as num?)?.toInt() ?? 0,
      firstSentAt: _parseTime(j['first_sent_at']),
      isReplay: (j['is_replay'] as bool?) ?? false,
    );
  }

  /// Build from the JSON shape emitted by the native runtime's
  /// `synheart_core_set_stream_callback` FFI export.
  ///
  /// The runtime shape differs from the cloud wire shape in two ways:
  ///   - `payload_json` is a pre-decoded UTF-8 JSON string rather than
  ///     base64 bytes; this factory re-encodes it to bytes so the
  ///     existing [payloadAsMap] getter / [RamenEventDispatcher] keep
  ///     working transparently.
  ///   - `app_id` / `user_id` are connection-level (not event-level)
  ///     and the runtime doesn't carry them on the broadcast. The
  ///     caller (typically the Flutter SDK shell) supplies them from
  ///     the active stream config.
  factory RamenEvent.fromRuntimeJson(
    Map<String, dynamic> j, {
    String appId = '',
    String userId = '',
  }) {
    final payloadJson = (j['payload_json'] as String?) ?? '';
    return RamenEvent(
      eventId: (j['event_id'] as String?) ?? '',
      seq: (j['seq'] as num?)?.toInt() ?? 0,
      appId: appId,
      userId: userId,
      provider: (j['provider'] as String?) ?? '',
      eventType: (j['event_type'] as String?) ?? '',
      deliveryHint: DeliveryHint.fromWire(j['delivery_hint'] as String?),
      rawId: (j['raw_id'] as String?) ?? '',
      payload: payloadJson.isEmpty ? null : utf8.encode(payloadJson),
      attempt: (j['delivery_attempt'] as num?)?.toInt() ?? 0,
      isReplay: (j['is_replay'] as bool?) ?? false,
    );
  }

  static List<int>? _decodePayload(dynamic raw) {
    if (raw == null) return null;
    if (raw is String && raw.isNotEmpty) {
      // The server serializes `[]byte` payloads as base64 strings.
      try {
        return base64Decode(raw);
      } catch (_) {
        // Some test producers may inline raw UTF-8 bytes; fall back.
        return utf8.encode(raw);
      }
    }
    if (raw is List) {
      return raw.whereType<num>().map((n) => n.toInt()).toList(growable: false);
    }
    return null;
  }

  static DateTime? _parseTime(dynamic raw) {
    if (raw is String && raw.isNotEmpty) {
      return DateTime.tryParse(raw);
    }
    return null;
  }

  @override
  String toString() =>
      'RamenEvent('
      'eventId=$eventId, seq=$seq, provider=$provider, '
      'type=$eventType, hint=${deliveryHint.wireName})';
}
