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
            bottomNavigationBar: _TabBar(
              selected: tab,
              onSelect: (t) => _tab.value = t,
            ),
          ),
        ),
      ),
    );
  }
}


/// Floating rounded tab bar; the selected tab sits in a theme-gradient pill.
class _TabBar extends StatelessWidget {
  final ShellTab selected;
  final ValueChanged<ShellTab> onSelect;
  const _TabBar({required this.selected, required this.onSelect});

  static const _items = [
    (ShellTab.home, Icons.home_rounded, 'Home'),
    (ShellTab.places, Icons.place_rounded, 'Places'),
    (ShellTab.map, Icons.map_rounded, 'Map'),
    (ShellTab.settings, Icons.settings_rounded, 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 4, 12, 10),
        height: 70,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(26),
          boxShadow: [BoxShadow(color: BB.navy.withValues(alpha: 0.22), blurRadius: 18, offset: const Offset(0, 6))],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: Row(children: [
          for (final (tab, icon, label) in _items)
            Expanded(
              child: Semantics(
                button: true,
                selected: tab == selected,
                label: '$label tab',
                excludeSemantics: true,
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => onSelect(tab),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      gradient: tab == selected ? BB.headerGradient : null,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(icon, size: 26, color: tab == selected ? Colors.white : BB.muted),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(label,
                            maxLines: 1,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: tab == selected ? Colors.white : BB.muted,
                            )),
                      ),
                    ]),
                  ),
                ),
              ),
            ),
        ]),
      ),
    );
  }
}
