import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:leafy/core/notifications.dart';
import 'package:leafy/data/care_text_ru.dart';
import 'package:leafy/data/models.dart';
import 'package:leafy/data/recognition/plant_id_parser.dart';

void main() {
  group('ежедневная сводка', () {
    final today = DateTime(2026, 10, 27);
    Plant plant(String id, String name) => Plant(id: id, nickname: name, createdAt: today);
    CareTask task(String id, String plantId, CareType type, DateTime due, {bool enabled = true}) =>
        CareTask(id: id, plantId: plantId, type: type, intervalDays: 7, nextDue: due, enabled: enabled);

    test('просроченные переносятся на сегодня, задачи группируются по дням и видам ухода', () {
      final data = GardenData(
        plants: [plant('a', 'Монстера'), plant('b', 'Фикус'), plant('c', 'Лаванда')],
        tasks: [
          task('1', 'a', CareType.water, today),
          task('2', 'b', CareType.water, today.subtract(const Duration(days: 3))),
          task('3', 'c', CareType.fertilize, today),
          task('4', 'a', CareType.fertilize, today.add(const Duration(days: 2))),
          task('5', 'c', CareType.mist, today, enabled: false),
          task('6', 'deleted', CareType.water, today),
          task('7', 'b', CareType.repot, today.add(const Duration(days: 40))),
        ],
      );
      final digests = buildDailyDigests(data, today, 30);
      expect(digests, hasLength(2));
      expect(digests[0].date, today);
      expect(digests[0].title, 'Растениям нужен уход: 3');
      expect(digests[0].body, 'Полив: Монстера, Фикус · Подкормка: Лаванда');
      expect(digests[1].date, today.add(const Duration(days: 2)));
      expect(digests[1].title, 'Растению нужен уход');
    });
  });

  group('русские сводки ухода', () {
    test('свет из реального ответа Plant.id', () {
      final json = jsonDecode(File('test/fixtures/plantid_identification.json').readAsStringSync()) as Map<String, dynamic>;
      final light = parsePlantIdIdentification(json).candidates.first.light!;
      expect(isRussian(light), isFalse);
      expect(lightSummaryRu(light), contains('рассеянный свет'));
    });

    test('предупреждение о прямом солнце не превращается в рекомендацию', () {
      expect(lightSummaryRu('Thrives in bright, indirect light; direct sun can scorch the leaves.'),
          'Яркий рассеянный свет, беречь от полуденного солнца');
      expect(lightSummaryRu('Prefers full sun.'), 'Прямое солнце');
    });

    test('ядовитость', () {
      expect(toxicitySummaryRu('Toxic to cats and dogs if ingested.'), 'Ядовито для кошек, собак');
      expect(toxicitySummaryRu('This plant is non-toxic to pets.'), 'Не ядовито');
      expect(toxicitySummaryRu('Ядовито'), 'Ядовито');
      expect(toxicitySummaryRu('Unknown'), isNull);
    });

    test('почва', () {
      expect(soilSummaryRu('Well-draining, rich in organic matter, slightly acidic.'),
          'Хорошо дренированная, богатая органикой, кислая');
    });
  });
}
