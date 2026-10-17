import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tci_beach_buddies/app/app.dart';
import 'package:tci_beach_buddies/app/shell.dart';
import 'package:tci_beach_buddies/data/offline_bundle.dart';
import 'package:tci_beach_buddies/features/settings/settings_screen.dart';
import 'package:tci_beach_buddies/platform/location/location_source.dart';

import '../support/fakes.dart';

Future<void> boot(WidgetTester t, {String root = syntheticRoot, LocationPermissionState perm = LocationPermissionState.granted}) async {
  SharedPreferences.setMockInitialValues({});
  await t.pumpWidget(TciBeachBuddiesApp(
    bundle: OfflineBundle(DirectoryAssetBundle(root)),
    liveSource: FakeLocationSource(permission: perm),
  ));
  // Bundle files are read with real IO: alternate real-time waits and pumps
  // until the app shell is up.
  for (var i = 0; i < 40 && find.byType(MainShell).evaluate().isEmpty; i++) {
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await t.pump(const Duration(milliseconds: 20));
  }
  expect(find.byType(MainShell), findsOneWidget);
}

void main() {
  testWidgets('Home shows the three primary actions and offline status', (t) async {
    await boot(t);
    expect(find.text('Explore Map'), findsOneWidget);
    expect(find.text('Destinations'), findsWidgets);
    expect(find.text('Return to Ship'), findsWidgets);
    expect(find.text('Offline ready'), findsOneWidget);
  });

  testWidgets('Missing bundle: warning shown and Return to Ship disabled', (t) async {
    await boot(t, root: '/nonexistent');
    expect(find.text('Offline data problem'), findsOneWidget);
    expect(find.textContaining('Navigation is disabled'), findsWidgets);
  });

  testWidgets('Destinations: search filters offline and empty state appears', (t) async {
    await boot(t);
    await t.tap(find.text('Destinations').last);
    await t.pump(const Duration(milliseconds: 300));
    await t.enterText(find.byType(TextField), 'lighthouse');
    await t.pump();
    expect(find.text('Grand Turk Lighthouse'), findsOneWidget);
    await t.enterText(find.byType(TextField), 'zzzz');
    await t.pump();
    expect(find.text('No destinations match your search.'), findsOneWidget);
  });

  testWidgets('Location denied: browsing still works and GPS state is explained', (t) async {
    await boot(t, perm: LocationPermissionState.denied);
    expect(find.text('Location permission off'), findsWidgets);
    await t.tap(find.text('Destinations').last);
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('Distance unknown until GPS is good.'), findsOneWidget);
    await t.enterText(find.byType(TextField), 'governor');
    await t.pump();
    expect(find.text("Governor's Beach"), findsOneWidget);
  });

  testWidgets('Settings shows verified bundle versions and attribution', (t) async {
    await boot(t);
    await t.tap(find.text('More'));
    await t.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('Verified on this launch'), findsOneWidget);
    final settingsList = find.descendant(of: find.byType(SettingsScreen), matching: find.byType(Scrollable)).first;
    await t.scrollUntilVisible(find.text('Map data attribution'), 300, scrollable: settingsList);
    expect(find.text('Map data attribution'), findsOneWidget);
    expect(find.text('© OpenStreetMap contributors'), findsWidgets);
  });
}
