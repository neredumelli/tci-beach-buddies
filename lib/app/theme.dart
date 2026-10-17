import 'package:flutter/material.dart';

import '../core/models/poi.dart';

/// Beach-themed palette taken from the approved mockup board, tuned for
/// outdoor/sunlight contrast (WCAG AA for text on the button fills).
class BB {
  static const navy = Color(0xFF0B2A5B);
  static const ocean = Color(0xFF0A7FA0);
  static const teal = Color(0xFF0E8A9E);
  static const lagoon = Color(0xFF7FD3E0);
  static const sea = Color(0xFFA9DCEB);
  static const sand = Color(0xFFF6EBD3);
  static const land = Color(0xFFF3F0E4);
  static const orange = Color(0xFFE8820C);
  static const purple = Color(0xFF5B3FA8);
  static const danger = Color(0xFFD32F2F);
  static const success = Color(0xFF1E9E5A);
  static const warning = Color(0xFFB26A00);
  static const route = Color(0xFF1F5BFF);
  static const user = Color(0xFF1A73E8);
  static const ink = Color(0xFF1B2733);
  static const muted = Color(0xFF5B6B7A);
  static const card = Colors.white;
  static const bg = Color(0xFFF4F8FB);

  static Color category(PoiCategory c) => switch (c) {
        PoiCategory.beach => const Color(0xFF0E8A9E),
        PoiCategory.landmark => const Color(0xFF6A3FB5),
        PoiCategory.historic => const Color(0xFF9A5B13),
        PoiCategory.dining => const Color(0xFFC6283D),
        PoiCategory.nature => const Color(0xFF2E7D32),
        PoiCategory.services => const Color(0xFF455A64),
      };

  static IconData categoryIcon(PoiCategory c) => switch (c) {
        PoiCategory.beach => Icons.beach_access,
        PoiCategory.landmark => Icons.flag,
        PoiCategory.historic => Icons.account_balance,
        PoiCategory.dining => Icons.restaurant,
        PoiCategory.nature => Icons.park,
        PoiCategory.services => Icons.directions_boat,
      };
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: BB.teal,
    primary: BB.teal,
    secondary: BB.orange,
    surface: Colors.white,
    error: BB.danger,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: BB.bg,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: BB.navy,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(color: BB.navy, fontSize: 19, fontWeight: FontWeight.w700),
    ),
    textTheme: const TextTheme(
      headlineSmall: TextStyle(color: BB.navy, fontWeight: FontWeight.w800),
      titleLarge: TextStyle(color: BB.navy, fontWeight: FontWeight.w700),
      titleMedium: TextStyle(color: BB.ink, fontWeight: FontWeight.w600),
      bodyMedium: TextStyle(color: BB.ink, height: 1.4),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        side: const BorderSide(color: BB.teal, width: 1.6),
        foregroundColor: BB.teal,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    chipTheme: const ChipThemeData(
      labelStyle: TextStyle(fontWeight: FontWeight.w600),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: BB.lagoon.withValues(alpha: 0.45),
      labelTextStyle: WidgetStateProperty.all(const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
    ),
  );
}
