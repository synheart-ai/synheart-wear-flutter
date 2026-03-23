import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:app_links/app_links.dart';
import 'package:synheart_wear/synheart_wear.dart';

class WhoopController extends ChangeNotifier {
  // ──────────────────────────────────────────────────────────────
  // Configuration
  // ──────────────────────────────────────────────────────────────
  static String get defaultBaseUrl => WhoopProvider.defaultBaseUrl;
  static String get defaultRedirectUri => WhoopProvider.defaultRedirectUri;

  // Configuration getters that read from provider
  String get baseUrl => _provider.baseUrl;
  String get appId => _provider.appId;
  String get redirectUri => _provider.redirectUri ?? defaultRedirectUri;

  // ──────────────────────────────────────────────────────────────
  // Dependencies
  // ──────────────────────────────────────────────────────────────
  late WhoopProvider _provider;

  WhoopProvider get provider => _provider;
  late final AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;
  StreamSubscription<WearServiceEvent>? _sseSubscription;

  // ──────────────────────────────────────────────────────────────
  // State
  // ──────────────────────────────────────────────────────────────
  String? _userId;
  String _status = 'Not connected';
  String _error = '';
  List<dynamic> _records =
      []; // Keep as dynamic for now to support different record types
  String? _pendingOAuthState;
  String? _currentDataType; // Track what type of data we're displaying
  bool _isSSESubscribed = false;
  List<WearServiceEvent> _sseEvents = []; // Store recent SSE events

  // ──────────────────────────────────────────────────────────────
  // Getters
  // ──────────────────────────────────────────────────────────────
  String? get userId => _userId;
  String get status => _status;
  String get error => _error;
  List<dynamic> get records => _records;
  String? get currentDataType => _currentDataType;
  /// WHOOP connection is tracked only by WHOOP OAuth (whoop_user_id in storage).
  /// Do not infer from Garmin or a shared user ID; user must authenticate WHOOP separately.
  bool get isConnected => _userId != null;
  bool get isSSESubscribed => _isSSESubscribed;
  List<WearServiceEvent> get sseEvents => _sseEvents;

  // ──────────────────────────────────────────────────────────────
  // Initialization
  // ──────────────────────────────────────────────────────────────
  WhoopController() {
    _appLinks = AppLinks();
  }

