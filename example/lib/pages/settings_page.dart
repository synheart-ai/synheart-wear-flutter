import 'package:flutter/material.dart';
import '../controller/whoop_controller.dart';
import '../controller/garmin_controller.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.controller,
    this.garminController,
    this.onMenuPressed,
  });

  final WhoopController controller;
  final GarminController? garminController;
  final VoidCallback? onMenuPressed;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _baseUrlController;
  late TextEditingController _appIdController;
  late TextEditingController _apiKeyController;
  late TextEditingController _projectIdController;
  late TextEditingController _redirectUriController;

  bool _isLoading = false;
  bool _useApiV1Prefix = true;

  @override
  void initState() {
    super.initState();
    _baseUrlController =
        TextEditingController(text: WhoopController.defaultBaseUrl);
    _appIdController = TextEditingController(text: 'app_test_ios_XvHE1g');
    _apiKeyController = TextEditingController();
    _projectIdController = TextEditingController();
    _redirectUriController =
        TextEditingController(text: WhoopController.defaultRedirectUri);
    _loadConfiguration();
  }

  Future<void> _loadConfiguration() async {
    try {
      final config = await widget.controller.provider.loadConfiguration();
      setState(() {
        _baseUrlController.text =
            config['baseUrl'] ?? widget.controller.baseUrl;
        _appIdController.text = config['appId'] ?? widget.controller.appId;
        _apiKeyController.text = config['apiKey'] ?? '';
        _projectIdController.text = config['projectId'] ?? '';
        _redirectUriController.text =
            config['redirectUri'] ?? widget.controller.redirectUri;
        _useApiV1Prefix = config['useApiV1Prefix'] != 'false';
      });
    } catch (e) {
      debugPrint('Error loading configuration: $e');
      setState(() {
        _baseUrlController.text = widget.controller.baseUrl;
        _appIdController.text = widget.controller.appId;
        _redirectUriController.text = widget.controller.redirectUri;
      });
    }
  }

  Future<void> _saveConfiguration() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await widget.controller.provider.saveConfiguration(
        baseUrl: _baseUrlController.text.trim(),
        appId: _appIdController.text.trim(),
        apiKey: _apiKeyController.text.trim().isNotEmpty
            ? _apiKeyController.text.trim()
            : null,
        projectId: _projectIdController.text.trim().isNotEmpty
            ? _projectIdController.text.trim()
            : null,
        redirectUri: _redirectUriController.text.trim(),
        // useApiV1Prefix: _useApiV1Prefix,
      );
      await widget.controller.reloadConfiguration();
      if (widget.garminController != null) {
        await widget.garminController!.reloadConfiguration();
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Configuration saved successfully'),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error saving configuration: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    _appIdController.dispose();
    _apiKeyController.dispose();
    _projectIdController.dispose();
    _redirectUriController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: widget.onMenuPressed ?? () => Scaffold.of(context).openDrawer(),
        ),
        title: const Text('Settings'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('SDK Configuration',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _baseUrlController,
                        decoration: const InputDecoration(
                          labelText: 'Base URL',
                          border: OutlineInputBorder(),
                          hintText: 'https://wear-service-dev.synheart.io',
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Enter base URL';
                          if (Uri.tryParse(v.trim()) == null || !Uri.parse(v.trim()).hasScheme) return 'Valid URL required';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _appIdController,
                        decoration: const InputDecoration(
                          labelText: 'App ID',
                          border: OutlineInputBorder(),
                          hintText: 'app_test_ios_XvHE1g',
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter App ID' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _apiKeyController,
                        decoration: const InputDecoration(
                          labelText: 'API Key (x-api-key)',
                          border: OutlineInputBorder(),
                          hintText: 'Required for all requests',
                        ),
                        obscureText: true,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _projectIdController,
                        decoration: const InputDecoration(
                          labelText: 'Project ID (optional)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _redirectUriController,
                        decoration: const InputDecoration(
                          labelText: 'Redirect URI',
                          border: OutlineInputBorder(),
                          hintText: 'synheart://oauth/callback',
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Enter redirect URI';
                          final u = Uri.tryParse(v.trim());
                          if (u == null || !u.hasScheme) return 'Valid URI required';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      SwitchListTile(
                        title: const Text('Use /api/v1 prefix'),
                        subtitle: const Text(
                          'Turn OFF if you get 404: backend uses paths without /api/v1 (e.g. /auth/connect/garmin)',
                        ),
                        value: _useApiV1Prefix,
                        onChanged: (v) => setState(() => _useApiV1Prefix = v),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _saveConfiguration,
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                                )
                              : const Text('Save Configuration'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline, color: Theme.of(context).colorScheme.primary, size: 24),
                          const SizedBox(width: 8),
                          const Text('Guide', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _guide('Base URL: wear service endpoint. If "Use /api/v1 prefix" is ON, /api/v1 is appended; turn OFF for backends that use paths like /auth/connect/garmin directly.'),
                      _guide('App ID / API Key: shared by WHOOP and Garmin. Set in Settings first.'),
                      _guide('Redirect URI: OAuth return URL after login.'),
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

  Widget _guide(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontSize: 14)),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }
}
