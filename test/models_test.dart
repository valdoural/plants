import 'package:flutter_test/flutter_test.dart';
import 'package:leafy/data/models.dart';

void main() {
  test('новая задача ухода — на сегодня', () {
    final t = CareTask.create('p1', CareType.water);
    expect(t.intervalDays, 7);
    expect(t.daysLeft, 0);
    expect(t.isDue, isTrue);
  });

  test('выполнение переносит задачу на интервал вперёд', () {
    final t = CareTask.create('p1', CareType.water, intervalDays: 5).complete();
    expect(t.daysLeft, 5);
    expect(t.isDue, isFalse);
    expect(t.lastDone, isNotNull);
  });

  test('отложить на день', () {
    final t = CareTask.create('p1', CareType.mist).snooze();
    expect(t.daysLeft, 1);
  });

  test('смена интервала после выполнения пересчитывает дату', () {
    final t = CareTask.create('p1', CareType.water).complete().withInterval(3);
    expect(t.intervalDays, 3);
    expect(t.daysLeft, 3);
  });

  test('JSON туда и обратно', () {
    final plant = Plant(
      id: 'p1',
      nickname: 'Фикус',
      createdAt: DateTime(2026, 1, 2),
      location: PlantLocation.balcony,
      species: const PlantCandidate(scientificName: 'Ficus elastica', probability: 0.9, wateringLevel: 1),
    );
    final back = Plant.fromJson(plant.toJson());
    expect(back.nickname, 'Фикус');
    expect(back.location, PlantLocation.balcony);
    expect(back.species!.suggestedWateringDays, 14);

    final task = CareTask.create('p1', CareType.fertilize).complete();
    final t2 = CareTask.fromJson(task.toJson());
    expect(t2.type, CareType.fertilize);
    expect(t2.daysLeft, task.daysLeft);
  });
}
