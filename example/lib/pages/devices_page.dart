import 'package:flutter/material.dart';
import '../controller/whoop_controller.dart';
import '../controller/garmin_controller.dart';

class DevicesPage extends StatelessWidget {
  const DevicesPage({
    super.key,
    required this.whoopController,
    required this.garminController,
    this.onMenuPressed,
  });

  final WhoopController whoopController;
  final GarminController garminController;
  final VoidCallback? onMenuPressed;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: onMenuPressed ?? () => Scaffold.of(context).openDrawer(),
        ),
        title: const Text('Wear SDK'),
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([whoopController, garminController]),
        builder: (context, _) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'WHOOP and Garmin use the same user ID but require separate sign-in. Connection state is tracked per provider.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Connected',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                if (whoopController.isConnected)
                  _DeviceCard(
                    name: 'WHOOP',
                    description: whoopController.userId != null
                        ? 'Recovery, sleep, strain · user ${whoopController.userId}'
                        : 'Recovery, sleep, strain',
                    icon: Icons.favorite,
                    color: Colors.blue,
                    isConnected: true,
                    status: whoopController.status,
                    error: whoopController.error,
                    onToggle: () async {
                      try {
                        await whoopController.disconnect();
                      } catch (e, st) {
                        debugPrint('WHOOP disconnect failed: $e');
                        debugPrint('$st');
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Disconnect failed: ${e.toString()}'),
                              backgroundColor: Colors.red,
                              duration: const Duration(seconds: 5),
                            ),
                          );
                        }
                      }
                    },
                  ),
                if (garminController.isConnected)
                  _DeviceCard(
                    name: 'Garmin',
                    description: garminController.userId != null
                        ? 'Fitness and health · user ${garminController.userId}'
                        : 'Fitness and health',
                    icon: Icons.fitness_center,
                    color: Colors.orange,
                    isConnected: true,
                    status: garminController.status,
                    error: garminController.error,
                    onToggle: () async {
                      try {
                        await garminController.disconnect();
                      } catch (e, st) {
                        debugPrint('Garmin disconnect failed: $e');
                        debugPrint('$st');
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Disconnect failed: ${e.toString()}'),
                              backgroundColor: Colors.red,
                              duration: const Duration(seconds: 5),
                            ),
                          );
                        }
                      }
                    },
                  ),
                if (!whoopController.isConnected && !garminController.isConnected)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'No devices connected. Connect below.',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ),
                const SizedBox(height: 24),
                Text(
                  'Available',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                if (!whoopController.isConnected)
                  _DeviceCard(
                    name: 'WHOOP',
                    description: 'Sign in with WHOOP (separate from Garmin)',
                    icon: Icons.favorite,
                    color: Colors.blue,
                    isConnected: false,
                    status: whoopController.status,
                    error: whoopController.error,
                    onToggle: () async => await whoopController.connect(),
                  ),
                if (!garminController.isConnected)
                  _DeviceCard(
                    name: 'Garmin',
                    description: 'Sign in with Garmin (separate from WHOOP)',
                    icon: Icons.fitness_center,
                    color: Colors.orange,
                    isConnected: false,
                    status: garminController.status,
                    error: garminController.error,
                    onToggle: () async => await garminController.connect(),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DeviceCard extends StatelessWidget {
  const _DeviceCard({
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
    required this.isConnected,
    required this.status,
    this.error,
    required this.onToggle,
  });

  final String name;
  final String description;
  final IconData icon;
  final Color color;
  final bool isConnected;
  final String status;
  final String? error;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: (isConnected ? color : Colors.grey).withAlpha(51),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon,
                      color: isConnected ? color : Colors.grey, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(status,
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey[600]),
                          overflow: TextOverflow.ellipsis),
                      if (error != null && error!.isNotEmpty)
                        Text(error!,
                            style: TextStyle(
                                fontSize: 12, color: Theme.of(context).colorScheme.error),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                Switch(
                  value: isConnected,
                  onChanged: (_) => onToggle(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
