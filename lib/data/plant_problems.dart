/// Справочник проблем растений и анкета ухода.
/// Анкета не заменяет фото-диагностику: она находит ошибки ухода, которые по снимку не видны.
library;

enum PlantPart {
  leaves('Листья', 'Пятна, желтизна, сухие кончики, налёт'),
  stem('Стебель и ствол', 'Размягчение, вытягивание, бляшки'),
  roots('Корни и почва', 'Гниль, плесень, мошки, солевая корка'),
  flowers('Цветы и бутоны', 'Опадают бутоны, нет цветения'),
  pests('Вредители', 'Клещ, тля, червец, щитовка, трипсы');

  const PlantPart(this.label, this.hint);
  final String label;
  final String hint;
}

/// Что заметно на растении.
enum Symptom {
  yellowLower(PlantPart.leaves, 'Желтеют нижние листья'),
  yellowAll(PlantPart.leaves, 'Желтеют или бледнеют листья по всему растению'),
  brownTips(PlantPart.leaves, 'Сохнут и буреют кончики и края'),
  brownSpots(PlantPart.leaves, 'Бурые или чёрные пятна'),
  spotsHalo(PlantPart.leaves, 'Пятна с жёлтым ободком'),
  burn(PlantPart.leaves, 'Светлые сухие пятна там, куда падает солнце'),
  whiteCoat(PlantPart.leaves, 'Белый мучнистый налёт'),
  droop(PlantPart.leaves, 'Листья поникли и обмякли'),
  curl(PlantPart.leaves, 'Листья скручиваются или деформируются'),
  drop(PlantPart.leaves, 'Опадают листья'),
  sticky(PlantPart.leaves, 'Листья липкие, блестят'),
  silver(PlantPart.leaves, 'Серебристые штрихи и чёрные точки'),
  webs(PlantPart.pests, 'Тонкая паутинка, мелкие светлые точки'),
  cottony(PlantPart.pests, 'Белые ватные комочки в пазухах'),
  scale(PlantPart.pests, 'Бурые бляшки на стеблях и жилках'),
  pale(PlantPart.stem, 'Стебли вытягиваются, листья мельчают'),
  stemSoft(PlantPart.stem, 'Стебель у основания мягкий и темнеет'),
  smell(PlantPart.roots, 'Почва кисло пахнет, долго не сохнет'),
  soilMold(PlantPart.roots, 'Плесень или пушистый налёт на почве'),
  soilCrust(PlantPart.roots, 'Белая корка на почве и краях горшка'),
  gnats(PlantPart.roots, 'Мелкие мошки над почвой'),
  budDrop(PlantPart.flowers, 'Опадают бутоны'),
  noBloom(PlantPart.flowers, 'Не цветёт, хотя должно');

  const Symptom(this.part, this.label);
  final PlantPart part;
  final String label;
}

/// Ошибки и обстоятельства ухода — из ответов анкеты.
enum CareFactor {
  overwater(
    'Почва всё время влажная',
    'Корням не хватает воздуха, они начинают гнить. Поливайте, когда просохнут верхние 2–3 см.',
  ),
  underwater(
    'Почва пересыхает полностью',
    'Растение сбрасывает листья, чтобы экономить воду. Поливайте раньше, обильно — до появления воды в поддоне.',
  ),
  irregular(
    'Полив нерегулярный',
    'Перепады «засуха — потоп» ослабляют корни. Включите напоминания о поливе.',
  ),
  noDrainage(
    'Горшок без дренажа',
    'Лишняя вода застаивается на дне. Нужен горшок с отверстиями и слой дренажа.',
  ),
  sun(
    'Прямое солнце',
    'Нежные листья обгорают. Отодвиньте от окна или притените тюлем.',
  ),
  lowLight(
    'Мало света',
    'Растение вытягивается, бледнеет и не цветёт. Переставьте ближе к окну или добавьте фитолампу.',
  ),
  dryAir(
    'Батарея или кондиционер рядом',
    'Сухой воздух сушит кончики листьев и привлекает паутинного клеща. Отодвиньте от батареи, поставьте поддон с мокрым керамзитом.',
  ),
  cold(
    'Сквозняк или холодное окно',
    'Холод вызывает обвисание и опадание листьев. Уберите с холодного подоконника, не ставьте под форточку.',
  ),
  moved(
    'Растение переставили',
    'Смена места — стресс: листья и бутоны могут опасть. Не переставляйте ещё 2–3 недели.',
  ),
  repotted(
    'Недавно пересаживали',
    'После пересадки растение 2–4 недели восстанавливается. Не подкармливайте и не переливайте.',
  ),
  noFeed(
    'Давно не подкармливали',
    'Почва истощилась. С весны до осени подкармливайте раз в 2–4 недели.',
  ),
  overfeed(
    'Часто подкармливали',
    'Избыток солей обжигает корни. Промойте почву большим количеством воды и сделайте перерыв.',
  ),
  pests(
    'Замечены насекомые',
    'Осмотрите изнанку листьев и пазухи, изолируйте растение от остальных.',
  );

