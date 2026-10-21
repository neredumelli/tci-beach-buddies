import 'package:flutter/material.dart';

import '../core/models/poi.dart';

/// One predefined theme: a colour palette plus a look.
/// Every theme has the same screens and flows (the v2.0 Visual Functional
/// Walkthrough); [photo] picks the look:
///  - classic (false): the v2.0 screens as presented to the customer, brighter;
///  - photo (true): bold photo-led cards, rounded fonts, curved headers.
class AppPalette {
  final String id;
  final String name;
  final String description;
  final bool photo;

  /// Headers, bottom bar, navigation banner, Home "Return to Cruise Port".
  final Color primary;
  final Color primaryDark;

  /// Lighter end of the header gradient. White bold text on it stays >= 3:1.
  final Color primaryLight;

  /// Secondary buttons, links and list icons. Readable on white (>= 4.5:1).
  final Color accent;

  /// "Start Navigation" / "Navigate" (go actions).
  final Color go;

  /// "Return to Cruise Port" on the Arrival screen.
  final Color port;

  /// Screen background and highlighted list rows.
  final Color bg;
  final Color selected;

  const AppPalette({
    required this.id,
    required this.name,
    required this.description,
    this.photo = false,
    required this.primary,
    required this.primaryDark,
    required this.primaryLight,
    required this.accent,
    required this.go,
    required this.port,
    required this.bg,
    required this.selected,
  });

  LinearGradient get header => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [primaryDark, primary, primaryLight],
        stops: const [0, 0.55, 1],
      );
}

/// The predefined themes a visitor can pick in Settings › Theme.
class AppThemes {
  /// Default: the v2.0 walkthrough's blue headers, made brighter.
  static const islandBlue = AppPalette(
    id: 'island-blue',
    name: 'Classic Blue',
    description: 'The approved v2.0 look, brighter',
    primary: Color(0xFF0B4FC2),
    primaryDark: Color(0xFF073584),
    primaryLight: Color(0xFF1E7FD8),
    accent: Color(0xFF1565D8),
    go: Color(0xFF167A36),
    port: Color(0xFFFF9800),
    bg: Color(0xFFEDF5FF),
    selected: Color(0xFFDCEBFF),
  );

  /// The bold photo look in the classic blue.
  static const islandPhoto = AppPalette(
    id: 'island-photo',
    name: 'Island Photo',
    description: 'Big photos, rounded type',
    photo: true,
    primary: Color(0xFF0B4FC2),
    primaryDark: Color(0xFF073584),
    primaryLight: Color(0xFF1E7FD8),
    accent: Color(0xFF1565D8),
    go: Color(0xFF167A36),
    port: Color(0xFFFF9800),
    bg: Color(0xFFEDF5FF),
    selected: Color(0xFFDCEBFF),
  );

  static const lagoon = AppPalette(
    id: 'lagoon',
    name: 'Turquoise Lagoon',
    description: 'Photo look, clear Caribbean water',
    photo: true,
    primary: Color(0xFF00747F),
    primaryDark: Color(0xFF00525A),
    primaryLight: Color(0xFF00939F),
    accent: Color(0xFF00727D),
    go: Color(0xFF167A36),
    port: Color(0xFFFF9800),
    bg: Color(0xFFE8F8F8),
    selected: Color(0xFFCFF0F1),
  );

  static const sunset = AppPalette(
    id: 'sunset',
    name: 'Sunset Coral',
    description: 'Photo look, warm evening colours',
    photo: true,
    primary: Color(0xFFC63B12),
    primaryDark: Color(0xFF962A0B),
    primaryLight: Color(0xFFE5531F),
    accent: Color(0xFFB83A0E),
    go: Color(0xFF167A36),
    port: Color(0xFF0B4FC2),
    bg: Color(0xFFFFF3EC),
    selected: Color(0xFFFFE1D2),
  );

  static const palm = AppPalette(
    id: 'palm',
    name: 'Palm Green',
    description: 'Classic look, fresh and leafy',
    primary: Color(0xFF17703A),
    primaryDark: Color(0xFF0E4D27),
    primaryLight: Color(0xFF26904B),
    accent: Color(0xFF16733A),
    go: Color(0xFF0B4FC2),
    port: Color(0xFFFF9800),
    bg: Color(0xFFEEF8EF),
    selected: Color(0xFFD6F0DA),
  );

  /// Strongest contrast, for reading in bright sunlight.
  static const highContrast = AppPalette(
    id: 'high-contrast',
    name: 'High Contrast',
    description: 'Classic look, easiest to read in bright sun',
    primary: Color(0xFF0A1E44),
    primaryDark: Color(0xFF050F26),
    primaryLight: Color(0xFF16346B),
    accent: Color(0xFF0040A8),
    go: Color(0xFF0B6B2B),
    port: Color(0xFFFFB300),
    bg: Color(0xFFFFFFFF),
    selected: Color(0xFFE1E8F5),
  );

