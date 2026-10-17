import 'package:flutter/material.dart';

import '../core/models/poi.dart';
import '../features/navigation/presentation/navigation_screen.dart';
import '../features/pois/presentation/destination_details_screen.dart';
import '../features/pois/presentation/destinations_screen.dart';
import 'app_services.dart';

/// Route name used to detect whether the Navigation screen is already shown.
const navigationRouteName = '/navigation';

bool _navigationVisible(BuildContext context) => NavigationScreen.mountedCount > 0;

/// Bring the Navigation screen to the front (without stacking duplicates).
void showNavigationScreen(BuildContext context, {bool replace = false}) {
  final nav = Navigator.of(context);
  if (!replace && _navigationVisible(context)) {
    nav.popUntil((r) => r.settings.name == navigationRouteName);
    return;
  }
  final route = MaterialPageRoute<void>(
    settings: const RouteSettings(name: navigationRouteName),
    builder: (_) => const NavigationScreen(),
  );
  if (replace) {
    nav.pushReplacement(route);
  } else {
    nav.push(route);
  }
}

/// Start navigation to [poi] from the latest live position and show it.
void startNavigation(BuildContext context, Poi poi, {bool replace = false}) {
  final s = AppScope.of(context);
  s.nav.selectDestination(poi);
  showNavigationScreen(context, replace: replace);
}

/// Persistent Return to Ship action (BR-06).
void returnToShip(BuildContext context, {bool replace = false}) {
  final s = AppScope.of(context);
  s.nav.returnToShip();
  showNavigationScreen(context, replace: replace);
}

void openDetails(BuildContext context, Poi poi) {
  Navigator.of(context).push(MaterialPageRoute<void>(
    builder: (_) => DestinationDetailsScreen(poiId: poi.id),
  ));
}

/// Destination picker used for "change destination" / "another destination".
Future<Poi?> pickDestination(BuildContext context) {
  return Navigator.of(context).push<Poi>(MaterialPageRoute<Poi>(
    builder: (_) => const DestinationsScreen(pickerMode: true),
  ));
}
