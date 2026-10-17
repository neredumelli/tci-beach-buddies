import 'package:flutter/material.dart';

import '../../../app/app_services.dart';
import '../../../app/nav_actions.dart';
import '../../../app/theme.dart';
import '../../../core/geo/geo.dart';
import '../../../core/models/poi.dart';
import '../../../shared/widgets.dart';
import '../../navigation/application/location_coordinator.dart';
import '../application/poi_search.dart';

/// Screen 3 - Destinations: offline search + category filter.
/// In [pickerMode] selecting a destination pops it back to the caller
/// (used for "change destination" while navigating).
class DestinationsScreen extends StatefulWidget {
  final bool pickerMode;
  const DestinationsScreen({super.key, this.pickerMode = false});
  @override
  State<DestinationsScreen> createState() => _DestinationsScreenState();
}

class _DestinationsScreenState extends State<DestinationsScreen> {
  final _query = TextEditingController();
  PoiCategory? _category;
  bool _sortByDistance = false;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final all = s.destinations;
    final cats = [for (final c in PoiCategory.values) if (all.any((p) => p.category == c)) c];
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.pickerMode ? 'Choose next destination' : 'Destinations'),
        automaticallyImplyLeading: widget.pickerMode,
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([s.location, s.settings]),
        builder: (context, _) {
          final st = s.location.status;
          final gpsOk = st == GpsStatus.good;
          final from = gpsOk ? s.location.latestFix?.position : null;
          final results = PoiSearch.search(all,
              query: _query.text, category: _category, sortFrom: _sortByDistance ? from : null);
          return Column(children: [
            if (!widget.pickerMode) const SimulatedBanner(),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
              child: TextField(
                controller: _query,
                onChanged: (_) => setState(() {}),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Search destinations…',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _query.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear search',
                          icon: const Icon(Icons.clear),
                          onPressed: () => setState(_query.clear),
                        ),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                ),
              ),
            ),
            SizedBox(
              height: 52,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                children: [
                  _chip('All (${all.length})', _category == null, () => setState(() => _category = null)),
                  for (final c in cats)
                    _chip(c.pluralLabel, _category == c, () => setState(() => _category = c)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: [
                Expanded(
                  child: Text(
                    gpsOk
                        ? 'Distances are straight-line from you, not walking distance.'
                        : 'Distance unknown until GPS is good.',
                    style: const TextStyle(color: BB.muted, fontSize: 12),
                  ),
                ),
                if (gpsOk)
                  TextButton.icon(
                    onPressed: () => setState(() => _sortByDistance = !_sortByDistance),
                    icon: Icon(_sortByDistance ? Icons.sort_by_alpha : Icons.near_me, size: 18),
                    label: Text(_sortByDistance ? 'A-Z' : 'Nearest'),
                  ),
              ]),
            ),
            Expanded(
              child: results.isEmpty
                  ? _EmptyState(hasData: all.isNotEmpty)
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                      itemCount: results.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final p = results[i];
                        final d = from == null ? null : haversineM(from, p.display);
                        return _PoiTile(
                          poi: p,
                          distance: d == null ? null : s.settings.formatDistance(d),
                          onTap: () {
                            if (widget.pickerMode) {
                              Navigator.of(context).pop(p);
                            } else {
                              openDetails(context, p);
                            }
                          },
                        );
                      },
                    ),
            ),
          ]);
        },
      ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(label),
          selected: selected,
          onSelected: (_) => onTap(),
          selectedColor: BB.teal,
          labelStyle: TextStyle(color: selected ? Colors.white : BB.navy, fontWeight: FontWeight.w700),
          showCheckmark: false,
        ),
      );
}

class _PoiTile extends StatelessWidget {
  final Poi poi;
  final String? distance;
  final VoidCallback onTap;
  const _PoiTile({required this.poi, required this.distance, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${poi.name}, ${poi.category.label}${distance == null ? '' : ', $distance away'}'
          '${poi.canNavigate ? '' : ', browse only'}',
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(children: [
              PoiThumb(poi: poi, size: 60),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(poi.name, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(poi.category.label, style: TextStyle(color: BB.category(poi.category), fontSize: 13)),
                  const SizedBox(height: 2),
                  Row(children: [
                    if (distance != null) ...[
                      const Icon(Icons.place, size: 14, color: BB.muted),
                      Text(distance!, style: const TextStyle(color: BB.muted, fontSize: 13)),
                      const SizedBox(width: 10),
                    ],
                    if (!poi.canNavigate)
                      const Text('Browse only', style: TextStyle(color: BB.warning, fontSize: 12.5, fontWeight: FontWeight.w700)),
                  ]),
                ]),
              ),
              const Icon(Icons.chevron_right, color: BB.muted),
            ]),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool hasData;
  const _EmptyState({required this.hasData});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.search_off, size: 52, color: BB.muted),
          const SizedBox(height: 10),
          Text(hasData ? 'No destinations match your search.' : 'The destination list is not installed.',
              textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          if (hasData) const Text('Try another name or category.', style: TextStyle(color: BB.muted)),
        ]),
      ),
    );
  }
}
