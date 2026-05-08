// SPDX-License-Identifier: Apache-2.0
//
// Provider for Oura ring cloud integration.
//
// Mirrors the WhoopProvider pattern: OAuth flow is initiated through
// the Synheart Wear API (`{baseUrl}/wear/v1/...`); the user's
// Oura access token never reaches the device. The client gets back
// a `vendor_user_id` after a successful connection and uses it to
// pull normalized health data through synheart's API.
//
// Data types (per Oura's v2 user-collection API):
//   - sleep         (daily_sleep + detailed sleep windows)
//   - hrv           (heartrate endpoint, includes RMSSD)
//   - activity      (daily_activity)
//   - readiness     (daily_readiness, mapped to Recovery)
//   - user_profile  (personal_info)

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/logger.dart';
import '../../core/models.dart' show WearMetrics;

class OuraProvider {
  // ── Storage keys ─────────────────────────────────────────────────
  static const String _userIdKey = 'oura_user_id';
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

  /// Vendor name passed to Synheart Wear API URL paths. Must match
  /// `domain.VendorOura` ("oura") on the cloud side.
  static const String vendorName = 'oura';

  // ── Configuration ────────────────────────────────────────────────
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

  OuraProvider({
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
      '🔧 OuraProvider initialized: baseUrl=${this.baseUrl}, '
      'appId=$appId, projectId=$projectId',
    );
    if (loadFromStorage) {
      _loadFromStorage();
    }
  }

  // ── Storage round-trip ───────────────────────────────────────────

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
      logWarning('OuraProvider: _loadFromStorage failed: $e');
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

  // ── OAuth flow (mediated by Synheart Wear API) ────────────────────────

