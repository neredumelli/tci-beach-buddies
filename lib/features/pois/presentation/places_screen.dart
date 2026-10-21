import 'package:flutter/material.dart';

import '../../../app/app_services.dart';
import '../../../app/nav_actions.dart';
import '../../../app/shell.dart';
import '../../../app/theme.dart';
import '../../../core/models/poi.dart';
import '../../../shared/widgets.dart';

/// 03 Places / Categories: category rows with destination counts + search.
class PlacesScreen extends StatelessWidget {
  const PlacesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final all = s.destinations;
    return Scaffold(
      appBar: AppBar(flexibleSpace: const HeaderBackground(), 
        title: const Text('Places'),
        leading: IconButton(
          tooltip: 'Home',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => ShellTabs.go(context, ShellTab.home),
        ),
        actions: [
          IconButton(tooltip: 'Search', icon: const Icon(Icons.search), onPressed: () => openSearch(context)),
        ],
      ),
      body: ListenableBuilder(
        listenable: s.settings,
        builder: (context, _) {
          final saved = all.where((p) => s.settings.isFavorite(p.id)).length;
          return ListView(padding: const EdgeInsets.fromLTRB(12, 10, 12, 24), children: [
            const SimulatedBanner(),
            Semantics(
              button: true,
              label: 'Search destinations',
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => openSearch(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFD5DEEA)),
                  ),
                  child: const Row(children: [
                    Expanded(child: Text('Search destinations…', style: TextStyle(color: BB.muted, fontSize: 15))),
                    Icon(Icons.search, color: BB.muted),
                  ]),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              clipBehavior: Clip.antiAlias,
              child: Column(children: [
                for (final c in PoiCategory.values) ...[
                  ListTile(
                    minVerticalPadding: 12,
                    leading: CategoryCircle(category: c),
                    title: Text(c.pluralLabel,
                        style: TextStyle(fontWeight: FontWeight.w700, color: BB.navy, fontSize: 16)),
                    subtitle: Text('${all.where((p) => p.category == c).length} destinations'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => openCategory(context, c),
                  ),
                  if (c != PoiCategory.values.last) const Divider(height: 1, indent: 72),
                ],
              ]),
            ),
            const SizedBox(height: 12),
            Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                leading: const CircleAvatar(backgroundColor: Color(0xFFE91E63), child: Icon(Icons.favorite, color: Colors.white)),
                title: Text('Saved places', style: TextStyle(fontWeight: FontWeight.w700, color: BB.navy)),
                subtitle: Text('$saved saved'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => openSearch(context),
              ),
            ),
          ]);
        },
      ),
    );
  }
}
