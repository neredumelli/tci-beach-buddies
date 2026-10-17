import 'package:flutter/material.dart';

import '../../../app/app_services.dart';
import '../../../app/nav_actions.dart';
import '../../../app/theme.dart';
import '../../../core/geo/geo.dart';
import '../../../shared/widgets.dart';

/// Screen 6 - Arrival. Shown once per navigation session, only after the
/// ArrivalEvaluator confirmed proximity with accurate consecutive fixes.
class ArrivalScreen extends StatelessWidget {
  final String poiId;
  const ArrivalScreen({super.key, required this.poiId});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final poi = s.poiById(poiId);
    if (poi == null) return const Scaffold(body: Center(child: Text('Destination not found.')));
    final nearby = s.destinations.where((p) => p.id != poi.id).toList()
      ..sort((a, b) => haversineM(poi.display, a.display).compareTo(haversineM(poi.display, b.display)));
    return Scaffold(
      body: Column(children: [
        const SimulatedBanner(),
        Expanded(
          child: ListView(padding: EdgeInsets.zero, children: [
            Container(
              height: 230,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF3FB7D6), Color(0xFFBDEBF0)],
                ),
              ),
              child: SafeArea(
                child: Stack(children: [
                  Align(
                    alignment: Alignment.topLeft,
                    child: IconButton(
                      tooltip: 'Close',
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () {
                        s.nav.stop();
                        Navigator.of(context).maybePop();
                      },
                    ),
                  ),
                  Center(
                    child: Container(
                      width: 104,
                      height: 104,
                      decoration: const BoxDecoration(
                        color: BB.teal,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: Color(0x55000000), blurRadius: 10)],
                      ),
                      child: const Icon(Icons.check, color: Colors.white, size: 68, semanticLabel: 'Arrived'),
                    ),
                  ),
                ]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text(poi.isShipTerminal ? 'Welcome back!' : 'You Have Arrived!',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: BB.navy)),
                const SizedBox(height: 4),
                Text(poi.name,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: BB.navy)),
                const SizedBox(height: 4),
                Text(poi.isShipTerminal ? 'You are at the Cruise Center.' : 'Enjoy your time!',
                    textAlign: TextAlign.center, style: const TextStyle(color: BB.muted)),
                const SizedBox(height: 14),
                Text(poi.description, textAlign: TextAlign.center),
                const SizedBox(height: 20),
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: BB.ocean),
                  onPressed: () => openDetails(context, poi),
                  icon: const Icon(Icons.info_outline),
                  label: const Text('View Information'),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () async {
                    final next = await pickDestination(context);
                    if (next != null && context.mounted) {
                      startNavigation(context, next, replace: true); // from latest GPS
                    }
                  },
                  icon: const Icon(Icons.place),
                  label: const Text('Navigate to Another Destination'),
                ),
                if (!poi.isShipTerminal) ...[
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: BB.purple,
                      side: const BorderSide(color: BB.purple, width: 1.6),
                    ),
                    onPressed: () => returnToShip(context, replace: true),
                    icon: const Icon(Icons.directions_boat),
                    label: const Text('Return to Ship'),
                  ),
                ],
                const SizedBox(height: 22),
                if (nearby.isNotEmpty)
                  const Text('Nearby Attractions',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: BB.navy)),
                for (final p in nearby.take(3))
                  Card(
                    margin: const EdgeInsets.only(top: 8),
                    child: ListTile(
                      leading: PoiThumb(poi: p, size: 46, radius: 10),
                      title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text('${s.settings.formatDistance(haversineM(poi.display, p.display))} straight-line'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => openDetails(context, p),
                    ),
                  ),
              ]),
            ),
          ]),
        ),
      ]),
    );
  }
}
