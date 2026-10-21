import 'package:flutter/material.dart';

import '../../../app/app_services.dart';
import '../../../app/nav_actions.dart';
import '../../../app/shell.dart';
import '../../../app/theme.dart';
import '../../../core/models/poi.dart';
import '../../../shared/photos.dart';
import '../../../shared/widgets.dart';

/// 03 Places / Categories: category rows with destination counts + search.
class PlacesScreen extends StatelessWidget {
  const PlacesScreen({super.key});

  @override
  Widget build(BuildContext context) => BB.photo ? _buildPhoto(context) : _buildClassic(context);

  /// v2.0 look as presented to the customer, brighter (classic themes).
  Widget _buildClassic(BuildContext context) {
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
                  decoration: BB.option(BB.navy, radius: 16),
                  child: Row(children: [
                    const Expanded(
                        child: Text('Search destinations…',
                            style: TextStyle(color: BB.muted, fontSize: 15, fontWeight: FontWeight.w600))),
                    Icon(Icons.search, color: BB.navy),
                  ]),
                ),
              ),
            ),
            const SizedBox(height: 10),
            for (final cat in PoiCategory.values) ...[
              _ClassicCategoryRow(
                category: cat,
                count: all.where((p) => p.category == cat).length,
                photo: _photoFor(all, cat),
                onTap: () => openCategory(context, cat),
              ),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 4),
            Container(
              decoration: BB.option(const Color(0xFFE91E63)),
              child: Material(
              type: MaterialType.transparency,
              child: ListTile(
                leading: const CircleAvatar(backgroundColor: Color(0xFFE91E63), child: Icon(Icons.favorite, color: Colors.white)),
                title: Text('Saved places', style: TextStyle(fontWeight: FontWeight.w700, color: BB.navy)),
                subtitle: Text('$saved saved'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => openSearch(context),
              ),
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
                borderRadius: BorderRadius.circular(20),
                onTap: () => openSearch(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: BB.navy.withValues(alpha: 0.14), blurRadius: 12, offset: const Offset(0, 4))],
                  ),
                  child: Row(children: [
                    Icon(Icons.search_rounded, color: BB.navy),
                    const SizedBox(width: 10),
                    const Expanded(
                        child: Text('Search destinations…',
                            style: TextStyle(color: BB.muted, fontSize: 15.5, fontWeight: FontWeight.w700))),
                  ]),
                ),
              ),
            ),
            const SizedBox(height: 10),
            for (final c in PoiCategory.values) ...[
              _CategoryCard(
                category: c,
                count: all.where((p) => p.category == c).length,
                photo: _photoFor(all, c),
                onTap: () => openCategory(context, c),
              ),
              const SizedBox(height: 12),
            ],
            Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              elevation: 2,
              shadowColor: const Color(0x330B2F44),
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

/// First licensed photo among a category's destinations (never an illustration).
String? _photoFor(List<Poi> all, PoiCategory c) {
  for (final p in all.where((p) => p.category == c)) {
    final ph = Photos.of(p.id);
    if (ph != null && !ph.isIllustration) return ph.asset;
  }
  return null;
}

/// 03 Places: one bold card per category - category gradient, icon, count,
/// with a photo of one of its places on the right.
class _CategoryCard extends StatelessWidget {
  final PoiCategory category;
  final int count;
  final String? photo;
  final VoidCallback onTap;
  const _CategoryCard({required this.category, required this.count, required this.photo, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = BB.category(category);
    final radius = BorderRadius.circular(24);
    return Semantics(
      button: true,
      label: '${category.pluralLabel}, $count destinations',
      excludeSemantics: true,
      child: Container(
        height: 96,
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: [BoxShadow(color: c.withValues(alpha: 0.35), blurRadius: 12, offset: const Offset(0, 5))],
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: Stack(fit: StackFit.expand, children: [
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [c, BB.categoryLight(category)]),
              ),
            ),
            if (photo != null)
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                width: 150,
                child: ShaderMask(
                  shaderCallback: (r) => const LinearGradient(
                    colors: [Color(0x00000000), Color(0xFF000000)],
                    stops: [0, 0.45],
                  ).createShader(r),
                  blendMode: BlendMode.dstIn,
                  child: Image.asset(photo!, fit: BoxFit.cover, excludeFromSemantics: true),
                ),
              ),
            Positioned(
              right: -18,
              bottom: -26,
              child: Icon(BB.categoryIcon(category), size: 96, color: Colors.white.withValues(alpha: 0.13)),
            ),
            Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
                  child: Row(children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      child: Icon(BB.categoryIcon(category), color: c, size: 30),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(category.pluralLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: heading(22, color: Colors.white)
                                .copyWith(shadows: const [Shadow(color: Color(0x66000000), blurRadius: 4)])),
                        Container(
                          margin: const EdgeInsets.only(top: 2),
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                          child: Text('$count destinations',
                              style: TextStyle(color: c, fontSize: 12.5, fontWeight: FontWeight.w900)),
                        ),
                      ]),
                    ),
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.9), shape: BoxShape.circle),
                      child: Icon(Icons.chevron_right_rounded, color: c),
                    ),
                  ]),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Classic Places row: bordered option card in the category colour, ringed
/// icon, count pill and a framed photo of one of its places.
class _ClassicCategoryRow extends StatelessWidget {
  final PoiCategory category;
  final int count;
  final String? photo;
  final VoidCallback onTap;
  const _ClassicCategoryRow({required this.category, required this.count, required this.photo, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = BB.category(category);
    return Container(
      decoration: BB.option(c),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  border: Border.all(color: c.withValues(alpha: 0.5), width: 2),
                ),
                child: CategoryCircle(category: category, size: 46),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(category.pluralLabel, style: TextStyle(fontWeight: FontWeight.w900, color: BB.navy, fontSize: 16.5)),
                  const SizedBox(height: 3),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                    decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
                    child: Text('$count destinations',
                        style: TextStyle(color: c, fontSize: 12.5, fontWeight: FontWeight.w800)),
                  ),
                ]),
              ),
              if (photo != null)
                Container(
                  decoration: BB.framed(accent: c, radius: 12, width: 2.5),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(9.5),
                    child: Image.asset(photo!, width: 64, height: 48, fit: BoxFit.cover, excludeFromSemantics: true),
                  ),
                ),
              const SizedBox(width: 6),
              Icon(Icons.chevron_right, color: c),
            ]),
          ),
        ),
      ),
    );
  }
}