  const CareFactor(this.label, this.advice);
  final String label;
  final String advice;
}

class PlantProblem {
  const PlantProblem({
    required this.id,
    required this.part,
    required this.title,
    required this.summary,
    required this.signs,
    required this.factors,
    required this.fix,
    this.prevent = const [],
    this.inatTaxonId,
  });

  final String id;
  final PlantPart part;
  final String title;
  final String summary;
  final Set<Symptom> signs;
  final Set<CareFactor> factors;
  final List<String> fix;
  final List<String> prevent;

  /// Возбудитель или вредитель в iNaturalist — оттуда берём фото для карточки.
  final int? inatTaxonId;
}

const plantProblems = <PlantProblem>[
  PlantProblem(
    id: 'root-rot',
    inatTaxonId: 360255,
    part: PlantPart.roots,
    title: 'Перелив и корневая гниль',
    summary: 'Самая частая причина гибели комнатных растений: в мокрой почве корни задыхаются и гниют, растение вянет, хотя земля влажная.',
    signs: {
      Symptom.yellowLower,
      Symptom.droop,
      Symptom.stemSoft,
      Symptom.smell,
      Symptom.soilMold,
      Symptom.gnats,
    },
    factors: {CareFactor.overwater, CareFactor.noDrainage},
    fix: [
      'Прекратите полив и дайте почве просохнуть.',
      'Если запах и мягкий стебель — выньте растение, обрежьте тёмные мягкие корни до здоровых белых.',
      'Присыпьте срезы толчёным углём, пересадите в свежую рыхлую почву в горшок с отверстиями.',
      'Первые 1–2 недели поливайте понемногу.',
    ],
    prevent: [
      'Поливайте только после просыхания верхнего слоя.',
      'Сливайте воду из поддона через 15 минут.',
    ],
  ),
  PlantProblem(
    id: 'underwatering',
    part: PlantPart.leaves,
    title: 'Недостаток воды',
    summary: 'Почва пересыхает полностью: листья теряют упругость, скручиваются, края сохнут, нижние листья желтеют и опадают.',
    signs: {
      Symptom.droop,
      Symptom.curl,
      Symptom.brownTips,
      Symptom.drop,
      Symptom.yellowLower,
    },
    factors: {CareFactor.underwater, CareFactor.irregular},
    fix: [
      'Полейте обильно, пока вода не появится в поддоне.',
      'Если ком пересох и вода проходит мимо — поставьте горшок в таз с водой на 20–30 минут.',
      'Включите напоминание о поливе и проверяйте почву пальцем.',
    ],
  ),
  PlantProblem(
    id: 'dry-air',
    part: PlantPart.leaves,
    title: 'Сухой воздух',
    summary: 'Зимой у батарей влажность падает до 20–30%. У тропических растений сохнут кончики и края листьев.',
    signs: {Symptom.brownTips, Symptom.curl},
    factors: {CareFactor.dryAir},
    fix: [
      'Отодвиньте растение от батареи и кондиционера.',
      'Поставьте горшок на поддон с мокрым керамзитом или используйте увлажнитель.',
      'Сухие кончики можно аккуратно подрезать, оставив узкую бурую кромку.',
    ],
  ),
  PlantProblem(
    id: 'low-light',
    part: PlantPart.stem,
    title: 'Недостаток света',
    summary: 'Стебли вытягиваются к окну, новые листья мельче и бледнее, пёстрые сорта зеленеют, цветения нет.',
    signs: {
      Symptom.pale,
      Symptom.yellowLower,
      Symptom.drop,
      Symptom.noBloom,
      Symptom.yellowAll,
    },
    factors: {CareFactor.lowLight},
    fix: [
      'Переставьте ближе к окну — каждый метр от окна уменьшает свет в несколько раз.',
      'Зимой добавьте фитолампу на 10–12 часов в день.',
      'Поворачивайте горшок раз в 2 недели, чтобы растение росло ровно.',
    ],
  ),
  PlantProblem(
    id: 'sunburn',
    part: PlantPart.leaves,
    title: 'Солнечный ожог',
    summary: 'На листьях, обращённых к стеклу, появляются светлые или бурые сухие пятна — особенно после переноса на солнечное место.',
    signs: {Symptom.burn, Symptom.brownSpots},
    factors: {CareFactor.sun, CareFactor.moved},
    fix: [
      'Отодвиньте от окна или притените тюлем в полдень.',
      'Обожжённые участки не восстановятся; сильно повреждённые листья удалите.',
      'К яркому солнцу приучайте постепенно, за 1–2 недели.',
    ],
  ),
  PlantProblem(
    id: 'cold',
    part: PlantPart.leaves,
    title: 'Переохлаждение и сквозняк',
    summary: 'Листья темнеют, обвисают, появляются тёмные мокнущие участки; при резком холоде растение сбрасывает листья и бутоны.',
    signs: {Symptom.droop, Symptom.drop, Symptom.brownSpots, Symptom.budDrop},
    factors: {CareFactor.cold, CareFactor.moved},
    fix: [
      'Уберите с холодного подоконника, подложите пенопласт или пробку под горшок.',
      'Не ставьте под открытую форточку, проветривайте без растения.',
      'Поливайте тёплой водой и реже, пока растение не оправится.',
    ],
  ),
  PlantProblem(
    id: 'hunger',
    part: PlantPart.leaves,
    title: 'Нехватка питания',
    summary: 'Если долго не подкармливать и не пересаживать, листья бледнеют равномерно, новые растут мелкими, цветения нет.',
    signs: {Symptom.yellowAll, Symptom.pale, Symptom.noBloom},
    factors: {CareFactor.noFeed},
    fix: [
      'С весны до осени подкармливайте комплексным удобрением раз в 2–4 недели.',
      'Если растение не пересаживали больше двух лет — пересадите в свежую почву.',
      'Жёлтые листья с зелёными жилками — признак нехватки железа: подойдёт хелат железа.',
    ],
  ),
  PlantProblem(
    id: 'salts',
    part: PlantPart.roots,
    title: 'Избыток удобрений и солей',
    summary: 'На почве и горшке появляется белая корка, кончики листьев буреют, корни обжигаются.',
    signs: {Symptom.soilCrust, Symptom.brownTips},
    factors: {CareFactor.overfeed},
    fix: [
      'Промойте почву: пропустите через горшок объём воды в 3–4 раза больше горшка.',
      'Снимите верхний слой с коркой и досыпьте свежую землю.',
      'Сделайте перерыв в подкормках на месяц, затем уменьшите дозу вдвое.',
    ],
  ),
  PlantProblem(
    id: 'spider-mite',
    inatTaxonId: 203333,
    part: PlantPart.pests,
    title: 'Паутинный клещ',
    summary: 'Крошечные клещи на изнанке листьев высасывают сок: лист покрывается светлыми точками, желтеет, появляется паутинка. Любит сухой тёплый воздух.',
    signs: {Symptom.webs, Symptom.yellowAll, Symptom.curl},
    factors: {CareFactor.dryAir, CareFactor.pests},
    fix: [
      'Изолируйте растение от остальных.',
      'Промойте листья под тёплым душем, особенно изнанку, протрите мыльным раствором.',
      'При сильном заражении — акарицид (например, на основе абамектина) 2–3 раза с интервалом 5–7 дней.',
      'Повысьте влажность воздуха.',
    ],
  ),
  PlantProblem(
    id: 'aphids',
    inatTaxonId: 52381,
    part: PlantPart.pests,
    title: 'Тля',
    summary: 'Колонии мелких зелёных или чёрных насекомых на молодых побегах и бутонах; листья скручиваются и становятся липкими.',
    signs: {Symptom.sticky, Symptom.curl},
    factors: {CareFactor.pests},
    fix: [
      'Смойте тлю струёй воды, протрите побеги мыльным раствором.',
      'Сильно поражённые верхушки обрежьте.',
      'При возврате — инсектицид системного действия.',
    ],
  ),
  PlantProblem(
    id: 'mealybug',
    inatTaxonId: 49574,
    part: PlantPart.pests,
    title: 'Мучнистый червец',
    summary: 'Белые ватные комочки в пазухах листьев и на корнях, липкий налёт; растение слабеет и желтеет.',
    signs: {Symptom.cottony, Symptom.sticky, Symptom.yellowAll},
    factors: {CareFactor.pests},
    fix: [
      'Снимите комочки ватной палочкой со спиртом.',
      'Промойте растение, обработайте системным инсектицидом 2–3 раза через 7–10 дней.',
      'Проверьте корни: при корневом червеце нужна пересадка с промывкой корней.',
    ],
  ),
  PlantProblem(
    id: 'scale',
    inatTaxonId: 49456,
    part: PlantPart.pests,
    title: 'Щитовка',
    summary: 'Неподвижные бурые бляшки на стеблях и вдоль жилок, под ними — насекомые; листья липкие.',
    signs: {Symptom.scale, Symptom.sticky},
    factors: {CareFactor.pests},
    fix: [
      'Счистите бляшки мягкой щёткой с мыльным раствором.',
      'Обработайте системным инсектицидом, повторите через 10–14 дней.',
      'Осмотрите соседние растения.',
    ],
  ),
  PlantProblem(
    id: 'thrips',
    inatTaxonId: 83201,
    part: PlantPart.pests,
    title: 'Трипсы',
    summary: 'На листьях серебристые штрихи и чёрные точки-выделения, цветы деформируются.',
    signs: {Symptom.silver, Symptom.curl},
    factors: {CareFactor.pests},
    fix: [
      'Изолируйте растение, срежьте поражённые цветы.',
      'Обработайте инсектицидом 3 раза с интервалом 5–7 дней — личинки прячутся в почве.',
      'Повесьте синие клеевые ловушки.',
    ],
  ),
  PlantProblem(
    id: 'fungus-gnats',
    inatTaxonId: 85259,
    part: PlantPart.roots,
    title: 'Грибные комарики (сциариды)',
    summary: 'Мелкие чёрные мошки над почвой; личинки живут в постоянно влажной земле и повреждают молодые корни.',
    signs: {Symptom.gnats, Symptom.soilMold},
    factors: {CareFactor.overwater},
    fix: [
      'Дайте верхнему слою почвы хорошо просохнуть между поливами.',
      'Повесьте жёлтые клеевые ловушки для взрослых мошек.',
      'Пролейте почву биопрепаратом против личинок или замените верхний слой песком.',
    ],
  ),
  PlantProblem(
    id: 'powdery-mildew',
    inatTaxonId: 55525,
    part: PlantPart.leaves,
    title: 'Мучнистая роса',
    summary: 'Белый мучнистый налёт на листьях и стеблях — грибковая болезнь, развивается при перепадах температуры и плохой вентиляции.',
    signs: {Symptom.whiteCoat},
    factors: {CareFactor.cold},
    fix: [
      'Удалите сильно поражённые листья.',
      'Обработайте фунгицидом или раствором соды (1 ч. л. на литр воды с каплей мыла).',
      'Не опрыскивайте листья, проветривайте без сквозняков.',
    ],
  ),
  PlantProblem(
    id: 'leaf-spot',
    inatTaxonId: 354898,
    part: PlantPart.leaves,
    title: 'Пятнистость листьев',
    summary: 'Бурые пятна с жёлтым ободком — грибковая или бактериальная инфекция, чаще при мокрых листьях и переливе.',
    signs: {Symptom.spotsHalo, Symptom.brownSpots},
    factors: {CareFactor.overwater},
    fix: [
      'Удалите поражённые листья, инструмент протрите спиртом.',
      'Поливайте под корень, не мочите листья.',
      'Обработайте медьсодержащим фунгицидом.',
    ],
  ),
  PlantProblem(
    id: 'shock',
    part: PlantPart.leaves,
    title: 'Стресс после пересадки или переезда',
    summary: 'После пересадки или смены места растение на время сбрасывает часть листьев и выглядит вялым.',
    signs: {Symptom.droop, Symptom.drop, Symptom.yellowLower},
    factors: {CareFactor.repotted, CareFactor.moved},
    fix: [
      'Не переставляйте растение 2–3 недели.',
      'Уберите с яркого солнца, поливайте умеренно, не подкармливайте месяц.',
      'Обычно растение оправляется само.',
    ],
  ),
  PlantProblem(
    id: 'bud-drop',
    part: PlantPart.flowers,
    title: 'Опадание бутонов',
    summary: 'Бутоны осыпаются, не раскрывшись: растение реагирует на перемещение, холод или пересушку.',
    signs: {Symptom.budDrop},
    factors: {CareFactor.moved, CareFactor.cold, CareFactor.underwater},
    fix: [
      'Не поворачивайте и не переносите растение с бутонами.',
      'Следите, чтобы почва не пересыхала.',
      'Уберите от холодного стекла и сквозняков.',
    ],
  ),
  PlantProblem(
    id: 'no-bloom',
    part: PlantPart.flowers,
    title: 'Нет цветения',
    summary: 'Взрослое растение не цветёт: обычно мало света, нет периода покоя или избыток азота.',
    signs: {Symptom.noBloom},
    factors: {CareFactor.lowLight, CareFactor.noFeed, CareFactor.overfeed},
    fix: [
      'Дайте больше света — это главное условие цветения.',
      'Перейдите на удобрение для цветущих растений (больше фосфора и калия).',
      'Узнайте, нужен ли виду прохладный период покоя зимой.',
    ],
  ),
];

