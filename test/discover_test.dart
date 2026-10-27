import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:leafy/data/discover/catalog.dart';
import 'package:leafy/data/discover/inat.dart';
import 'package:leafy/data/discover/place_weather.dart';

Map<String, dynamic> fixture(String name) =>
    Map<String, dynamic>.from(jsonDecode(File('test/fixtures/$name').readAsStringSync()) as Map);

Weather weather({required List<double> min, required List<double> max, List<double>? rain, double humidity = 60}) =>
    Weather.fromOpenMeteo({
      'current': {'temperature_2m': max.first, 'relative_humidity_2m': humidity},
      'daily': {
        'time': [for (var i = 0; i < min.length; i++) '2026-10-${27 + i}'],
        'temperature_2m_min': min,
        'temperature_2m_max': max,
        'precipitation_sum': rain ?? List.filled(min.length, 0.0),
      },
    });

void main() {
  test('iNaturalist: популярные растения рядом (реальный ответ)', () {
    final j = fixture('inat_species_counts.json');
    final list = (j['results'] as List)
        .map((e) => InatTaxon.fromJson(Map<String, dynamic>.from((e as Map)['taxon'] as Map), count: e['count'] as int))
        .toList();
    expect(list, isNotEmpty);
    expect(list.first.commonName, isNotNull);
    expect(list.first.photoUrl, startsWith('https://'));
    expect(list.first.count, greaterThan(0));
  });

  test('iNaturalist: карточка вида с семейством и описанием', () {
    final j = fixture('inat_taxon_detail.json');
    final t = InatTaxon.fromJson(Map<String, dynamic>.from((j['results'] as List).first as Map));
    expect(t.name, 'Monstera deliciosa');
    expect(t.family, 'Araceae');
    expect(t.summary, isNot(contains('<')));
    final c = t.toCandidate();
    expect(c.scientificName, 'Monstera deliciosa');
    expect(c.imageUrls, isNotEmpty);
  });

  test('советы по погоде', () {
    expect(weatherTips(weather(min: [5, -2, 1], max: [9, 6, 7])).first, contains('заморозки'));
    expect(weatherTips(weather(min: [18, 20, 21], max: [30, 31, 29])).first, contains('Жара'));
    expect(weatherTips(weather(min: [10, 10, 10], max: [15, 15, 15], rain: [5, 6, 4])).first, contains('мм осадков'));
    expect(weatherTips(weather(min: [10, 10, 10], max: [15, 15, 15], humidity: 30)).first, contains('Влажность'));
    expect(weatherTips(weather(min: [10, 10, 10], max: [15, 15, 15])), ['Погода спокойная — поливаем по графику, без поправок.']);
  });

  test('каталог: списки без пропусков, месяцы сезона по кругу', () {
    for (final k in CatalogKind.values.where((k) => !k.flowering)) {
      expect(k.ids, isNotEmpty);
      expect(k.ids!.toSet().length, k.ids!.length, reason: '${k.name}: повторы id');
    }
    expect(seasonMonths(DateTime(2026, 1, 15)), [12, 1, 2]);
    expect(seasonMonths(DateTime(2026, 12, 1)), [11, 12, 1]);
  });
}
