import 'package:flutter/material.dart';

import '../../../app/app_services.dart';
import '../../../app/nav_actions.dart';
import '../../../app/theme.dart';
import '../../../core/models/poi.dart';
import '../../../shared/art.dart';
import '../../../shared/photos.dart';
import '../../../shared/widgets.dart';

/// 05 Destination Details: image, name + distance, category chip,
/// description, Interesting Facts, View on Map + Navigate.
class DestinationDetailsScreen extends StatelessWidget {
  final String poiId;
  const DestinationDetailsScreen({super.key, required this.poiId});

  @override
  Widget build(BuildContext context) => BB.photo ? _buildPhoto(context) : _buildClassic(context);

  /// v2.0 look as presented to the customer, brighter (classic themes).
  Widget _buildClassic(BuildContext context) {
    final s = AppScope.of(context);
    final poi = s.poiById(poiId);
    if (poi == null) {
      return Scaffold(appBar: AppBar(flexibleSpace: const HeaderBackground()), body: const Center(child: Text('Destination not found.')));
    }
    return Scaffold(
      appBar: AppBar(flexibleSpace: const HeaderBackground(), 
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
          final dist = directDistance(context, poi.display, verified: poi.locationVerified);
          final navEnabled = poi.canNavigate && s.bundle.navigationAvailable;
          return Column(children: [
            const SimulatedBanner(),
            Expanded(
              child: ListView(padding: EdgeInsets.zero, children: [
                // Photo in a white frame with a category-coloured glow.
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                  child: Container(
                    decoration: BB.framed(accent: BB.category(poi.category), radius: 24, width: 4),
                    child: PlaceArt(
                        poi: poi,
                        width: double.infinity,
                        height: (MediaQuery.sizeOf(context).height * 0.33).clamp(200.0, 340.0),
                        radius: 20,
                        expandable: true),
                  ),
                ),
                if (Photos.of(poi.id) != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 6, 18, 0),
                    child: Text(Photos.creditLine(poi.id)!,
                        style: const TextStyle(fontSize: 10.5, color: BB.muted), maxLines: 2),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Expanded(
                        child: Text(poi.name,
                            style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800, color: BB.navy)),
                      ),
                      if (dist != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: BB.selectedRow,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: BB.blue.withValues(alpha: 0.5), width: 1.5),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.place, color: BB.blue, size: 17),
                            Text(dist, style: TextStyle(color: BB.blue, fontWeight: FontWeight.w800, fontSize: 14)),
                          ]),
                        ),
                    ]),
                    const SizedBox(height: 8),
                    Wrap(spacing: 8, runSpacing: 6, children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                        decoration: BoxDecoration(
                          gradient: BB.categoryGradient(poi.category),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [BoxShadow(color: BB.category(poi.category).withValues(alpha: 0.35), blurRadius: 6)],
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(BB.categoryIcon(poi.category), size: 15, color: Colors.white),
                          const SizedBox(width: 4),
                          Text(poi.category.label,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                        ]),
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
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BB.option(const Color(0xFFFFA000)).copyWith(color: const Color(0xFFFFF8E1)),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFC93C),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(Icons.lightbulb, color: BB.ink, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('Interesting Facts',
                                  style: TextStyle(color: BB.navy, fontWeight: FontWeight.w900, fontSize: 16)),
                              const SizedBox(height: 4),
                              Text(poi.facts, style: const TextStyle(color: BB.ink, fontSize: 14.5, height: 1.4)),
                            ]),
                          ),
                        ]),
                      ),
                    ],
                    if (poi.accessNotes.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(poi.accessNotes, style: const TextStyle(color: BB.muted, fontSize: 13)),
                    ],
                    if (!poi.canNavigate) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BB.option(const Color(0xFFFFB74D)).copyWith(color: const Color(0xFFFFF3E0)),
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

  /// Bold photo look (photo themes).
  Widget _buildPhoto(BuildContext context) {
    final s = AppScope.of(context);
    final poi = s.poiById(poiId);
    if (poi == null) {
      return Scaffold(appBar: AppBar(flexibleSpace: const HeaderBackground()), body: const Center(child: Text('Destination not found.')));
    }
    Widget roundBtn({required String tooltip, required IconData icon, required VoidCallback onTap, Color? color}) =>
        Padding(
          padding: const EdgeInsets.all(6),
          child: Material(
            color: Colors.white,
            shape: const CircleBorder(),
            elevation: 3,
            child: IconButton(tooltip: tooltip, icon: Icon(icon, color: color ?? BB.navy), onPressed: onTap),
          ),
        );
    final heroH = (MediaQuery.sizeOf(context).height * 0.42).clamp(250.0, 420.0);
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: roundBtn(tooltip: 'Back', icon: Icons.arrow_back_rounded, onTap: () => Navigator.of(context).maybePop()),
        actions: [
          ListenableBuilder(
            listenable: s.settings,
            builder: (context, _) => roundBtn(
              tooltip: s.settings.isFavorite(poi.id) ? 'Remove from saved' : 'Save',
              icon: s.settings.isFavorite(poi.id) ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              color: const Color(0xFFE8344F),
              onTap: () => s.settings.toggleFavorite(poi.id),
            ),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([s.location, s.settings]),
        builder: (context, _) {
          final dist = directDistance(context, poi.display, verified: poi.locationVerified);
          final navEnabled = poi.canNavigate && s.bundle.navigationAvailable;
          return Column(children: [
            Expanded(
              child: ListView(padding: EdgeInsets.zero, children: [
                // Photo hero with the content sheet curving up over it.
                SizedBox(
                  height: heroH,
                  child: Stack(fit: StackFit.expand, children: [
                    PlaceArt(poi: poi, width: double.infinity, height: heroH, radius: 0, expandable: true),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: -1,
                      height: 30,
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: BB.bg,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                          ),
                        ),
                      ),
                    ),
                  ]),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 2, 20, 8),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Wrap(spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                        decoration: BoxDecoration(
                            gradient: BB.categoryGradient(poi.category), borderRadius: BorderRadius.circular(20)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(BB.categoryIcon(poi.category), size: 15, color: Colors.white),
                          const SizedBox(width: 5),
                          Text(poi.category.label,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13)),
                        ]),
                      ),
                      if (dist != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                          decoration: BoxDecoration(color: BB.selectedRow, borderRadius: BorderRadius.circular(20)),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.place_rounded, color: BB.navy, size: 16),
                            const SizedBox(width: 3),
                            Text(dist, style: TextStyle(color: BB.navy, fontWeight: FontWeight.w900, fontSize: 13)),
                          ]),
                        ),
                      if (!poi.isApproved) const ProvisionalBadge(),
                    ]),
                    const SizedBox(height: 10),
                    Text(poi.name, style: heading(30)),
                    if (Photos.of(poi.id) != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(Photos.creditLine(poi.id)!,
                            style: const TextStyle(fontSize: 11, color: BB.muted, fontWeight: FontWeight.w600), maxLines: 2),
                      ),
                    const SizedBox(height: 12),
                    Text(poi.description,
                        style: const TextStyle(fontSize: 16.5, color: BB.ink, height: 1.5, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 44),
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        shape: const StadiumBorder(),
                      ),
                      onPressed: () => s.voice.speak('${poi.name}. ${poi.description} ${poi.facts}'),
                      icon: const Icon(Icons.volume_up_rounded),
                      label: const Text('Listen'),
                    ),
                    if (poi.facts.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Color(0xFFFFF4C7), Color(0xFFFFE7A3)]),
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: const BoxDecoration(color: Color(0xFFFFC93C), shape: BoxShape.circle),
                            child: const Icon(Icons.lightbulb_rounded, color: BB.ink),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('Interesting Facts', style: heading(19, color: BB.ink)),
                              const SizedBox(height: 2),
                              Text(poi.facts,
                                  style: const TextStyle(color: BB.ink, fontSize: 15, height: 1.45, fontWeight: FontWeight.w600)),
                            ]),
                          ),
                        ]),
                      ),
                    ],
                    if (poi.accessNotes.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(poi.accessNotes, style: const TextStyle(color: BB.muted, fontSize: 13)),
                    ],
                    if (!poi.canNavigate) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: const Color(0xFFFFF3E0), borderRadius: BorderRadius.circular(18)),
                        child: Text(
                          'Navigation is not available for this destination'
                          '${poi.notRoutableReason == null ? '.' : ': ${poi.notRoutableReason}'}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                  ]),
                ),
              ]),
            ),
            const SimulatedBanner(),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
                boxShadow: [BoxShadow(color: BB.navy.withValues(alpha: 0.12), blurRadius: 16, offset: const Offset(0, -4))],
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Row(children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => openMapAt(context, poi),
                        icon: const Icon(Icons.map_rounded),
                        label: const Text('View on Map'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: navEnabled ? () => openRoutePreview(context, poi) : null,
                        icon: const Icon(Icons.navigation_rounded),
                        label: const Text('Navigate'),
                      ),
                    ),
                  ]),
                ),
              ),
            ),
          ]);
        },
      ),
    );
  }
}