PlantProblem? problemById(String id) =>
    plantProblems.where((p) => p.id == id).firstOrNull;

/// Проблема и насколько она подходит под ответы.
class ProblemMatch {
  const ProblemMatch(this.problem, this.score, this.signs, this.factors);

  final PlantProblem problem;
  final int score;
  final Set<Symptom> signs;
  final Set<CareFactor> factors;
}

/// Подбирает вероятные проблемы: совпавший признак весит 2, обстоятельство ухода — 1.
/// Без единого совпавшего признака проблема не предлагается — одних ошибок ухода мало.
List<ProblemMatch> matchProblems(
  Set<Symptom> symptoms,
  Set<CareFactor> factors, {
  int limit = 3,
}) {
  final matches = [
    for (final p in plantProblems)
      if (p.signs.intersection(symptoms) case final s when s.isNotEmpty)
        ProblemMatch(
          p,
          s.length * 2 + p.factors.intersection(factors).length,
          s,
          p.factors.intersection(factors),
        ),
  ]..sort((a, b) => b.score.compareTo(a.score));
  return matches.take(limit).toList();
}

// ───── Анкета ─────

enum WateringHabit {
  dry('Когда почва полностью высохнет', CareFactor.underwater),
  top('Когда подсохнет сверху', null),
  wet('Держу почву всегда влажной', CareFactor.overwater),
  random('Нерегулярно, когда вспомню', CareFactor.irregular);

