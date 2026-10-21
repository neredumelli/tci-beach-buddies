// Real screenshots of every screen in every theme, for review documents.
//   SCREENSHOT_DIR=build/screens flutter test screenshots/screens_test.dart
// Drives the real app with the real offline bundle and a fake GPS fix at the
// Cruise Center (no Demo banner). Without SCREENSHOT_DIR it only checks the
// flow runs. Not part of the normal `flutter test` run (lives outside test/).
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tci_beach_buddies/app/app.dart';
import 'package:tci_beach_buddies/app/app_services.dart';
import 'package:tci_beach_buddies/app/shell.dart';
import 'package:tci_beach_buddies/app/theme.dart';
import 'package:tci_beach_buddies/data/offline_bundle.dart';
import 'package:tci_beach_buddies/platform/audio/voice_service.dart';

import '../test/support/fakes.dart';

const _root = ValueKey('screenshot-root');
final _outDir = Platform.environment['SCREENSHOT_DIR'];

Future<void> _loadFonts() async {
  // Widget tests draw text with a box font unless real fonts are loaded.
  final candidates = <String>[
    if (Platform.environment['FLUTTER_ROOT'] != null)
      '${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts',
    // flutter_tester lives in <flutter>/bin/cache/artifacts/engine/<platform>/
    '${File(Platform.resolvedExecutable).parent.parent.parent.path}/material_fonts',
  ];
  Directory? dir;
  for (final c in candidates) {
    if (Directory(c).existsSync()) {
      dir = Directory(c);
      break;
    }
  }
  if (dir == null) return;
  final files = dir.listSync().whereType<File>().toList();
  ByteData bytes(File f) => ByteData.sublistView(f.readAsBytesSync());
  final roboto = FontLoader('Roboto');
  for (final f in files.where((f) => RegExp(r'/Roboto-[A-Za-z]+\.ttf$').hasMatch(f.path))) {
    roboto.addFont(Future.value(bytes(f)));
  }
  await roboto.load();
  final icons = files.where((f) => f.path.endsWith('MaterialIcons-Regular.otf'));
  if (icons.isNotEmpty) {
    await (FontLoader('MaterialIcons')..addFont(Future.value(bytes(icons.first)))).load();
  }
}

Future<void> _settle(WidgetTester t, [int frames = 10]) async {
  for (var i = 0; i < frames; i++) {
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await t.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _shot(WidgetTester t, String theme, String name) async {
  if (_outDir == null) return;
  await t.runAsync(() async {
    for (final e in find.byType(Image).evaluate().toList()) {
      final w = e.widget as Image;
      try {
        await precacheImage(w.image, e);
      } catch (_) {}
    }
  });
  await t.pump(const Duration(milliseconds: 50));
  await t.pump(const Duration(milliseconds: 50));
  final ro = t.renderObject<RenderRepaintBoundary>(find.byKey(_root));
  final png = await t.runAsync(() async {
    final img = await ro.toImage(pixelRatio: 2.5);
    final bd = await img.toByteData(format: ui.ImageByteFormat.png);
    return bd!.buffer.asUint8List();
  });
  File('$_outDir/$theme/$name.png')
    ..createSync(recursive: true)
    ..writeAsBytesSync(png!);
}

Future<(FakeLocationSource, AppServices)> _boot(WidgetTester t, String theme) async {
  SharedPreferences.setMockInitialValues({'theme': theme});
  await t.binding.setSurfaceSize(const Size(390, 844));
  final gps = FakeLocationSource();
  await t.pumpWidget(RepaintBoundary(
    key: _root,
    child: TciBeachBuddiesApp(bundle: OfflineBundle(DirectoryAssetBundle('.')), liveSource: gps, voice: RecordingVoiceService()),
  ));
  for (var i = 0; i < 150 && find.byType(MainShell).evaluate().isEmpty; i++) {
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    await t.pump(const Duration(milliseconds: 100));
  }
  expect(find.byType(MainShell), findsOneWidget);
  final s = AppScope.of(t.element(find.byType(MainShell)));
  gps.emit(s.nav.shipTerminal!.approach!);
  await _settle(t);
  return (gps, s);
}

Future<void> _tap(WidgetTester t, Finder f) async {
  await t.ensureVisible(f);
  await _settle(t, 3);
  await t.tap(f);
  await _settle(t);
}

/// Waits (real time) until [done] or ~8 s pass, emitting fresh fixes.
Future<void> _until(WidgetTester t, bool Function() done, {void Function()? tick}) async {
  for (var i = 0; i < 80 && !done(); i++) {
    tick?.call();
    await _settle(t, 1);
  }
}

void main() {
  setUpAll(_loadFonts);
  tearDown(() => BB.palette = AppThemes.islandBlue);

  for (final theme in AppThemes.all) {
    final full = theme.id == AppThemes.islandBlue.id;

    testWidgets('journey screens · ${theme.id}', (t) async {
      final (gps, s) = await _boot(t, theme.id);
      final ship = s.nav.shipTerminal!.approach!;
      await _shot(t, theme.id, '02_home');

      await _tap(t, find.text('Places').last);
      await _shot(t, theme.id, '03_places');
      await _tap(t, find.text('Beaches').first);
      if (full) await _shot(t, theme.id, '04_destination_list');
      await _tap(t, find.text("Governor's Beach").first);
      await _shot(t, theme.id, '05_destination_details');
      if (full && find.text('Tap to enlarge').evaluate().isNotEmpty) {
        await _tap(t, find.text('Tap to enlarge'));
        await _shot(t, theme.id, '05b_photo_full_screen');
        await _tap(t, find.byTooltip('Close photo'));
      }

      await _tap(t, find.text('Navigate'));
      await _until(t, () => s.nav.route != null, tick: () => gps.emit(ship));
      await _settle(t);
      await _shot(t, theme.id, '07_route_preview');

      await _tap(t, find.text('Start Navigation'));
      final r = s.nav.route!;
      final mid = r.polyline[r.polyline.length ~/ 3];
      for (var i = 0; i < 3; i++) {
        gps.emit(mid);
        await _settle(t, 3);
      }
      await _shot(t, theme.id, '08_navigation');

      final dest = s.nav.destination!.approach!;
      await _until(t, () => find.text("You've Arrived!").evaluate().isNotEmpty, tick: () => gps.emit(dest));
      await _settle(t);
      await _shot(t, theme.id, '09_arrival');

      if (full) {
        await _tap(t, find.text('Return to Cruise Port'));
        await _until(t, () => s.nav.route != null && s.nav.destination?.isShipTerminal == true,
            tick: () => gps.emit(dest));
        await _settle(t);
        await _shot(t, theme.id, '10_return_to_cruise_port');
      }
      expect(t.takeException(), isNull);
    });

    testWidgets('map, settings, search · ${theme.id}', (t) async {
      await _boot(t, theme.id);
      await _tap(t, find.text('Map').last);
      await _settle(t, 10);
      await _shot(t, theme.id, '06_offline_map');
      await _tap(t, find.text('Settings').last);
      await _shot(t, theme.id, '11_settings');
      await _tap(t, find.text('Theme'));
      await _shot(t, theme.id, '11b_theme_picker');
      if (full) {
        Navigator.of(t.element(find.text('Choose a theme'))).pop(); // close the sheet
        await _settle(t);
        await t.tap(find.text('Home', skipOffstage: false).last);
        await _settle(t);
        await _tap(t, find.byTooltip('Search destinations'));
        await t.enterText(find.byType(TextField).last, 'beach');
        await _settle(t);
        await _shot(t, theme.id, '12_search');
      }
      expect(t.takeException(), isNull);
    });
  }
}
