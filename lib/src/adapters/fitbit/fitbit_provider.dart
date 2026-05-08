// SPDX-License-Identifier: Apache-2.0
//
// Provider for Fitbit cloud integration.
//
// Mirrors the WhoopProvider / OuraProvider pattern: OAuth flow is
// initiated through the Synheart Wear API. Tokens stay on the cloud
// side; the device only sees a `vendor_user_id`.
//
// Data types mapped to Fitbit's Web API endpoints
// (https://dev.fitbit.com/build/reference/web-api/):
//   - hrv         (heart-rate time series; intraday for paid scope)
//   - sleep       (date-range summaries)
//   - activity    (daily activity)
//   - userProfile (profile.json)

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/logger.dart';
import '../../core/models.dart' show WearMetrics;

class FitbitProvider {
  // ── Storage keys ─────────────────────────────────────────────────
  static const String _userIdKey = 'fitbit_user_id';
  static const String _baseUrlKey = 'sdk_base_url';
  static const String _appIdKey = 'sdk_app_id';
  static const String _apiKeyKey = 'sdk_api_key';
  static const String _projectIdKey = 'sdk_project_id';
  static const String _redirectUriKey = 'sdk_redirect_uri';

  // ── Defaults ─────────────────────────────────────────────────────
  static const String _envBaseUrl = String.fromEnvironment(
    'SYNHEART_BASE_URL',
    defaultValue: 'https://api.synheart.ai',
  );
  static const String defaultBaseUrl = '$_envBaseUrl/wear/v1';
  static const String defaultRedirectUri = 'synheart://oauth/callback';

  /// Wire-name shared with `domain.VendorFitbit` ("fitbit") in the cloud.
  static const String vendorName = 'fitbit';

  // ── Config ───────────────────────────────────────────────────────
  String baseUrl;
  String? redirectUri;
  String appId;
  String apiKey;
  String? projectId;
  String? userId;
  final bool _baseUrlExplicitlyProvided;

  String get _apiBase => baseUrl.endsWith('/')
      ? baseUrl.substring(0, baseUrl.length - 1)
      : baseUrl;

  FitbitProvider({
    String? baseUrl,
    String? appId,
    String? apiKey,
    String? projectId,
    String? redirectUri,
    this.userId,
    bool loadFromStorage = true,
  }) : baseUrl = baseUrl ?? defaultBaseUrl,
       appId = appId ?? '',
       apiKey = apiKey ?? '',
       projectId = projectId,
       redirectUri = redirectUri ?? defaultRedirectUri,
       _baseUrlExplicitlyProvided = baseUrl != null {
    logDebug(
      '🔧 FitbitProvider initialized: baseUrl=${this.baseUrl}, '
      'appId=$appId, projectId=$projectId',
    );
    if (loadFromStorage) {
      _loadFromStorage();
    }
  }

  // ── Storage ──────────────────────────────────────────────────────

