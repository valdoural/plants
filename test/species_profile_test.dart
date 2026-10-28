import 'package:flutter_test/flutter_test.dart';
import 'package:leafy/data/discover/inat.dart';
import 'package:leafy/data/discover/species_profile.dart';

const _extract = '''Монсте́ра делика́тесная (лат. Monstera deliciosa) — вечнозелёная лиана, вид рода Монстера. Многолетнее растение, в природе достигает высоты 20 м.


== Название ==
Видовой эпитет deliciosa означает «лакомая» — за съедобные плоды.

== Ботаническое описание ==
Листья крупные, кожистые.

=== Цветки ===
Початок кремовый.

== Распространение и экология ==
Растёт во влажных тропических лесах Мексики и Панамы.

== Применение ==
Популярное комнатное растение. Плоды едят в сыром виде.

== Примечания ==
1. Ссылка.
''';

void main() {
  test('статья Википедии делится на разделы, служебные отброшены', () {
    final a = parseWikiExtract('Монстера деликатесная', _extract);
    expect(a.lead, startsWith('Монстера деликатесная'));
    expect(a.lead.contains('́'), isFalse);
    expect(a.section(['назван']), contains('лакомая'));
    expect(a.section(['применен']), contains('комнатное'));
    expect(a.section(['распространен']), contains('Мексики'));
    expect(a.section(['описан']), contains('Початок'));
    expect(a.section(['примечан']), isNull);
    expect(a.url, contains('ru.wikipedia.org/wiki/'));
  });

  test('факты из текста: форма роста, продолжительность жизни, высота', () {
    final text = parseWikiExtract('М', _extract).fullText;
    expect(growthForm(text), 'Лиана');
    expect(lifespan(text), 'Многолетнее');
    expect(plantHeight(text), '20 м');
    expect(plantHeight('Кустарник высотой до 1,5 м.'), 'до 1,5 м');
    expect(plantHeight('Стебли 30–60 см высотой'), isNull);
    expect(plantHeight('растение высотой 30–60 см'), '30–60 см');
    expect(growthForm('Полукустарник с серыми листьями'), 'Полукустарник');
    expect(lifespan('Дерево высотой до 30 м'), 'Многолетнее');
  });

  test('тип растения по классу и климат по поясам', () {
    expect(plantType({'class': 'Liliopsida'}), 'Цветковое, однодольное');
    expect(plantType({'class': 'Pinopsida'}), 'Хвойное');
    const c = ClimateProfile({
      ClimateZone.tropical: 800,
      ClimateZone.subtropical: 150,
      ClimateZone.temperate: 50,
      ClimateZone.cold: 0,
    });
    expect(c.main, ClimateZone.tropical);
    expect(c.share(ClimateZone.tropical), closeTo(0.8, 1e-9));
    expect(const ClimateProfile({ClimateZone.cold: 3}).main, isNull);
  });

  test('месяцы цветения — где не меньше четверти пика', () {
    const p = SpeciesProfile(
      flowering: {4: 5, 5: 40, 6: 100, 7: 60, 8: 20, 9: 2},
    );
    expect(p.floweringMonths, [5, 6, 7]);
    expect(const SpeciesProfile(flowering: {6: 3}).floweringMonths, isEmpty);
  });

  test('сорная репутация по спискам', () {
    expect(
      weedPotential(const InatTaxon(id: 499936, name: 'Heracleum sosnowskyi')),
      startsWith('Высокий'),
    );
    expect(
      weedPotential(const InatTaxon(id: 1, name: 'X')),
      startsWith('Не отмечен'),
    );
  });
}