  /// Build the OAuth URL by calling
  /// `POST {baseUrl}/oauth/oura/initiate`. The Synheart Wear API holds
  /// Oura's client secret + builds the signed authorize URL with
  /// the right state. Returns a map with `auth_url` + `state`.
  Future<Map<String, String>> initiateOAuthConnection({String? userId}) async {
    final uid = userId ?? this.userId;
    if (uid == null || uid.isEmpty) {
      throw StateError('OuraProvider: userId required to initiate OAuth');
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
        'OuraProvider: initiate failed (${resp.statusCode}): '
        '${resp.body}',
      );
    }
    final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
    return {
      'auth_url': decoded['auth_url'] as String? ?? '',
      'state': decoded['state'] as String? ?? '',
    };
  }

  /// Initiate the OAuth flow and launch the system browser to the
  /// authorize URL. Returns the state token so the caller can
  /// match it in the deep-link callback.
  Future<String> startOAuthFlow({String? userId}) async {
    final result = await initiateOAuthConnection(userId: userId);
    final authUrl = result['auth_url'];
    if (authUrl == null || authUrl.isEmpty) {
      throw StateError('OuraProvider: Synheart Wear API returned empty auth_url');
    }
    final launched = await launchUrl(
      Uri.parse(authUrl),
      mode: LaunchMode.externalApplication,
    );
    if (!launched) {
      throw Exception('OuraProvider: could not launch authorize URL');
    }
    return result['state'] ?? '';
  }

  /// Convenience wrapper for app code: kick off the OAuth flow and
  /// return the state. `context` parameter is accepted for parity
  /// with other adapters but unused.
  Future<String> connect([dynamic context, String? userId]) =>
      startOAuthFlow(userId: userId);

  /// Handle a deep-link callback from the OAuth provider. Returns
  /// the new vendor_user_id on success, or null when the callback
  /// is for a different vendor / state.
  ///
  /// Expected URI shape: `synheart://oauth/callback?vendor=oura&user_id=...&status=success`
  Future<String?> handleDeepLinkCallback(Uri uri) async {
    final vendor = uri.queryParameters['vendor'];
    if (vendor != vendorName) {
      logDebug('OuraProvider: deep link for vendor=$vendor, ignoring');
      return null;
    }
    final status = uri.queryParameters['status'];
    if (status != 'success') {
      logWarning('OuraProvider: oauth callback status=$status');
      return null;
    }
    final newUserId = uri.queryParameters['user_id'];
    if (newUserId == null || newUserId.isEmpty) {
      logWarning('OuraProvider: callback missing user_id');
      return null;
    }
    await saveUserId(newUserId);
    logInfo('OuraProvider: connected (user_id=$newUserId)');
    return newUserId;
  }

  /// Mark the connection as established without going through deep
  /// link. Useful when the Synheart Wear API confirms via a different
  /// channel (e.g. polling).
  Future<void> markConnected(String userId) async {
    await saveUserId(userId);
  }

  Future<void> disconnect([String? userIdOverride]) async {
    final uid = userIdOverride ?? userId;
    if (uid == null || uid.isEmpty) {
      logDebug('OuraProvider.disconnect: no userId');
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
      logWarning('OuraProvider.disconnect: ${e.toString()}');
    } finally {
      await clearUserId();
    }
  }

  // ── Data fetchers ────────────────────────────────────────────────

  /// Fetch daily readiness records (mapped to Recovery).
  Future<List<WearMetrics>> fetchReadiness({
    DateTime? start,
    DateTime? end,
    int limit = 50,
  }) async {
    return _fetchData(
      dataType: 'readiness',
      start: start,
      end: end,
      limit: limit,
    );
  }

  /// Fetch sleep records (daily_sleep + detailed sleep windows).
  Future<List<WearMetrics>> fetchSleep({
    DateTime? start,
    DateTime? end,
    int limit = 50,
  }) async {
    return _fetchData(dataType: 'sleep', start: start, end: end, limit: limit);
  }

  /// Fetch HRV / heart-rate samples (the Oura `/heartrate` endpoint).
  Future<List<WearMetrics>> fetchHrv({
    DateTime? start,
    DateTime? end,
    int limit = 200,
  }) async {
    return _fetchData(dataType: 'hrv', start: start, end: end, limit: limit);
  }

  /// Fetch daily activity records.
  Future<List<WearMetrics>> fetchActivity({
    DateTime? start,
    DateTime? end,
    int limit = 50,
  }) async {
    return _fetchData(
      dataType: 'activity',
      start: start,
      end: end,
      limit: limit,
    );
  }

  /// Fetch the connected user's profile (personal_info).
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
        'OuraProvider.fetchUserProfile: ${resp.statusCode} ${resp.body}',
      );
      return null;
    }
    final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
    return decoded;
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
      throw StateError('OuraProvider.$dataType: not connected (no userId)');
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
        'OuraProvider._fetchData($dataType): '
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

  /// Map a single Oura record envelope (returned by Synheart Wear API) to
  /// the cross-vendor `WearMetrics` shape.
  ///
  /// Oura records vary by data type; we extract what's universally
  /// useful and stash the raw record under `meta` for callers that
  /// want vendor-specific fields.
  WearMetrics _recordToWearMetrics(Map<String, dynamic> record) {
    final tsRaw =
        record['timestamp'] ?? record['day'] ?? record['summary_date'];
    final ts = DateTime.tryParse('$tsRaw') ?? DateTime.now().toUtc();

    final metrics = <String, double>{};
    void put(String key, dynamic v) {
      if (v is num) metrics[key] = v.toDouble();
    }

    put('hr', record['average_heart_rate']);
    put('hr', record['heart_rate']);
    put('hrv', record['rmssd']);
    put('hrv', record['average_hrv']);
    put('steps', record['steps']);
    put('calories', record['active_calories']);
    put('readiness_score', record['score']);
    put('sleep_duration_s', record['total_sleep_duration']);
    put('deep_sleep_s', record['deep_sleep_duration']);
    put('rem_sleep_s', record['rem_sleep_duration']);
    put('light_sleep_s', record['light_sleep_duration']);

    return WearMetrics(
      timestamp: ts,
      deviceId: 'oura',
      source: 'oura',
      metrics: metrics,
      meta: {
        'data_type': '${record['data_type'] ?? ''}',
        'object_id': '${record['object_id'] ?? record['id'] ?? ''}',
      },
    );
  }
}
