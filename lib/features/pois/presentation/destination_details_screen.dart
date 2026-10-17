import 'package:flutter/material.dart';

import '../../../app/app_services.dart';
import '../../../app/nav_actions.dart';
import '../../../app/theme.dart';
import '../../../core/geo/geo.dart';
import '../../../core/models/poi.dart';
import '../../../shared/widgets.dart';
import '../../navigation/application/location_coordinator.dart';

/// Screen 4 - Destination Details.
class DestinationDetailsScreen extends StatelessWidget {
  final String poiId;
  const DestinationDetailsScreen({super.key, required this.poiId});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final poi = s.poiById(poiId);
    if (poi == null) {
      return Scaffold(appBar: AppBar(), body: const Center(child: Text('Destination not found.')));
    }
    final color = BB.category(poi.category);
    return Scaffold(
      floatingActionButton: const ShipButton(extended: false),
      body: ListenableBuilder(
        listenable: Listenable.merge([s.location, s.settings]),
        builder: (context, _) {
          final st = s.location.status;
          final fix = s.location.latestFix;
          final gpsOk = st == GpsStatus.good || st == GpsStatus.poor;
          final direct = (gpsOk && fix != null) ? haversineM(fix.position, poi.display) : null;
          final navEnabled = poi.canNavigate && s.bundle.navigationAvailable;
          return CustomScrollView(slivers: [
            SliverAppBar(
              pinned: true,
              expandedHeight: 210,
              backgroundColor: color,
              foregroundColor: Colors.white,
              actions: [
                IconButton(
                  tooltip: s.settings.isFavorite(poi.id) ? 'Remove from favourites' : 'Save to favourites',
                  icon: Icon(s.settings.isFavorite(poi.id) ? Icons.favorite : Icons.favorite_border),
                  onPressed: () => s.settings.toggleFavorite(poi.id),
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [color.withValues(alpha: 0.75), color],
                    ),
                  ),
                  child: Center(child: Icon(BB.categoryIcon(poi.category), size: 96, color: Colors.white24)),
                ),
              ),
            ),
            if (s.location.isSimulated) const SliverToBoxAdapter(child: SimulatedBanner()),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 100),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(poi.name, style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 4),
                  Row(children: [
                    Text(poi.category.label, style: TextStyle(color: color, fontWeight: FontWeight.w700)),
                    const SizedBox(width: 10),
                    if (!poi.isApproved) const ProvisionalBadge(),
                  ]),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                    child: Row(children: [
                      _Stat(
                        icon: Icons.place,
                        value: direct == null ? '—' : s.settings.formatDistance(direct),
                        label: direct == null ? 'GPS needed' : 'straight-line',
                      ),
                      if (s.settings.showWalkingEstimate)
                        _Stat(
                          icon: Icons.directions_walk,
                          value: direct == null ? '—' : s.settings.formatWalk(direct * 1.3),
                          label: 'rough estimate',
                        ),
                      _Stat(
                        icon: navEnabled ? Icons.directions_walk : Icons.block,
                        value: navEnabled ? 'Walkable' : 'Browse only',
                        label: navEnabled ? 'route available' : 'no route',
                      ),
                    ]),
                  ),
                  const SizedBox(height: 16),
                  Text(poi.description, style: const TextStyle(fontSize: 15.5)),
                  if (poi.accessNotes.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Icon(Icons.info_outline, size: 18, color: BB.teal),
                      const SizedBox(width: 6),
                      Expanded(child: Text(poi.accessNotes, style: const TextStyle(color: BB.muted))),
                    ]),
                  ],
                  if (!poi.canNavigate) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: const Color(0xFFFFF3E0), borderRadius: BorderRadius.circular(12)),
                      child: Text(
                        'Navigation is not available for this destination'
                        '${poi.notRoutableReason == null ? '.' : ': ${poi.notRoutableReason}'}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: BB.teal),
                    onPressed: navEnabled ? () => startNavigation(context, poi) : null,
                    icon: const Icon(Icons.navigation),
                    label: const Text('Navigate Here'),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () => s.settings.toggleFavorite(poi.id),
                    icon: Icon(s.settings.isFavorite(poi.id) ? Icons.favorite : Icons.favorite_border),
                    label: Text(s.settings.isFavorite(poi.id) ? 'Saved to Favourites' : 'Save to Favourites'),
                  ),
                  const SizedBox(height: 14),
                  Text('Location source: ${poi.locationSource}', style: const TextStyle(color: BB.muted, fontSize: 11.5)),
                ]),
              ),
            ),
          ]);
        },
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  const _Stat({required this.icon, required this.value, required this.label});
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(children: [
        Icon(icon, color: BB.teal),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w800, color: BB.navy)),
        Text(label, style: const TextStyle(fontSize: 11.5, color: BB.muted)),
      ]),
    );
  }
}