  const WateringHabit(this.label, this.factor);
  final String label;
  final CareFactor? factor;
}

enum LightSpot {
  sun('На солнце', CareFactor.sun),
  bright('У окна, без прямого солнца', null),
  far('Далеко от окна', CareFactor.lowLight);

  const LightSpot(this.label, this.factor);
  final String label;
  final CareFactor? factor;
}

enum FeedingHabit {
  never('Редко или никогда', CareFactor.noFeed),
  normal('Раз в 2–4 недели весной и летом', null),
  often('Каждую неделю и чаще', CareFactor.overfeed);

  const FeedingHabit(this.label, this.factor);
  final String label;
  final CareFactor? factor;
}

/// Что менялось за последний месяц.
const recentChanges = [
  CareFactor.moved,
  CareFactor.repotted,
  CareFactor.dryAir,
  CareFactor.cold,
];

/// Ответы анкеты → обстоятельства ухода.
Set<CareFactor> careFactors({
  WateringHabit? watering,
  bool? drainage,
  LightSpot? light,
  FeedingHabit? feeding,
  Set<CareFactor> changes = const {},
  bool pestsSeen = false,
}) => {
  ?watering?.factor,
  if (drainage == false) CareFactor.noDrainage,
  ?light?.factor,
  ?feeding?.factor,
  ...changes,
  if (pestsSeen) CareFactor.pests,
};

/// Проблемы, которые чаще всего встречаются у вида с такими потребностями.
/// [wateringLevel] 1…3 (засухоустойчивое…влаголюбивое), [likesSun] — любит прямое солнце,
/// [tropical] — родом из тропиков (боится сухого воздуха и холода).
List<PlantProblem> likelyProblems({
  double? wateringLevel,
  bool? likesSun,
  bool tropical = false,
  int limit = 8,
}) {
  final ids = <String>[
    if (wateringLevel != null && wateringLevel <= 1.6) 'root-rot',
    if (wateringLevel != null && wateringLevel >= 2.4) 'underwatering',
    if (tropical) ...['dry-air', 'spider-mite', 'cold'],
    if (likesSun == true) 'low-light',
    if (likesSun == false) 'sunburn',
    'root-rot',
    'mealybug',
    'fungus-gnats',
    'aphids',
    'leaf-spot',
    'scale',
    'powdery-mildew',
    'hunger',
    'thrips',
  ];
  final seen = <String>{};
  return [
    for (final id in ids)
      if (seen.add(id)) ?problemById(id),
  ].take(limit).toList();
}
