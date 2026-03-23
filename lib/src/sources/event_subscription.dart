import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/logger.dart';

/// Event received from SSE stream
class WearServiceEvent {
  final String? id;
  final String? event;
  final Map<String, dynamic>? data;
  final DateTime timestamp;

  WearServiceEvent({this.id, this.event, this.data, DateTime? timestamp})
    : timestamp = timestamp ?? DateTime.now();

  @override
  String toString() {
    return 'WearServiceEvent(id: $id, event: $event, data: $data, timestamp: $timestamp)';
  }
}

/// SSE subscription service for wear service events.
///
/// Subscribes to Server-Sent Events (SSE). Real-time Garmin data is also
/// delivered via RAMEN gRPC when app is active.
///
/// Every request sends x-app-id and x-api-key (Managed OAuth v2).
class EventSubscriptionService {
  final String baseUrl;
  final String appId;
  final String apiKey;
  StreamController<WearServiceEvent>? _eventController;
  http.Client? _client;
  StreamSubscription<List<int>>? _streamSubscription;
  bool _isSubscribed = false;
  bool _isDisposed = false;

  EventSubscriptionService({
    required this.baseUrl,
    required this.appId,
    this.apiKey = '',
  });

  Map<String, String> _authHeaders() {
    final h = <String, String>{'Accept': 'text/event-stream', 'Cache-Control': 'no-cache'};
    if (appId.isNotEmpty) h['x-app-id'] = appId;
    if (apiKey.isNotEmpty) h['x-api-key'] = apiKey;
    return h;
  }

  /// Subscribe to SSE events
  ///
  /// Optional parameters:
  /// - userId: Filter events for specific user
  /// - vendors: Comma-separated vendor filter (e.g., "whoop,garmin")
  ///
  /// Returns a stream of WearServiceEvent objects.
  ///
  /// Example:
  /// ```dart
  /// final subscription = EventSubscriptionService(
  ///   baseUrl: 'https://api.wear.synheart.ai',
  ///   appId: 'app-123',
  /// );
  ///
  /// subscription.subscribe(userId: 'user-456', vendors: ['whoop'])
  ///   .listen((event) {
  ///     print('Received event: ${event.event}');
  ///     print('Data: ${event.data}');
  ///   });
  /// ```
  Stream<WearServiceEvent> subscribe({String? userId, List<String>? vendors}) {
    if (_isSubscribed) {
      throw Exception(
        'Already subscribed. Cancel existing subscription first.',
      );
    }

    if (_isDisposed) {
      throw Exception('Service has been disposed. Create a new instance.');
    }

    _eventController = StreamController<WearServiceEvent>.broadcast();
    _isSubscribed = true;

    _startSSEConnection(userId: userId, vendors: vendors);

    return _eventController!.stream;
  }

  Future<void> _startSSEConnection({
    String? userId,
    List<String>? vendors,
  }) async {
    final params = {
      'app_id': appId,
      if (userId != null) 'user_id': userId,
      if (vendors != null && vendors.isNotEmpty) 'vendors': vendors.join(','),
    };

    final cleanBaseUrl = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final uri = Uri.parse(
      '$cleanBaseUrl/events/subscribe',
    ).replace(queryParameters: params);

    _client = http.Client();

    try {
      logDebug('Subscribing to SSE: $uri');

      final request = http.Request('GET', uri);
      _authHeaders().forEach((k, v) => request.headers[k] = v);

      final response = await _client!.send(request);

      if (response.statusCode != 200) {
        final errorBody = await response.stream.bytesToString();
        throw Exception(
          'SSE subscription failed (${response.statusCode}): $errorBody',
        );
      }

      logDebug('SSE connection established');

      // Parse SSE stream
      String buffer = '';
      try {
        await for (final chunk in response.stream.transform(utf8.decoder)) {
          if (_isDisposed) break;

          buffer += chunk;
          final parseResult = _parseSSEBuffer(buffer);
          buffer = parseResult.remainingBuffer;

          for (final event in parseResult.events) {
            _eventController?.add(event);
          }
        }
        // Stream ended normally (server closed connection)
        logDebug('SSE stream ended normally');
        if (!_isDisposed) {
          // Don't treat normal stream end as error - it's expected for SSE
          // The stream can end due to network issues, server restarts, etc.
          logWarning('SSE connection closed by server or network');
        }
      } catch (e, stackTrace) {
        // Only log as error if it's not a normal closure
        final errorMessage = e.toString();
        if (errorMessage.contains('Connection closed') ||
            errorMessage.contains('Connection terminated')) {
          logWarning('SSE connection closed: $e');
          // Don't add as error - connection closures are normal
        } else {
          logError('SSE connection error: $e', e, stackTrace);
          if (!_isDisposed) {
            _eventController?.addError(e);
          }
        }
      }
    } catch (e, stackTrace) {
      logError('SSE connection error: $e', e, stackTrace);
      if (!_isDisposed) {
        _eventController?.addError(e);
      }
    } finally {
      await cancel();
    }
  }

