import 'dart:math' as math;

import 'models.dart';

/// Какой свет любит вид — по тексту ухода (английскому от Plant.id или русскому).
Set<PlantLight> preferredLight(String? text) {
  if (text == null) return const {};
  final t = text.toLowerCase();
  return {
    if (t.contains('full sun') ||
        (t.contains('direct sun') && !t.contains('indirect')) ||
        t.contains('прямое солнце'))
      PlantLight.sun,
    if (t.contains('indirect') ||
        t.contains('bright') ||
        t.contains('filtered') ||
        t.contains('рассеянн'))
      PlantLight.bright,
    if (t.contains('partial') ||
        t.contains('part shade') ||
        t.contains('semi-shade') ||
        t.contains('полутен'))
      PlantLight.partial,
    if (t.contains('low light') ||
        t.contains('full shade') ||
        t.contains('deep shade') ||
        t.contains('слабый свет') ||
        t.contains('тень'))
      PlantLight.shade,
  };
}

/// Подсказки по условиям растения: дренаж, горшок, свет.
List<String> conditionAdvice(Plant plant) {
  final c = plant.conditions;
  final tips = <String>[];
  if (c.drainage == false) {
    tips.add(
      'Без дренажных отверстий вода застаивается и корни загнивают. Пересадите в горшок с отверстиями или поливайте вдвое меньше.',
    );
  }
  final likes = preferredLight(plant.species?.light);
  if (c.light != null && likes.isNotEmpty && !likes.contains(c.light)) {
    final darker = likes.every((l) => l.index < c.light!.index);
    tips.add(
      darker
          ? 'Этому виду нужно больше света, чем «${c.light!.label.toLowerCase()}». Переставьте ближе к окну или добавьте фитолампу.'
          : 'Свет «${c.light!.label.toLowerCase()}» для этого вида слишком яркий — притените от полуденного солнца.',
    );
  }
  if (c.pot == PotType.terracotta) {
    tips.add(
      'Терракота пропускает воздух, почва сохнет быстрее — проверяйте её чаще.',
    );
  }
  if (c.light == PlantLight.shade &&
      (c.pot == PotType.plastic || c.pot == PotType.glazed)) {
    tips.add(
      'В тени и в непористом горшке почва сохнет медленно — не заливайте.',
    );
  }
  if (c.age == PlantAge.seedling) {
    tips.add(
      'Молодым растениям нельзя пересыхать полностью — держите почву слегка влажной.',
    );
  }
  return tips;
}

/// Расчёт полива: как часто и сколько воды.
class WaterPlan {
  const WaterPlan({
    required this.intervalDays,
    required this.amountMl,
    required this.reasons,
  });

  final int intervalDays;

  /// Сколько воды за один полив; null — если размер горшка неизвестен.
  final int? amountMl;

  /// Что повлияло на расчёт — показываем пользователю.
  final List<String> reasons;
}

/// Объём горшка (мл) по диаметру: высота примерно равна диаметру, стенки сужаются.
int potVolumeMl(int diameterCm) =>
    (math.pi * math.pow(diameterCm / 2, 2) * diameterCm * 0.85).round();

WaterPlan waterPlan({
  required int baseDays,
  required PlantConditions conditions,
  required PlantLocation location,
  required DateTime date,
}) {
  var k = 1.0;
  final reasons = <String>['По виду: раз в $baseDays дн.'];
  void apply(double f, String why) {
    k *= f;
    reasons.add(why);
  }

  switch (conditions.light) {
    case PlantLight.sun:
      apply(0.75, 'Прямое солнце — почва сохнет быстрее');
    case PlantLight.bright:
      apply(0.9, 'Яркий свет — чуть чаще');
    case PlantLight.partial:
      apply(1.15, 'Полутень — реже');
    case PlantLight.shade:
      apply(1.35, 'Тень — заметно реже');
    case null:
      break;
  }
  switch (conditions.pot) {
    case PotType.terracotta:
      apply(0.85, 'Терракота испаряет влагу через стенки');
    case PotType.ground:
      apply(1.2, 'В грунте влага держится дольше');
    case PotType.plastic || PotType.glazed || null:
      break;
  }
  final d = conditions.potCm;
  if (d != null && d <= 10) apply(0.8, 'Маленький горшок быстро пересыхает');
  if (d != null && d >= 25) apply(1.25, 'Большой горшок держит влагу дольше');
  if (conditions.age == PlantAge.seedling) {
    apply(0.8, 'Молодое растение — не пересушивать');
  }
  final m = date.month;
  final winter = m == 11 || m == 12 || m <= 2;
  final summer = m >= 6 && m <= 8;
  if (location == PlantLocation.indoor && winter) {
    apply(1.3, 'Зима: рост замедлен, света мало');
  } else if (summer) {
    apply(0.85, 'Лето: жарко, растение активно растёт');
  }

  final interval = (baseDays * k).round().clamp(2, 30);
  int? amount;
  if (d != null && conditions.pot != PotType.ground) {
    // Около четверти объёма горшка — пока вода не появится в поддоне.
    var ml = potVolumeMl(d) * 0.25;
    if (conditions.drainage == false) {
      ml /= 2;
      reasons.add('Без дренажа — воды вдвое меньше');
    }
    amount = math.max(50, (ml / 50).round() * 50);
  }
  return WaterPlan(intervalDays: interval, amountMl: amount, reasons: reasons);
}
