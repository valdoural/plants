// Проверка вёрстки: каждый экран на ширинах 320–1440 и с увеличенным системным шрифтом
// не должен давать переполнений (текст и блоки не вылезают за рамки).
// Сеть подменена: iNaturalist и Open-Meteo отвечают сохранёнными ответами.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:leafy/core/router.dart';
import 'package:leafy/core/settings.dart';
import 'package:leafy/core/theme.dart';
import 'package:leafy/data/discover/discover_providers.dart';
import 'package:leafy/data/discover/inat.dart';
import 'package:leafy/data/discover/place_weather.dart';
import 'package:leafy/data/garden_controller.dart';
import 'package:leafy/data/models.dart';
import 'package:leafy/data/repository/local_garden_repository.dart';
import 'package:leafy/features/diagnose/diagnose_result_screen.dart';
import 'package:leafy/features/identify/identify_result_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _routes = [
  '/',
  '/garden',
  '/diagnose',
  '/more',
  '/plant/a',
  '/search',
  '/catalog/houseplants',
  '/catalog/allergens',
  '/taxon/122521',
  '/tools/light',
  '/tools/water',
  '/tools/repot',
  '/diagnose/survey',
  '/problems/leaves',
  '/problem/root-rot',
  '/reminders',
  '/history',
  '/settings',
  '/welcome',
  'identify-result',
  'diagnose-result',
];

const _sizes = [Size(320, 640), Size(390, 844), Size(800, 1000), Size(1440, 900)];

String _day(int n) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day + n).toUtc().toIso8601String();
}

final _longSpecies = PlantCandidate(
  scientificName: 'Monstera deliciosa var. borsigiana',
  probability: 0.93,
  commonNames: const ['монстера деликатесная пёстролистная'],
  family: 'Araceae',
  wateringLevel: 2,
  light: 'Bright indirect light, tolerates partial shade',
  soil: 'Well-drained, rich in organic matter',
  toxicity: 'Toxic to cats and dogs',
  description: 'Крупная тропическая лиана с рассечёнными листьями. ' * 6,
);

Map<String, Object> _seed() {
  final plants = [
    Plant(
      id: 'a',
      nickname: 'Монстера деликатесная у южного окна в гостиной',
      createdAt: DateTime(2026, 3, 1),
      scientificName: _longSpecies.scientificName,
      commonName: _longSpecies.commonNames.first,
      species: _longSpecies,
      conditions: const PlantConditions(
        age: PlantAge.old,
        light: PlantLight.shade,
        pot: PotType.terracotta,
        drainage: false,
        potCm: 32,
      ),
      collectionIds: const ['k'],
    ),
    Plant(id: 'b', nickname: 'Калатея', createdAt: DateTime(2026, 4, 1)),
    Plant(
      id: 'c',
      nickname: 'Стрелиция королевская на балконе',
      createdAt: DateTime(2026, 5, 1),
      location: PlantLocation.balcony,
    ),
  ];
  final tasks = [
    {'id': 't1', 'plant_id': 'a', 'type': 'water', 'interval_days': 7, 'next_due': _day(-3), 'enabled': true},
    {'id': 't2', 'plant_id': 'a', 'type': 'rotate', 'interval_days': 14, 'next_due': _day(0), 'enabled': true},
    {'id': 't3', 'plant_id': 'b', 'type': 'mist', 'interval_days': 3, 'next_due': _day(-1), 'enabled': true},
    {'id': 't4', 'plant_id': 'c', 'type': 'fertilize', 'interval_days': 30, 'next_due': _day(2), 'enabled': true},
  ];
  final idents = [
    IdentificationRecord(
      id: 'i1',
      provider: 'Plant.id',
      candidates: [
        _longSpecies,
        const PlantCandidate(scientificName: 'Philodendron bipinnatifidum', probability: 0.04, commonNames: ['филодендрон двоякоперистый']),
      ],
      createdAt: DateTime(2026, 10, 1),
    ),
  ];
  final diags = [
    DiagnosisRecord(
      id: 'd1',
      plantId: 'a',
      createdAt: DateTime(2026, 10, 2),
      result: const HealthResult(
        healthyProbability: 0.2,
        diseases: [
          DiseaseSuggestion(
            name: 'недостаток питательных веществ и хлороз молодых листьев',
            probability: 0.61,
            description: 'Листья желтеют между жилками.',
            biological: ['Подкормите хелатом железа.'],
            prevention: ['Регулярно подкармливайте весной и летом.'],
          ),
        ],
      ),
    ),
  ];
  String enc(Object v) => jsonEncode(v);
  return {
    'flutter.onboardingDone': true,
    'flutter.plantIdKey': 'test',
    'flutter.place': enc(const UserPlace(lat: 55.75, lon: 37.62, label: 'Москва, Центральный федеральный округ, Россия').toJson()),
    'flutter.garden.plants': enc(plants.map((p) => p.toJson()).toList()),
    'flutter.garden.tasks': enc(tasks),
    'flutter.garden.identifications': enc(idents.map((e) => e.toJson()).toList()),
    'flutter.garden.diagnoses': enc(diags.map((e) => e.toJson()).toList()),
    'flutter.garden.collections': enc([
      PlantCollection(id: 'k', name: 'Кухня и подоконник у плиты', createdAt: DateTime(2026)).toJson(),
    ]),
    'flutter.garden.wishlist': enc([
      WishItem(id: 'w', taxonId: 53202, scientificName: 'Lavandula angustifolia', commonName: 'лаванда узколистная', createdAt: DateTime(2026)).toJson(),
    ]),
  };
}

