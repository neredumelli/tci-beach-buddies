// On-device journey test (run with the phone in AIRPLANE MODE, GPS on):
//   flutter test integration_test/offline_journey_test.dart -d <device>
//
// Uses the REAL bundled assets and the clearly-labelled Demo location source
// to drive Cruise -> Governor's Beach -> Lighthouse -> Return to Ship through
// the real UI, asserting route origins at every step.
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

  testWidgets('offline Cruise -> A -> B -> Ship through the UI (Demo location)', (t) async {
    await t.pumpWidget(const TciBeachBuddiesApp());
    await settle(t, 5);
    expect(find.byType(MainShell), findsOneWidget);
    expect(find.text('Offline ready'), findsOneWidget, reason: 'bundle must verify on device');

    final s = AppScope.of(t.element(find.byType(MainShell)));
    await s.setDemoMode(true);
    await settle(t);
    expect(find.textContaining('SIMULATED'), findsWidgets);

    final demo = s.demoSource!;
    final ship = s.nav.shipTerminal!.approach!;
    final gov = s.poiById('governors-beach')!;
    final lh = s.poiById('grand-turk-lighthouse')!;

    // Cruise -> Governor's Beach via Destinations > Details > Navigate Here.
    demo.placeAt(ship);
    await settle(t);
    await t.tap(find.text('Destinations').last);
    await settle(t);
    await t.enterText(find.byType(TextField).last, 'governor');
    await settle(t, 1);
    await t.tap(find.text(gov.name));
    await settle(t);
    await t.ensureVisible(find.text('Navigate Here'));
    await settle(t, 1);
    await t.tap(find.text('Navigate Here'));
    await settle(t, 3);
    expect(s.nav.phase, NavPhase.navigating);
    expect(haversineM(s.nav.route!.originFix, ship), lessThan(1));
    expect(find.textContaining('to go along route'), findsOneWidget);

    // Arrive at A.
    demo.placeAt(gov.approach!);
    await settle(t, 4);
    expect(find.text('You Have Arrived!'), findsOneWidget);

    // A -> B from the arrival screen; route must start at A.
    await t.ensureVisible(find.text('Navigate to Another Destination'));
    await settle(t, 1);
    await t.tap(find.text('Navigate to Another Destination'));
    await settle(t);
    await t.enterText(find.byType(TextField).last, 'lighthouse');
    await settle(t, 1);
    await t.tap(find.text(lh.name).last);
    await settle(t, 3);
    expect(s.nav.destination!.id, lh.id);
    expect(haversineM(s.nav.route!.originFix, gov.approach!), lessThan(1));

    // Return to Ship from mid-route.
    final r = s.nav.route!;
    demo.placeAt(r.polyline[r.polyline.length ~/ 2]);
    await settle(t);
    await t.tap(find.text('To Ship'));
    await settle(t, 3);
    expect(s.nav.destination!.isShipTerminal, isTrue);
    expect(haversineM(s.nav.route!.originFix, r.polyline[r.polyline.length ~/ 2]), lessThan(1));

    await t.tap(find.text('End Navigation'));
    await settle(t);
    expect(s.nav.phase, NavPhase.idle);
    await s.setDemoMode(false);
    await settle(t);
    expect(find.byType(Scaffold), findsWidgets);
  });
}
