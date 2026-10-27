import 'package:flutter/material.dart';

/// Дизайн-система Leafy «Витрина»: фото растения — главный элемент экрана,
/// интерфейс — тихий: один фон, одни «чернила», один акцент. Две темы.
@immutable
class LeafyPalette extends ThemeExtension<LeafyPalette> {
  const LeafyPalette({
    required this.bg,
    required this.surface,
    required this.surfaceHigh,
    required this.bar,
    required this.ink,
    required this.inkSecondary,
    required this.accent,
    required this.inkButton,
    required this.onInkButton,
    required this.water,
    required this.alert,
  });

  /// Фон экранов.
  final Color bg;

  /// Плашки и поля поверх фона (шаг тона вместо рамок и теней).
  final Color surface;
  final Color surfaceHigh;

  /// Нижняя панель навигации.
  final Color bar;

  /// Основной текст и второстепенный текст (оба проходят контраст 4.5:1 на bg и surface).
  final Color ink;
  final Color inkSecondary;

  /// Единственный акцент: активная вкладка, статус «сегодня», уверенность распознавания.
  final Color accent;

  /// Главная кнопка — «чернилами»: светлая на тёмной теме, тёмная на светлой.
  final Color inkButton;
  final Color onInkButton;

  /// Смысловые цвета: вода (полив) и «просрочено».
  final Color water;
  final Color alert;

  static const dark = LeafyPalette(
    bg: Color(0xFF0F110F),
    surface: Color(0xFF1C1F1B),
    surfaceHigh: Color(0xFF262A25),
    bar: Color(0xFF181A17),
    ink: Color(0xFFF3F4F0),
    inkSecondary: Color(0xFFA9ADA6),
    accent: Color(0xFFCFE3C8),
    inkButton: Color(0xFFF3F4F0),
    onInkButton: Color(0xFF0F110F),
    water: Color(0xFF8EC5F2),
    alert: Color(0xFFFFB4A8),
  );

  static const light = LeafyPalette(
    bg: Color(0xFFF6F7F4),
    surface: Color(0xFFECEEE9),
    surfaceHigh: Color(0xFFE3E6E0),
    bar: Color(0xFFFFFFFF),
    ink: Color(0xFF121411),
    inkSecondary: Color(0xFF5B6058),
    accent: Color(0xFF3E6B45),
    inkButton: Color(0xFF121411),
    onInkButton: Color(0xFFFFFFFF),
    water: Color(0xFF1F5FA8),
    alert: Color(0xFFB42318),
  );

  @override
  LeafyPalette copyWith() => this;

  @override
  LeafyPalette lerp(ThemeExtension<LeafyPalette>? other, double t) {
    if (other is! LeafyPalette) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return LeafyPalette(
      bg: l(bg, other.bg),
      surface: l(surface, other.surface),
      surfaceHigh: l(surfaceHigh, other.surfaceHigh),
      bar: l(bar, other.bar),
      ink: l(ink, other.ink),
      inkSecondary: l(inkSecondary, other.inkSecondary),
      accent: l(accent, other.accent),
      inkButton: l(inkButton, other.inkButton),
      onInkButton: l(onInkButton, other.onInkButton),
      water: l(water, other.water),
      alert: l(alert, other.alert),
    );
  }
}

extension LeafyThemeX on BuildContext {
  LeafyPalette get palette => Theme.of(this).extension<LeafyPalette>()!;
}

const _font = 'Manrope';

