// Copyright 2025 Synheart. Wear Service REST client per SDK Integration Guide.

import 'dart:convert';

import 'package:http/http.dart' as http;

/// REST client for Wear Service: historical data and backfill.
/// Base URL: https://api.synheart.ai/wear/v1/{vendor}/data/{userId}/...
/// Per udated_doc.txt — use for Historical Charts and Backfill.
class WearServiceClient {
  WearServiceClient({
    required this.baseUrl,
    this.appId = '',
    this.apiKey = '',
    this.bearerToken,
    required this.vendor,
    required this.userId,
    this.client,
  }) : _base = _buildBase(baseUrl, vendor, userId);

  static Uri _buildBase(String baseUrl, String vendor, String userId) {
    final u = Uri.parse(baseUrl);
    final path = u.path.replaceFirst(RegExp(r'/+$'), '');
    final prefix = path.isEmpty ? '/wear/v1/$vendor/data/$userId' : '$path/wear/v1/$vendor/data/$userId';
    return u.replace(path: prefix.endsWith('/') ? prefix : '$prefix/');
  }

  final String baseUrl;
  final String appId;
  final String apiKey;
  final String? bearerToken;
  final String vendor;
  final String userId;
  final http.Client? client;

  late final Uri _base;

  static const String defaultBaseUrl = 'https://api.synheart.ai/';

  /// Create with default Synheart API base.
  factory WearServiceClient.synheart({
    required String vendor,
    required String userId,
    String appId = '',
    String apiKey = '',
    String? bearerToken,
    http.Client? client,
  }) {
    return WearServiceClient(
      baseUrl: defaultBaseUrl,
      appId: appId,
      apiKey: apiKey,
      bearerToken: bearerToken,
      vendor: vendor,
      userId: userId,
      client: client,
    );
  }

  http.Client get _client => client ?? http.Client();

  /// Headers for every request: X-app-id and X-api-key (security); optional Bearer.
  Map<String, String> get _headers {
    final h = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
    if (appId.isNotEmpty) h['x-app-id'] = appId;
    if (apiKey.isNotEmpty) h['x-api-key'] = apiKey;
    if (bearerToken != null && bearerToken!.isNotEmpty) {
      h['Authorization'] = 'Bearer $bearerToken';
    }
    return h;
  }

  Uri _path(String path, [Map<String, String>? queryParams]) {
    final p = path.replaceFirst(RegExp(r'^/+'), '').replaceFirst(RegExp(r'/+$'), '');
    if (p.isEmpty) {
      var u = _base;
      if (queryParams != null && queryParams.isNotEmpty) {
        u = u.replace(queryParameters: queryParams);
      }
      return u;
    }
    final segs = _base.pathSegments.toList()..addAll(p.split('/').where((s) => s.isNotEmpty));
    var u = _base.replace(path: '/${segs.join('/')}');
    if (queryParams != null && queryParams.isNotEmpty) {
      u = u.replace(queryParameters: queryParams);
    }
    return u;
  }

  /// GET historical data at a path (e.g. '', 'days', 'range', 'summary').
  /// [queryParams] e.g. from, to for date range.
  Future<WearServiceResponse> get(
    String path, {
    Map<String, String>? queryParams,
  }) async {
    final uri = _path(path, queryParams);
    final response = await _client.get(uri, headers: _headers);
    return WearServiceResponse(
      statusCode: response.statusCode,
      body: response.body,
      bodyJson: _tryJson(response.body),
    );
  }

  static Map<String, dynamic>? _tryJson(String body) {
    if (body.isEmpty) return null;
    try {
      return jsonDecode(body) as Map<String, dynamic>?;
    } catch (_) {
      return null;
    }
  }

  /// Fetch a date range of data (convenience). Path/query shape depends on backend.
  Future<WearServiceResponse> getRange({
    required DateTime from,
    required DateTime to,
    String path = 'range',
  }) async {
    return get(
      path,
      queryParams: {
        'from': from.toUtc().toIso8601String(),
        'to': to.toUtc().toIso8601String(),
      },
    );
  }
}

/// Response from Wear Service REST calls.
class WearServiceResponse {
  WearServiceResponse({
    required this.statusCode,
    required this.body,
    this.bodyJson,
  });

  final int statusCode;
  final String body;
  final Map<String, dynamic>? bodyJson;

  bool get isOk => statusCode >= 200 && statusCode < 300;
}
