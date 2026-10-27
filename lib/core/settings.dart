import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum RecognitionProviderId {
  plantId(
    title: 'Plant.id (Kindwise)',
    short: 'Plant.id',
    keyUrl: 'https://admin.kindwise.com',
    pros: [
      'Высокая точность, более 30 000 видов',
      'Сразу даёт описание, полив, освещение, ядовитость',
      'Умеет диагностировать болезни растений',
      'Понимает фото целого растения — орган указывать не нужно',
    ],
    cons: [
      'Платный: при регистрации даются бесплатные кредиты на пробу, дальше — оплата за запросы',
    ],
  ),
  plantNet(
    title: 'Pl@ntNet',
    short: 'Pl@ntNet',
    keyUrl: 'https://my.plantnet.org',
    pros: [
      'Бесплатно для личного некоммерческого использования (до 500 распознаваний в день)',
      'Научный проект, хорошо знает дикорастущие и садовые растения',
    ],
    cons: [
      'Возвращает только название вида и фото — без советов по уходу',
      'Нет диагностики болезней (для неё нужен ключ Plant.id)',
      'Точнее, если указать, что на фото: лист, цветок, плод или кора',
      'В браузере: добавьте адрес сайта в my.plantnet.org → Settings → Authorized domains',
    ],
  );

  const RecognitionProviderId({
    required this.title,
    required this.short,
    required this.keyUrl,
    required this.pros,
    required this.cons,
  });

  final String title;
  final String short;
  final String keyUrl;
  final List<String> pros;
  final List<String> cons;
}

class AppSettings {
  const AppSettings({
    this.provider = RecognitionProviderId.plantNet,
    this.plantIdKey = '',
    this.plantNetKey = '',
    this.language = 'ru',
    this.useServerProxy = false,
    this.supabaseUrl = '',
    this.supabaseAnonKey = '',
    this.onboardingDone = false,
    this.notificationsEnabled = true,
    this.reminderHour = 9,
    this.reminderMinute = 0,
    this.themeMode = ThemeMode.system,
  });

  final RecognitionProviderId provider;
  final String plantIdKey;
  final String plantNetKey;

  /// Язык названий и описаний в ответах сервисов распознавания.
  final String language;

  /// Ходить в сервисы распознавания через Supabase Edge Function, где хранятся ключи.
  final bool useServerProxy;
  final String supabaseUrl;
  final String supabaseAnonKey;
  final bool onboardingDone;

  /// Ежедневная сводка задач ухода (Android/iOS).
  final bool notificationsEnabled;
  final int reminderHour;
  final int reminderMinute;

  /// Тема оформления: как в системе, светлая или тёмная.
  final ThemeMode themeMode;

  bool get supabaseConfigured => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  bool hasKeyFor(RecognitionProviderId id) =>
      (useServerProxy && supabaseConfigured) ||
      switch (id) {
        RecognitionProviderId.plantId => plantIdKey.isNotEmpty,
        RecognitionProviderId.plantNet => plantNetKey.isNotEmpty,
      };

  bool get canDiagnose => hasKeyFor(RecognitionProviderId.plantId);

  AppSettings copyWith({
    RecognitionProviderId? provider,
    String? plantIdKey,
    String? plantNetKey,
    String? language,
    bool? useServerProxy,
    String? supabaseUrl,
    String? supabaseAnonKey,
    bool? onboardingDone,
    bool? notificationsEnabled,
    int? reminderHour,
    int? reminderMinute,
    ThemeMode? themeMode,
  }) =>
      AppSettings(
        provider: provider ?? this.provider,
        plantIdKey: plantIdKey ?? this.plantIdKey,
        plantNetKey: plantNetKey ?? this.plantNetKey,
        language: language ?? this.language,
        useServerProxy: useServerProxy ?? this.useServerProxy,
        supabaseUrl: supabaseUrl ?? this.supabaseUrl,
        supabaseAnonKey: supabaseAnonKey ?? this.supabaseAnonKey,
        onboardingDone: onboardingDone ?? this.onboardingDone,
        notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
        reminderHour: reminderHour ?? this.reminderHour,
        reminderMinute: reminderMinute ?? this.reminderMinute,
        themeMode: themeMode ?? this.themeMode,
      );

  static AppSettings load(SharedPreferences p) => AppSettings(
        provider: RecognitionProviderId.values.asNameMap()[p.getString('provider')] ?? RecognitionProviderId.plantNet,
        plantIdKey: p.getString('plantIdKey') ?? '',
        plantNetKey: p.getString('plantNetKey') ?? '',
        language: p.getString('language') ?? 'ru',
        useServerProxy: p.getBool('useServerProxy') ?? false,
        supabaseUrl: p.getString('supabaseUrl') ?? const String.fromEnvironment('SUPABASE_URL'),
        supabaseAnonKey: p.getString('supabaseAnonKey') ?? const String.fromEnvironment('SUPABASE_ANON_KEY'),
        onboardingDone: p.getBool('onboardingDone') ?? false,
        notificationsEnabled: p.getBool('notificationsEnabled') ?? true,
        reminderHour: p.getInt('reminderHour') ?? 9,
        reminderMinute: p.getInt('reminderMinute') ?? 0,
        themeMode: ThemeMode.values.asNameMap()[p.getString('themeMode')] ?? ThemeMode.system,
      );

  Future<void> save(SharedPreferences p) async {
    await p.setString('provider', provider.name);
    await p.setString('plantIdKey', plantIdKey);
    await p.setString('plantNetKey', plantNetKey);
    await p.setString('language', language);
    await p.setBool('useServerProxy', useServerProxy);
    await p.setString('supabaseUrl', supabaseUrl);
    await p.setString('supabaseAnonKey', supabaseAnonKey);
    await p.setBool('onboardingDone', onboardingDone);
    await p.setBool('notificationsEnabled', notificationsEnabled);
    await p.setInt('reminderHour', reminderHour);
    await p.setInt('reminderMinute', reminderMinute);
    await p.setString('themeMode', themeMode.name);
  }
}

final sharedPrefsProvider = Provider<SharedPreferences>((ref) => throw UnimplementedError('override in main'));

/// Инициализирован ли Supabase при запуске (меняется только после перезапуска).
final supabaseReadyProvider = Provider<bool>((ref) => false);

final settingsProvider = NotifierProvider<SettingsController, AppSettings>(SettingsController.new);

class SettingsController extends Notifier<AppSettings> {
  @override
  AppSettings build() => AppSettings.load(ref.read(sharedPrefsProvider));

  Future<void> update(AppSettings Function(AppSettings) change) async {
    state = change(state);
    await state.save(ref.read(sharedPrefsProvider));
  }
}