ThemeData buildTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final p = dark ? LeafyPalette.dark : LeafyPalette.light;
  final scheme = ColorScheme(
    brightness: brightness,
    primary: p.inkButton,
    onPrimary: p.onInkButton,
    primaryContainer: p.surfaceHigh,
    onPrimaryContainer: p.ink,
    secondary: p.accent,
    onSecondary: p.bg,
    secondaryContainer: p.surface,
    onSecondaryContainer: p.ink,
    tertiary: p.accent,
    onTertiary: p.bg,
    tertiaryContainer: p.surface,
    onTertiaryContainer: p.ink,
    error: p.alert,
    onError: p.bg,
    surface: p.bg,
    onSurface: p.ink,
    onSurfaceVariant: p.inkSecondary,
    surfaceContainerLowest: p.bg,
    surfaceContainerLow: p.surface,
    surfaceContainer: p.surface,
    surfaceContainerHigh: p.surfaceHigh,
    surfaceContainerHighest: p.surfaceHigh,
    outline: p.inkSecondary,
    outlineVariant: p.surfaceHigh,
    inverseSurface: p.ink,
    onInverseSurface: p.bg,
  );

  final base = ThemeData(colorScheme: scheme, useMaterial3: true, brightness: brightness, fontFamily: _font);
  final text = base.textTheme.apply(bodyColor: p.ink, displayColor: p.ink).copyWith(
        displaySmall: base.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -1, color: p.ink),
        headlineMedium: base.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.8, color: p.ink),
        headlineSmall: base.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.5, color: p.ink),
        titleLarge: base.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700, color: p.ink),
        titleMedium: base.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, color: p.ink),
        bodyLarge: base.textTheme.bodyLarge?.copyWith(fontSize: 17, height: 1.4, color: p.ink),
        bodyMedium: base.textTheme.bodyMedium?.copyWith(fontSize: 15, height: 1.4, color: p.ink),
      );
  const pill = StadiumBorder();

  return base.copyWith(
    extensions: [p],
    textTheme: text,
    scaffoldBackgroundColor: p.bg,
    appBarTheme: AppBarTheme(
      backgroundColor: p.bg,
      foregroundColor: p.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: text.titleLarge?.copyWith(fontSize: 20),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: p.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
    ),
    listTileTheme: ListTileThemeData(iconColor: p.inkSecondary, textColor: p.ink),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: p.inkButton,
        foregroundColor: p.onInkButton,
        disabledBackgroundColor: p.surfaceHigh,
        disabledForegroundColor: p.inkSecondary,
        minimumSize: const Size(48, 54),
        shape: pill,
        textStyle: const TextStyle(fontFamily: _font, fontWeight: FontWeight.w700, fontSize: 17),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: p.ink,
        backgroundColor: p.surface,
        side: BorderSide.none,
        minimumSize: const Size(48, 50),
        shape: pill,
        textStyle: const TextStyle(fontFamily: _font, fontWeight: FontWeight.w600, fontSize: 16),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: p.accent,
        textStyle: const TextStyle(fontFamily: _font, fontWeight: FontWeight.w700, fontSize: 15),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(style: IconButton.styleFrom(foregroundColor: p.ink)),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.surface,
      hintStyle: TextStyle(color: p.inkSecondary),
      labelStyle: TextStyle(color: p.inkSecondary),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: p.surface,
      selectedColor: p.inkButton,
      labelStyle: TextStyle(fontFamily: _font, color: p.ink, fontWeight: FontWeight.w600),
      secondaryLabelStyle: TextStyle(fontFamily: _font, color: p.onInkButton, fontWeight: FontWeight.w700),
      checkmarkColor: p.onInkButton,
      side: BorderSide.none,
      shape: const StadiumBorder(),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: SegmentedButton.styleFrom(
        backgroundColor: p.surface,
        foregroundColor: p.ink,
        selectedBackgroundColor: p.inkButton,
        selectedForegroundColor: p.onInkButton,
        side: BorderSide.none,
        shape: pill,
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? p.onInkButton : p.inkSecondary),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? p.inkButton : p.surfaceHigh),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: p.ink,
      unselectedLabelColor: p.inkSecondary,
      indicatorColor: p.accent,
      dividerColor: Colors.transparent,
      labelStyle: const TextStyle(fontFamily: _font, fontWeight: FontWeight.w700, fontSize: 15),
      unselectedLabelStyle: const TextStyle(fontFamily: _font, fontWeight: FontWeight.w600, fontSize: 15),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      showDragHandle: true,
      backgroundColor: p.bg,
      dragHandleColor: p.surfaceHigh,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    ),
    dialogTheme: DialogThemeData(backgroundColor: p.surface),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: p.inkButton,
      contentTextStyle: TextStyle(fontFamily: _font, color: p.onInkButton, fontWeight: FontWeight.w600),
      actionTextColor: p.onInkButton,
      behavior: SnackBarBehavior.floating,
      // Сообщения бывают в несколько строк — «таблетка» их уродует.
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: p.accent),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: p.inkButton,
      foregroundColor: p.onInkButton,
      elevation: 0,
      shape: const StadiumBorder(),
    ),
    badgeTheme: BadgeThemeData(backgroundColor: p.accent, textColor: p.bg),
    dividerTheme: DividerThemeData(color: p.surfaceHigh, thickness: 1),
  );
}
