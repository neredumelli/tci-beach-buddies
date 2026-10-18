// On-device journey through the v2.0 screens (run in AIRPLANE MODE):
//   flutter test integration_test/offline_journey_test.dart -d <device>
// Uses the REAL bundle and the clearly-labelled Demo location source:
// Home -> Beaches -> Governor's Beach -> Navigate -> Route Preview ->
// Start Navigation -> Arrival -> (search) Lighthouse -> Navigate ... -> Return.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tci_beach_buddies/app/app.dart';
import 'package:tci_beach_buddies/app/app_services.dart';
import 'package:tci_beach_buddies/app/shell.dart';
import 'package:tci_beach_buddies/core/geo/geo.dart';
import 'package:tci_beach_buddies/features/navigation/application/navigation_controller.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> settle(WidgetTester t, [int seconds = 2]) async {
    for (var i = 0; i < seconds * 10; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> tapText(WidgetTester t, String text, {bool last = false}) async {
    final f = last ? find.text(text).last : find.text(text).first;
    await t.ensureVisible(f);
    await settle(t, 1);
    await t.tap(f);
    await settle(t);
  }

  testWidgets('offline Cruise -> A -> B -> Return to Cruise Port through the UI', (t) async {
    await t.pumpWidget(const TciBeachBuddiesApp());
    await settle(t, 6);
    expect(find.byType(MainShell), findsOneWidget);
    expect(find.text('Offline ready'), findsOneWidget, reason: 'bundle must verify on device');
    expect(find.text('RETURN TO CRUISE PORT'), findsOneWidget);

    final s = AppScope.of(t.element(find.byType(MainShell)));
    await s.setDemoMode(true);
    await settle(t);
    final demo = s.demoSource!;
    final ship = s.nav.shipTerminal!.approach!;
    final gov = s.poiById('governors-beach')!;
    final lh = s.poiById('grand-turk-lighthouse')!;

    // 02 Home -> 04 Beaches -> 05 Governor's Beach -> 07 Preview -> 08 Navigation
    demo.placeAt(ship);
    await settle(t);
    await tapText(t, 'Beaches');
    await tapText(t, gov.name);
    await tapText(t, 'Navigate');
    await settle(t, 2);
    expect(find.text('Route Preview'), findsOneWidget);
    expect(s.nav.phase, NavPhase.navigating);
    expect(haversineM(s.nav.route!.originFix, ship), lessThan(1));
    await tapText(t, 'Start Navigation');
    expect(s.nav.guidanceStarted, isTrue);
    expect(find.textContaining('ETA'), findsOneWidget);

    // 09 Arrival at A
    demo.placeAt(gov.approach!);
    await settle(t, 4);
    expect(find.text("You've Arrived!"), findsOneWidget);
    expect(find.text('Explore Nearby'), findsOneWidget);

    // A -> B: Home, search Lighthouse, Navigate. Route must start at A.
    await tapText(t, 'Home', last: true);
    // Home keeps its scroll position (it was scrolled to reach Beaches).
    await t.ensureVisible(find.byTooltip('Search destinations'));
    await settle(t, 1);
    await t.tap(find.byTooltip('Search destinations'));
    await settle(t);
    await t.enterText(find.byType(TextField).last, 'lighthouse');
    await settle(t, 1);
    await tapText(t, lh.name, last: true);
    await tapText(t, 'Navigate');
    await settle(t, 2);
    expect(s.nav.destination!.id, lh.id);
    expect(haversineM(s.nav.route!.originFix, gov.approach!), lessThan(1));
    await tapText(t, 'Start Navigation');

    // 10 Return to Cruise Port from mid-route.
    final r = s.nav.route!;
    final mid = r.polyline[r.polyline.length ~/ 2];
    demo.placeAt(mid);
    await settle(t);
    await tapText(t, 'Return');
    await settle(t, 2);
    expect(find.text('Return to Cruise Port'), findsOneWidget);
    expect(s.nav.destination!.isShipTerminal, isTrue);
    expect(haversineM(s.nav.route!.originFix, mid), lessThan(1));
    await tapText(t, 'Start Navigation');
    await tapText(t, 'Stop');
    expect(s.nav.phase, NavPhase.idle);
    await s.setDemoMode(false);
    await settle(t);
    expect(find.byType(Scaffold), findsWidgets);
  });
}
