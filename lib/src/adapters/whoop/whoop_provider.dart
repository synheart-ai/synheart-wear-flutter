import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/logger.dart';
import '../../core/models.dart' show WearMetrics;
import '../wear_request_signer.dart';

/// Provider for Whoop cloud API integration
///
/// Handles OAuth 2.0 authentication and data fetching from Whoop devices.
/// Supports cycles, recovery, sleep, and workout data retrieval.
class WhoopProvider {
  // Storage keys
  static const String _userIdKey = 'whoop_user_id';
  static const String _baseUrlKey = 'sdk_base_url';
  static const String _appIdKey = 'sdk_app_id';
  static const String _apiKeyKey = 'sdk_api_key';
  static const String _projectIdKey = 'sdk_project_id';
  static const String _redirectUriKey = 'sdk_redirect_uri';

  // Resolved from SYNHEART_BASE_URL at compile time.
  static const String _envBaseUrl = String.fromEnvironment(
    'SYNHEART_BASE_URL',
    defaultValue: 'https://api.synheart.ai',
  );
  static const String defaultBaseUrl = '$_envBaseUrl/wear/v1';
  static const String defaultRedirectUri = 'synheart://oauth/callback';

  String baseUrl;
  String? redirectUri;
  String appId; // REQUIRED
  String apiKey; // REQUIRED - sent as x-api-key on every request
  String? projectId; // Optional - for WHOOP data queries
  String? userId;
  final bool _baseUrlExplicitlyProvided;

  /// Optional hook to supply per-request auth headers. When null, requests use
  /// the default app-id/app-key headers.
  final WearRequestSigner? signRequest;

  /// Base URL for all API requests (auth, data, events).
  String get _apiBase {
    final b = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    return b;
  }

  WhoopProvider({
    String? baseUrl,
    String? appId,
    String? apiKey,
    String? projectId,
    String? redirectUri,
    this.userId,
    this.signRequest,
    bool loadFromStorage = true,
  }) : baseUrl = baseUrl ?? defaultBaseUrl,
       appId = appId ?? 'app_test_ios_XvHE1g',
       apiKey = apiKey ?? '',
       projectId = projectId,
       redirectUri = redirectUri ?? defaultRedirectUri,
       _baseUrlExplicitlyProvided = baseUrl != null {
    logDebug(
      'WhoopProvider init: appId=$appId loadFromStorage=$loadFromStorage',
    );
    if (loadFromStorage) {
      _loadFromStorage();
    }
  }

  /// Load configuration and userId from local storage
  Future<void> _loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Load configuration
      final savedBaseUrl = prefs.getString(_baseUrlKey);
      final savedAppId = prefs.getString(_appIdKey);
      final savedApiKey = prefs.getString(_apiKeyKey);
      final savedProjectId = prefs.getString(_projectIdKey);
      final savedRedirectUri = prefs.getString(_redirectUriKey);

      if (savedBaseUrl != null && !_baseUrlExplicitlyProvided) {
        baseUrl = savedBaseUrl;
      }
      if (savedAppId != null) appId = savedAppId;
      if (savedApiKey != null) apiKey = savedApiKey;
      if (savedProjectId != null) projectId = savedProjectId;
      if (savedRedirectUri != null) redirectUri = savedRedirectUri;

      final savedUserId = prefs.getString(_userIdKey);
      if (savedUserId != null) userId = savedUserId;

