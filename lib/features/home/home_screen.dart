import 'package:flutter/material.dart';

import '../../app/app_services.dart';
import '../../app/nav_actions.dart';
import '../../app/shell.dart';
import '../../app/theme.dart';
import '../../core/geo/geo.dart';
import '../../core/models/poi.dart';
import '../../shared/art.dart';
import '../../shared/photos.dart';
import '../../shared/place_info.dart';
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

  /// Photo used behind each Home tile (first one with a licensed photo).
  static const _tilePhotos = {
    PoiCategory.beach: ['boaby-rock-beach', 'osprey-beach', 'governors-beach'],
    PoiCategory.attraction: ['grand-turk-lighthouse', 'john-glenn-exhibit', 'north-creek'],
    PoiCategory.restaurant: ['margaritaville', 'jacks-shack', 'bohio'],
    PoiCategory.shopping: ['front-street', 'cockburn-town', 'grand-turk-cruise-center'],
    PoiCategory.historical: ['national-museum', 'st-marys', 'st-thomas'],
  };

  static String? photoFor(List<String> ids) {
    for (final id in ids) {
      final p = Photos.of(id);
      if (p != null && !p.isIllustration) return p.asset;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) => BB.photo ? _buildPhoto(context) : _buildClassic(context);

  /// v2.0 Home as presented to the customer, brighter (default themes).
  Widget _buildClassic(BuildContext context) {
    final s = AppScope.of(context);
    return Scaffold(
      body: Column(children: [
        const SimulatedBanner(safeTop: true),
        Expanded(
          child: ListView(padding: EdgeInsets.zero, children: [
            Container(
              height: 276,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
                boxShadow: [BoxShadow(color: BB.navy.withValues(alpha: 0.30), blurRadius: 14, offset: const Offset(0, 6))],
              ),
              child: ClipRRect(
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
              child: Stack(fit: StackFit.expand, children: [
              Container(
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
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.80),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: Text('Welcome to\nGrand Turk',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: BB.navy, fontSize: 27, height: 1.1, fontWeight: FontWeight.w900)),
                    ),
                  ]),
                ),
              ),
              const Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 6,
                child: DecoratedBox(decoration: BoxDecoration(gradient: BB.islandStripe)),
              ),
              ]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const DataHealthBanner(),
                const _ActiveNavCard(),
                const ReturnToPortButton(),
                const SizedBox(height: 14),
                GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  childAspectRatio: 0.98,
                  children: [
                    for (final c in _tiles)
                      _ClassicTile(
                        color: BB.category(c),
                        gradient: BB.categoryGradient(c),
                        icon: BB.categoryIcon(c),
                        label: c.tileLabel,
                        onTap: () => openCategory(context, c),
                      ),
                    _ClassicTile(
                      color: BB.navy,
                      gradient: BB.headerGradient,
                      icon: Icons.more_horiz,
                      label: 'More',
                      onTap: () => ShellTabs.go(context, ShellTab.places),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const IslandPostcard(),
                const SizedBox(height: 14),
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

  /// Bold photo Home (photo themes).
  Widget _buildPhoto(BuildContext context) {
    final s = AppScope.of(context);
    final ship = s.nav.shipTerminal;
    final featured = ship == null
        ? <Poi>[]
        : (s.destinations.where((p) => !p.isShipTerminal && p.canNavigate && Photos.of(p.id) != null).toList()
              ..sort((a, b) => haversineM(ship.display, a.display).compareTo(haversineM(ship.display, b.display))))
            .take(8)
            .toList();
    final heroPhoto = Photos.of('boaby-rock-beach')?.asset;
    return Scaffold(
      body: Column(children: [
        const SimulatedBanner(safeTop: true),
        Expanded(
          child: ListView(padding: EdgeInsets.zero, children: [
            // Hero: full-bleed beach photo, logo, big welcome.
            SizedBox(
              height: 300,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(36)),
                child: Stack(fit: StackFit.expand, children: [
                  Image.asset(heroPhoto ?? 'assets/images/splash.jpg',
                      fit: BoxFit.cover,
                      alignment: heroPhoto == null ? const Alignment(0, 0.55) : const Alignment(-0.3, 0),
                      excludeFromSemantics: true),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x880B2F44), Color(0x000B2F44), Color(0x000B2F44), Color(0xB30B2F44)],
                        stops: [0, 0.35, 0.5, 1],
                      ),
                    ),
                  ),
                  SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          const _OfflineChip(),
                          const Spacer(),
                          Material(
                            color: Colors.white,
                            shape: const CircleBorder(),
                            elevation: 3,
                            child: IconButton(
                              tooltip: 'Search destinations',
                              onPressed: () => openSearch(context),
                              icon: Icon(Icons.search_rounded, color: BB.navy, size: 26),
                            ),
                          ),
                        ]),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.94),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Image.asset('assets/images/logo.png', height: 48, semanticLabel: 'TCI Beach Buddies'),
                        ),
                        // Scales down (never overflows) with large text settings.
                        Expanded(
                          child: Align(
                            alignment: Alignment.bottomLeft,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.bottomLeft,
                              child: Text('Welcome to\nGrand Turk',
                                  style: heading(40, color: Colors.white, height: 1.0).copyWith(
                                      shadows: const [Shadow(color: Color(0x99000000), blurRadius: 10)])),
                            ),
                          ),
                        ),
                        const SizedBox(height: 44),
                      ]),
                    ),
                  ),
                ]),
              ),
            ),
            // Return sits over the bottom of the hero: the most important action.
            Transform.translate(
              offset: const Offset(0, -30),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  ReturnToPortButton(color: BB.orange),
                  const SizedBox(height: 10),
                  const DataHealthBanner(),
                  const _ActiveNavCard(),
                ]),
              ),
            ),
            Transform.translate(
              offset: const Offset(0, -18),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text('What do you feel like?', style: heading(23)),
                  const SizedBox(height: 10),
                  GridView.count(
                    crossAxisCount: 3,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.92,
                    children: [
                      for (final c in _tiles)
                        _Tile(
                          color: BB.category(c),
                          gradient: BB.categoryGradient(c),
                          photo: photoFor(_tilePhotos[c] ?? const []),
                          icon: BB.categoryIcon(c),
                          label: c.tileLabel,
                          onTap: () => openCategory(context, c),
                        ),
                      _Tile(
                        color: BB.navy,
                        gradient: BB.headerGradient,
                        icon: Icons.apps_rounded,
                        label: 'More',
                        onTap: () => ShellTabs.go(context, ShellTab.places),
                      ),
                    ],
                  ),
                  if (featured.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Row(children: [
                      Expanded(child: Text('Near the ship', style: heading(23))),
                      TextButton(onPressed: () => ShellTabs.go(context, ShellTab.places), child: const Text('See all')),
                    ]),
                    const SizedBox(height: 4),
                    SizedBox(
                      height: 204,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: featured.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (context, i) {
                          final p = featured[i];
                          return _FeaturedCard(
                            poi: p,
                            distance: '${s.settings.formatDistance(haversineM(ship!.display, p.display))} from ship',
                            onTap: () => openDetails(context, p),
                          );
                        },
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  const IslandPostcard(),
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                        onPressed: () => ShellTabs.go(context, ShellTab.map),
                        icon: const Icon(Icons.map_rounded),
                        label: const Text('Map'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(child: Center(child: GpsStatusChip(compact: true))),
                  ]),
                  const SizedBox(height: 10),
                  Text('${s.destinations.length} places to explore · works without internet',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: BB.muted, fontSize: 13, fontWeight: FontWeight.w700)),
                ]),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

