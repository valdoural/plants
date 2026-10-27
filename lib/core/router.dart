import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/diagnose/diagnose_result_screen.dart';
import '../features/diagnose/diagnose_screen.dart';
import '../features/garden/garden_screen.dart';
import '../features/garden/plant_detail_screen.dart';
import '../features/history/history_screen.dart';
import '../features/home/home_screen.dart';
import '../features/identify/identify_result_screen.dart';
import '../features/identify/identify_screen.dart';
import '../features/identify/species_screen.dart';
import '../features/more/more_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/reminders/reminders_screen.dart';
import '../features/settings/settings_screen.dart';
import 'shell.dart';

GoRouter buildRouter({required bool showOnboarding}) => GoRouter(
      initialLocation: showOnboarding ? '/welcome' : '/',
      routes: [
        GoRoute(path: '/welcome', builder: (_, _) => const OnboardingScreen()),
        StatefulShellRoute.indexedStack(
          builder: (_, _, shell) => AppShell(shell: shell),
          branches: [
            StatefulShellBranch(routes: [GoRoute(path: '/', builder: (_, _) => const HomeScreen())]),
            StatefulShellBranch(routes: [GoRoute(path: '/diagnose', builder: (_, _) => const DiagnoseScreen())]),
            StatefulShellBranch(routes: [GoRoute(path: '/garden', builder: (_, _) => const GardenScreen())]),
            StatefulShellBranch(routes: [GoRoute(path: '/more', builder: (_, _) => const MoreScreen())]),
          ],
        ),
        // Экраны поверх нижней навигации.
        GoRoute(path: '/identify', builder: (_, _) => const IdentifyScreen()),
        GoRoute(
          path: '/identify/result',
          builder: (_, s) => IdentifyResultScreen(args: s.extra! as IdentifyResultArgs),
        ),
        GoRoute(path: '/species', builder: (_, s) => SpeciesScreen(args: s.extra! as SpeciesArgs)),
        GoRoute(path: '/plant/:id', builder: (_, s) => PlantDetailScreen(plantId: s.pathParameters['id']!)),
        GoRoute(
          path: '/diagnose/result',
          builder: (_, s) => DiagnoseResultScreen(args: s.extra! as DiagnoseResultArgs),
        ),
        GoRoute(path: '/reminders', builder: (_, _) => const RemindersScreen()),
        GoRoute(path: '/history', builder: (_, _) => const HistoryScreen()),
        GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
      ],
      errorBuilder: (_, s) => Scaffold(body: Center(child: Text('Страница не найдена: ${s.uri}'))),
    );
