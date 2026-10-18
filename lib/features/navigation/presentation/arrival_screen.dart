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
  Widget build(BuildContext context) {
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
                PlaceArt(poi: poi, width: double.infinity, height: (MediaQuery.sizeOf(context).height * 0.40).clamp(240.0, 420.0), radius: 0),
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
                    const Icon(Icons.check_circle, color: BB.go, size: 44, semanticLabel: 'Arrived'),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(poi.isShipTerminal ? 'Welcome Back!' : "You've Arrived!",
                          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: BB.go)),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  Text(poi.name, textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: BB.navy)),
                  Text(
                    poi.isShipTerminal || fromShip == null
                        ? poi.category.label
                        : '${poi.category.label}  •  $fromShip from the ship',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: BB.blue, fontWeight: FontWeight.w600),
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
}