  static const all = [islandBlue, islandPhoto, lagoon, sunset, palm, highContrast];

  static AppPalette byId(String? id) => all.firstWhere((p) => p.id == id, orElse: () => islandBlue);
}

/// App colours. The theme-dependent ones are getters that read the active
/// [palette]; the rest (status, map and category colours) never change, so
/// meaning stays the same in every theme.
class BB {
  static AppPalette palette = AppThemes.islandBlue;

  /// True when the active theme uses the bold photo look.
  static bool get photo => palette.photo;

  static Color get navy => palette.primary; // headers, bottom bar, nav banner
  static Color get navyDark => palette.primaryDark;
  static Color get primaryLight => palette.primaryLight;
  static Color get blue => palette.accent; // secondary buttons, links
  static Color get go => palette.go; // Start Navigation / Navigate
  static Color get orange => palette.port; // Return to Cruise Port (Arrival)
  static Color get bg => palette.bg;
  static Color get selectedRow => palette.selected;
  static LinearGradient get headerGradient => palette.header;

  static const ocean = Color(0xFF0A7FA0);
  static const teal = Color(0xFF0E8A9E);
  static const lagoon = Color(0xFF7FD3E0);
  static const sea = Color(0xFFA9DCEB);
  static const sand = Color(0xFFF6EBD3);
  static const land = Color(0xFFEAF3DC);
  static const purple = Color(0xFF5B3FA8);
  static const danger = Color(0xFFD32F2F);
  static const success = Color(0xFF1E9E5A);
  static const warning = Color(0xFFB26A00);
  static const route = Color(0xFF1F6BFF);
  static const user = Color(0xFF1A73E8);
  static const ink = Color(0xFF1B2733);
  static const muted = Color(0xFF5B6B7A);
  static const card = Colors.white;

  /// Text/icon colour that reads on [c] (dark on light fills, white on dark).
  static Color onColor(Color c) => c.computeLuminance() > 0.4 ? ink : Colors.white;

  /// Category colour (circles, chips, tile base). White text on it >= 4.5:1.
  static Color category(PoiCategory c) => switch (c) {
        PoiCategory.beach => const Color(0xFF0270B8),
        PoiCategory.attraction => const Color(0xFFC04A00),
        PoiCategory.restaurant => const Color(0xFFC62032),
        PoiCategory.shopping => const Color(0xFF1E7F35),
        PoiCategory.historical => const Color(0xFF6A2FC0),
        PoiCategory.services => const Color(0xFF2F44C2),
      };

  /// Bright top of a category tile gradient.
  static Color categoryLight(PoiCategory c) => switch (c) {
        PoiCategory.beach => const Color(0xFF29B6F6),
        PoiCategory.attraction => const Color(0xFFFFA726),
        PoiCategory.restaurant => const Color(0xFFFF5A5F),
        PoiCategory.shopping => const Color(0xFF5CD16A),
        PoiCategory.historical => const Color(0xFFB07CFF),
        PoiCategory.services => const Color(0xFF6E86FF),
      };

  static LinearGradient categoryGradient(PoiCategory c) => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [categoryLight(c), category(c)],
      );

  static IconData categoryIcon(PoiCategory c) => switch (c) {
        PoiCategory.beach => Icons.beach_access,
        PoiCategory.attraction => Icons.account_balance,
        PoiCategory.restaurant => Icons.restaurant,
        PoiCategory.shopping => Icons.shopping_bag,
        PoiCategory.historical => Icons.castle,
        PoiCategory.services => Icons.local_hospital,
      };
}

/// Heading type (Baloo 2, bundled) - friendly, bold and rounded.
/// Photo themes use Baloo 2; classic themes keep the system font (as v2.0).
TextStyle heading(double size, {Color? color, FontWeight weight = FontWeight.w800, double height = 1.08}) =>
    TextStyle(
        fontFamily: BB.photo ? 'Baloo2' : null,
        fontSize: BB.photo ? size : size * 0.9,
        fontWeight: BB.photo ? weight : FontWeight.w800,
        height: height,
        color: color ?? BB.navy);

/// The theme-coloured header behind every app bar: a gradient with a curved
/// bottom edge and soft "sun and sea" circles.
class HeaderBackground extends StatelessWidget {
  const HeaderBackground({super.key});
  @override
  Widget build(BuildContext context) => !BB.photo
      ? DecoratedBox(decoration: BoxDecoration(gradient: BB.headerGradient))
      : ClipRRect(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
        child: DecoratedBox(
          decoration: BoxDecoration(gradient: BB.headerGradient),
          child: const Stack(fit: StackFit.expand, children: [
            Positioned(right: -30, top: -40, child: _Bubble(size: 130, alpha: 0.14)),
            Positioned(right: 70, bottom: -46, child: _Bubble(size: 90, alpha: 0.10)),
            Positioned(left: -24, bottom: -30, child: _Bubble(size: 70, alpha: 0.10)),
          ]),
        ),
      );
}

