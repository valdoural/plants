import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/discover/catalog.dart';
import '../data/plant_problems.dart';
import '../features/tools/tools_screens.dart';
import '../features/diagnose/diagnose_result_screen.dart';
import '../features/diagnose/diagnose_screen.dart';
import '../features/diagnose/problems_screens.dart';
import '../features/discover/discover_screens.dart';
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
import 'responsive.dart';
import 'shell.dart';
import 'theme.dart';

GoRouter buildRouter({required bool showOnboarding}) => GoRouter(
  initialLocation: showOnboarding ? '/welcome' : '/',
  routes: [
    GoRoute(path: '/welcome', builder: (_, _) => const OnboardingScreen()),
    StatefulShellRoute.indexedStack(
      builder: (_, _, shell) => AppShell(shell: shell),
      branches: [
        StatefulShellBranch(
          routes: [GoRoute(path: '/', builder: (_, _) => const HomeScreen())],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/diagnose',
              builder: (_, _) => const _Narrow(child: DiagnoseScreen()),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/garden',
              builder: (_, _) =>
                  const _Narrow(maxWidth: 1200, child: GardenScreen()),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/more',
              builder: (_, _) => const _Narrow(child: MoreScreen()),
            ),
          ],
        ),
      ],
    ),
    // Экраны поверх нижней навигации.
    GoRoute(
      path: '/identify',
      builder: (_, _) => const _Narrow(maxWidth: 640, child: IdentifyScreen()),
    ),
    GoRoute(
      path: '/diagnose/camera',
      builder: (_, _) => const _Narrow(
        maxWidth: 640,
        child: IdentifyScreen(mode: CameraMode.diagnose),
      ),
    ),
    GoRoute(
      path: '/identify/result',
      builder: (_, s) => _Narrow(
        child: IdentifyResultScreen(args: s.extra! as IdentifyResultArgs),
      ),
    ),
    GoRoute(
      path: '/species',
      builder: (_, s) =>
          _Narrow(child: SpeciesScreen(args: s.extra! as SpeciesArgs)),
    ),
    GoRoute(
      path: '/plant/:id',
      builder: (_, s) =>
          _Narrow(child: PlantDetailScreen(plantId: s.pathParameters['id']!)),
    ),
    GoRoute(
      path: '/diagnose/result',
      builder: (_, s) => _Narrow(
        child: DiagnoseResultScreen(args: s.extra! as DiagnoseResultArgs),
      ),
    ),
    GoRoute(
      path: '/reminders',
      builder: (_, _) => const _Narrow(child: RemindersScreen()),
    ),
    GoRoute(
      path: '/history',
      builder: (_, _) => const _Narrow(child: HistoryScreen()),
    ),
    GoRoute(
      path: '/settings',
      builder: (_, _) => const _Narrow(child: SettingsScreen()),
    ),
    GoRoute(
      path: '/search',
      builder: (_, s) =>
          PlantSearchScreen(pick: s.uri.queryParameters['pick'] == '1'),
    ),
    GoRoute(
      path: '/catalog/:kind',
      builder: (_, s) => CatalogScreen(
        kind: CatalogKind.values.byName(s.pathParameters['kind']!),
      ),
    ),
    GoRoute(
      path: '/diagnose/survey',
      builder: (_, s) =>
          CareSurveyScreen(plantId: s.uri.queryParameters['plant']),
    ),
    GoRoute(
      path: '/problems/:part',
      builder: (_, s) => ProblemsPartScreen(
        part: PlantPart.values.byName(s.pathParameters['part']!),
      ),
    ),
    GoRoute(
      path: '/problem/:id',
      builder: (_, s) => ProblemScreen(id: s.pathParameters['id']!),
    ),
    GoRoute(path: '/tools/light', builder: (_, _) => const LightMeterScreen()),
    GoRoute(
      path: '/tools/water',
      builder: (_, _) => const WaterCalculatorScreen(),
    ),
    GoRoute(path: '/tools/repot', builder: (_, _) => const RepotCheckScreen()),
    GoRoute(
      path: '/taxon/:id',
      builder: (_, s) => TaxonScreen(id: int.parse(s.pathParameters['id']!)),
    ),
  ],
  errorBuilder: (_, s) =>
      Scaffold(body: Center(child: Text('Страница не найдена: ${s.uri}'))),
);

/// Экран-«колонка»: на больших экранах не растягивается на всю ширину, по бокам — фон.
class _Narrow extends StatelessWidget {
  const _Narrow({required this.child, this.maxWidth = 860});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    if (context.windowSize.isCompact) return child;
    return ColoredBox(
      color: context.palette.bg,
      child: MaxWidth(maxWidth: maxWidth, child: child),
    );
  }
}
