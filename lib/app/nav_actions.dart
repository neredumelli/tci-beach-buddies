// Screen-to-screen flow from the v2.0 Visual Functional Walkthrough:
//   01 Splash -> 02 Home -> 03 Places -> 04 List -> 05 Details
//   05 Details -> 06 Map | 07 Route Preview -> 08 Navigation -> 09 Arrival
//   Home / Map / Navigation / Arrival -> 10 Return to Cruise Port -> 07 -> 08
import 'package:flutter/material.dart';

import '../core/geo/geo.dart';
import '../core/models/poi.dart';
import '../features/map/presentation/map_screen.dart';
import '../features/navigation/presentation/navigation_screen.dart';
import '../features/navigation/presentation/route_preview_screen.dart';
import '../features/pois/presentation/destination_details_screen.dart';
import '../features/pois/presentation/destination_list_screen.dart';
import '../features/pois/presentation/nearby_screen.dart';
import '../features/pois/presentation/search_screen.dart';
import 'app_services.dart';

const navigationRouteName = '/navigation';

Future<T?> _push<T>(BuildContext context, Widget page, {bool replace = false, String? name}) {
  final route = MaterialPageRoute<T>(builder: (_) => page, settings: RouteSettings(name: name));
  final nav = Navigator.of(context);
  return replace ? nav.pushReplacement<T, void>(route) : nav.push<T>(route);
}

/// 03 -> 04
void openCategory(BuildContext context, PoiCategory category) =>
    _push<void>(context, DestinationListScreen(category: category));

/// 04 / map marker / search -> 05
void openDetails(BuildContext context, Poi poi) => _push<void>(context, DestinationDetailsScreen(poiId: poi.id));

/// 05 View on Map -> 06 centred on the destination.
void openMapAt(BuildContext context, Poi poi) => _push<void>(context, MapScreen(focusPoiId: poi.id, pushed: true));

/// 05 Navigate -> 07 Route Preview. The route is computed from the LATEST
/// live GPS fix; guidance (and voice) start only on Start Navigation.
void openRoutePreview(BuildContext context, Poi poi, {bool replace = false}) {
  AppScope.of(context).nav.selectDestination(poi);
  _push<void>(context, const RoutePreviewScreen(), replace: replace);
}

/// Any screen -> 10 Return to Cruise Port (a Route Preview for the ship).
void openReturnToShip(BuildContext context, {bool replace = false}) {
  AppScope.of(context).nav.returnToShip();
  _push<void>(context, const RoutePreviewScreen(isReturn: true), replace: replace);
}

/// 07 Start Navigation -> 08 Turn-by-Turn (replaces the preview).
void startNavigation(BuildContext context) {
  AppScope.of(context).nav.startGuidance();
  _push<void>(context, const NavigationScreen(), replace: true, name: navigationRouteName);
}

/// Resume an active navigation from Home/Map.
void showNavigationScreen(BuildContext context) {
  if (NavigationScreen.mountedCount > 0) {
    Navigator.of(context).popUntil((r) => r.settings.name == navigationRouteName || r.isFirst);
    return;
  }
  _push<void>(context, const NavigationScreen(), name: navigationRouteName);
}

/// While navigating: switch destination immediately from the latest fix.
Future<Poi?> pickDestination(BuildContext context) =>
    _push<Poi>(context, const SearchScreen(pickerMode: true));

/// 12 Search
void openSearch(BuildContext context) => _push<void>(context, const SearchScreen());

/// 09 Explore Nearby -> 12 Nearby
void openNearby(BuildContext context, GeoPoint from, {String? excludeId}) =>
    _push<void>(context, NearbyScreen(from: from, excludeId: excludeId));

/// Back to the Home tab from anywhere.
void goHome(BuildContext context) => Navigator.of(context).popUntil((r) => r.isFirst);
