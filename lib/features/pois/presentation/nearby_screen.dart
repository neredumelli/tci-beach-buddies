import 'package:flutter/material.dart';

import '../../../app/app_services.dart';
import '../../../app/nav_actions.dart';
import '../../../app/theme.dart';
import '../../../core/geo/geo.dart';
import '../../../core/models/poi.dart';
import '../../../shared/widgets.dart';

/// 12 Nearby Places: categories, then the closest destinations to [from]
/// (usually where the visitor just arrived). Distances are straight-line.
class NearbyScreen extends StatefulWidget {
  final GeoPoint from;
  final String? excludeId;
  const NearbyScreen({super.key, required this.from, this.excludeId});
  @override
  State<NearbyScreen> createState() => _NearbyScreenState();
}

class _NearbyScreenState extends State<NearbyScreen> {
  PoiCategory? _cat;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final list = s.destinations.where((p) => p.id != widget.excludeId && (_cat == null || p.category == _cat)).toList()
      ..sort((a, b) => haversineM(widget.from, a.display).compareTo(haversineM(widget.from, b.display)));
    return Scaffold(
      appBar: AppBar(title: const Text('Nearby Places')),
      body: ListView(padding: const EdgeInsets.fromLTRB(12, 10, 12, 24), children: [
        const SimulatedBanner(),
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 8),
          child: Text('Close to you', style: TextStyle(color: BB.go, fontWeight: FontWeight.w800, fontSize: 15)),
        ),
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          clipBehavior: Clip.antiAlias,
          child: Column(children: [
            for (final c in [PoiCategory.restaurant, PoiCategory.shopping, PoiCategory.attraction, PoiCategory.beach])
              ListTile(
                selected: _cat == c,
                selectedTileColor: BB.selectedRow,
                leading: CategoryCircle(category: c, size: 38),
                title: Text(c == PoiCategory.shopping ? 'Shops' : c.pluralLabel,
                    style: const TextStyle(fontWeight: FontWeight.w700, color: BB.navy)),
                trailing: Icon(_cat == c ? Icons.check : Icons.chevron_right),
                onTap: () => setState(() => _cat = _cat == c ? null : c),
              ),
          ]),
        ),
        const SizedBox(height: 14),
        for (final p in list.take(10)) ...[
          PlaceCard(
            poi: p,
            distance: s.settings.formatDistance(haversineM(widget.from, p.display)),
            onTap: () => openDetails(context, p),
          ),
          const SizedBox(height: 8),
        ],
      ]),
    );
  }
}