class _Bubble extends StatelessWidget {
  final double size;
  final double alpha;
  const _Bubble({required this.size, required this.alpha});
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: alpha)),
      );
}

ThemeData buildTheme() => BB.photo ? _photoTheme() : _classicTheme();

/// v2.0 look, brighter: blue gradient headers, system font, solid tab bar.
ThemeData _classicTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: BB.navy,
    primary: BB.navy,
    secondary: BB.blue,
    surface: Colors.white,
    error: BB.danger,
  );
  final tt = ThemeData(useMaterial3: true, colorScheme: scheme).textTheme;
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: BB.bg,
    appBarTheme: AppBarTheme(
      backgroundColor: BB.navy,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: tt.titleLarge!.copyWith(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800),
      iconTheme: const IconThemeData(color: Colors.white),
      actionsIconTheme: const IconThemeData(color: Colors.white),
    ),
    textTheme: tt.copyWith(
      headlineSmall: tt.headlineSmall!.copyWith(color: BB.navy, fontWeight: FontWeight.w800),
      titleLarge: tt.titleLarge!.copyWith(color: BB.navy, fontWeight: FontWeight.w700),
      titleMedium: tt.titleMedium!.copyWith(color: BB.navy, fontWeight: FontWeight.w700),
      bodyMedium: tt.bodyMedium!.copyWith(color: BB.ink, height: 1.4),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        backgroundColor: BB.go,
        foregroundColor: Colors.white,
        elevation: 2,
        shadowColor: BB.go.withValues(alpha: 0.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: tt.labelLarge!.copyWith(fontSize: 17, fontWeight: FontWeight.w800),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        side: BorderSide(color: BB.blue, width: 1.8),
        foregroundColor: BB.blue,
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: tt.labelLarge!.copyWith(fontSize: 16, fontWeight: FontWeight.w800),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Colors.white : null),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? BB.go : null),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: BB.navy,
      indicatorColor: Colors.white.withValues(alpha: 0.22),
      iconTheme: WidgetStateProperty.all(const IconThemeData(color: Colors.white)),
      labelTextStyle: WidgetStateProperty.all(
          tt.labelMedium!.copyWith(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
    ),
  );
}

/// Bold photo look: rounded fonts, curved headers, pill buttons.
ThemeData _photoTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: BB.navy,
    primary: BB.navy,
    secondary: BB.blue,
    surface: Colors.white,
    error: BB.danger,
  );
  final tt = ThemeData(useMaterial3: true, colorScheme: scheme, fontFamily: 'Nunito').textTheme;
  final pill = RoundedRectangleBorder(borderRadius: BorderRadius.circular(18));
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: 'Nunito',
    scaffoldBackgroundColor: BB.bg,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      foregroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      toolbarHeight: 66,
      titleTextStyle: heading(24, color: Colors.white),
      iconTheme: const IconThemeData(color: Colors.white, size: 26),
      actionsIconTheme: const IconThemeData(color: Colors.white, size: 26),
    ),
    textTheme: tt.copyWith(
      headlineSmall: heading(26),
      titleLarge: heading(22),
      titleMedium: tt.titleMedium!.copyWith(color: BB.navy, fontWeight: FontWeight.w800),
      bodyMedium: tt.bodyMedium!.copyWith(color: BB.ink, height: 1.45, fontWeight: FontWeight.w600),
      bodySmall: tt.bodySmall!.copyWith(fontWeight: FontWeight.w600),
    ),
    listTileTheme: ListTileThemeData(
      titleTextStyle: tt.titleMedium!.copyWith(fontWeight: FontWeight.w800, color: BB.navy),
      subtitleTextStyle: tt.bodyMedium!.copyWith(color: BB.muted, fontWeight: FontWeight.w600),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        backgroundColor: BB.go,
        foregroundColor: Colors.white,
        elevation: 4,
        shadowColor: BB.go.withValues(alpha: 0.55),
        shape: pill,
        textStyle: tt.labelLarge!.copyWith(fontSize: 17.5, fontWeight: FontWeight.w900, letterSpacing: 0.2),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        side: BorderSide(color: BB.blue, width: 2),
        foregroundColor: BB.blue,
        backgroundColor: Colors.white,
        shape: pill,
        textStyle: tt.labelLarge!.copyWith(fontSize: 16.5, fontWeight: FontWeight.w900),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: BB.blue,
        textStyle: tt.labelLarge!.copyWith(fontSize: 15.5, fontWeight: FontWeight.w800),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      titleTextStyle: heading(24),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    ),
    chipTheme: ChipThemeData(
      shape: const StadiumBorder(),
      side: BorderSide.none,
      backgroundColor: Colors.white,
      labelStyle: tt.labelLarge!.copyWith(fontWeight: FontWeight.w800),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Colors.white : null),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? BB.go : null),
    ),
  );
}
