import 'package:flutter/material.dart';

import '../../app/app_services.dart';
import '../../app/nav_actions.dart';
import '../../app/shell.dart';
import '../../app/theme.dart';
import '../../core/models/poi.dart';
import '../../shared/widgets.dart';
import '../navigation/application/navigation_controller.dart';

/// 02 Home: tropical hero, Welcome to Grand Turk, RETURN TO CRUISE PORT and
/// six colourful category tiles. First functional screen after Splash.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const _tiles = [
    PoiCategory.beach,
    PoiCategory.attraction,
    PoiCategory.restaurant,
    PoiCategory.shopping,
    PoiCategory.historical,
  ];

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(children: [
        const SimulatedBanner(safeTop: true),
        Expanded(
          child: ListView(padding: EdgeInsets.zero, children: [
            SizedBox(
              height: 270,
              child: Container(
                decoration: const BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage('assets/images/splash.jpg'),
                    fit: BoxFit.cover,
                    alignment: Alignment(0, 0.55), // beach + sea part of the design image
                  ),
                ),
                child: SafeArea(
                  bottom: false,
                  child: Column(children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                      child: Row(children: [
                        const _OfflineChip(),
                        const Spacer(),
                        IconButton(
                          tooltip: 'Search destinations',
                          onPressed: () => openSearch(context),
                          icon: const Icon(Icons.search, color: Colors.white, size: 28,
                              shadows: [Shadow(color: Color(0x88000000), blurRadius: 4)]),
                        ),
                      ]),
                    ),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 70),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(16)),
                      child: Image.asset('assets/images/logo.png', height: 62, semanticLabel: 'TCI Beach Buddies'),
                    ),
                    const SizedBox(height: 10),
                    Text('Welcome to\nGrand Turk',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: BB.navy, fontSize: 28, height: 1.1, fontWeight: FontWeight.w900,
                            shadows: [Shadow(color: Colors.white, blurRadius: 8)])),
                  ]),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const DataHealthBanner(),
                const _ActiveNavCard(),
                const ReturnToPortButton(),
                const SizedBox(height: 14),
                GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.0,
                  children: [
                    for (final c in _tiles)
                      _Tile(
                        color: BB.category(c),
                        gradient: BB.categoryGradient(c),
                        icon: BB.categoryIcon(c),
                        label: c.tileLabel,
                        onTap: () => openCategory(context, c),
                      ),
                    _Tile(
                      color: BB.navy,
                      gradient: BB.headerGradient,
                      icon: Icons.more_horiz,
                      label: 'More',
                      onTap: () => ShellTabs.go(context, ShellTab.places),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(46)),
                      onPressed: () => ShellTabs.go(context, ShellTab.map),
                      icon: const Icon(Icons.map),
                      label: const Text('Map'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(child: Center(child: GpsStatusChip(compact: true))),
                ]),
                const SizedBox(height: 10),
                Text('${s.destinations.length} places to explore · works without internet',
                    textAlign: TextAlign.center, style: const TextStyle(color: BB.muted, fontSize: 12.5)),
              ]),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _Tile extends StatelessWidget {
  final Color color;
  final Gradient gradient;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _Tile({required this.color, required this.gradient, required this.icon, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(18);
    return Semantics(
      button: true,
      label: label,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: radius,
          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.38), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: radius,
            onTap: onTap,
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.22), shape: BoxShape.circle),
                child: Icon(icon, color: Colors.white, size: 32),
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w800,
                        shadows: [Shadow(color: Color(0x55000000), blurRadius: 3)])),
              ),
            ]),
          ),
        ),
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
  const _ActiveNavCard();
  @override
  Widget build(BuildContext context) {
    final nav = AppScope.of(context).nav;
    return ListenableBuilder(
      listenable: nav,
      builder: (context, _) {
        if (!nav.guidanceStarted || !nav.isActive || nav.destination == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Material(
            color: BB.go,
            borderRadius: BorderRadius.circular(12),
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
