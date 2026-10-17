import 'package:flutter/material.dart';

import '../../../app/app_services.dart';
import '../../../app/nav_actions.dart';
import '../../../app/theme.dart';
import '../../../core/models/poi.dart';
import '../../../shared/art.dart';
import '../../../shared/widgets.dart';

/// 05 Destination Details: image, name + distance, category chip,
/// description, Interesting Facts, View on Map + Navigate.
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
    return Scaffold(
      appBar: AppBar(
        actions: [
          ListenableBuilder(
            listenable: s.settings,
            builder: (context, _) => IconButton(
              tooltip: s.settings.isFavorite(poi.id) ? 'Remove from saved' : 'Save',
              icon: Icon(s.settings.isFavorite(poi.id) ? Icons.favorite : Icons.favorite_border),
              onPressed: () => s.settings.toggleFavorite(poi.id),
            ),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([s.location, s.settings]),
        builder: (context, _) {
          final dist = directDistance(context, poi.display);
          final navEnabled = poi.canNavigate && s.bundle.navigationAvailable;
          return Column(children: [
            const SimulatedBanner(),
            Expanded(
              child: ListView(padding: EdgeInsets.zero, children: [
                PlaceArt(poi: poi, height: 210, radius: 0),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Expanded(
                        child: Text(poi.name,
                            style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w800, color: BB.navy)),
                      ),
                      if (dist != null) ...[
                        const Icon(Icons.place, color: BB.blue, size: 20),
                        Text(dist, style: const TextStyle(color: BB.blue, fontWeight: FontWeight.w700, fontSize: 15)),
                      ],
                    ]),
                    const SizedBox(height: 8),
                    Wrap(spacing: 8, runSpacing: 6, children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: BB.category(poi.category).withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(8)),
                        child: Text(poi.category.label,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                      ),
                      if (!poi.isApproved) const ProvisionalBadge(),
                    ]),
                    const SizedBox(height: 14),
                    Text(poi.description, style: const TextStyle(fontSize: 16, color: BB.ink, height: 1.45)),
                    TextButton.icon(
                      style: TextButton.styleFrom(padding: EdgeInsets.zero),
                      onPressed: () => s.voice.speak('${poi.name}. ${poi.description} ${poi.facts}'),
                      icon: const Icon(Icons.volume_up),
                      label: const Text('Listen'),
                    ),
                    if (poi.facts.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Icon(Icons.info, color: BB.blue),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            const Text('Interesting Facts',
                                style: TextStyle(color: BB.navy, fontWeight: FontWeight.w800, fontSize: 16)),
                            const SizedBox(height: 4),
                            Text(poi.facts, style: const TextStyle(color: BB.muted, fontSize: 14.5)),
                          ]),
                        ),
                      ]),
                    ],
                    if (poi.accessNotes.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(poi.accessNotes, style: const TextStyle(color: BB.muted, fontSize: 13)),
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
                  ]),
                ),
              ]),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
                child: Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => openMapAt(context, poi),
                      icon: const Icon(Icons.map_outlined),
                      label: const Text('View on Map'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: navEnabled ? () => openRoutePreview(context, poi) : null,
                      icon: const Icon(Icons.navigation),
                      label: const Text('Navigate'),
                    ),
                  ),
                ]),
              ),
            ),
          ]);
        },
      ),
    );
  }
}
