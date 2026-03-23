import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:synheart_wear/synheart_wear.dart';

// Persistence keys for RAMEN config
const String _keyHost = 'ramen_host';
const String _keyPort = 'ramen_port';
const String _keyAppId = 'ramen_app_id';
const String _keyApiKey = 'ramen_api_key';
const String _keyDeviceId = 'ramen_device_id';
const String _keyUserId = 'ramen_user_id';
const String _keyAutoConnect = 'ramen_auto_connect';

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
  final _hostController = TextEditingController();
  final _portController = TextEditingController();
  final _appIdController = TextEditingController();
  final _apiKeyController = TextEditingController();
  final _deviceIdController = TextEditingController();
  final _userIdController = TextEditingController();

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
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    _hostController.text = prefs.getString(_keyHost) ?? 'ramen-service-dev.synheart.io';
    _portController.text = prefs.getString(_keyPort) ?? '443';
    _appIdController.text = prefs.getString(_keyAppId) ?? '';
    _apiKeyController.text = prefs.getString(_keyApiKey) ?? '';
    _deviceIdController.text = prefs.getString(_keyDeviceId) ?? '';
    _userIdController.text = prefs.getString(_keyUserId) ?? '';
    if (mounted) setState(() {});

    // Auto-connect if previously connected
    if (prefs.getBool(_keyAutoConnect) == true && _hasRequiredFields()) {
      _connect();
    }
  }

  Future<void> _saveConfig() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyHost, _hostController.text.trim());
    await prefs.setString(_keyPort, _portController.text.trim());
    await prefs.setString(_keyAppId, _appIdController.text.trim());
    await prefs.setString(_keyApiKey, _apiKeyController.text.trim());
    await prefs.setString(_keyDeviceId, _deviceIdController.text.trim());
    await prefs.setString(_keyUserId, _userIdController.text.trim());
  }

  bool _hasRequiredFields() {
    return _hostController.text.trim().isNotEmpty &&
        _deviceIdController.text.trim().isNotEmpty &&
        _userIdController.text.trim().isNotEmpty;
  }

  Future<void> _connect() async {
    final host = _hostController.text.trim();
    if (host.isEmpty) {
      setState(() => _error = 'Host required');
      return;
    }
    final port = int.tryParse(_portController.text.trim()) ?? 443;
    final deviceId = _deviceIdController.text.trim();
    if (deviceId.isEmpty) {
      setState(() => _error = 'Device ID required');
      return;
    }
    final userId = _userIdController.text.trim();
    if (userId.isEmpty) {
      setState(() => _error = 'User ID required');
      return;
    }

    // Save config so it persists across restarts
    await _saveConfig();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAutoConnect, true);

    setState(() {
      _connecting = true;
      _error = null;
      _status = 'Connecting…';
    });

    final appId = _appIdController.text.trim();
    final apiKey = _apiKeyController.text.trim();

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

    _stateSub = client.connectionState.listen((state) {
      if (!mounted) return;
      setState(() {
        _connecting = false;
        switch (state) {
          case RamenConnectionState.connecting:
            _status = 'Connecting…';
            _error = null;
          case RamenConnectionState.connected:
            _status = 'Connected';
            _error = null;
          case RamenConnectionState.disconnected:
            _status = 'Disconnected';
          case RamenConnectionState.reconnecting:
            _status = 'Reconnecting…';
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAutoConnect, false);

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
    _userIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: widget.onMenuPressed,
        ),
        title: const Text('RAMEN'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Config card ──
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Connection', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 12),
                  _field(_hostController, 'Host', 'ramen-service-dev.synheart.io', TextInputType.url),
                  _field(_portController, 'Port', '443', TextInputType.number),
                  _field(_appIdController, 'App ID', 'x-app-id'),
                  _field(_apiKeyController, 'API Key', 'x-api-key', null, true),
                  _field(_deviceIdController, 'Device ID', 'e.g. pixel10-test'),
                  _field(_userIdController, 'User ID', 'e.g. test-user-001'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Status + buttons ──
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _client != null && _status == 'Connected'
                      ? Colors.green
                      : _connecting
                          ? Colors.orange
                          : Colors.grey,
                ),
              ),
              const SizedBox(width: 8),
              Text(_status, style: theme.textTheme.bodyMedium),
              if (_error != null) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _error!,
                    style: theme.textTheme.bodySmall?.copyWith(color: cs.error),
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

          // ── Events ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Events (${_events.length})', style: theme.textTheme.titleMedium),
              if (_events.isNotEmpty)
                TextButton(
                  onPressed: () => setState(() => _events.clear()),
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
                    _client != null
                        ? 'Waiting for events…'
                        : 'Connect to receive real-time events.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            )
          else
            ..._events.take(50).map((e) {
              final payload = e.payloadJson;
              final display = payload.length > 120 ? '${payload.substring(0, 120)}…' : payload;
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(
                    '${e.provider} / ${e.eventType}',
                    style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'seq=${e.seq} id=${e.eventId}${e.isReplay ? ' (replay)' : ''}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontFamily: 'monospace',
                          fontSize: 10,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      if (display.isNotEmpty)
                        Text(display, style: theme.textTheme.bodySmall, maxLines: 3, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label,
    String hint, [
    TextInputType? keyboard,
    bool obscure = false,
  ]) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(labelText: label, hintText: hint),
        keyboardType: keyboard,
        obscureText: obscure,
        enabled: _client == null,
      ),
    );
  }
}
