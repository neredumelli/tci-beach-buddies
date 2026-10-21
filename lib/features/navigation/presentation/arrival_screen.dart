import 'package:flutter/material.dart';

import '../../../app/app_services.dart';
import '../../../app/nav_actions.dart';
import '../../../app/theme.dart';
import '../../../core/geo/geo.dart';
import '../../../core/models/poi.dart';
import '../../../shared/art.dart';
import '../../../shared/widgets.dart';

/// 09 Arrival: image, green check "You've Arrived!", name + category,
/// local information, Explore Nearby and Return to Cruise Port.
/// Shown once per navigation, only after verified arrival.
class ArrivalScreen extends StatelessWidget {
  final String poiId;
  const ArrivalScreen({super.key, required this.poiId});

  @override
  Widget build(BuildContext context) => BB.photo ? _buildPhoto(context) : _buildClassic(context);

  /// v2.0 look as presented to the customer, brighter (classic themes).
  Widget _buildClassic(BuildContext context) {
    final s = AppScope.of(context);
    final poi = s.poiById(poiId);
    if (poi == null) return const Scaffold(body: Center(child: Text('Destination not found.')));
    final ship = s.nav.shipTerminal;
    final fromShip = ship == null ? null : s.settings.formatDistance(haversineM(ship.display, poi.display));
    // Arrived is a terminal state (not "active"), so leaving with Back is safe.
    return Scaffold(
        backgroundColor: Colors.white,
        body: Column(children: [
          const SimulatedBanner(safeTop: true),
          Expanded(
            child: ListView(padding: EdgeInsets.zero, children: [
              Stack(children: [
                // Full-width hero photo, ~40% of the screen height.
                PlaceArt(poi: poi, width: double.infinity, height: (MediaQuery.sizeOf(context).height * 0.40).clamp(240.0, 420.0), radius: 0, expandable: true),
                SafeArea(
                  child: IconButton(
                    tooltip: 'Home',
                    onPressed: () {
                      s.nav.stop();
                      goHome(context);
                    },
                    icon: const Icon(Icons.home, color: Colors.white, size: 28,
                        shadows: [Shadow(color: Color(0x88000000), blurRadius: 4)]),
                  ),
                ),
              ]),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.check_circle, color: BB.go, size: 44, semanticLabel: 'Arrived'),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(poi.isShipTerminal ? 'Welcome Back!' : "You've Arrived!",
                          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: BB.go)),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  Text(poi.name, textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: BB.navy)),
                  Text(
                    poi.isShipTerminal || fromShip == null
                        ? poi.category.label
                        : '${poi.category.label}  •  $fromShip from the ship',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: BB.blue, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  Text(poi.description, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15)),
                  Center(
                    child: TextButton.icon(
                      onPressed: () => s.voice.speak('${poi.description} ${poi.facts}'),
                      icon: const Icon(Icons.volume_up),
                      label: const Text('Listen'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 54,
                    child: FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: BB.blue),
                      onPressed: () => openNearby(context, poi.display, excludeId: poi.id),
                      child: const Text('Explore Nearby'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (!poi.isShipTerminal)
                    ReturnToPortButton(color: BB.orange, replace: true, label: 'Return to Cruise Port'),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () {
                      s.nav.stop();
                      goHome(context);
                    },
                    child: const Text('Home', style: TextStyle(fontSize: 16)),
                  ),
                  if (!poi.isApproved) const Center(child: ProvisionalBadge()),
                ]),
              ),
            ]),
          ),
        ]),
    );
  }

  /// Bold photo look (photo themes).
  Widget _buildPhoto(BuildContext context) {
    final s = AppScope.of(context);
    final poi = s.poiById(poiId);
    if (poi == null) return const Scaffold(body: Center(child: Text('Destination not found.')));
    final ship = s.nav.shipTerminal;
    final fromShip = ship == null ? null : s.settings.formatDistance(haversineM(ship.display, poi.display));
    // Arrived is a terminal state (not "active"), so leaving with Back is safe.
    final heroH = (MediaQuery.sizeOf(context).height * 0.40).clamp(240.0, 400.0);
    void home() {
      s.nav.stop();
      goHome(context);
    }

    return Scaffold(
      body: Column(children: [
        const SimulatedBanner(safeTop: true),
        Expanded(
          child: ListView(padding: EdgeInsets.zero, children: [
            SizedBox(
              height: heroH + 44,
              child: Stack(clipBehavior: Clip.none, children: [
                // Full-width hero photo with a rounded bottom edge.
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  height: heroH,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(40)),
                    child: PlaceArt(poi: poi, width: double.infinity, height: heroH, radius: 0, expandable: true),
                  ),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Material(
                      color: Colors.white,
                      shape: const CircleBorder(),
                      elevation: 3,
                      child: IconButton(
                        tooltip: 'Home',
                        onPressed: home,
                        icon: Icon(Icons.home_rounded, color: BB.navy, size: 26),
                      ),
                    ),
                  ),
                ),
                // Big green check badge straddling the photo edge.
                Positioned(
                  left: 0,
                  right: 0,
                  top: heroH - 46,
                  child: Center(
                    child: Container(
                      width: 92,
                      height: 92,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color.lerp(BB.go, Colors.white, 0.25)!, BB.go],
                        ),
                        border: Border.all(color: BB.bg, width: 6),
                        boxShadow: [BoxShadow(color: BB.go.withValues(alpha: 0.45), blurRadius: 16, offset: const Offset(0, 6))],
                      ),
                      child: const Icon(Icons.check_rounded, color: Colors.white, size: 54, semanticLabel: 'Arrived'),
                    ),
                  ),
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text(poi.isShipTerminal ? 'Welcome Back!' : "You've Arrived!",
                    textAlign: TextAlign.center, style: heading(36, color: BB.go)),
                const SizedBox(height: 4),
                Text(poi.name, textAlign: TextAlign.center, style: heading(24)),
                const SizedBox(height: 8),
                Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 6, children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                    decoration: BoxDecoration(gradient: BB.categoryGradient(poi.category), borderRadius: BorderRadius.circular(20)),
                    child: Text(poi.category.label,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13)),
                  ),
                  if (!poi.isShipTerminal && fromShip != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                      decoration: BoxDecoration(color: BB.selectedRow, borderRadius: BorderRadius.circular(20)),
                      child: Text('$fromShip from the ship',
                          style: TextStyle(color: BB.navy, fontWeight: FontWeight.w900, fontSize: 13)),
                    ),
                ]),
                const SizedBox(height: 12),
                Text(poi.description,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16, height: 1.5, fontWeight: FontWeight.w600, color: BB.ink)),
                Center(
                  child: TextButton.icon(
                    onPressed: () => s.voice.speak('${poi.description} ${poi.facts}'),
                    icon: const Icon(Icons.volume_up_rounded),
                    label: const Text('Listen'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 58,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: BB.headerGradient,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [BoxShadow(color: BB.navy.withValues(alpha: 0.35), blurRadius: 12, offset: const Offset(0, 5))],
                    ),
                    child: Material(
                      type: MaterialType.transparency,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () => openNearby(context, poi.display, excludeId: poi.id),
                        child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(Icons.explore_rounded, color: Colors.white),
                          SizedBox(width: 10),
                          Text('Explore Nearby',
                              style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900)),
                        ]),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (!poi.isShipTerminal)
                  ReturnToPortButton(color: BB.orange, replace: true, label: 'Return to Cruise Port'),
                const SizedBox(height: 8),
                TextButton(onPressed: home, child: const Text('Home', style: TextStyle(fontSize: 16))),
                if (!poi.isApproved) const Center(child: ProvisionalBadge()),
              ]),
            ),
          ]),
        ),
      ]),
    );
  }
}
