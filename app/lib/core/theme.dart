import 'package:flutter/material.dart';

abstract final class OvColors {
  static const cream = Color(0xFFF2EFE7);
  static const night = Color(0xFF0C1F14);
  static const green = Color(0xFF1F4D2E);
  static const gold = Color(0xFFC9A227);
  static const brown = Color(0xFF7A4E2B);
  static const ink = Color(0xFF16241B);
  static const body = Color(0xFF3E4A42);
  static const line = Color(0xFFD8D6CC);
  static const olive = Color(0xFF556B2F);
  static const red = Color(0xFFA4462F);
}

ThemeData buildOvTheme(bool dark) {
  final foreground = dark ? OvColors.cream : OvColors.ink;
  final background = dark ? OvColors.night : OvColors.cream;
  final base = ThemeData(
    useMaterial3: true,
    brightness: dark ? Brightness.dark : Brightness.light,
    fontFamily: 'Inter',
    scaffoldBackgroundColor: background,
    colorScheme: ColorScheme.fromSeed(
      seedColor: OvColors.green,
      brightness: dark ? Brightness.dark : Brightness.light,
      primary: dark ? OvColors.cream : OvColors.green,
      onPrimary: dark ? OvColors.green : OvColors.cream,
      secondary: OvColors.gold,
      surface: dark ? OvColors.ink : Colors.white,
      onSurface: foreground,
      error: dark ? const Color(0xFFE08A70) : OvColors.red,
    ),
  );
  TextStyle heading(double size, FontWeight weight) => TextStyle(
    fontFamily: 'Poppins',
    fontFamilyFallback: const ['Inter'],
    fontSize: size,
    fontWeight: weight,
    height: 1.2,
    color: foreground,
    letterSpacing: size > 28 ? -.8 : -.2,
  );
  return base.copyWith(
    textTheme: base.textTheme.copyWith(
      displayLarge: heading(48, FontWeight.w600),
      displayMedium: heading(40, FontWeight.w600),
      displaySmall: heading(36, FontWeight.w500),
      headlineLarge: heading(32, FontWeight.w500),
      headlineMedium: heading(28, FontWeight.w500),
      headlineSmall: heading(24, FontWeight.w500),
      titleLarge: heading(22, FontWeight.w600),
      titleMedium: heading(17, FontWeight.w600),
      titleSmall: heading(14, FontWeight.w500),
      bodyLarge: TextStyle(
        fontSize: 17,
        height: 1.65,
        color: dark ? OvColors.cream.withValues(alpha: .82) : OvColors.body,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        height: 1.6,
        color: dark ? OvColors.cream.withValues(alpha: .82) : OvColors.body,
      ),
      bodySmall: TextStyle(
        fontSize: 12,
        height: 1.5,
        color: dark ? OvColors.cream.withValues(alpha: .7) : OvColors.body,
      ),
      labelLarge: heading(14, FontWeight.w500),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: background,
      foregroundColor: foreground,
      elevation: 0,
      centerTitle: false,
    ),
    dividerColor: dark ? OvColors.cream.withValues(alpha: .18) : OvColors.line,
    cardTheme: CardThemeData(
      elevation: 0,
      color: dark ? OvColors.ink : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: dark ? OvColors.cream.withValues(alpha: .16) : OvColors.line,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? OvColors.ink : Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 17),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(28),
        borderSide: const BorderSide(color: OvColors.line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(28),
        borderSide: BorderSide(
          color: dark ? OvColors.cream.withValues(alpha: .2) : OvColors.line,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(28),
        borderSide: BorderSide(
          color: dark ? OvColors.gold : OvColors.green,
          width: 1.5,
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 52),
        textStyle: const TextStyle(
          fontFamily: 'Poppins',
          fontWeight: FontWeight.w500,
          fontSize: 15,
        ),
        shape: const StadiumBorder(),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 52),
        textStyle: const TextStyle(
          fontFamily: 'Poppins',
          fontWeight: FontWeight.w500,
          fontSize: 15,
        ),
        side: BorderSide(
          color: dark ? OvColors.cream.withValues(alpha: .4) : OvColors.line,
        ),
        shape: const StadiumBorder(),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      shape: const StadiumBorder(),
      side: BorderSide(
        color: dark ? OvColors.cream.withValues(alpha: .25) : OvColors.line,
      ),
      selectedColor: dark ? OvColors.cream : OvColors.green,
      backgroundColor: dark ? OvColors.ink : Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: OvColors.night,
      contentTextStyle: const TextStyle(color: OvColors.cream),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: OvColors.gold,
      linearTrackColor: OvColors.line,
    ),
    sliderTheme: base.sliderTheme.copyWith(
      activeTrackColor: dark ? OvColors.gold : OvColors.green,
      thumbColor: OvColors.gold,
    ),
  );
}