  /// Parse SSE buffer and extract events
  /// SSE format:
  /// id: 550e8400-e29b-41d4-a716-446655440000
  /// event: sleep
  /// data: {"vendor":"whoop","user_id":"user-456",...}
  ///
  /// or:
  /// : heartbeat (comment/heartbeat line)
  _SSEParseResult _parseSSEBuffer(String buffer) {
    final events = <WearServiceEvent>[];
    final lines = buffer.split('\n');
    String remainingBuffer = '';

    String? currentId;
    String? currentEvent;
    String? currentData;
    bool hasCompleteEvent = false;

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];

      // Empty line indicates end of event
      if (line.isEmpty) {
        // Process event if we have data (event type is optional, defaults to "message")
        if (hasCompleteEvent && currentData != null) {
          try {
            final dataMap = jsonDecode(currentData) as Map<String, dynamic>;
            events.add(
              WearServiceEvent(
                id: currentId,
                event:
                    currentEvent ??
                    'message', // Default to "message" if no event type
                data: dataMap,
              ),
            );
          } catch (e) {
            logWarning('Failed to parse SSE data: $e');
          }
        }

        // Reset for next event
        currentId = null;
        currentEvent = null;
        currentData = null;
        hasCompleteEvent = false;
        continue;
      }

      // Comment/heartbeat line (starts with :)
      if (line.startsWith(':')) {
        final comment = line.length > 1 ? line.substring(1).trim() : '';
        if (comment == 'heartbeat' || comment.isEmpty) {
          // Emit a heartbeat event for tracking
          logDebug('SSE heartbeat received');
          // Optionally emit a heartbeat event:
          // events.add(WearServiceEvent(
          //   event: 'heartbeat',
          //   data: {'type': 'heartbeat', 'timestamp': DateTime.now().toIso8601String()},
          // ));
        } else {
          logDebug('SSE comment: $comment');
        }
        continue;
      }

      if (line.startsWith('id:')) {
        currentId = line.substring(3).trim();
        hasCompleteEvent = true;
      } else if (line.startsWith('event:')) {
        currentEvent = line.substring(6).trim();
        hasCompleteEvent = true;
      } else if (line.startsWith('data:')) {
        final dataLine = line.substring(5).trim();
        if (currentData == null) {
          currentData = dataLine;
        } else {
          // Multi-line data (append)
          currentData += '\n$dataLine';
        }
        hasCompleteEvent = true;
      } else if (line.trim().isNotEmpty) {
        // Unknown line format - keep in buffer for next parse
        remainingBuffer += line + '\n';
      }
    }

    // If we have incomplete event data, keep it in buffer
    if (hasCompleteEvent && currentData != null && lines.isNotEmpty) {
      // Only keep incomplete data if we're not at the end of a complete event
      if (!lines.last.isEmpty) {
        remainingBuffer = lines.join('\n');
      }
    }

    return _SSEParseResult(events: events, remainingBuffer: remainingBuffer);
  }

  /// Cancel subscription and close connection
  Future<void> cancel() async {
    if (_isDisposed) return;

    _isDisposed = true;
    _isSubscribed = false;

    await _streamSubscription?.cancel();
    _client?.close(); // http.Client.close() returns void, not Future
    await _eventController?.close();

    _streamSubscription = null;
    _client = null;
    _eventController = null;
  }

  /// Dispose of the service
  void dispose() {
    cancel();
  }
}

/// Internal class for SSE parsing results
class _SSEParseResult {
  final List<WearServiceEvent> events;
  final String remainingBuffer;

  _SSEParseResult({required this.events, required this.remainingBuffer});
}
