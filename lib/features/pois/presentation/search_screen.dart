import 'package:flutter/material.dart';

import '../../../app/app_services.dart';
import '../../../app/nav_actions.dart';
import '../../../app/theme.dart';
import '../../../core/geo/geo.dart';
import '../../../core/models/poi.dart';
import '../../../shared/widgets.dart';
import '../../navigation/application/location_coordinator.dart';
import '../application/poi_search.dart';

/// 12 Search: offline destination search. In [pickerMode] the chosen place is
/// returned to the caller (change destination while navigating).
class SearchScreen extends StatefulWidget {
  final bool pickerMode;
  const SearchScreen({super.key, this.pickerMode = false});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _q = TextEditingController();
  PoiCategory? _cat;
  bool _savedOnly = false;

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(flexibleSpace: const HeaderBackground(), title: Text(widget.pickerMode ? 'Choose destination' : 'Search')),
      body: ListenableBuilder(
        listenable: Listenable.merge([s.location, s.settings]),
        builder: (context, _) {
          final st = s.location.status;
          final f = s.location.latestFix;
          final GeoPoint? here = ((st == GpsStatus.good || st == GpsStatus.poor) && f != null) ? f.position : null;
          final gps = here != null;
          var results = PoiSearch.search(s.destinations, query: _q.text, category: _cat);
          if (_savedOnly) results = results.where((p) => s.settings.isFavorite(p.id)).toList();
          return Column(children: [
            const SimulatedBanner(),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
              child: TextField(
                controller: _q,
                autofocus: !widget.pickerMode,
                onChanged: (_) => setState(() {}),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Search destinations…',
                  suffixIcon: _q.text.isEmpty
                      ? const Icon(Icons.search)
                      : IconButton(tooltip: 'Clear', icon: const Icon(Icons.clear), onPressed: () => setState(_q.clear)),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            SizedBox(
              height: 48,
              child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 10), children: [
                _chip('All', _cat == null && !_savedOnly, () => setState(() { _cat = null; _savedOnly = false; })),
                _chip('Saved', _savedOnly, () => setState(() => _savedOnly = !_savedOnly)),
                for (final c in PoiCategory.values) _chip(c.tileLabel, _cat == c, () => setState(() => _cat = _cat == c ? null : c)),
              ]),
            ),
            Expanded(
              child: results.isEmpty
                  ? const _Empty()
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                      itemCount: results.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final p = results[i];
                        return PlaceCard(
                          poi: p,
                          distance: (gps && p.locationVerified) ? s.settings.formatDistance(haversineM(here!, p.display)) : null,
                          onTap: () => widget.pickerMode ? Navigator.pop(context, p) : openDetails(context, p),
                        );
                      },
                    ),
            ),
          ]);
        },
      ),
    );
  }

  Widget _chip(String label, bool sel, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.only(right: 6, top: 6, bottom: 6),
        child: ChoiceChip(
          label: Text(label),
          selected: sel,
          showCheckmark: false,
          selectedColor: BB.navy,
          labelStyle: TextStyle(color: sel ? Colors.white : BB.navy, fontWeight: FontWeight.w700),
          onSelected: (_) => onTap(),
        ),
      );
}

class _Empty extends StatelessWidget {
  const _Empty();
  @override
  Widget build(BuildContext context) => const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.search_off, size: 52, color: BB.muted),
            SizedBox(height: 10),
            Text('No destinations match your search.', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            Text('Try another name or category.', style: TextStyle(color: BB.muted)),
          ]),
        ),
      );
}
