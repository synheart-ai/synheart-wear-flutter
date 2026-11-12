import 'package:flutter/material.dart';
import 'package:synheart_wear/synheart_wear.dart';

/// Minimal example showing how to wire `SynheartWear` and request
/// permissions. Vendor-specific OAuth flows (WHOOP, Garmin, Fitbit) live
/// in the consumer app — see the SDK README for the full surface.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final SynheartWear _wear;
  String _status = 'Not initialized';
  Map<MetricType, num>? _latestMetrics;
  String? _source;
  String? _history;

  @override
  void initState() {
    super.initState();
    _wear = SynheartWear(
      config: SynheartWearConfig.withAdapters(
        const {DeviceAdapter.platformHealth},
      ),
    );
  }

  Future<void> _connect() async {
    setState(() => _status = 'Requesting permissions…');
    try {
      final granted = await _wear.requestPermissions(
        permissions: const {
          PermissionType.heartRate,
          PermissionType.heartRateVariability,
          PermissionType.steps,
        },
      );
      if (granted.values.every((v) => v != ConsentStatus.granted)) {
        setState(() => _status = 'Permissions denied');
        return;
      }
      await _wear.initialize();
      final metrics = await _wear.readMetrics();
      setState(() {
        _status = 'Connected';
        _source = '${metrics.source} (${metrics.deviceId})';
        _latestMetrics = {
          for (final t in MetricType.values)
            if (metrics.getMetric(t) != null) t: metrics.getMetric(t)!,
        };
      });
    } catch (e) {
      setState(() => _status = 'Error: $e');
    }
  }

  /// Android: lift Health Connect's 30-day limit on past data.
  Future<void> _requestHistory() async {
    final available = await HealthAdapter.isHistoryAvailable();
    final granted = await HealthAdapter.requestHistoryAuthorization();
    setState(() => _history = 'available: $available, granted: $granted');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Synheart Wear example')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Status: $_status'),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _connect,
              child: const Text('Request permissions and read metrics'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _requestHistory,
              child: const Text('Request history access'),
            ),
            if (_history != null) Text('History $_history'),
            const SizedBox(height: 24),
            if (_source != null) Text('Source: $_source'),
            if (_latestMetrics != null) ...[
              Text(
                'Latest metrics',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              for (final entry in _latestMetrics!.entries)
                Text('${entry.key.name}: ${entry.value}'),
            ],
          ],
        ),
      ),
    );
  }
}
