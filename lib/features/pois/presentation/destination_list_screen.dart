import 'package:flutter/material.dart';

import '../../../app/app_services.dart';
import '../../../app/nav_actions.dart';
import '../../../core/geo/geo.dart';
import '../../../core/models/poi.dart';
import '../../../shared/widgets.dart';
import '../../navigation/application/location_coordinator.dart';

/// 04 Destination List for one category: image cards, name, distance.
class DestinationListScreen extends StatelessWidget {
  final PoiCategory category;
  const DestinationListScreen({super.key, required this.category});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(category.pluralLabel),
        actions: [IconButton(tooltip: 'Search', icon: const Icon(Icons.search), onPressed: () => openSearch(context))],
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([s.location, s.settings]),
        builder: (context, _) {
          final st = s.location.status;
          final f = s.location.latestFix;
          final GeoPoint? here = ((st == GpsStatus.good || st == GpsStatus.poor) && f != null) ? f.position : null;
          final gps = here != null;
          final items = s.destinations.where((p) => p.category == category).toList();
          if (gps) {
            items.sort((a, b) => haversineM(here!, a.display).compareTo(haversineM(here!, b.display)));
          } else {
            items.sort((a, b) => a.name.compareTo(b.name));
          }
          if (items.isEmpty) {
            return const Center(child: Text('No destinations in this category yet.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
            itemCount: items.length + 1,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              if (i == 0) {
                return Column(children: [
                  const SimulatedBanner(),
                  Text(gps ? 'Nearest first · straight-line distance' : 'Distance appears when GPS has your position',
                      style: const TextStyle(fontSize: 12, color: Colors.black54)),
                ]);
              }
              final p = items[i - 1];
              return PlaceCard(
                poi: p,
                distance: gps ? s.settings.formatDistance(haversineM(here!, p.display)) : null,
                onTap: () => openDetails(context, p),
              );
            },
          );
        },
      ),
    );
  }
}
