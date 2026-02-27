import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:synheart_wear/synheart_wear.dart';

// Read-only: pre-fill from Settings (nothing from RAMEN is saved to local storage)
const String _sharedAppIdKey = 'sdk_app_id';
const String _sharedApiKeyKey = 'sdk_api_key';
// User ID is always read from Garmin/WHOOP local storage (same keys as synheart_wear package)
const String _storageKeyGarminUserId = 'garmin_user_id';
const String _storageKeyWhoopUserId = 'whoop_user_id';

class RamenPage extends StatefulWidget {
  const RamenPage({
    super.key,
    required this.onMenuPressed,
  });

  final VoidCallback onMenuPressed;

  @override
  State<RamenPage> createState() => _RamenPageState();
}

class _RamenPageState extends State<RamenPage> {
  // Base URL: https://ramen-service-dev.synheart.io/ (host + port 443, TLS)
  final _hostController =
      TextEditingController(text: 'ramen-service-dev.synheart.io');
  final _portController = TextEditingController(text: '443');
  final _appIdController = TextEditingController();
  final _apiKeyController = TextEditingController();
  final _deviceIdController = TextEditingController();

  RamenClient? _client;
  StreamSubscription<RamenEvent>? _eventSub;
  StreamSubscription<RamenConnectionState>? _stateSub;
  final List<RamenEvent> _events = [];
  bool _connecting = false;
  String _status = 'Disconnected';
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  /// User ID is always from local storage (Garmin or WHOOP). Nothing from RAMEN is saved.
  Future<String> _getUserIdFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final garmin = prefs.getString(_storageKeyGarminUserId);
    if (garmin != null && garmin.isNotEmpty) return garmin;
    final whoop = prefs.getString(_storageKeyWhoopUserId);
    if (whoop != null && whoop.isNotEmpty) return whoop;
    return '';
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _appIdController.text = prefs.getString(_sharedAppIdKey) ?? '';
    _apiKeyController.text = prefs.getString(_sharedApiKeyKey) ?? '';
    if (mounted) setState(() {});
  }

  Future<void> _connect() async {
    final host = _hostController.text.trim();
    if (host.isEmpty) {
      setState(() {
        _error = 'Host required';
      });
      return;
    }
    final port = int.tryParse(_portController.text.trim()) ?? 443;
    final deviceId = _deviceIdController.text.trim();
    if (deviceId.isEmpty) {
      setState(() {
        _error = 'Device ID required (e.g. Android ID or UUID)';
      });
      return;
    }
    final userId = await _getUserIdFromStorage();
    if (userId.isEmpty) {
      setState(() {
        _error = 'Connect Garmin or WHOOP first to get a user ID';
      });
      return;
    }
    setState(() {
      _connecting = true;
      _error = null;
      _status = 'Connecting…';
    });

    final appId = _appIdController.text.trim();
    final apiKey = _apiKeyController.text.trim();
    final payload = {
      'host': host,
      'port': port,
      'appId': appId,
      'apiKey': apiKey,
      'deviceId': deviceId,
      'userId': userId,
      'useTls': port == 443,
    };
    debugPrint('RAMEN Connect payload: $payload');

    final client = RamenClient(
      host: host,
      port: port,
      appId: appId,
      apiKey: apiKey,
      deviceId: deviceId,
      userId: userId,
      useTls: port == 443,
      logResponses: true,
    );
    _client = client;

    // Update status from connection state (connected = first server message received)
    _stateSub = client.connectionState.listen((state) {
      if (!mounted) return;
      setState(() {
        _connecting = false;
        switch (state) {
          case RamenConnectionState.connecting:
            _status = 'Connecting…';
            _error = null;
            break;
          case RamenConnectionState.connected:
            _status = 'Connected';
            _error = null;
            break;
          case RamenConnectionState.disconnected:
            _status = 'Disconnected';
            break;
          case RamenConnectionState.reconnecting:
            _status = 'Reconnecting…';
            break;
        }
      });
    });

    _eventSub = client.events.listen((e) {
      if (mounted) {
        setState(() {
          _events.insert(0, e);
          if (_events.length > 200) _events.removeLast();
        });
      }
    });

    try {
      await client.connect();
      // Status is updated via connectionState (Connected only after first server message)
    } catch (e) {
      if (mounted) {
        setState(() {
          _connecting = false;
          _status = 'Error';
          _error = '$e';
        });
      }
    }
  }

  Future<void> _disconnect() async {
    await _stateSub?.cancel();
    _stateSub = null;
    await _eventSub?.cancel();
    _eventSub = null;
    await _client?.close();
    _client = null;
    if (mounted) {
      setState(() {
        _status = 'Disconnected';
        _connecting = false;
      });
    }
  }

  @override
  void dispose() {
    _eventSub?.cancel();
    _client?.close();
    _hostController.dispose();
    _portController.dispose();
    _appIdController.dispose();
    _apiKeyController.dispose();
    _deviceIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: widget.onMenuPressed,
        ),
        title: const Text('RAMEN (gRPC)'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'How to use RAMEN',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '1. Set Base URL, App ID and API Key in Settings (same as WHOOP/Garmin). Connect Garmin or WHOOP first — user ID is read from local storage.\n'
                    '2. Here, set Host (ramen-service-dev.synheart.io), Port 443 for https:// base URL, and App ID / API Key (pre-filled from Settings). Enter a Device ID.\n'
                    '3. Tap Connect. When status shows "Connected", you’ll receive real-time events (alerts, daily summaries) below. Nothing on this page is saved to local storage.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Config',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _hostController,
                    decoration: const InputDecoration(
                      labelText: 'Host',
                      hintText: 'ramen-service-dev.synheart.io',
                    ),
                    keyboardType: TextInputType.url,
                    enabled: _client == null,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _portController,
                    decoration: const InputDecoration(
                      labelText: 'Port',
                      hintText: '443 (https)',
                    ),
                    keyboardType: TextInputType.number,
                    enabled: _client == null,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _appIdController,
                    decoration: const InputDecoration(
                      labelText: 'App ID (x-app-id)',
                      hintText: 'app_test_ios_XvHE1g',
                    ),
                    enabled: _client == null,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _apiKeyController,
                    decoration: const InputDecoration(
                      labelText: 'API Key (x-api-key)',
                    ),
                    obscureText: true,
                    enabled: _client == null,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _deviceIdController,
                    decoration: const InputDecoration(
                      labelText: 'Device ID',
                      hintText: 'Unique device identifier',
                    ),
                    enabled: _client == null,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                _status,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: _client != null ? Colors.green : colorScheme.onSurface,
                ),
              ),
              if (_error != null) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _error!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.error,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              FilledButton(
                onPressed: _client == null && !_connecting ? _connect : null,
                child: Text(_connecting ? 'Connecting…' : 'Connect'),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: _client != null ? _disconnect : null,
                child: const Text('Disconnect'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Events (${_events.length})',
                style: theme.textTheme.titleMedium,
              ),
              if (_events.isNotEmpty)
                TextButton(
                  onPressed: () {
                    setState(() => _events.clear());
                  },
                  child: const Text('Clear'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (_events.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Text(
                    'Connect to receive RAMEN events (real-time alerts, daily summaries).',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface.withOpacity(0.7),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            )
          else
            ..._events.take(50).map((e) {
                  final payload = e.payloadJson;
                  final displayPayload = payload.length > 120 ? '${payload.substring(0, 120)}…' : payload;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(
                        e.eventId,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontFamily: 'monospace',
                        ),
                      ),
                      subtitle: Text(
                        displayPayload,
                        style: theme.textTheme.bodySmall,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  );
                }),
        ],
      ),
    );
  }
}