  Future<void> initialize() async {
    _initializeProvider();
    await _setupDeepLinkListener();
    // Load saved user ID after the first frame (gives platform channels time to initialize)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadUserId();
    });
    // provider.clearUserId();
  }

  void _initializeProvider() {
    _provider = WhoopProvider(loadFromStorage: true);
    debugPrint(
        '📋 Loaded configuration: baseUrl=${_provider.baseUrl}, appId=${_provider.appId}, redirectUri=${_provider.redirectUri}');
  }

  Future<void> reloadConfiguration() async {
    await _provider.reloadFromStorage();
    notifyListeners();
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    _sseSubscription?.cancel();
    super.dispose();
  }

  // ──────────────────────────────────────────────────────────────
  // Deep Link Handling
  // ──────────────────────────────────────────────────────────────
  Future<void> _setupDeepLinkListener() async {
    // Handle app launch from deep link (cold start)
    final initialUri = await _appLinks.getInitialLink();
    if (initialUri != null) _handleIncomingLink(initialUri);

    // Handle when app is already running
    _linkSubscription = _appLinks.uriLinkStream.listen(
      _handleIncomingLink,
      onError: (err) => debugPrint('Deep link error: $err'),
    );
  }

  Future<void> _handleIncomingLink(Uri uri) async {
    debugPrint('🔗 Deep link received: $uri');

    if (uri.scheme != 'synheart' ||
        uri.host != 'oauth' ||
        uri.path != '/callback') {
      debugPrint('⚠️  Ignoring non-OAuth deep link');
      return;
    }

    // Managed OAuth v2: wear service redirects to return URL with status/success and user_id
    final status = uri.queryParameters['status'];
    final success = uri.queryParameters['success'];
    final userID = uri.queryParameters['user_id'];
    final error = uri.queryParameters['error'];

    debugPrint('✅ WHOOP OAuth callback received (managed flow)');
    debugPrint(
        '   Status: $status Success: $success User ID: $userID Error: $error');

    // Only process this callback if WE started the OAuth flow (pending state).
    // The same deep link is delivered to both WHOOP and Garmin controllers; we must
    // not process a callback that was meant for the other provider.
    if (_pendingOAuthState == null) {
      debugPrint(
          '⚠️  No pending WHOOP OAuth state - ignoring (callback may be for Garmin)');
      debugPrint('   Current user ID in memory: $_userId');
      final hasSavedUserId = await _hasSavedUserId();
      if (hasSavedUserId) {
        debugPrint(
            '   Found saved WHOOP user ID in storage - already connected');
        return;
      }
      _updateState(
        status: 'Stale OAuth callback ignored. Please connect again.',
        error: '',
      );
      return;
    }

    if (_userId != null && _pendingOAuthState != null) {
      debugPrint(
          '⚠️  Already connected but received OAuth callback. Processing...');
    }

    _updateState(
      status: 'Processing connection...',
      error: '',
    );

    try {
      // Use the provider's handleDeepLinkCallback which handles status parameter
      final userId = await _provider.handleDeepLinkCallback(uri);

      if (userId != null) {
        debugPrint('✅ WHOOP connection successful: $userId');
        _pendingOAuthState = null;
        // User ID is already saved by handleDeepLinkCallback

        _updateState(
          userId: userId,
          status: 'Connected successfully!',
          error: '',
        );

        // Real-time (SSE) disabled to avoid 404 when backend does not expose /events/subscribe
        // await subscribeToEvents();
      } else {
        debugPrint('⚠️  WHOOP callback returned null user ID');
        debugPrint('   Status parameter: $status');
        debugPrint('   User ID parameter: $userID');
        _pendingOAuthState = null;
        _updateState(
          error: 'Connection failed: No user ID received',
          status: 'Connection failed',
        );
      }
    } catch (e) {
      debugPrint('❌ WHOOP OAuth callback error: $e');
      _pendingOAuthState = null;

      String errorMsg = e.toString();
      if (errorMsg.contains('OAuth callback failed')) {
        // Extract the actual error message from the exception
        errorMsg =
            errorMsg.replaceAll('Exception: OAuth callback failed: ', '');
      }

      _updateState(
        error: 'Failed to complete OAuth: $errorMsg',
        status: 'Connection failed',
      );
    }
  }

  // ──────────────────────────────────────────────────────────────
  // State Management
  // ──────────────────────────────────────────────────────────────
  void _updateState({
    String? userId,
    String? status,
    String? error,
    List<dynamic>? records,
    String? dataType,
    bool clearUserId = false,
    bool clearDataType = false,
  }) {
    bool changed = false;

    if (clearUserId) {
      _userId = null;
      changed = true;
    } else if (userId != null && userId != _userId) {
      _userId = userId;
      changed = true;
    }
    if (status != null && status != _status) {
      _status = status;
      changed = true;
    }
    if (error != null && error != _error) {
      _error = error;
      changed = true;
    }
    if (records != null) {
      _records = records;
      changed = true;
    }
    if (clearDataType) {
      _currentDataType = null;
      changed = true;
    } else if (dataType != null && dataType != _currentDataType) {
      _currentDataType = dataType;
      changed = true;
    }

    if (changed) {
      notifyListeners();
    }
  }

  // ──────────────────────────────────────────────────────────────
  // OAuth Connection
  // ──────────────────────────────────────────────────────────────
  Future<void> connect() async {
    _updateState(
      status: 'Preparing WHOOP login...',
      error: '',
    );

    try {
      final state = await _provider.startOAuthFlow();
      _pendingOAuthState = state;
      debugPrint('🔐 Started OAuth flow with state: $state');

      _updateState(status: 'Log in to WHOOP in the browser...');
    } catch (e) {
      _pendingOAuthState = null;
      final errorMessage = _extractErrorMessage(e.toString());
      _updateState(
        error: errorMessage,
        status: 'Login failed',
      );
    }
  }

  // ──────────────────────────────────────────────────────────────
  // Error Handling
  // ──────────────────────────────────────────────────────────────
  String _extractErrorMessage(String error) {
    // Check if error contains HTML
    if (error.contains('<html') || error.contains('<!DOCTYPE')) {
      // Try to extract meaningful error from HTML
      // Look for common error patterns in HTML
      if (error.contains('404') || error.toLowerCase().contains('not found')) {
        return 'Server not found. Please check your Base URL configuration.';
      }
      if (error.contains('500') ||
          error.toLowerCase().contains('internal server error')) {
        return 'Server error. Please check your Base URL and try again.';
      }
      if (error.contains('400') ||
          error.toLowerCase().contains('bad request')) {
        return 'Invalid request. Please check your configuration settings.';
      }
      if (error.contains('403') || error.toLowerCase().contains('forbidden')) {
        return 'Access forbidden. Please check your App ID.';
      }
      if (error.contains('401') ||
          error.toLowerCase().contains('unauthorized')) {
        return 'Unauthorized. Please check your App ID.';
      }

      // Generic HTML error message
      return 'Invalid server response. Please check your Base URL configuration in Settings.';
    }

    // Check for common connection errors
    if (error.toLowerCase().contains('failed host lookup') ||
        error.toLowerCase().contains('socketexception') ||
        error.toLowerCase().contains('network is unreachable')) {
      return 'Cannot connect to server. Please check your Base URL and internet connection.';
    }

    if (error.toLowerCase().contains('invalid url') ||
        error.toLowerCase().contains('malformed')) {
      return 'Invalid Base URL. Please check your configuration in Settings.';
    }

    // Return original error if it's already user-friendly
    return error;
  }

  // ──────────────────────────────────────────────────────────────
  // Local Storage
  // ──────────────────────────────────────────────────────────────
  Future<bool> _hasSavedUserId() async {
    final savedUserId = await _provider.loadUserId();
    return savedUserId != null && savedUserId.isNotEmpty;
  }

  /// Restore WHOOP connection state from storage (whoop_user_id only). Never use Garmin's user ID.
  Future<void> _loadUserId() async {
    final savedUserId = await _provider.loadUserId();
    if (savedUserId != null && savedUserId.isNotEmpty) {
      _updateState(
        userId: savedUserId,
        status: 'Connected (restored from storage)',
      );
      debugPrint('📂 Loaded WHOOP user ID from local storage: $savedUserId');
    } else {
      debugPrint('📂 No saved user ID found in local storage');
    }
  }

  Future<void> clearUserId() async {
    await _provider.clearUserId();
    debugPrint('🗑️  Cleared user ID from local storage');
  }

  // ──────────────────────────────────────────────────────────────
  // Data Fetching
  // ──────────────────────────────────────────────────────────────
  Future<void> fetchRecovery({
    DateTime? start,
    DateTime? end,
  }) async {
    if (_userId == null) return;

    _updateState(
      status: 'Fetching recovery data...',
      error: '',
    );

    try {
      final List<WearMetrics> result = await _provider.fetchRecovery(
        userId: _userId!,
        start: start ?? DateTime.now().subtract(const Duration(days: 30)),
        end: end ?? DateTime.now(),
        limit: 50,
      );
      debugPrint('result: $result');

      // SDK now returns List<WearMetrics> directly
      _updateState(
        records: result,
        dataType: 'recovery',
        status: 'Recovery data loaded (${result.length} records)',
      );
    } catch (e) {
      final errorMessage = _extractErrorMessage(e.toString());
      _updateState(
        error: errorMessage,
        status: 'Failed to fetch data',
      );
    }
  }

  Future<void> fetchWorkouts({
    DateTime? start,
    DateTime? end,
  }) async {
    if (_userId == null) return;

    _updateState(
      status: 'Fetching workout data...',
      error: '',
    );

    try {
      final List<WearMetrics> result = await _provider.fetchWorkouts(
        userId: _userId!,
        start: start ?? DateTime.now().subtract(const Duration(days: 30)),
        end: end ?? DateTime.now(),
        limit: 50,
      );

      // SDK now returns List<WearMetrics> directly
      _updateState(
        records: result,
        dataType: 'workout',
        status: 'Workout data loaded (${result.length} records)',
      );
    } catch (e) {
      final errorMessage = _extractErrorMessage(e.toString());
      _updateState(
        error: errorMessage,
        status: 'Failed to fetch data',
      );
    }
  }

  Future<void> fetchHeartRate({
    DateTime? start,
    DateTime? end,
  }) async {
    if (_userId == null) return;

    _updateState(
      status: 'Fetching heart rate data...',
      error: '',
    );

    try {
      final List<WearMetrics> result = await _provider.fetchWorkouts(
        userId: _userId!,
        start: start ?? DateTime.now().subtract(const Duration(days: 7)),
        end: end ?? DateTime.now(),
        limit: 200,
      );

      // SDK now returns List<WearMetrics> directly (heart rate data comes from workouts)
      _updateState(
        records: result,
        dataType: 'heart_rate',
        status: 'Heart rate data loaded (${result.length} records)',
      );
    } catch (e) {
      final errorMessage = _extractErrorMessage(e.toString());
      _updateState(
        error: errorMessage,
        status: 'Failed to fetch data',
      );
    }
  }

  Future<void> fetchStrain({
    DateTime? start,
    DateTime? end,
  }) async {
    if (_userId == null) return;

    _updateState(
      status: 'Fetching strain data...',
      error: '',
    );

    try {
      final List<WearMetrics> result = await _provider.fetchRecovery(
        userId: _userId!,
        start: start ?? DateTime.now().subtract(const Duration(days: 30)),
        end: end ?? DateTime.now(),
        limit: 50,
      );

      // SDK now returns List<WearMetrics> directly (strain data comes from recovery)
      _updateState(
        records: result,
        dataType: 'strain',
        status: 'Strain data loaded (${result.length} records)',
      );
    } catch (e) {
      final errorMessage = _extractErrorMessage(e.toString());
      _updateState(
        error: errorMessage,
        status: 'Failed to fetch data',
      );
    }
  }

  Future<void> fetchSleep({
    DateTime? start,
    DateTime? end,
  }) async {
    if (_userId == null) return;

    _updateState(
      status: 'Fetching sleep data...',
      error: '',
    );

    try {
      final List<WearMetrics> result = await _provider.fetchSleep(
        userId: _userId!,
        start: start ?? DateTime.now().subtract(const Duration(days: 30)),
        end: end ?? DateTime.now(),
        limit: 50,
      );

      // SDK now returns List<WearMetrics> directly
      _updateState(
        records: result,
        dataType: 'sleep',
        status: 'Sleep data loaded (${result.length} records)',
      );
    } catch (e) {
      final errorMessage = _extractErrorMessage(e.toString());
      _updateState(
        error: errorMessage,
        status: 'Failed to fetch data',
      );
    }
  }

  // ──────────────────────────────────────────────────────────────
  // Disconnect
  // ──────────────────────────────────────────────────────────────
  Future<void> disconnect() async {
    if (_userId == null) return;

    _updateState(status: 'Disconnecting...');

    try {
      await _provider.disconnect(_userId!);
      await clearUserId();
      _pendingOAuthState = null;
      _updateState(
        userId: null,
        records: [],
        dataType: null,
        status: 'Disconnected',
      );
    } catch (e, stackTrace) {
      debugPrint('❌ WHOOP disconnect error: $e');
      debugPrint('$stackTrace');
      final errorMessage = _extractErrorMessage(e.toString());
      _updateState(
        error: errorMessage,
        status: 'Disconnect failed',
      );
    }
    notifyListeners();
  }

  // ──────────────────────────────────────────────────────────────
  // SSE Event Subscription
  // ──────────────────────────────────────────────────────────────

  /// Subscribe to real-time events via SSE
  /// Real-time (SSE) disabled in example app when backend does not expose /events/subscribe.
  ///
  /// Per documentation: GET /v1/events/subscribe?app_id={app_id}
  Future<void> subscribeToEvents() async {
    const whoopRealtimeEnabled = false; // Set true when backend exposes /events/subscribe
    if (!whoopRealtimeEnabled) return;
    // ignore: dead_code
    if (_isSSESubscribed) {
      debugPrint('⚠️  Already subscribed to SSE events');
      return;
    }

    if (_userId == null) {
      debugPrint('⚠️  Cannot subscribe to SSE: Not connected');
      _updateState(
        error: 'Must be connected before subscribing to events',
        status: 'Subscription failed',
      );
      return;
    }

    try {
      debugPrint('📡 Subscribing to SSE events...');
      _updateState(status: 'Subscribing to real-time events...', error: '');

      _sseSubscription = _provider.subscribeToEvents(userId: _userId).listen(
        (event) {
          debugPrint('📨 SSE Event received: ${event.event}');
          debugPrint('   ID: ${event.id}');
          debugPrint('   Data: ${event.data}');

          // Add to events list (keep last 100 events)
          _sseEvents.insert(0, event);
          if (_sseEvents.length > 100) {
            _sseEvents = _sseEvents.take(100).toList();
          }

          // Handle different event types
          _handleSSEEvent(event);

          notifyListeners();
        },
        onError: (error) {
          final errorMessage = error.toString();
          debugPrint('❌ SSE subscription error: $error');

          // Check if it's a connection closure (not a real error)
          if (errorMessage.contains('Connection closed') ||
              errorMessage.contains('Connection terminated')) {
            debugPrint(
                '⚠️ SSE connection closed (may reconnect automatically)');
            _isSSESubscribed = false;
            _updateState(
              status: 'SSE connection closed - will reconnect',
              error: '',
            );
            notifyListeners();

            // Attempt to reconnect after a delay
            Future.delayed(const Duration(seconds: 3), () {
              if (isConnected && !_isSSESubscribed) {
                debugPrint('🔄 Attempting to reconnect SSE...');
                subscribeToEvents();
              }
            });
          } else {
            // Real error
            _isSSESubscribed = false;
            _updateState(
              error:
                  'SSE subscription error: ${_extractErrorMessage(errorMessage)}',
              status: 'SSE connection lost',
            );
            notifyListeners();
          }
        },
        onDone: () {
          debugPrint('🔌 SSE subscription closed');
          _isSSESubscribed = false;

          // Only update status if we're still connected (not manually unsubscribed)
          if (isConnected) {
            _updateState(
              status: 'SSE connection closed - will reconnect',
              error: '',
            );
            notifyListeners();

            // Attempt to reconnect after a delay
            Future.delayed(const Duration(seconds: 3), () {
              if (isConnected && !_isSSESubscribed) {
                debugPrint('🔄 Attempting to reconnect SSE...');
                subscribeToEvents();
              }
            });
          } else {
            _updateState(
              status: 'SSE connection closed',
              error: '',
            );
            notifyListeners();
          }
        },
        cancelOnError: false,
      );

      _isSSESubscribed = true;
      _updateState(
        status: 'Connected & subscribed to real-time events',
        error: '',
      );
      debugPrint('✅ Successfully subscribed to SSE events');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Failed to subscribe to SSE: $e');
      _isSSESubscribed = false;
      _updateState(
        error:
            'Failed to subscribe to SSE: ${_extractErrorMessage(e.toString())}',
        status: 'Subscription failed',
      );
      notifyListeners();
    }
  }

  /// Unsubscribe from SSE events
  Future<void> unsubscribeFromEvents() async {
    if (!_isSSESubscribed) {
      debugPrint('⚠️  Not subscribed to SSE events');
      return;
    }

    try {
      debugPrint('🔌 Unsubscribing from SSE events...');
      await _sseSubscription?.cancel();
      _sseSubscription = null;
      _isSSESubscribed = false;
      _updateState(
        status: 'SSE subscription cancelled',
        error: '',
      );
      debugPrint('✅ Successfully unsubscribed from SSE events');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Failed to unsubscribe from SSE: $e');
      _updateState(
        error: 'Failed to unsubscribe: ${_extractErrorMessage(e.toString())}',
      );
      notifyListeners();
    }
  }

  /// Handle incoming SSE events
  void _handleSSEEvent(WearServiceEvent event) {
    if (event.event == 'connected') {
      debugPrint('✅ SSE connection confirmed');
      debugPrint('   Client ID: ${event.data?['client_id']}');
      debugPrint('   App ID: ${event.data?['app_id']}');
      return;
    }

    // Handle WHOOP-specific events
    if (event.data?['vendor'] == 'whoop') {
      final eventType = event.event;
      final userId = event.data?['user_id'];
      final data = event.data?['data'];

      debugPrint('📊 WHOOP event: $eventType for user: $userId');

      // If this event is for the current user, we could auto-refresh data
      if (userId == _userId && data != null) {
        // Optionally refresh the current data type
        if (_currentDataType != null) {
          debugPrint('   Auto-refreshing $_currentDataType data...');
          // Could trigger a refresh here if needed
        }
      }
    }
  }

  /// Clear SSE events history
  void clearSSEEvents() {
    _sseEvents.clear();
    notifyListeners();
  }

  /// Test Flux processing: Fetch raw WHOOP data, process through Flux, and print HSI result
  Future<void> testFluxProcessing(BuildContext context) async {
    if (_userId == null) {
      debugPrint('❌ No userId - connect first');
      _updateState(
        error: 'No userId - connect first',
        status: 'Cannot test Flux - not connected',
      );
      return;
    }

    _updateState(
      status: 'Testing Flux processing...',
      error: '',
    );

    try {
      // Step 1: Fetch raw WHOOP data
      debugPrint('📥 Step 1: Fetching raw WHOOP data...');

      final fluxPayload = await _provider.fetchRawDataForFlux(
        userId: _userId!,
        start: DateTime.now().subtract(const Duration(days: 7)),
        end: DateTime.now(),
        limit: 50,
      );

      final rawJson = jsonEncode(fluxPayload);
      debugPrint('📦 Raw WHOOP JSON size: ${rawJson.length} chars');
      debugPrint(
          '📊 Data counts - Sleep: ${fluxPayload['sleep'].length}, Recovery: ${fluxPayload['recovery'].length}, Cycle: ${fluxPayload['cycle'].length}');

      // Print first 500 chars of raw JSON
      final preview =
          rawJson.length > 500 ? '${rawJson.substring(0, 500)}...' : rawJson;
      debugPrint('📄 Raw JSON preview: $preview');

      // Flux processing was removed from the SDK package in main.
      // Keep this button as a raw payload fetch + preview for debugging.
      if (context.mounted) {
        _showHsiResultDialog(context, fluxPayload);
      }

      _updateState(
        status: 'Fetched raw WHOOP payload',
        error: '',
      );
    } catch (e, stackTrace) {
      final errorMsg = 'Error in Flux processing: $e';
      debugPrint('❌ $errorMsg');
      debugPrint('Stack trace: $stackTrace');
      _updateState(
        error: errorMsg,
        status: 'Flux processing failed',
      );
    }
  }

  void _showHsiResultDialog(BuildContext context, Map<String, dynamic> payload) {
    final prettyJson = const JsonEncoder.withIndent('  ').convert(payload);
    final sleepCount = (payload['sleep'] as List?)?.length ?? 0;
    final recoveryCount = (payload['recovery'] as List?)?.length ?? 0;
    final cycleCount = (payload['cycle'] as List?)?.length ?? 0;
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.8,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'HSI Result',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(),
              // Scrollable content
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSection(
                        'Raw payload',
                        [
                          _buildInfoRow('Sleep', '$sleepCount'),
                          _buildInfoRow('Recovery', '$recoveryCount'),
                          _buildInfoRow('Cycle', '$cycleCount'),
                          _buildInfoRow('JSON chars', '${prettyJson.length}'),
                        ],
                      ),
                      SelectableText(
                        prettyJson,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
        ),
        ...children,
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }
}
