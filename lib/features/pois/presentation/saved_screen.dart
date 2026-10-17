import 'package:flutter/material.dart';

import '../../../app/app_services.dart';
import '../../../app/nav_actions.dart';
import '../../../app/theme.dart';
import '../../../core/models/poi.dart';
import '../../../shared/widgets.dart';

/// Saved favourites (stored locally on the device only).
class SavedScreen extends StatelessWidget {
  const SavedScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Saved'), automaticallyImplyLeading: false),
      body: ListenableBuilder(
        listenable: s.settings,
        builder: (context, _) {
          final saved = s.destinations.where((p) => s.settings.isFavorite(p.id)).toList();
          if (saved.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.favorite_border, size: 52, color: BB.muted),
                  SizedBox(height: 10),
                  Text('No saved places yet', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                  SizedBox(height: 4),
                  Text('Tap the heart on any destination to keep it here.',
                      textAlign: TextAlign.center, style: TextStyle(color: BB.muted)),
                ]),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              for (final Poi p in saved)
                Card(
                  child: ListTile(
                    leading: PoiThumb(poi: p, size: 48, radius: 10),
                    title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(p.category.label),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => openDetails(context, p),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
