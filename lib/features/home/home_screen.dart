import 'package:flutter/material.dart';

import '../../app/app_services.dart';
import '../../app/nav_actions.dart';
import '../../app/shell.dart';
import '../../app/theme.dart';
import '../../shared/widgets.dart';
import '../navigation/application/navigation_controller.dart';

/// Screen 1 - Home: welcome + quick access to Explore, Destinations, Ship.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final count = s.destinations.length;
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF3FB7D6), Color(0xFF7FD3E0), Color(0xFFBDEBF0), BB.sand],
            stops: [0, 0.45, 0.75, 1],
          ),
        ),
        child: Column(children: [
          const SimulatedBanner(),
          Expanded(
            child: SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
                children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const _OfflineChip(),
                    const GpsStatusChip(compact: true),
                  ]),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Image.asset('assets/images/logo.png', height: 92, semanticLabel: 'TCI Beach Buddies'),
                  ),
                  const SizedBox(height: 18),
                  const Text('Your Guide to\nGrand Turk',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        height: 1.15,
                        fontWeight: FontWeight.w800,
                        shadows: [Shadow(color: Color(0x66003355), blurRadius: 8)],
                      )),
                  const SizedBox(height: 6),
                  const Text('Works offline - no data or Wi-Fi needed',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600,
                          shadows: [Shadow(color: Color(0x66003355), blurRadius: 6)])),
                  const DataHealthBanner(),
                  const SizedBox(height: 18),
                  _ActiveNavCard(),
                  _HomeAction(
                    color: BB.teal,
                    icon: Icons.map_outlined,
                    title: 'Explore Map',
                    subtitle: 'See the island and attractions',
                    onTap: () => ShellTabs.go(context, ShellTab.map),
                  ),
                  _HomeAction(
                    color: BB.orange,
                    icon: Icons.place,
                    title: 'Destinations',
                    subtitle: count == 0 ? 'Destination list not installed' : '$count places to visit',
                    onTap: () => ShellTabs.go(context, ShellTab.destinations),
                  ),
                  _HomeAction(
                    color: BB.purple,
                    icon: Icons.directions_boat,
                    title: 'Return to Ship',
                    subtitle: 'Navigate to the Cruise Center',
                    onTap: s.bundle.navigationAvailable ? () => returnToShip(context) : null,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Obey road signs and local conditions, and allow plenty of time to return to your ship.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: BB.navy, fontSize: 12.5, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class _OfflineChip extends StatelessWidget {
  const _OfflineChip();
  @override
  Widget build(BuildContext context) {
    final ok = AppScope.of(context).bundle.navigationAvailable;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(ok ? Icons.offline_pin : Icons.error_outline, size: 14, color: ok ? BB.success : BB.danger),
        const SizedBox(width: 5),
        Text(ok ? 'Offline ready' : 'Offline data problem',
            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

class _ActiveNavCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final nav = AppScope.of(context).nav;
    return ListenableBuilder(
      listenable: nav,
      builder: (context, _) {
        if (!nav.isActive || nav.destination == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Material(
            color: BB.navy,
            borderRadius: BorderRadius.circular(16),
            child: ListTile(
              onTap: () => showNavigationScreen(context),
              leading: const Icon(Icons.navigation, color: Colors.white),
              title: Text('Navigating to ${nav.destination!.name}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              subtitle: Text(nav.phase == NavPhase.navigating ? 'Tap to resume' : 'Preparing route…',
                  style: const TextStyle(color: Colors.white70)),
              trailing: const Icon(Icons.chevron_right, color: Colors.white),
            ),
          ),
        );
      },
    );
  }
}

class _HomeAction extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  const _HomeAction({required this.color, required this.icon, required this.title, required this.subtitle, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Semantics(
        button: true,
        label: '$title. $subtitle',
        child: Material(
          color: onTap == null ? Colors.grey : color,
          borderRadius: BorderRadius.circular(18),
          elevation: 3,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              child: Row(children: [
                Icon(icon, color: Colors.white, size: 38),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(title, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: const TextStyle(color: Colors.white, fontSize: 13.5)),
                  ]),
                ),
                const Icon(Icons.chevron_right, color: Colors.white),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