      logDebug(
        'WhoopProvider storage loaded: appId=$appId hasUserId=${userId != null}',
      );
    } catch (e, stackTrace) {
      logError(
        'WhoopProvider storage load failed, using defaults',
        e,
        stackTrace,
      );
    }
  }

  /// Redact a UUID-like identifier to last-4 suffix for logging.
  static String _redactId(String? id) {
    if (id == null || id.isEmpty) return '<none>';
    if (id.length <= 4) return '****';
    return '****${id.substring(id.length - 4)}';
  }

  /// Save userId to local storage
  Future<void> saveUserId(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_userIdKey, userId);
      this.userId = userId;
    } catch (e) {
      // Silently fail
    }
  }

  /// Load userId from local storage
  Future<String?> loadUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedUserId = prefs.getString(_userIdKey);
      if (savedUserId != null) {
        userId = savedUserId;
        return savedUserId;
      }
    } catch (e) {
      // Silently fail
    }
    return null;
  }

  /// Clear userId from local storage
  Future<void> clearUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_userIdKey);
      userId = null;
    } catch (e) {
      // Silently fail
    }
  }

  /// Security headers for every request (Managed OAuth v2).
  Map<String, String> _authHeaders() {
    final h = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (appId.isNotEmpty) h['x-app-id'] = appId;
    if (apiKey.isNotEmpty) h['x-app-key'] = apiKey;
    return h;
  }

  /// Headers for a request, using [signRequest] when provided and falling back
  /// to [_authHeaders] otherwise. [bodyBytes] must be the exact bytes sent as
  /// the request body (null for requests without a body).
  Future<Map<String, String>> _requestHeaders(
    String method,
    Uri url, {
    List<int>? bodyBytes,
  }) async {
    if (signRequest == null) return _authHeaders();
    final h = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    h.addAll(
      await signRequest!(method: method, url: url, bodyBytes: bodyBytes),
    );
    return h;
  }

  /// Save configuration to local storage
  Future<void> saveConfiguration({
    String? baseUrl,
    String? appId,
    String? apiKey,
    String? projectId,
    String? redirectUri,
  }) async {
    try {
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
      } else if (projectId == null) {
        await prefs.remove(_projectIdKey);
        this.projectId = null;
      }

      if (redirectUri != null) {
        await prefs.setString(_redirectUriKey, redirectUri);
        this.redirectUri = redirectUri;
      }
    } catch (e) {
      // Silently fail
    }
  }

  /// Load configuration from local storage
  Future<Map<String, String?>> loadConfiguration() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return {
        'baseUrl': prefs.getString(_baseUrlKey),
        'appId': prefs.getString(_appIdKey),
        'apiKey': prefs.getString(_apiKeyKey),
        'projectId': prefs.getString(_projectIdKey),
        'redirectUri': prefs.getString(_redirectUriKey),
      };
    } catch (e) {
      return {};
    }
  }

  /// Call when app receives success from return URL deep link (Managed OAuth v2).
  /// Wear service completes token exchange and redirects to platform return URL;
  /// app parses deep link and calls this to mark user connected.
  Future<void> markConnected(String userId) async {
    await saveUserId(userId);
  }

  /// Reload configuration and userId from storage
  Future<void> reloadFromStorage() async {
    await _loadFromStorage();
  }

  /// Managed OAuth v2: POST /auth/connect/whoop with app_id, user_id.
  /// Returns authorization_url and state. Wear service handles callback and
  /// redirects to platform-configured return URL; app calls [markConnected] when it receives success.
  Future<Map<String, String>> initiateOAuthConnection({String? userId}) async {
    final effectiveUserId = userId ?? this.userId;
    logDebug(
      '[AUTH] WHOOP initiateOAuthConnection: appId=$appId '
      'user=${_redactId(effectiveUserId)}',
    );

    final serviceUrl = Uri.parse('$_apiBase/auth/connect/whoop');

    final requestBody = <String, dynamic>{
      'app_id': appId,
      if (effectiveUserId != null && effectiveUserId.isNotEmpty)
        'user_id': effectiveUserId,
      // Without this, the cloud renders a "you can close this window"
      // fallback page instead of redirecting back to the app, so the
      // deep-link callback that updates UI state never fires.
      if (redirectUri != null && redirectUri!.isNotEmpty)
        'redirect_uri': redirectUri,
    };

    try {
      final body = jsonEncode(requestBody);
      final response = await http.post(
        serviceUrl,
        headers: await _requestHeaders(
          'POST',
          serviceUrl,
          bodyBytes: utf8.encode(body),
        ),
        body: body,
      );

      if (response.statusCode != 200) {
        final snippet = response.body.length > 500
            ? '${response.body.substring(0, 500)}…'
            : response.body;
        logError(
          '[AUTH] WHOOP initiate failed: status=${response.statusCode} '
          'body=$snippet',
          Exception('Status ${response.statusCode}'),
          StackTrace.current,
        );
        throw Exception(
          'Failed to initiate WHOOP OAuth connection (${response.statusCode}): ${response.body}',
        );
      }

      final json = jsonDecode(response.body);

      final String? authorizationUrl = json['authorization_url'] as String?;
      final String? state = json['state'] as String?;

      if (authorizationUrl == null || authorizationUrl.isEmpty) {
        logError(
          '[AUTH] WHOOP initiate: authorization_url missing in response',
          Exception('Empty authorization_url'),
          StackTrace.current,
        );
        throw Exception('authorization_url is missing in response');
      }

      if (state == null || state.isEmpty) {
        logError(
          '[AUTH] WHOOP initiate: state missing in response',
          Exception('Empty state'),
          StackTrace.current,
        );
        throw Exception('state is missing in response');
      }

      logDebug('[AUTH] WHOOP initiate ok: state=${_redactId(state)}');
      return {'authorization_url': authorizationUrl, 'state': state};
    } catch (e, stackTrace) {
      logError('[AUTH] WHOOP initiateOAuthConnection error', e, stackTrace);
      rethrow;
    }
  }

  /// Start OAuth flow: initiate connection, get URL, and launch browser.
  /// [userId] optional; passed to POST /auth/connect/whoop.
  Future<String> startOAuthFlow({String? userId}) async {
    try {
      final result = await initiateOAuthConnection(userId: userId);
      final authorizationUrl = result['authorization_url']!;
      final state = result['state']!;

      final launched = await launchUrl(
        Uri.parse(authorizationUrl),
        mode: LaunchMode.externalApplication,
      );

      if (!launched) {
        logError(
          '[AUTH] WHOOP browser launch failed',
          Exception('Browser launch failed'),
          StackTrace.current,
        );
        throw Exception('Cannot open browser');
      }

      logDebug('[AUTH] WHOOP OAuth flow started: state=${_redactId(state)}');
      return state;
    } catch (e, stackTrace) {
      logError('[AUTH] WHOOP startOAuthFlow error', e, stackTrace);
      rethrow;
    }
  }

  /// Connect: initiates Managed OAuth v2, returns auth URL (and opens browser).
  /// [userId] optional; if provided used in connect request and can be stored after success.
  /// Returns state string. After user completes login, wear service redirects to return URL;
  /// app parses deep link and calls [markConnected(userId)] or [handleDeepLinkCallback(uri)].
  Future<String> connect([dynamic context, String? userId]) async {
    try {
      final state = await startOAuthFlow(userId: userId);
      logDebug('[AUTH] WHOOP connect ok: state=${_redactId(state)}');
      return state;
    } catch (e, stackTrace) {
      logError('[AUTH] WHOOP connect error', e, stackTrace);
      rethrow;
    }
  }

  /// Handle return URL deep link after Managed OAuth v2.
  /// Wear service redirects to platform-configured return URL with success and user_id.
  /// Supports ?status=success&user_id=xxx or ?success=true&user_id=xxx.
  Future<String?> handleDeepLinkCallback(Uri uri) async {
    final status = uri.queryParameters['status'];
    final success = uri.queryParameters['success'];
    final userID = uri.queryParameters['user_id'];
    final error = uri.queryParameters['error'];

    final isSuccess = status == 'success' || success == 'true';

    logDebug(
      '[AUTH] WHOOP deep link: status=$status success=$success '
      'user=${_redactId(userID)} error=$error',
    );

    if (isSuccess && userID != null && userID.isNotEmpty) {
      await saveUserId(userID);

      // Validate data freshness after connection
      try {
        final testData = await _fetch(
          'recovery',
          userID,
          DateTime.now().subtract(const Duration(days: 7)),
          DateTime.now(),
          1, // Just fetch 1 record to check freshness
          null,
        );
        _validateDataFreshness(testData, 'WHOOP connection');
      } catch (e, stackTrace) {
        // Don't fail connection if validation fails, just log warning
        logWarning('[AUTH] WHOOP post-connect freshness check failed: $e');
        logError('[AUTH] WHOOP validation error details', e, stackTrace);
      }

      logDebug(
        '[AUTH] WHOOP handleDeepLinkCallback ok: user=${_redactId(userID)}',
      );
      return userID;
    } else if (status == 'error' || error != null) {
      // Connection failed
      final errorMessage = error ?? 'Unknown error';
      logError(
        '[AUTH] WHOOP OAuth callback failed: $errorMessage',
        Exception(errorMessage),
        StackTrace.current,
      );
      throw Exception('OAuth callback failed: $errorMessage');
    }

    logWarning('[AUTH] WHOOP callback missing status/userID or error');
    return null;
  }

  // 3. Fetch methods – CORRECT PATH + app_id in query
  /// Fetch recovery data (userId is optional, uses stored userId if not provided)
  /// Returns list of WearMetrics in unified format
  Future<List<WearMetrics>> fetchRecovery({
    String? userId,
    DateTime? start,
    DateTime? end,
    int limit = 100,
    String? cursor,
  }) async {
    final effectiveUserId = userId ?? this.userId;
    if (effectiveUserId == null) {
      throw Exception(
        'userId is required. Either provide it or connect first.',
      );
    }
    final response = await _fetch(
      'recovery',
      effectiveUserId,
      start,
      end,
      limit,
      cursor,
    );
    return _convertToWearMetricsList(response, 'whoop', effectiveUserId);
  }

  /// Fetch sleep data (userId is optional, uses stored userId if not provided)
  /// Returns list of WearMetrics in unified format
  Future<List<WearMetrics>> fetchSleep({
    String? userId,
    DateTime? start,
    DateTime? end,
    int limit = 100,
    String? cursor,
  }) async {
    final effectiveUserId = userId ?? this.userId;
    if (effectiveUserId == null) {
      throw Exception(
        'userId is required. Either provide it or connect first.',
      );
    }
    final response = await _fetch(
      'sleep',
      effectiveUserId,
      start,
      end,
      limit,
      cursor,
    );
    return _convertToWearMetricsList(response, 'whoop', effectiveUserId);
  }

  /// Fetch workouts data (userId is optional, uses stored userId if not provided)
  /// Returns list of WearMetrics in unified format
  Future<List<WearMetrics>> fetchWorkouts({
    String? userId,
    DateTime? start,
    DateTime? end,
    int limit = 100,
    String? cursor,
  }) async {
    final effectiveUserId = userId ?? this.userId;
    if (effectiveUserId == null) {
      throw Exception(
        'userId is required. Either provide it or connect first.',
      );
    }
    final response = await _fetch(
      'workouts',
      effectiveUserId,
      start,
      end,
      limit,
      cursor,
    );
    return _convertToWearMetricsList(response, 'whoop', effectiveUserId);
  }

  /// Fetch cycles data (userId is optional, uses stored userId if not provided)
  /// Returns list of WearMetrics in unified format
  Future<List<WearMetrics>> fetchCycles({
    String? userId,
    DateTime? start,
    DateTime? end,
    int limit = 100,
    String? cursor,
  }) async {
    final effectiveUserId = userId ?? this.userId;
    if (effectiveUserId == null) {
      throw Exception(
        'userId is required. Either provide it or connect first.',
      );
    }
    final response = await _fetch(
      'cycles',
      effectiveUserId,
      start,
      end,
      limit,
      cursor,
    );
    return _convertToWearMetricsList(response, 'whoop', effectiveUserId);
  }

  /// Fetch raw WHOOP data in the canonical normalized format (sleep, recovery, cycle).
  /// Returns a map with 'sleep', 'recovery', and 'cycle' arrays.
  Future<Map<String, dynamic>> fetchRawData({
    String? userId,
    DateTime? start,
    DateTime? end,
    int limit = 50,
  }) async {
    final effectiveUserId = userId ?? this.userId;
    if (effectiveUserId == null) {
      throw Exception(
        'userId is required. Either provide it or connect first.',
      );
    }

    // Fetch all three data types
    final sleep = await _fetch(
      'sleep',
      effectiveUserId,
      start,
      end,
      limit,
      null,
    );
    final recovery = await _fetch(
      'recovery',
      effectiveUserId,
      start,
      end,
      limit,
      null,
    );
    final cycles = await _fetch(
      'cycles',
      effectiveUserId,
      start,
      end,
      limit,
      null,
    );

    // Extract arrays from responses
    // _fetch always returns Map<String, dynamic> from jsonDecode
    List<dynamic> sleepArray = [];
    if (sleep.containsKey('data') && sleep['data'] is List) {
      sleepArray = sleep['data'] as List;
    } else if (sleep.containsKey('records') && sleep['records'] is List) {
      sleepArray = sleep['records'] as List;
    } else if (sleep.containsKey('items') && sleep['items'] is List) {
      sleepArray = sleep['items'] as List;
    }

    List<dynamic> recoveryArray = [];
    if (recovery.containsKey('data') && recovery['data'] is List) {
      recoveryArray = recovery['data'] as List;
    } else if (recovery.containsKey('records') && recovery['records'] is List) {
      recoveryArray = recovery['records'] as List;
    } else if (recovery.containsKey('items') && recovery['items'] is List) {
      recoveryArray = recovery['items'] as List;
    }

    List<dynamic> cycleArray = [];
    if (cycles.containsKey('data') && cycles['data'] is List) {
      cycleArray = cycles['data'] as List;
    } else if (cycles.containsKey('records') && cycles['records'] is List) {
      cycleArray = cycles['records'] as List;
    } else if (cycles.containsKey('items') && cycles['items'] is List) {
      cycleArray = cycles['items'] as List;
    }

    // Transform data to match the canonical schema:
    // - Remove UUID string 'id' fields (the engine expects an integer id, not a UUID string)
    // - Ensure stage_summary has all required fields, especially total_sleep_time_milli
    sleepArray = sleepArray.map((item) {
      if (item is Map<String, dynamic>) {
        final transformed = Map<String, dynamic>.from(item);
        transformed.remove('id'); // Remove UUID string id

        // Fix stage_summary if it exists
        if (transformed.containsKey('score') &&
            transformed['score'] is Map<String, dynamic>) {
          final score = transformed['score'] as Map<String, dynamic>;
          if (score.containsKey('stage_summary') &&
              score['stage_summary'] is Map<String, dynamic>) {
            final stageSummary = score['stage_summary'] as Map<String, dynamic>;

            // Calculate total_sleep_time_milli if missing
            if (!stageSummary.containsKey('total_sleep_time_milli')) {
              int totalSleep = 0;
              if (stageSummary.containsKey('total_light_sleep_time_milli') &&
                  stageSummary['total_light_sleep_time_milli'] is num) {
                totalSleep +=
                    (stageSummary['total_light_sleep_time_milli'] as num)
                        .toInt();
              }
              if (stageSummary.containsKey(
                    'total_slow_wave_sleep_time_milli',
                  ) &&
                  stageSummary['total_slow_wave_sleep_time_milli'] is num) {
                totalSleep +=
                    (stageSummary['total_slow_wave_sleep_time_milli'] as num)
                        .toInt();
              }
              if (stageSummary.containsKey('total_rem_sleep_time_milli') &&
                  stageSummary['total_rem_sleep_time_milli'] is num) {
                totalSleep +=
                    (stageSummary['total_rem_sleep_time_milli'] as num).toInt();
              }

              // If we couldn't calculate it, set to 0 (the schema requires the field to exist)
              stageSummary['total_sleep_time_milli'] = totalSleep;
            }

            // Ensure all required fields exist with defaults if missing
            if (!stageSummary.containsKey('total_in_bed_time_milli')) {
              stageSummary['total_in_bed_time_milli'] = 0;
            }
            if (!stageSummary.containsKey('total_awake_time_milli')) {
              stageSummary['total_awake_time_milli'] = 0;
            }
            if (!stageSummary.containsKey('total_light_sleep_time_milli')) {
              stageSummary['total_light_sleep_time_milli'] = 0;
            }
            if (!stageSummary.containsKey('total_slow_wave_sleep_time_milli')) {
              stageSummary['total_slow_wave_sleep_time_milli'] = 0;
            }
            if (!stageSummary.containsKey('total_rem_sleep_time_milli')) {
              stageSummary['total_rem_sleep_time_milli'] = 0;
            }
            if (!stageSummary.containsKey('disturbance_count')) {
              stageSummary['disturbance_count'] = 0;
            }
          }
        }

        return transformed;
      }
      return item;
    }).toList();

    cycleArray = cycleArray.map((item) {
      if (item is Map<String, dynamic>) {
        final transformed = Map<String, dynamic>.from(item);
        transformed.remove('id'); // Remove UUID string id
        return transformed;
      }
      return item;
    }).toList();

    // Note: cycle_id in recovery might be an integer, so we keep it
    // If it causes issues, we can remove it too

    return {
      'sleep': sleepArray,
      'recovery': recoveryArray,
      'cycle': cycleArray,
    };
  }

  /// GET /whoop/data/{user_id}/{type} with app_id, project_id, start, end, limit, cursor.
  /// x-app-id and x-api-key sent on every request.
  Future<Map<String, dynamic>> _fetch(
    String type,
    String userId,
    DateTime? start,
    DateTime? end,
    int limit,
    String? cursor,
  ) async {
    final params = <String, String>{
      'app_id': appId,
      if (projectId != null && projectId!.isNotEmpty) 'project_id': projectId!,
      if (start != null) 'start': start.toUtc().toIso8601String(),
      if (end != null) 'end': end.toUtc().toIso8601String(),
      'limit': limit.toString(),
      if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
    };

    final uri = Uri.parse(
      '$_apiBase/whoop/data/$userId/$type',
    ).replace(queryParameters: params);
    // INFO-safe: redact user UUID and never log full URL/query (PII +
    // tokens). Full URI is available at debug level when needed.
    logDebug(
      'WHOOP data fetch: type=$type user=${_redactId(userId)} '
      'limit=$limit hasCursor=${cursor != null && cursor.isNotEmpty}',
    );
    final res = await http.get(uri, headers: await _requestHeaders('GET', uri));
    // Full response bodies are third-party PII (sleep stages, HR samples)
    // and routinely tens of KB; never log at INFO. Surface status + size
    // only — re-run with a local print if you need the payload.
    logDebug(
      'WHOOP data response: type=$type status=${res.statusCode} '
      'bytes=${res.bodyBytes.length}',
    );
    if (res.statusCode != 200) {
      // Errors get a truncated body so we can debug without dumping
      // megabytes into the log on a 5xx loop.
      final snippet = res.body.length > 500
          ? '${res.body.substring(0, 500)}…'
          : res.body;
      logWarning(
        'WHOOP data fetch failed: type=$type status=${res.statusCode} '
        'body=$snippet',
      );
      throw Exception(res.body);
    }
    final data = jsonDecode(res.body);

    // Validate data freshness
    _validateDataFreshness(data, 'WHOOP $type fetch');

    return data;
  }

  /// Extract latest timestamp from API response
  /// Handles various response formats: array, object with data array, or single object
  DateTime? _extractLatestTimestamp(Map<String, dynamic> response) {
    try {
      // Check if response has a 'data' array
      if (response.containsKey('data') && response['data'] is List) {
        final dataList = response['data'] as List;
        if (dataList.isEmpty) return null;

        DateTime? latest;
        for (final item in dataList) {
          if (item is Map<String, dynamic>) {
            final timestamp = _extractTimestampFromItem(item);
            if (timestamp != null &&
                (latest == null || timestamp.isAfter(latest))) {
              latest = timestamp;
            }
          }
        }
        return latest;
      }

      // Check if response is directly an array (wrapped in a map somehow)
      // Or check for common timestamp fields
      if (response.containsKey('timestamp')) {
        return _parseTimestamp(response['timestamp']);
      }

      // Check for common array fields
      for (final key in ['records', 'items', 'results']) {
        if (response.containsKey(key) && response[key] is List) {
          final list = response[key] as List;
          if (list.isNotEmpty && list.first is Map<String, dynamic>) {
            return _extractTimestampFromItem(
              list.first as Map<String, dynamic>,
            );
          }
        }
      }

      // If response itself might be an array (shouldn't happen but handle it)
      // This case is unlikely but we'll return null if we can't find timestamp
      return null;
    } catch (e) {
      logWarning('Error extracting timestamp from WHOOP response: $e');
      return null;
    }
  }

  /// Extract timestamp from a single item (object)
  DateTime? _extractTimestampFromItem(Map<String, dynamic> item) {
    // Try common timestamp field names
    final timestampFields = [
      'timestamp',
      'created_at',
      'start_time',
      'end_time',
      'date',
    ];
    for (final field in timestampFields) {
      if (item.containsKey(field)) {
        return _parseTimestamp(item[field]);
      }
    }
    return null;
  }

  /// Parse timestamp from various formats
  DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (e) {
        return null;
      }
    }
    if (value is int) {
      // Unix timestamp (seconds or milliseconds)
      if (value > 1000000000000) {
        // Milliseconds
        return DateTime.fromMillisecondsSinceEpoch(value);
      } else {
        // Seconds
        return DateTime.fromMillisecondsSinceEpoch(value * 1000);
      }
    }
    return null;
  }

  /// Convert WHOOP API response to list of WearMetrics
  /// Extracts bio signals (HR, HRV, steps, calories, etc.) from API response
  List<WearMetrics> _convertToWearMetricsList(
    dynamic response,
    String source,
    String userId,
  ) {
    final List<WearMetrics> metricsList = [];

    try {
      // Handle if response is already a List
      if (response is List) {
        for (final item in response) {
          if (item is Map<String, dynamic>) {
            final metric = _convertSingleItemToWearMetrics(
              item,
              source,
              userId,
            );
            if (metric != null) {
              metricsList.add(metric);
            }
          }
        }
        return metricsList;
      }

      // Handle if response is a Map
      if (response is! Map<String, dynamic>) {
        return metricsList;
      }

      // Extract data array from response
      List<dynamic>? dataList;
      if (response.containsKey('data') && response['data'] is List) {
        dataList = response['data'] as List;
      } else if (response.containsKey('records') &&
          response['records'] is List) {
        dataList = response['records'] as List;
      } else if (response.containsKey('items') && response['items'] is List) {
        dataList = response['items'] as List;
      }

      if (dataList == null || dataList.isEmpty) {
        // If no array, try to convert single object
        final singleMetric = _convertSingleItemToWearMetrics(
          response,
          source,
          userId,
        );
        if (singleMetric != null) {
          metricsList.add(singleMetric);
        }
        return metricsList;
      }

      // Convert each item in the array
      for (final item in dataList) {
        if (item is Map<String, dynamic>) {
          final metric = _convertSingleItemToWearMetrics(item, source, userId);
          if (metric != null) {
            metricsList.add(metric);
          }
        }
      }
    } catch (e) {
      logWarning('Error converting WHOOP response to WearMetrics: $e');
    }

    return metricsList;
  }

  /// Convert a single WHOOP API item to WearMetrics
  WearMetrics? _convertSingleItemToWearMetrics(
    Map<String, dynamic> item,
    String source,
    String userId,
  ) {
    try {
      final metrics = <String, num?>{};
      final meta = <String, Object?>{};

      // Extract timestamp
      DateTime? timestamp = _extractTimestampFromItem(item);
      if (timestamp == null) {
        // Try to use current time if no timestamp found
        timestamp = DateTime.now();
      }

      // WHOOP nests scored fields under `item['score']` (recovery and
      // sleep records both follow this shape) — dig into it for the
      // numeric extractions below so HRV / RHR / scores actually
      // surface on `WearMetrics.metrics`. Without this fallback the
      // recovery → Baselines bridge sees null HRV even when the API
      // returned valid numbers.
      final score = item['score'];
      Map<String, dynamic>? scoreMap = score is Map<String, dynamic>
          ? score
          : null;
      T? readNested<T>(String key) {
        if (item.containsKey(key)) return item[key] as T?;
        if (scoreMap != null && scoreMap.containsKey(key)) {
          return scoreMap[key] as T?;
        }
        return null;
      }

      // Extract bio signals from WHOOP API response
      // WHOOP recovery data typically contains: recovery_score, hr, hrv, etc.
      final recoveryScore = readNested<dynamic>('recovery_score');
      if (recoveryScore != null) {
        meta['recovery_score'] = recoveryScore;
      }
      final strainScore = readNested<dynamic>('strain_score');
      if (strainScore != null) {
        meta['strain_score'] = strainScore;
      }
      final sleepScore = readNested<dynamic>('sleep_score');
      if (sleepScore != null) {
        meta['sleep_score'] = sleepScore;
      }

      // Heart rate (top-level on workouts, nested under `score` on
      // recovery records as `resting_heart_rate`).
      final hrTop =
          readNested<dynamic>('heart_rate') ??
          readNested<dynamic>('hr') ??
          readNested<dynamic>('heartRate');
      if (hrTop != null) {
        metrics['hr'] = _toNum(hrTop);
      }
      final restingHr =
          readNested<dynamic>('resting_heart_rate') ??
          readNested<dynamic>('resting_hr') ??
          readNested<dynamic>('restingHeartRate');
      if (restingHr != null) {
        metrics['resting_hr'] = _toNum(restingHr);
      }

      // HRV — WHOOP recovery records ship as `score.hrv_rmssd_milli`
      // (already in milliseconds; the field name is the WHOOP-ism).
      final hrvMilli = readNested<dynamic>('hrv_rmssd_milli');
      final hrvRmssd =
          readNested<dynamic>('hrv_rmssd') ??
          readNested<dynamic>('hrvRmssd') ??
          hrvMilli;
      final hrvSdnn =
          readNested<dynamic>('hrv_sdnn') ?? readNested<dynamic>('hrvSdnn');
      final hrvAlt = readNested<dynamic>('hrv');
      if (hrvRmssd != null) {
        metrics['hrv_rmssd'] = _toNum(hrvRmssd);
        if (hrvSdnn == null) metrics['hrv_sdnn'] = _toNum(hrvRmssd);
      } else if (hrvAlt != null) {
        final v = _toNum(hrvAlt);
        metrics['hrv_rmssd'] = v;
        metrics['hrv_sdnn'] = v;
      }
      if (hrvSdnn != null) {
        metrics['hrv_sdnn'] = _toNum(hrvSdnn);
      }
      // Stash SpO2 + skin temp when present (recovery record carries
      // them under score; useful for downstream provenance).
      final spo2 =
          readNested<dynamic>('spo2_percentage') ?? readNested<dynamic>('spo2');
      if (spo2 != null) {
        metrics['spo2'] = _toNum(spo2);
      }
      final skinTemp = readNested<dynamic>('skin_temp_celsius');
      if (skinTemp != null) {
        metrics['skin_temp_c'] = _toNum(skinTemp);
      }

      // Steps (from workout data)
      if (item.containsKey('steps')) {
        metrics['steps'] = _toNum(item['steps']);
      } else if (item.containsKey('step_count')) {
        metrics['steps'] = _toNum(item['step_count']);
      }

      // Calories
      if (item.containsKey('calories')) {
        metrics['calories'] = _toNum(item['calories']);
      } else if (item.containsKey('kilojoule')) {
        // WHOOP sometimes uses kilojoules, convert to kcal (1 kJ = 0.239 kcal)
        final kj = _toNum(item['kilojoule']);
        if (kj != null) {
          metrics['calories'] = kj * 0.239;
        }
      } else if (item.containsKey('calorie')) {
        metrics['calories'] = _toNum(item['calorie']);
      }

      // Distance (from workout data)
      if (item.containsKey('distance')) {
        metrics['distance'] = _toNum(item['distance']);
      } else if (item.containsKey('distance_meter')) {
        // Convert meters to km
        final meters = _toNum(item['distance_meter']);
        if (meters != null) {
          metrics['distance'] = meters / 1000.0;
        }
      }

      // Stress (recovery score can be used as stress indicator)
      if (item.containsKey('recovery_score')) {
        final recovery = _toNum(item['recovery_score']);
        if (recovery != null) {
          // Invert recovery score as stress (lower recovery = higher stress)
          metrics['stress'] = 100 - recovery;
        }
      }

      // Store original WHOOP data in meta for reference
      meta['whoop_data'] = item;
      meta['synced'] = true;
      meta['source_type'] = 'whoop_cloud';

      return WearMetrics(
        timestamp: timestamp,
        deviceId: 'whoop_$userId',
        source: source,
        metrics: metrics,
        meta: meta,
      );
    } catch (e) {
      logWarning('Error converting WHOOP item to WearMetrics: $e');
      return null;
    }
  }

  /// Helper to safely convert dynamic value to num
  num? _toNum(dynamic value) {
    if (value == null) return null;
    if (value is num) return value;
    if (value is String) {
      return num.tryParse(value);
    }
    return null;
  }

  /// Validate data freshness (within 24 hours)
  void _validateDataFreshness(Map<String, dynamic> response, String context) {
    final latestTimestamp = _extractLatestTimestamp(response);

    if (latestTimestamp == null) {
      logWarning('$context: could not extract timestamp from response');
      return; // Don't fail if we can't extract timestamp
    }

    final dataAge = DateTime.now().difference(latestTimestamp);
    const maxStaleAge = Duration(hours: 24);

    // Handle timezone differences
    final isFutureData = dataAge.isNegative;
    final absoluteAge = isFutureData ? -dataAge : dataAge;

    if (absoluteAge > maxStaleAge) {
      final errorMessage =
          'WHOOP data is stale (${absoluteAge.inHours} hours old). '
          'Please check if your wearable device is connected to get latest data.';
      logWarning('$context: $errorMessage');
      throw Exception(errorMessage);
    }

    if (isFutureData) {
      logDebug(
        '$context: data timestamp ${absoluteAge.inHours}h in the future '
        '(likely timezone) - treating as valid',
      );
    } else {
      logDebug('$context: data is fresh (${absoluteAge.inHours}h old)');
    }
  }

  /// Disconnect WHOOP integration (x-app-id and x-api-key sent).
  Future<void> disconnect(String userId) async {
    final uri = Uri.parse(
      '$_apiBase/whoop/oauth/disconnect',
    ).replace(queryParameters: {'user_id': userId, 'app_id': appId});
    final res =
        await http.delete(uri, headers: await _requestHeaders('DELETE', uri));
    if (res.statusCode != 200) throw Exception(res.body);
  }
}
