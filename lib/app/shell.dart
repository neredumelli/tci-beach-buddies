import 'package:flutter/material.dart';

import '../features/home/home_screen.dart';
import '../features/map/presentation/map_screen.dart';
import '../features/pois/presentation/places_screen.dart';
import '../features/settings/settings_screen.dart';
import 'theme.dart';

/// Bottom tabs from the v2.0 walkthrough: Home, Places, Map, Settings.
enum ShellTab { home, places, map, settings }

class ShellTabs extends InheritedNotifier<ValueNotifier<ShellTab>> {
  const ShellTabs({super.key, required ValueNotifier<ShellTab> tab, required super.child}) : super(notifier: tab);

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
        builder: (context, tab, _) => PopScope(
          // Android back on a non-Home tab returns to Home instead of exiting.
          canPop: tab == ShellTab.home,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _tab.value = ShellTab.home;
          },
          child: Scaffold(
            body: IndexedStack(
              index: tab.index,
              children: const [HomeScreen(), PlacesScreen(), MapScreen(), SettingsScreen()],
            ),
            bottomNavigationBar: DecoratedBox(
              decoration: BoxDecoration(gradient: BB.headerGradient),
              child: NavigationBar(
              backgroundColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              selectedIndex: tab.index,
              onDestinationSelected: (i) => _tab.value = ShellTab.values[i],
              height: 66,
              destinations: const [
                NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
                NavigationDestination(icon: Icon(Icons.place_outlined), selectedIcon: Icon(Icons.place), label: 'Places'),
                NavigationDestination(icon: Icon(Icons.map_outlined), selectedIcon: Icon(Icons.map), label: 'Map'),
                NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Settings'),
              ],
            ),
            ),
          ),
        ),
      ),
    );
  }
}