http.Client _fakeNetwork() {
  final counts = File('test/fixtures/inat_species_counts.json').readAsStringSync();
  final detail = File('test/fixtures/inat_taxon_detail.json').readAsStringSync();
  final countsJson = jsonDecode(counts) as Map<String, dynamic>;
  final taxa = jsonEncode({
    'results': [for (final r in countsJson['results'] as List) (r as Map)['taxon']],
  });
  final dates = [for (var i = 0; i < 4; i++) _day(i).substring(0, 10)];
  final meteo = jsonEncode({
    'current': {'temperature_2m': 6.4, 'relative_humidity_2m': 31},
    'daily': {
      'time': dates,
      'temperature_2m_min': [2, -3, 1, 3],
      'temperature_2m_max': [29, 5, 6, 8],
      'precipitation_sum': [0, 12.4, 0, 6.1],
    },
  });
  return MockClient((req) async {
    final path = req.url.path;
    final body = switch (req.url.host) {
      'api.open-meteo.com' => meteo,
      'api.inaturalist.org' when path.contains('species_counts') => counts,
      'api.inaturalist.org' when path.contains('autocomplete') => taxa,
      'api.inaturalist.org' when path.startsWith('/v1/taxa/') && !path.contains(',') => detail,
      'api.inaturalist.org' => taxa,
      _ => null,
    };
    return body == null
        ? http.Response('not found', 404)
        : http.Response.bytes(utf8.encode(body), 200, headers: {'content-type': 'application/json; charset=utf-8'});
  });
}

Future<void> _loadFonts() async {
  final loader = FontLoader('Manrope');
  for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold']) {
    final bytes = File('assets/fonts/Manrope-$w.ttf').readAsBytesSync();
    loader.addFont(Future.value(ByteData.sublistView(bytes)));
  }
  await loader.load();
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ru');
    await _loadFonts();
  });

  for (final scale in [1.0, 1.3, 1.6]) {
    for (final size in _sizes) {
      testWidgets('вёрстка ${size.width.toInt()}×${size.height.toInt()}, шрифт ×$scale', (tester) async {
        SharedPreferences.setMockInitialValues(_seed());
        final prefs = await SharedPreferences.getInstance();
        final net = _fakeNetwork();
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        final router = buildRouter(showOnboarding: false);
        final container = ProviderContainer(
          overrides: [
            sharedPrefsProvider.overrideWithValue(prefs),
            gardenRepositoryProvider.overrideWithValue(LocalGardenRepository(prefs)),
            inatClientProvider.overrideWithValue(InatClient(client: net)),
            placeWeatherClientProvider.overrideWithValue(PlaceWeatherClient(client: net)),
          ],
        );
        addTearDown(container.dispose);

        var current = '/';
        final problems = <String>[];
        final original = FlutterError.onError;
        FlutterError.onError = (d) {
          final text = d.exceptionAsString();
          // Сеть картинок в тестах недоступна — это не ошибка вёрстки.
          if (text.contains('HTTP request failed') || text.contains('NetworkImage')) return;
          final where = RegExp(r'lib/[\w/]+\.dart:\d+').firstMatch(d.toString())?.group(0) ?? '?';
          problems.add('$current · $where · ${text.split('\n').first}');
        };
        addTearDown(() => FlutterError.onError = original);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp.router(
              theme: buildTheme(Brightness.light),
              darkTheme: buildTheme(Brightness.dark),
              themeMode: ThemeMode.dark,
              locale: const Locale('ru'),
              supportedLocales: const [Locale('ru')],
              localizationsDelegates: GlobalMaterialLocalizations.delegates,
              routerConfig: router,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
            ),
          ),
        );
        final garden = await container.read(gardenProvider.future);

        try {
          for (final route in _routes) {
            current = route;
            switch (route) {
              case 'identify-result':
                router.go('/');
                await tester.pump();
                router.push('/identify/result', extra: IdentifyResultArgs(record: garden.identifications.first));
              case 'diagnose-result':
                router.go('/');
                await tester.pump();
                router.push('/diagnose/result', extra: DiagnoseResultArgs(record: garden.diagnoses.first));
              default:
                router.go(route);
            }
            for (var i = 0; i < 6; i++) {
              await tester.pump(const Duration(milliseconds: 300));
            }
            // Прокручиваем длинные экраны до конца: переполнения бывают ниже первого экрана.
            final scrollables = find.byType(Scrollable);
            for (var i = 0; i < 4 && scrollables.evaluate().isNotEmpty; i++) {
              await tester.drag(scrollables.first, Offset(0, -size.height * 0.8), warnIfMissed: false);
              await tester.pump(const Duration(milliseconds: 300));
            }
          }
        } finally {
          FlutterError.onError = original;
        }
        // Таймеры анимаций и запросов — дать им завершиться до конца теста.
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 2));
        expect(problems.toSet().toList(), isEmpty);
      });
    }
  }
}
