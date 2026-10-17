import 'package:flutter/material.dart';

import '../features/home/home_screen.dart';
import '../features/map/presentation/map_screen.dart';
import '../features/pois/presentation/destinations_screen.dart';
import '../features/pois/presentation/saved_screen.dart';
import '../features/settings/settings_screen.dart';

enum ShellTab { home, map, destinations, saved, more }

/// Lets any tab switch to another tab (e.g. Home > Explore Map).
class ShellTabs extends InheritedNotifier<ValueNotifier<ShellTab>> {
  const ShellTabs({super.key, required ValueNotifier<ShellTab> tab, required super.child})
      : super(notifier: tab);

  static void go(BuildContext context, ShellTab tab) {
    final w = context.getInheritedWidgetOfExactType<ShellTabs>();
    w?.notifier?.value = tab;
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  final _tab = ValueNotifier<ShellTab>(ShellTab.home);

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ShellTabs(
      tab: _tab,
      child: ValueListenableBuilder<ShellTab>(
        valueListenable: _tab,
        builder: (context, tab, _) => Scaffold(
          body: IndexedStack(
            index: tab.index,
            children: const [
              HomeScreen(),
              MapScreen(),
              DestinationsScreen(),
              SavedScreen(),
              SettingsScreen(),
            ],
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: tab.index,
            onDestinationSelected: (i) => _tab.value = ShellTab.values[i],
            height: 66,
            destinations: const [
              NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
              NavigationDestination(icon: Icon(Icons.map_outlined), selectedIcon: Icon(Icons.map), label: 'Map'),
              NavigationDestination(icon: Icon(Icons.place_outlined), selectedIcon: Icon(Icons.place), label: 'Destinations'),
              NavigationDestination(icon: Icon(Icons.favorite_border), selectedIcon: Icon(Icons.favorite), label: 'Saved'),
              NavigationDestination(icon: Icon(Icons.menu), selectedIcon: Icon(Icons.menu_open), label: 'More'),
            ],
          ),
        ),
      ),
    );
  }
}
