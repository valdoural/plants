import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/router.dart';
import 'core/settings.dart';
import 'core/theme.dart';
import 'data/garden_controller.dart';
import 'data/repository/garden_repository.dart';
import 'data/repository/local_garden_repository.dart';
import 'data/repository/supabase_garden_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ru');
  final prefs = await SharedPreferences.getInstance();
  final settings = AppSettings.load(prefs);

  // Если Supabase настроен — данные в облаке (анонимный вход), иначе — на устройстве.
  GardenRepository repository = LocalGardenRepository(prefs);
  var supabaseReady = false;
  String? startupWarning;
  if (settings.supabaseConfigured) {
    try {
      await Supabase.initialize(url: settings.supabaseUrl, publishableKey: settings.supabaseAnonKey);
      final auth = Supabase.instance.client.auth;
      if (auth.currentSession == null) await auth.signInAnonymously();
      repository = SupabaseGardenRepository(Supabase.instance.client);
      supabaseReady = true;
    } catch (e) {
      startupWarning = 'Не удалось подключиться к Supabase, данные сохраняются на устройстве. ($e)';
    }
  }

  runApp(ProviderScope(
    overrides: [
      sharedPrefsProvider.overrideWithValue(prefs),
      supabaseReadyProvider.overrideWithValue(supabaseReady),
      gardenRepositoryProvider.overrideWithValue(repository),
    ],
    child: LeafyApp(showOnboarding: !settings.onboardingDone, startupWarning: startupWarning),
  ));
}

class LeafyApp extends StatefulWidget {
  const LeafyApp({super.key, required this.showOnboarding, this.startupWarning});

  final bool showOnboarding;
  final String? startupWarning;

  @override
  State<LeafyApp> createState() => _LeafyAppState();
}

class _LeafyAppState extends State<LeafyApp> {
  late final _router = buildRouter(showOnboarding: widget.showOnboarding);
  final _messenger = GlobalKey<ScaffoldMessengerState>();

  @override
  void initState() {
    super.initState();
    if (widget.startupWarning case final w?) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _messenger.currentState?.showSnackBar(SnackBar(content: Text(w), duration: const Duration(seconds: 8))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Leafy',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: _messenger,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      locale: const Locale('ru'),
      supportedLocales: const [Locale('ru'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      routerConfig: _router,
    );
  }
}