/// Photo card in the "Near the ship" strip.
class _FeaturedCard extends StatelessWidget {
  final Poi poi;
  final String distance;
  final VoidCallback onTap;
  const _FeaturedCard({required this.poi, required this.distance, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${poi.name}, $distance',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: 184,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Stack(children: [
              PlaceArt(poi: poi, width: 184, height: 136, radius: 22),
              Positioned(
                left: 8,
                bottom: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                  child: Text(distance,
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900, color: BB.navy)),
                ),
              ),
            ]),
            const SizedBox(height: 6),
            Text(poi.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w900, color: BB.ink, height: 1.15)),
          ]),
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final Color color;
  final Gradient gradient;
  final String? photo;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _Tile({required this.color, required this.gradient, this.photo, required this.icon, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final radius = leafRadius(28, 10);
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.40), blurRadius: 12, offset: const Offset(0, 5))],
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: Stack(fit: StackFit.expand, children: [
            DecoratedBox(decoration: BoxDecoration(gradient: gradient)),
            if (photo != null) Image.asset(photo!, fit: BoxFit.cover, excludeFromSemantics: true),
            if (photo != null)
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [color.withValues(alpha: 0.15), color.withValues(alpha: 0.92)],
                    stops: const [0.2, 1],
                  ),
                ),
              ),
            Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 4)],
                      ),
                      child: Icon(icon, color: color, size: 23),
                    ),
                    const Spacer(),
                    Text(label,
                        maxLines: 2,
                        style: const TextStyle(color: Colors.white, fontSize: 14.5, fontWeight: FontWeight.w900, height: 1.1,
                            shadows: [Shadow(color: Color(0x88000000), blurRadius: 4)])),
                  ]),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _ClassicTile extends StatelessWidget {
  final Color color;
  final Gradient gradient;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ClassicTile({required this.color, required this.gradient, required this.icon, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(20);
    return Semantics(
      button: true,
      label: label,
      child: Container(
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: radius,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: [
            BoxShadow(color: color.withValues(alpha: 0.45), blurRadius: 12, offset: const Offset(0, 5)),
            BoxShadow(color: color.withValues(alpha: 0.35), spreadRadius: 1.5),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(17),
          child: Stack(fit: StackFit.expand, children: [
            // Glossy highlight on the top half.
            const Align(
              alignment: Alignment.topCenter,
              child: FractionallySizedBox(
                heightFactor: 0.5,
                widthFactor: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x40FFFFFF), Color(0x00FFFFFF)],
                    ),
                  ),
                ),
              ),
            ),
            Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: onTap,
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.25),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2.5),
                    ),
                    child: Icon(icon, color: Colors.white, size: 30),
                  ),
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(label,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w900,
                            shadows: [Shadow(color: Color(0x66000000), blurRadius: 3)])),
                  ),
                ]),
              ),
            ),
          ]),
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


