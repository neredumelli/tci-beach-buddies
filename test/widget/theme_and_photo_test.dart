import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tci_beach_buddies/app/app.dart';
import 'package:tci_beach_buddies/app/shell.dart';
import 'package:tci_beach_buddies/app/theme.dart';
import 'package:tci_beach_buddies/data/offline_bundle.dart';
import 'package:tci_beach_buddies/platform/audio/voice_service.dart';
import 'package:tci_beach_buddies/features/pois/presentation/destination_details_screen.dart';
import 'package:tci_beach_buddies/shared/art.dart';
import 'package:tci_beach_buddies/shared/photo_viewer.dart';

import '../support/fakes.dart';

/// The synthetic bundle has no photos; give Governor's Beach the real one.
final _credits = utf8.encode(jsonEncode({
  'governors-beach': {
    'file': 'governors-beach.jpg',
    'title': "Governor's Beach",
    'author': 'Test Author',
    'license': 'CC BY 2.0',
    'url': '',
  },
}));

/// Governor's Beach with two photos, to test rotation and swiping.
final _twoPhotos = utf8.encode(jsonEncode({
  'governors-beach': {
    'file': 'governors-beach.jpg',
    'title': "Governor's Beach",
    'author': 'Test Author',
    'license': 'CC BY 2.0',
    'url': '',
    'more': [
      {'file': 'jacks-shack-2.jpg', 'title': 'Second', 'author': 'TCI Beach Buddies', 'license': '', 'url': '', 'kind': 'supplied'},
    ],
  },
}));

Future<void> _boot(WidgetTester t, {Map<String, Object>? prefs = const {}, List<int>? credits}) async {
  // prefs == null: keep what earlier runs saved (simulates reopening the app).
  if (prefs != null) SharedPreferences.setMockInitialValues(prefs);
  await t.binding.setSurfaceSize(const Size(420, 900));
  await t.pumpWidget(TciBeachBuddiesApp(
    bundle: OfflineBundle(DirectoryAssetBundle(syntheticRoot, overrides: {'assets/photos/credits.json': credits ?? _credits})),
    liveSource: FakeLocationSource(),
    voice: RecordingVoiceService(),
  ));
  for (var i = 0; i < 120 && find.byType(MainShell).evaluate().isEmpty; i++) {
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    await t.pump(const Duration(milliseconds: 100));
  }
  expect(find.byType(MainShell), findsOneWidget);
}

