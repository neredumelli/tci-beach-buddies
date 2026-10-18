import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tci_beach_buddies/app/app.dart';
import 'package:tci_beach_buddies/app/shell.dart';
import 'package:tci_beach_buddies/data/offline_bundle.dart';
import 'package:tci_beach_buddies/features/navigation/presentation/route_preview_screen.dart';
import 'package:tci_beach_buddies/features/pois/presentation/destination_details_screen.dart';
import 'package:tci_beach_buddies/features/settings/settings_screen.dart';
import 'package:tci_beach_buddies/platform/audio/voice_service.dart';
import 'package:tci_beach_buddies/platform/location/location_source.dart';

import '../support/fakes.dart';

Future<void> boot(WidgetTester t, {String root = syntheticRoot, LocationPermissionState perm = LocationPermissionState.granted, bool pump = true}) async {
  if (pump) {
    SharedPreferences.setMockInitialValues({});
    await t.binding.setSurfaceSize(const Size(420, 900));
    await t.pumpWidget(TciBeachBuddiesApp(
      bundle: OfflineBundle(DirectoryAssetBundle(root)),
      liveSource: FakeLocationSource(permission: perm),
      voice: RecordingVoiceService(),
    ));
  }
  // 01 Splash: bundle files are read with real IO; the splash also has a
  // minimum display time. Alternate real waits and fake-time pumps.
  for (var i = 0; i < 60 && find.byType(MainShell).evaluate().isEmpty; i++) {
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    await t.pump(const Duration(milliseconds: 100));
  }
  expect(find.byType(MainShell), findsOneWidget);
}

Future<void> settle(WidgetTester t, [int frames = 8]) async {
  for (var i = 0; i < frames; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('01 Splash shows Loading, then 02 Home with Return + category tiles', (t) async {
    SharedPreferences.setMockInitialValues({});
    await t.binding.setSurfaceSize(const Size(420, 900));
    await t.pumpWidget(TciBeachBuddiesApp(
      bundle: OfflineBundle(DirectoryAssetBundle(syntheticRoot)),
      liveSource: FakeLocationSource(),
      voice: RecordingVoiceService(),
    ));
    await t.pump();
    // Splash = the approved design image (logo, tagline, "Loading..." baked in) + live ring.
    expect(find.byWidgetPredicate((w) => w is Image && w.image is AssetImage && (w.image as AssetImage).assetName == 'assets/images/splash.jpg'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await boot(t, pump: false);
    expect(find.text('Welcome to\nGrand Turk'), findsOneWidget);
    expect(find.text('RETURN TO CRUISE PORT'), findsOneWidget);
    for (final label in ['Beaches', 'Attractions', 'Restaurants', 'Shopping', 'Historical Sites', 'More']) {
      expect(find.text(label), findsWidgets, reason: label);
    }
    expect(find.text('Offline ready'), findsOneWidget);
    expect(find.text('Places'), findsWidgets); // bottom tab
  });

  testWidgets('Missing bundle: recovery message, navigation disabled', (t) async {
    await boot(t, root: '/nonexistent');
    expect(find.text('Offline data problem'), findsOneWidget);
    expect(find.textContaining('Navigation is disabled'), findsWidgets);
  });

  testWidgets('03 Places lists the six categories with counts; 04 list opens', (t) async {
    await boot(t);
    await t.tap(find.text('Places').last);
    await settle(t);
    for (final c in ['Beaches', 'Attractions', 'Restaurants', 'Shopping & Essentials', 'Historical Sites', 'Emergency & Services']) {
      expect(find.text(c), findsOneWidget, reason: c);
    }
    expect(find.textContaining('destinations'), findsWidgets);
    await t.tap(find.text('Beaches'));
    await settle(t);
    expect(find.text("Governor's Beach"), findsOneWidget);
    expect(find.text('Distance appears when GPS has your position'), findsOneWidget);
  });

  testWidgets('12 Search filters offline and shows empty state', (t) async {
    await boot(t);
    await t.tap(find.byTooltip('Search destinations'));
    await settle(t);
    await t.enterText(find.byType(TextField), 'lighthouse');
    await t.pump();
    expect(find.text('Grand Turk Lighthouse'), findsOneWidget);
    await t.enterText(find.byType(TextField), 'zzzz');
    await t.pump();
    expect(find.text('No destinations match your search.'), findsOneWidget);
  });

  testWidgets('Location denied: browsing works and GPS state is explained', (t) async {
    await boot(t, perm: LocationPermissionState.denied);
    expect(find.text('Location permission off'), findsWidgets);
    await t.tap(find.text('Beaches').first);
    await settle(t);
    expect(find.text("Governor's Beach"), findsOneWidget);
  });

  testWidgets('04 -> 05 Details -> Navigate -> 07 Route Preview; no GPS -> GPS Unavailable dialog', (t) async {
    await boot(t);
    await t.tap(find.text('Beaches').first);
    await settle(t);
    await t.tap(find.text("Governor's Beach"));
    await settle(t);
    expect(t.takeException(), isNull);
    expect(find.byType(DestinationDetailsScreen), findsOneWidget);
    expect(find.text('View on Map'), findsOneWidget);
    expect(find.text('Interesting Facts'), findsOneWidget);
    await t.tap(find.text('Navigate'));
    await settle(t);
    expect(find.byType(RoutePreviewScreen), findsOneWidget);
    expect(find.text('Route Preview'), findsOneWidget);
    expect(find.text('Finding your GPS position…'), findsOneWidget);
    // No fix ever arrives: after the wait, the recovery dialog appears and no
    // route is fabricated.
    await t.pump(const Duration(seconds: 9));
    await settle(t, 4);
    expect(find.text('GPS Unavailable'), findsOneWidget);
    await t.tap(find.text('OK'));
    await settle(t, 4);
    expect(find.text('Retry'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('Home RETURN TO CRUISE PORT opens 10 Return to Cruise Port', (t) async {
    await boot(t);
    await t.tap(find.text('RETURN TO CRUISE PORT'));
    await settle(t);
    expect(find.text('Return to Cruise Port'), findsOneWidget);
    expect(find.text('Cruise Center'), findsOneWidget);
    await t.pump(const Duration(seconds: 9));
    await settle(t, 4);
    expect(t.takeException(), isNull);
  });

  testWidgets('11 Settings: voice, units (miles), offline map, GPS, version, privacy', (t) async {
    await boot(t);
    await t.tap(find.text('Settings').last);
    await settle(t);
    for (final label in ['Voice Guidance', 'Distance Units', 'Miles (mi)', 'Offline Map', 'Available', 'GPS Status', 'App Version', 'Privacy Policy']) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    final list = find.descendant(of: find.byType(SettingsScreen), matching: find.byType(Scrollable)).first;
    await t.scrollUntilVisible(find.text('Map data attribution'), 300, scrollable: list);
    expect(find.text('© OpenStreetMap contributors'), findsWidgets);
  });
}
