/// Короткие русские формулировки для полей ухода, которые Plant.id отдаёт только на английском.
/// Это не перевод, а классификация по ключевым словам; исходный текст остаётся доступен как «подробнее».
library;

final _cyrillic = RegExp('[а-яё]', caseSensitive: false);

bool isRussian(String text) => _cyrillic.hasMatch(text);

/// Свет: «Яркий рассеянный свет», «Полутень» и т.п.
String? lightSummaryRu(String? text) {
  if (text == null) return null;
  if (isRussian(text)) return text;
  final t = text.toLowerCase();
  final parts = <String>[
    // «direct sun» в описании рассеянного света обычно звучит как предупреждение, а не рекомендация.
    if (t.contains('full sun') || (t.contains('direct sun') && !t.contains('indirect'))) 'прямое солнце',
    if (t.contains('indirect') || t.contains('bright light') || t.contains('filtered')) 'яркий рассеянный свет',
    if (t.contains('partial') || t.contains('part shade') || t.contains('semi-shade')) 'полутень',
    if (t.contains('low light') || t.contains('full shade') || t.contains('deep shade')) 'выносит слабый свет',
  ];
  if (t.contains('scorch') || t.contains('burn')) parts.add('беречь от полуденного солнца');
  return parts.isEmpty ? null : _cap(parts.toSet().join(', '));
}

/// Почва: «Рыхлая, хорошо дренированная, богатая органикой».
String? soilSummaryRu(String? text) {
  if (text == null) return null;
  if (isRussian(text)) return text;
  final t = text.toLowerCase();
  final parts = <String>[
    if (t.contains('well-drain') || t.contains('well drain') || t.contains('drainage')) 'хорошо дренированная',
    if (t.contains('loose') || t.contains('aerated') || t.contains('airy')) 'рыхлая',
    if (t.contains('organic') || t.contains('rich') || t.contains('humus') || t.contains('fertile')) 'богатая органикой',
    if (t.contains('sand')) 'с песком',
    if (t.contains('loam')) 'суглинок',
    if (t.contains('peat')) 'с торфом',
    if (t.contains('perlite')) 'с перлитом',
    if (t.contains('bark') || t.contains('orchid')) 'с корой',
    if (t.contains('cactus') || t.contains('succulent')) 'для суккулентов',
    if (t.contains('acid')) 'кислая',
    if (t.contains('alkaline')) 'щелочная',
    if (t.contains('neutral')) 'нейтральная',
    if (t.contains('moist') && !t.contains('not moist')) 'умеренно влажная',
  ];
  return parts.isEmpty ? null : _cap(parts.toSet().join(', '));
}

/// Ядовитость: «Ядовито для кошек, собак» / «Не ядовито».
String? toxicitySummaryRu(String? text) {
  if (text == null) return null;
  if (isRussian(text)) return text;
  final t = text.toLowerCase();
  if (t.contains('non-toxic') || t.contains('not toxic') || t.contains('nontoxic') || t.contains('safe for')) {
    return 'Не ядовито';
  }
  if (!t.contains('toxic') && !t.contains('poison') && !t.contains('irritat')) return null;
  final whom = <String>[
    if (t.contains('cat')) 'кошек',
    if (t.contains('dog')) 'собак',
    if (t.contains('pet') && !t.contains('cat') && !t.contains('dog')) 'домашних животных',
    if (t.contains('human') || t.contains('people') || t.contains('child')) 'людей',
    if (t.contains('horse')) 'лошадей',
  ];
  final base = t.contains('mild') || t.contains('irritat') && !t.contains('toxic') ? 'Слабо ядовито' : 'Ядовито';
  return whom.isEmpty ? base : '$base для ${whom.join(', ')}';
}

String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