Future<void> _settle(WidgetTester t, [int frames = 8]) async {
  for (var i = 0; i < frames; i++) {
    await t.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  tearDown(() => BB.palette = AppThemes.islandBlue);

  test('every theme keeps white header text and go buttons readable', () {
    double lum(Color c) => c.computeLuminance();
    double ratio(Color a, Color b) {
      final x = lum(a), y = lum(b);
      return (x > y ? x + 0.05 : y + 0.05) / (x > y ? y + 0.05 : x + 0.05);
    }

    for (final p in AppThemes.all) {
      expect(ratio(Colors.white, p.primary), greaterThanOrEqualTo(4.5), reason: '${p.id} header');
      expect(ratio(Colors.white, p.primaryLight), greaterThanOrEqualTo(3.0), reason: '${p.id} header gradient end');
      expect(ratio(p.accent, Colors.white), greaterThanOrEqualTo(4.5), reason: '${p.id} accent text');
      expect(ratio(Colors.white, p.go), greaterThanOrEqualTo(4.5), reason: '${p.id} go button');
      expect(ratio(BB.onColor(p.port), p.port), greaterThanOrEqualTo(4.5), reason: '${p.id} port button');
    }
    expect(AppThemes.all.map((p) => p.id).toSet().length, AppThemes.all.length);
    expect(AppThemes.byId('nope').id, 'island-blue');
  });

  testWidgets('Settings › Theme: picking a theme restyles the app and is remembered', (t) async {
    await _boot(t);
    expect(BB.palette.id, 'island-blue');
    await t.tap(find.text('Settings').last);
    await _settle(t);
    expect(find.text('Classic Blue'), findsOneWidget);
    await t.tap(find.text('Theme'));
    await _settle(t);
    expect(find.text('Choose a theme'), findsOneWidget);
    for (final p in AppThemes.all) {
      expect(find.text(p.name), findsWidgets, reason: p.name);
    }
    await t.tap(find.text('Sunset Coral'));
    await _settle(t);
    expect(BB.palette.id, 'sunset');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('theme'), 'sunset');
    expect(t.takeException(), isNull);
  });

  testWidgets('Chosen theme stays after closing and reopening the app', (t) async {
    await _boot(t);
    await t.tap(find.text('Settings').last);
    await _settle(t);
    await t.tap(find.text('Theme'));
    await _settle(t);
    await t.tap(find.text('Palm Green'));
    await _settle(t);
    expect(BB.palette.id, 'palm');
    // Close the app completely...
    await t.pumpWidget(const SizedBox());
    BB.palette = AppThemes.islandBlue;
    await _settle(t, 2);
    // ...and open it again with the same phone storage.
    await _boot(t, prefs: null);
    expect(BB.palette.id, 'palm');
    await t.tap(find.text('Settings').last);
    await _settle(t);
    expect(find.text('Palm Green'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('A saved theme is applied when the app starts', (t) async {
    await _boot(t, prefs: {'theme': 'palm'});
    expect(BB.palette.id, 'palm');
    expect(t.takeException(), isNull);
  });

  testWidgets('05 Details: tapping the photo opens it full screen; Close returns', (t) async {
    await _boot(t);
    await t.tap(find.text('Beaches').first);
    await _settle(t);
    await t.tap(find.text("Governor's Beach"));
    await _settle(t);
    expect(find.byType(DestinationDetailsScreen), findsOneWidget);
    expect(find.text('Tap to enlarge'), findsOneWidget);
    await t.tap(find.text('Tap to enlarge'));
    await _settle(t);
    expect(find.byType(PhotoViewerScreen), findsOneWidget);
    expect(find.text('Pinch or double-tap to zoom'), findsOneWidget);
    expect(find.textContaining('Test Author'), findsWidgets);
    await t.tap(find.byTooltip('Close photo'));
    await _settle(t);
    expect(find.byType(PhotoViewerScreen), findsNothing);
    expect(find.byType(DestinationDetailsScreen), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('A place with two photos rotates them, and the viewer swipes between them', (t) async {
    await _boot(t, credits: _twoPhotos);
    await t.tap(find.text('Beaches').first);
    await _settle(t);
    await t.tap(find.text("Governor's Beach"));
    await _settle(t);
    final slides = find.byType(PhotoSlides);
    expect(slides, findsOneWidget);
    PhotoSlidesState st() => t.state<PhotoSlidesState>(slides);
    expect(st().index, 0);
    // It moves on by itself after a few seconds...
    for (var i = 0; i < 60 && st().index == 0; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
    expect(st().index, 1);
    await _settle(t);
    // ...and a swipe changes it too.
    await t.fling(slides, const Offset(-300, 0), 1000);
    await _settle(t);
    expect(st().index, 0);

    // Full screen opens on the photo showing, and can be swiped.
    await t.tap(find.text('Tap to enlarge'));
    await _settle(t);
    expect(find.byType(PhotoViewerScreen), findsOneWidget);
    expect(find.text('1 / 2'), findsOneWidget);
    expect(find.textContaining('Test Author'), findsWidgets);
    await t.fling(find.byType(PageView), const Offset(-300, 0), 1000);
    await _settle(t);
    expect(find.text('2 / 2'), findsOneWidget);
    expect(find.text('Photo supplied by TCI Beach Buddies'), findsOneWidget);
    await t.tap(find.byTooltip('Close photo'));
    await _settle(t);
    expect(find.byType(PhotoViewerScreen), findsNothing);
    // Back on Details, the hero shows the photo that was last viewed.
    expect(st().index, 1);
    expect(t.takeException(), isNull);
  });
}
