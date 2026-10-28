import 'package:flutter_test/flutter_test.dart';
import 'package:leafy/data/care_advice.dart';
import 'package:leafy/data/light_meter.dart';
import 'package:leafy/data/models.dart';

void main() {
  test('условия, папки и список желаний переживают сохранение', () {
    final plant = Plant(
      id: 'p1',
      nickname: 'Фикус',
      createdAt: DateTime(2026, 5, 1),
      conditions: const PlantConditions(
        age: PlantAge.mature,
        light: PlantLight.partial,
        pot: PotType.terracotta,
        drainage: false,
        potCm: 18,
      ),
      collectionIds: const ['c1'],
    );
    final back = Plant.fromJson(plant.toJson());
    expect(back.conditions.light, PlantLight.partial);
    expect(back.conditions.pot, PotType.terracotta);
    expect(back.conditions.drainage, isFalse);
    expect(back.conditions.potCm, 18);
    expect(back.collectionIds, ['c1']);

    // Старые записи без новых полей читаются как пустые.
    final legacy = Plant.fromJson({
      'id': 'p2',
      'nickname': 'Старое',
      'created_at': '2026-01-01T00:00:00Z',
    });
    expect(legacy.conditions.isEmpty, isTrue);
    expect(legacy.collectionIds, isEmpty);

    final wish = WishItem.fromJson(
      WishItem(
        id: 'w',
        taxonId: 47,
        scientificName: 'Monstera deliciosa',
        commonName: 'монстера',
        createdAt: DateTime(2026),
      ).toJson(),
    );
    expect(wish.displayName, 'Монстера');
    expect(wish.taxonId, 47);
  });

  test('«не тот вид» меняет вид, но сохраняет имя, фото и условия', () {
    final plant = Plant(
      id: 'p',
      nickname: 'Моё',
      createdAt: DateTime(2026),
      photoUrl: 'data:mine',
      conditions: const PlantConditions(potCm: 12),
    );
    final fixed = plant.withSpecies(
      const PlantCandidate(
        scientificName: 'Ficus elastica',
        probability: 1,
        commonNames: ['фикус каучуконосный'],
      ),
    );
    expect(fixed.scientificName, 'Ficus elastica');
    expect(fixed.commonName, 'фикус каучуконосный');
    expect(fixed.nickname, 'Моё');
    expect(fixed.photoUrl, 'data:mine');
    expect(fixed.conditions.potCm, 12);
  });

  test('расчёт полива учитывает свет, горшок, сезон и дренаж', () {
    final summerSun = waterPlan(
      baseDays: 7,
      conditions: const PlantConditions(
        light: PlantLight.sun,
        pot: PotType.terracotta,
        potCm: 15,
      ),
      location: PlantLocation.indoor,
      date: DateTime(2026, 7, 1),
    );
    final winterShade = waterPlan(
      baseDays: 7,
      conditions: const PlantConditions(
        light: PlantLight.shade,
        pot: PotType.plastic,
        potCm: 15,
        drainage: false,
      ),
      location: PlantLocation.indoor,
      date: DateTime(2026, 1, 10),
    );
    expect(summerSun.intervalDays, lessThan(7));
    expect(winterShade.intervalDays, greaterThan(7));
    // 15 см ≈ 2,25 л, четверть — около 550–600 мл; без дренажа вдвое меньше.
    expect(summerSun.amountMl, inInclusiveRange(500, 650));
    expect(winterShade.amountMl, lessThan(summerSun.amountMl!));
    expect(winterShade.reasons.join(), contains('Без дренажа'));

    final unknown = waterPlan(
      baseDays: 7,
      conditions: const PlantConditions(),
      location: PlantLocation.outdoor,
      date: DateTime(2026, 4, 1),
    );
    expect(unknown.intervalDays, 7);
    expect(unknown.amountMl, isNull);
  });

  test('подсказки: нет дренажа, вид хочет больше света', () {
    final plant = Plant(
      id: 'p',
      nickname: 'Кактус',
      createdAt: DateTime(2026),
      species: const PlantCandidate(
        scientificName: 'Echinopsis',
        probability: 1,
        light: 'Full sun',
      ),
      conditions: const PlantConditions(
        light: PlantLight.shade,
        drainage: false,
      ),
    );
    final tips = conditionAdvice(plant);
    expect(tips.any((t) => t.contains('дренаж')), isTrue);
    expect(tips.any((t) => t.contains('больше света')), isTrue);
  });

  test('люксметр: EXIF и яркость кадра дают разумные люксы', () {
    // Комната днём: 1/50 с, f/1.8, ISO 200 → EV100 ≈ 6,3.
    const room = Exposure(seconds: 1 / 50, fNumber: 1.8, iso: 200);
    final lux = luxFromExposure(room, meanLinear: 0.18);
    expect(lux, inInclusiveRange(30, 150));
    expect(lightFromLux(lux), PlantLight.shade);
    // Подоконник под прямым солнцем: 1/16000 с, f/1.8, ISO 50 → ≈50 000 лк.
    const sill = Exposure(seconds: 1 / 16000, fNumber: 1.8, iso: 50);
    expect(
      lightFromLux(luxFromExposure(sill, meanLinear: 0.18)),
      PlantLight.sun,
    );
    expect(srgbToLinear(255), closeTo(1, 1e-9));
    expect(srgbToLinear(118), closeTo(0.18, 0.01));
  });

  test('оценка света по окну', () {
    expect(
      estimateLight(side: WindowSide.south, distance: WindowDistance.sill),
      PlantLight.sun,
    );
    expect(
      estimateLight(
        side: WindowSide.south,
        distance: WindowDistance.sill,
        sheerCurtain: true,
      ),
      PlantLight.bright,
    );
    expect(
      estimateLight(side: WindowSide.north, distance: WindowDistance.far),
      PlantLight.shade,
    );
    expect(
      estimateLight(side: WindowSide.eastWest, distance: WindowDistance.near),
      PlantLight.partial,
    );
  });

  test('пересадка: гниль срочно, теснота — пора, без признаков — не нужно', () {
    expect(
      repotVerdict({RepotSign.rot}, month: 12).urgency,
      RepotUrgency.rescue,
    );
    final tight = repotVerdict({RepotSign.roots, RepotSign.dries}, month: 4);
    expect(tight.urgency, RepotUrgency.now);
    expect(tight.text, contains('подходящее время'));
    expect(
      repotVerdict({RepotSign.roots, RepotSign.dries}, month: 12).text,
      contains('весны'),
    );
    expect(
      repotVerdict({RepotSign.old}, month: 5).urgency,
      RepotUrgency.notYet,
    );
    expect(
      repotVerdict({RepotSign.old, RepotSign.soil}, month: 5).urgency,
      RepotUrgency.soon,
    );
  });
}
