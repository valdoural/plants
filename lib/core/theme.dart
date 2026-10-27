import 'package:flutter/material.dart';

/// Собственная палитра Leafy: лесной зелёный, тёплый кремовый фон, терракотовый акцент.
abstract final class LeafyColors {
  static const forest = Color(0xFF2F5D50);
  static const moss = Color(0xFF6E8B5E);
  static const cream = Color(0xFFF7F4EC);
  static const terracotta = Color(0xFFC8693F);
  static const ink = Color(0xFF1E2A26);
  static const water = Color(0xFF4F8FBF);
}

ThemeData buildTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: LeafyColors.forest,
    brightness: brightness,
    primary: dark ? const Color(0xFF8FC1A9) : LeafyColors.forest,
    secondary: LeafyColors.moss,
    tertiary: LeafyColors.terracotta,
    primaryContainer: dark ? const Color(0xFF2C4A40) : const Color(0xFFDCE8DF),
    onPrimaryContainer: dark ? const Color(0xFFD4EADF) : LeafyColors.forest,
    secondaryContainer: dark ? const Color(0xFF2E3A2A) : const Color(0xFFE6EBD9),
    onSecondaryContainer: dark ? const Color(0xFFDDE6CF) : const Color(0xFF34432B),
    tertiaryContainer: dark ? const Color(0xFF4A2E22) : const Color(0xFFF6E1D5),
    onTertiaryContainer: dark ? const Color(0xFFF6D9CA) : const Color(0xFF5C2C16),
    surface: dark ? const Color(0xFF151C19) : LeafyColors.cream,
  );
  final base = ThemeData(colorScheme: scheme, useMaterial3: true, brightness: brightness);
  return base.copyWith(
    scaffoldBackgroundColor: scheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: base.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700, color: scheme.onSurface),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: dark ? const Color(0xFF1F2925) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? const Color(0xFF1F2925) : Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
    ),
    chipTheme: base.chipTheme.copyWith(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
    bottomSheetTheme: const BottomSheetThemeData(showDragHandle: true),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
    ),
    bottomAppBarTheme: BottomAppBarThemeData(color: dark ? const Color(0xFF1F2925) : Colors.white),
  );
}
