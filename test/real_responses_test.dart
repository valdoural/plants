import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:leafy/data/recognition/plant_id_parser.dart';
import 'package:leafy/data/recognition/plantnet_parser.dart';

/// Настоящие ответы сервисов (сохранены 27.10.2026), чтобы парсеры не зависели от догадок о формате.
Map<String, dynamic> fixture(String name) => Map<String, dynamic>.from(
  jsonDecode(File('test/fixtures/$name').readAsStringSync()) as Map,
);

void main() {
  test('Pl@ntNet: монстера', () {
    final r = parsePlantNet(fixture('plantnet_identify.json'));
    final top = r.candidates.first;
    expect(top.scientificName, 'Monstera deliciosa');
    expect(top.probability, greaterThan(0.5));
    expect(top.displayName, 'Монстера деликатесная');
    expect(top.family, isNotNull);
    expect(top.gbifId, 2868241);
    expect(top.imageUrls, isNotEmpty);
  });

  test('Plant.id: фикус', () {
    final r = parsePlantIdIdentification(
      fixture('plantid_identification.json'),
    );
    final top = r.candidates.first;
    expect(top.scientificName, 'Ficus elastica');
    expect(top.displayName, 'Фикус каучуконосный');
    expect(top.description, contains('Фикус'));
    expect(top.suggestedWateringDays, 7);
    expect(top.light, isNotNull);
    expect(top.imageUrls, isNotEmpty);
    expect(r.isPlantProbability, greaterThan(0.5));
  });

  test('Plant.id: диагностика здорового растения', () {
    final h = parsePlantIdHealth(fixture('plantid_health.json'));
    expect(h.isHealthy, isTrue);
    expect(h.diseases, isNotEmpty);
  });
}
