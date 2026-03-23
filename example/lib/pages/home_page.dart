import 'package:flutter/material.dart';
import '../controller/whoop_controller.dart';
import '../controller/garmin_controller.dart';
import 'devices_page.dart';
// import 'whoop_page.dart';
// import 'garmin_page.dart';
import 'ramen_page.dart';
import 'settings_page.dart';

enum NavigationItem {
  devices,
  // whoop,
  // garmin,
  ramen,
  settings,
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final WhoopController _whoopController;
  late final GarminController _garminController;
  NavigationItem _currentItem = NavigationItem.devices;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _whoopController = WhoopController();
    _garminController = GarminController();
    _whoopController.initialize();
    _garminController.initialize();
  }

  @override
  void dispose() {
    _whoopController.dispose();
    _garminController.dispose();
    super.dispose();
  }

  void _onNavigationItemSelected(NavigationItem item) {
    setState(() => _currentItem = item);
    Navigator.pop(context);
  }

  void _openDrawer() => _scaffoldKey.currentState?.openDrawer();

  Widget _buildCurrentPage() {
    switch (_currentItem) {
      case NavigationItem.devices:
        return DevicesPage(
          whoopController: _whoopController,
          garminController: _garminController,
          onMenuPressed: _openDrawer,
        );
      // case NavigationItem.whoop:
      //   return WhoopPage(
      //     controller: _whoopController,
      //     onMenuPressed: _openDrawer,
      //   );
      // case NavigationItem.garmin:
      //   return GarminPage(
      //     controller: _garminController,
      //     onMenuPressed: _openDrawer,
      //   );
      case NavigationItem.ramen:
        return RamenPage(onMenuPressed: _openDrawer);
      case NavigationItem.settings:
        return SettingsPage(
          controller: _whoopController,
          garminController: _garminController,
          onMenuPressed: _openDrawer,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: _buildDrawer(context),
      body: _buildCurrentPage(),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    final theme = Theme.of(context);
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: theme.colorScheme.primaryContainer),
            child: Text(
              'Wear Example',
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
          ),
          _drawerTile(context, NavigationItem.devices, Icons.watch, 'Devices'),
          // _drawerTile(context, NavigationItem.whoop, Icons.favorite, 'WHOOP'),
          // _drawerTile(context, NavigationItem.garmin, Icons.fitness_center, 'Garmin'),
          _drawerTile(context, NavigationItem.ramen, Icons.stream, 'RAMEN'),
          const Divider(),
          _drawerTile(context, NavigationItem.settings, Icons.settings, 'Settings'),
        ],
      ),
    );
  }

  ListTile _drawerTile(
    BuildContext context,
    NavigationItem item,
    IconData icon,
    String label,
  ) {
    final selected = _currentItem == item;
    return ListTile(
      leading: Icon(icon, color: selected ? Theme.of(context).colorScheme.primary : null),
      title: Text(label),
      selected: selected,
      onTap: () => _onNavigationItemSelected(item),
    );
  }
}
