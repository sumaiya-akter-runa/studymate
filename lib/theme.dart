/// FILE: lib/theme.dart
/// PURPOSE: The whole look of the app lives here.
///
/// Design notes (why it looks the way it does):
///  - Calm teal palette (287A74, 359FA0, 31AAA9, 55A9A0, 8AD6D1, AEEED3).
///    Headers are a teal gradient with white text. No orange or yellow.
///  - Light mode: pale mint background with white cards.
///    Dark mode: near-black with teal accents, easy on the eyes at night.
///  - Cards are separated by hairline borders instead of heavy shadows.
///  - One rounded typeface (Nunito) for everything.
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/cupertino.dart';

class AppColors {
  // Brand: calm teal, taken from the palette
  //   287A74  359FA0  31AAA9  55A9A0  8AD6D1  AEEED3
  static const primary = Color(0xFF287A74);
  static const primaryDark = Color(0xFF1F625D);
  static const primaryLight = Color(0xFF8AD6D1); // brand on dark backgrounds
  static const teal = Color(0xFF359FA0);
  static const tealBright = Color(0xFF31AAA9);
  static const seafoam = Color(0xFF55A9A0);
  static const mint = Color(0xFFAEEED3);

  // Meaning colours: soft, all in the teal family (no orange, no yellow)
  static const accent = Color(0xFF3FAE86); // success / correct (mint green)
  static const warn = Color(0xFF5B8DB8); // dusty sea-blue: blends with teal
  static const danger = Color(0xFFDC6F6F); // soft coral red
  static const violet = Color(0xFF7F8EDB); // soft periwinkle, for variety
  static const pink = Color(0xFFD98AA8); // muted rose, for variety
  static const cyan = Color(0xFF31AAA9);

  // Light mode: very pale mint, so white cards still stand out
  static const bg = Color(0xFFEDF7F4);
  static const text = Color(0xFF14302D);
  static const muted = Color(0xFF688582); // readable on light AND dark surfaces
  static const hairlineLight = Color(0xFFDCEBE7);
  static const borderLight = Color(0xFFC6DDD8);

  // Dark mode: true near-black with a faint teal tint
  static const bgDark = Color(0xFF090E0E);
  static const surfaceDark = Color(0xFF121A1A);
  static const hairlineDark = Color(0xFF1F2D2C);
  static const borderDark = Color(0xFF2B403E);
  static const textDark = Color(0xFFE4F3F0);
}

/// Colours that change with light / dark mode.
/// Use these instead of `Colors.white`, `Colors.grey.shade300` or
/// `AppColors.text` anywhere a screen has a surface background.
extension AppThemeX on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
  Color get surfaceColor => isDark ? AppColors.surfaceDark : Colors.white;
  Color get hairline =>
      isDark ? AppColors.hairlineDark : AppColors.hairlineLight;
  Color get borderColor => isDark ? AppColors.borderDark : AppColors.borderLight;
  Color get textColor => Theme.of(this).colorScheme.onSurface;

  /// Soft fill used for skeletons and quiet panels.
  Color get quietFill =>
      isDark ? const Color(0xFF1B2726) : const Color(0xFFDDEEE9);

  /// Soft coloured shadow in light mode. Dark mode uses a border instead.
  List<BoxShadow> get softShadow => isDark
      ? const []
      : [
    BoxShadow(
      color: AppColors.primaryDark.withValues(alpha: 0.10),
      blurRadius: 22,
      offset: const Offset(0, 8),
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.04),
      blurRadius: 4,
      offset: const Offset(0, 1),
    ),
  ];

  /// Teal brand header (white text sits on top of it in BOTH modes).
  LinearGradient get headerGradient => LinearGradient(
    colors: isDark
        ? const [Color(0xFF0F2927), Color(0xFF1A4F4B)]
        : const [Color(0xFF226F6A), Color(0xFF2E8E8B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

ThemeData buildLightTheme() => _build(Brightness.light);
ThemeData buildDarkTheme() => _build(Brightness.dark);

/// Kept so old code that calls buildTheme() still works.
ThemeData buildTheme() => buildLightTheme();

ThemeData _build(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final surface = dark ? AppColors.surfaceDark : Colors.white;
  final hairline = dark ? AppColors.hairlineDark : AppColors.hairlineLight;
  final border = dark ? AppColors.borderDark : AppColors.borderLight;
  final bg = dark ? AppColors.bgDark : AppColors.bg;
  final fg = dark ? AppColors.textDark : AppColors.text;
  final primary = dark ? AppColors.primaryLight : AppColors.primary;

  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    brightness: brightness,
  ).copyWith(
    primary: primary,
    onPrimary: dark ? const Color(0xFF06201F) : Colors.white,
    surface: surface,
    onSurface: fg,
    outline: border,
    outlineVariant: hairline,
    error: AppColors.danger,
  );

  final base = ThemeData(brightness: brightness, useMaterial3: true);
  final textTheme = GoogleFonts.nunitoTextTheme(base.textTheme)
      .apply(bodyColor: fg, displayColor: fg);

  OutlineInputBorder outline(Color c, [double w = 1]) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: BorderSide(color: c, width: w),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: bg,
    textTheme: textTheme,
    splashFactory: InkSparkle.splashFactory,
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: CupertinoPageTransitionsBuilder(),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
    }),
    dividerTheme: DividerThemeData(color: hairline, space: 1, thickness: 1),
    appBarTheme: AppBarTheme(
      backgroundColor: bg,
      foregroundColor: fg,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleTextStyle:
      textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: dark ? const Color(0xFF1F3331) : const Color(0xFF1B3A37),
      contentTextStyle: textTheme.bodyMedium?.copyWith(color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: hairline),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: surface,
      side: BorderSide(color: border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      labelStyle: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface,
      contentPadding:
      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      hintStyle: const TextStyle(color: AppColors.muted),
      border: outline(border),
      enabledBorder: outline(border),
      focusedBorder: outline(primary, 1.6),
      errorBorder: outline(AppColors.danger),
      focusedErrorBorder: outline(AppColors.danger, 1.6),
    ),
    // Buttons keep the sea-teal background with white text in BOTH modes so
    // the label always has enough contrast.
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        disabledBackgroundColor: border,
        minimumSize: const Size.fromHeight(52),
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primary,
        side: BorderSide(color: border),
        minimumSize: const Size.fromHeight(50),
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: primary,
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        side: BorderSide(color: border),
        selectedBackgroundColor: primary.withValues(alpha: 0.16),
        selectedForegroundColor: primary,
        foregroundColor: AppColors.muted,
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: primary),
    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(horizontal: 16),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      height: 68,
      indicatorColor: primary.withValues(alpha: dark ? 0.26 : 0.16),
      indicatorShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
        color: states.contains(WidgetState.selected)
            ? primary
            : AppColors.muted,
      )),
      labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: states.contains(WidgetState.selected)
            ? primary
            : AppColors.muted,
      )),
    ),
  );
}