/// "Welcome to Grand Turk" postcard on Home: the colourful island sign and a
/// few things every visitor should know.
class IslandPostcard extends StatelessWidget {
  const IslandPostcard({super.key});

  static const facts = [
    (Icons.account_balance_rounded, 'Cockburn Town is the capital of the Turks and Caicos Islands'),
    (Icons.attach_money_rounded, 'The currency is the US dollar'),
    (Icons.directions_car_rounded, 'Traffic drives on the left: look right first when crossing'),
    (Icons.water_rounded, 'Salt raked from the island\'s ponds was once its main export'),
  ];

  @override
  Widget build(BuildContext context) {
    final radius = leafRadius(34, 12);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: radius,
        boxShadow: [BoxShadow(color: BB.navy.withValues(alpha: 0.16), blurRadius: 18, offset: const Offset(0, 6))],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          SizedBox(
            height: 190,
            child: Stack(fit: StackFit.expand, children: [
              Image.asset('assets/images/grand-turk-sign.jpg',
                  fit: BoxFit.cover,
                  alignment: const Alignment(0, 0.1),
                  semanticLabel: 'The colourful Grand Turk sign'),
              Positioned(
                left: 0,
                right: 0,
                bottom: -1,
                height: 30,
                child: ClipPath(clipper: const WaveTopClipper(depth: 30), child: const ColoredBox(color: Colors.white)),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Good to know on Grand Turk',
                  style: BB.photo
                      ? heading(21, color: BB.ink)
                      : TextStyle(color: BB.navy, fontWeight: FontWeight.w900, fontSize: 17)),
              const SizedBox(height: 8),
              for (final (icon, text) in facts)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(color: BB.selectedRow, borderRadius: leafRadius(12, 4)),
                      child: Icon(icon, size: 17, color: BB.navy),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(text,
                            style: const TextStyle(fontSize: 14, height: 1.3, color: BB.ink, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ]),
                ),
            ]),
          ),
        ]),
      ),
    );
  }
}