  Future<void> _loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!_baseUrlExplicitlyProvided) {
        final stored = prefs.getString(_baseUrlKey);
        if (stored != null && stored.isNotEmpty) baseUrl = stored;
      }
      appId = prefs.getString(_appIdKey) ?? appId;
      apiKey = prefs.getString(_apiKeyKey) ?? apiKey;
      projectId = prefs.getString(_projectIdKey) ?? projectId;
      redirectUri = prefs.getString(_redirectUriKey) ?? redirectUri;
      userId = prefs.getString(_userIdKey) ?? userId;
    } catch (e) {
      logWarning('FitbitProvider: _loadFromStorage failed: $e');
    }
  }

  Future<void> reloadFromStorage() => _loadFromStorage();

  Future<void> saveUserId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userIdKey, id);
    userId = id;
  }

  Future<String?> loadUserId() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_userIdKey);
    if (id != null) userId = id;
    return id;
  }

  Future<void> clearUserId() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userIdKey);
    userId = null;
  }

  Future<void> saveConfiguration({
    String? baseUrl,
    String? appId,
    String? apiKey,
    String? projectId,
    String? redirectUri,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (baseUrl != null) {
      await prefs.setString(_baseUrlKey, baseUrl);
      this.baseUrl = baseUrl;
    }
    if (appId != null) {
      await prefs.setString(_appIdKey, appId);
      this.appId = appId;
    }
    if (apiKey != null) {
      await prefs.setString(_apiKeyKey, apiKey);
      this.apiKey = apiKey;
    }
    if (projectId != null) {
      await prefs.setString(_projectIdKey, projectId);
      this.projectId = projectId;
    }
    if (redirectUri != null) {
      await prefs.setString(_redirectUriKey, redirectUri);
      this.redirectUri = redirectUri;
    }
  }

  Future<Map<String, String?>> loadConfiguration() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      _baseUrlKey: prefs.getString(_baseUrlKey),
      _appIdKey: prefs.getString(_appIdKey),
      _apiKeyKey: prefs.getString(_apiKeyKey),
      _projectIdKey: prefs.getString(_projectIdKey),
      _redirectUriKey: prefs.getString(_redirectUriKey),
      _userIdKey: prefs.getString(_userIdKey),
    };
  }

  // ── OAuth ────────────────────────────────────────────────────────

  Future<Map<String, String>> initiateOAuthConnection({String? userId}) async {
    final uid = userId ?? this.userId;
    if (uid == null || uid.isEmpty) {
      throw StateError('FitbitProvider: userId required to initiate OAuth');
    }
    final url = Uri.parse('$_apiBase/oauth/$vendorName/initiate');
    final resp = await http.post(
      url,
      headers: _baseHeaders(),
      body: jsonEncode({
        'user_id': uid,
        'redirect_uri': redirectUri,
        'project_id': projectId,
      }),
    );
    if (resp.statusCode >= 400) {
      throw Exception(
        'FitbitProvider: initiate failed (${resp.statusCode}): '
        '${resp.body}',
      );
    }
    final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
    return {
      'auth_url': decoded['auth_url'] as String? ?? '',
      'state': decoded['state'] as String? ?? '',
    };
  }

  Future<String> startOAuthFlow({String? userId}) async {
    final result = await initiateOAuthConnection(userId: userId);
    final authUrl = result['auth_url'];
    if (authUrl == null || authUrl.isEmpty) {
      throw StateError('FitbitProvider: Synheart Wear API returned empty auth_url');
    }
    final launched = await launchUrl(
      Uri.parse(authUrl),
      mode: LaunchMode.externalApplication,
    );
    if (!launched) {
      throw Exception('FitbitProvider: could not launch authorize URL');
    }
    return result['state'] ?? '';
  }

  Future<String> connect([dynamic context, String? userId]) =>
      startOAuthFlow(userId: userId);

  /// Handle a deep-link callback. Expected URI shape:
  /// `synheart://oauth/callback?vendor=fitbit&user_id=...&status=success`
  Future<String?> handleDeepLinkCallback(Uri uri) async {
    final vendor = uri.queryParameters['vendor'];
    if (vendor != vendorName) {
      logDebug('FitbitProvider: deep link for vendor=$vendor, ignoring');
      return null;
    }
    final status = uri.queryParameters['status'];
    if (status != 'success') {
      logWarning('FitbitProvider: oauth callback status=$status');
      return null;
    }
    final newUserId = uri.queryParameters['user_id'];
    if (newUserId == null || newUserId.isEmpty) {
      logWarning('FitbitProvider: callback missing user_id');
      return null;
    }
    await saveUserId(newUserId);
    logInfo('FitbitProvider: connected (user_id=$newUserId)');
    return newUserId;
  }

  Future<void> markConnected(String userId) async {
    await saveUserId(userId);
  }

  Future<void> disconnect([String? userIdOverride]) async {
    final uid = userIdOverride ?? userId;
    if (uid == null || uid.isEmpty) {
      logDebug('FitbitProvider.disconnect: no userId');
      return;
    }
    final url = Uri.parse('$_apiBase/$vendorName/disconnect');
    try {
      await http.post(
        url,
        headers: _baseHeaders(),
        body: jsonEncode({'user_id': uid}),
      );
    } catch (e) {
      logWarning('FitbitProvider.disconnect: ${e.toString()}');
    } finally {
      await clearUserId();
    }
  }

  // ── Data fetchers ────────────────────────────────────────────────

  Future<List<WearMetrics>> fetchHrv({
    DateTime? start,
    DateTime? end,
    int limit = 100,
  }) async => _fetchData(dataType: 'hrv', start: start, end: end, limit: limit);

  Future<List<WearMetrics>> fetchSleep({
    DateTime? start,
    DateTime? end,
    int limit = 50,
  }) async =>
      _fetchData(dataType: 'sleep', start: start, end: end, limit: limit);

  Future<List<WearMetrics>> fetchActivity({
    DateTime? start,
    DateTime? end,
    int limit = 50,
  }) async =>
      _fetchData(dataType: 'activity', start: start, end: end, limit: limit);

  Future<Map<String, dynamic>?> fetchUserProfile() async {
    final uid = userId;
    if (uid == null || uid.isEmpty) return null;
    final qp = <String, String>{'user_id': uid, 'data_type': 'user_profile'};
    final url = Uri.parse(
      '$_apiBase/$vendorName/single',
    ).replace(queryParameters: qp);
    final resp = await http.get(url, headers: _baseHeaders());
    if (resp.statusCode >= 400) {
      logWarning(
        'FitbitProvider.fetchUserProfile: ${resp.statusCode} ${resp.body}',
      );
      return null;
    }
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  // ── Internals ────────────────────────────────────────────────────

  Future<List<WearMetrics>> _fetchData({
    required String dataType,
    DateTime? start,
    DateTime? end,
    int limit = 50,
  }) async {
    final uid = userId;
    if (uid == null || uid.isEmpty) {
      throw StateError('FitbitProvider.$dataType: not connected (no userId)');
    }
    final qp = <String, String>{
      'user_id': uid,
      'data_type': dataType,
      'limit': limit.toString(),
    };
    if (start != null) qp['start'] = start.toUtc().toIso8601String();
    if (end != null) qp['end'] = end.toUtc().toIso8601String();
    if (projectId != null && projectId!.isNotEmpty) {
      qp['project_id'] = projectId!;
    }

    final url = Uri.parse(
      '$_apiBase/$vendorName/data',
    ).replace(queryParameters: qp);
    final resp = await http.get(url, headers: _baseHeaders());
    if (resp.statusCode >= 400) {
      throw Exception(
        'FitbitProvider._fetchData($dataType): '
        '${resp.statusCode} ${resp.body}',
      );
    }
    final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
    final records = (decoded['records'] as List?) ?? const [];
    return records
        .whereType<Map<String, dynamic>>()
        .map(_recordToWearMetrics)
        .toList(growable: false);
  }

  Map<String, String> _baseHeaders() {
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
    if (apiKey.isNotEmpty) headers['x-api-key'] = apiKey;
    if (appId.isNotEmpty) headers['x-app-id'] = appId;
    return headers;
  }

  /// Map a Fitbit record envelope to the cross-vendor `WearMetrics`
  /// shape. Fitbit's responses vary by endpoint; we extract the
  /// universally-useful fields and stash the raw under `meta` for
  /// callers that want vendor-specific shapes.
  WearMetrics _recordToWearMetrics(Map<String, dynamic> record) {
    final tsRaw = record['dateTime'] ?? record['date'] ?? record['timestamp'];
    final ts = DateTime.tryParse('$tsRaw') ?? DateTime.now().toUtc();

    final metrics = <String, double>{};
    void put(String key, dynamic v) {
      if (v is num) metrics[key] = v.toDouble();
    }

    // Activity summary
    final summary = record['summary'] as Map<String, dynamic>?;
    if (summary != null) {
      put('steps', summary['steps']);
      put('calories', summary['caloriesOut']);
      put(
        'distance',
        summary['distances'] is List &&
                (summary['distances'] as List).isNotEmpty
            ? ((summary['distances'] as List).first
                  as Map<String, dynamic>)['distance']
            : null,
      );
    }
    // Heart-rate series item
    final value = record['value'];
    if (value is Map<String, dynamic>) {
      put('hr_resting', value['restingHeartRate']);
    }
    // Sleep summary
    final sleep = record['sleep'];
    if (sleep is List && sleep.isNotEmpty) {
      final first = sleep.first as Map<String, dynamic>;
      put(
        'sleep_duration_s',
        first['duration'] is num ? (first['duration'] as num) / 1000 : null,
      );
      put('sleep_efficiency', first['efficiency']);
    }

    return WearMetrics(
      timestamp: ts,
      deviceId: 'fitbit',
      source: 'fitbit',
      metrics: metrics,
      meta: {'data_type': '${record['data_type'] ?? ''}'},
    );
  }
}
