import 'package:flutter/material.dart';

import '../core/models/poi.dart';

/// Palette from the v2.0 Visual Functional Walkthrough: blue navigation
/// headers, turquoise sea, colourful category tiles, green "go" actions and an
/// orange "Return to Cruise Port" on Arrival.
class BB {
  static const navy = Color(0xFF0B3C8C); // headers, bottom bar, nav banner
  static const navyDark = Color(0xFF082C68);
  static const blue = Color(0xFF1976D2); // primary blue buttons
  static const ocean = Color(0xFF0A7FA0);
  static const teal = Color(0xFF0E8A9E);
  static const lagoon = Color(0xFF7FD3E0);
  static const sea = Color(0xFFA9DCEB);
  static const sand = Color(0xFFF6EBD3);
  static const land = Color(0xFFEAF3DC);
  static const go = Color(0xFF2E9E46); // Start Navigation / Navigate
  static const orange = Color(0xFFF59E0B); // Return to Cruise Port (Arrival)
  static const purple = Color(0xFF5B3FA8);
  static const danger = Color(0xFFD32F2F);
  static const success = Color(0xFF1E9E5A);
  static const warning = Color(0xFFB26A00);
  static const route = Color(0xFF1F6BFF);
  static const user = Color(0xFF1A73E8);
  static const ink = Color(0xFF1B2733);
  static const muted = Color(0xFF5B6B7A);
  static const card = Colors.white;
  static const bg = Color(0xFFF2F6FB);
  static const selectedRow = Color(0xFFE3EEFC);

  /// Home tile / category colours (screen 02 / 03).
  static Color category(PoiCategory c) => switch (c) {
        PoiCategory.beach => const Color(0xFF1E9BD7),
        PoiCategory.attraction => const Color(0xFFF08A12),
        PoiCategory.restaurant => const Color(0xFFE0353B),
        PoiCategory.shopping => const Color(0xFF43A047),
        PoiCategory.historical => const Color(0xFF7E4FC2),
        PoiCategory.services => const Color(0xFF3949AB),
      };

  static IconData categoryIcon(PoiCategory c) => switch (c) {
        PoiCategory.beach => Icons.beach_access,
        PoiCategory.attraction => Icons.account_balance,
        PoiCategory.restaurant => Icons.restaurant,
        PoiCategory.shopping => Icons.shopping_bag,
        PoiCategory.historical => Icons.castle,
        PoiCategory.services => Icons.local_hospital,
      };
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: BB.navy,
    primary: BB.navy,
    secondary: BB.blue,
    surface: Colors.white,
    error: BB.danger,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: BB.bg,
    appBarTheme: const AppBarTheme(
      backgroundColor: BB.navy,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w700),
      iconTheme: IconThemeData(color: Colors.white),
      actionsIconTheme: IconThemeData(color: Colors.white),
    ),
    textTheme: const TextTheme(
      headlineSmall: TextStyle(color: BB.navy, fontWeight: FontWeight.w800),
      titleLarge: TextStyle(color: BB.navy, fontWeight: FontWeight.w700),
      titleMedium: TextStyle(color: BB.navy, fontWeight: FontWeight.w700),
      bodyMedium: TextStyle(color: BB.ink, height: 1.4),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        backgroundColor: BB.go,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        side: const BorderSide(color: BB.blue, width: 1.6),
        foregroundColor: BB.blue,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: BB.navy,
      indicatorColor: Colors.white.withValues(alpha: 0.18),
      iconTheme: WidgetStateProperty.all(const IconThemeData(color: Colors.white)),
      labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
    ),
  );
}
