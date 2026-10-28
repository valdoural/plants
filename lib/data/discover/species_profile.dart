import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'catalog.dart';
import 'discover_providers.dart';
import 'inat.dart';

/// Статья русской Википедии, разобранная на разделы.
class WikiArticle {
  const WikiArticle({
    required this.title,
    required this.lead,
    required this.sections,
  });

  final String title;

  /// Вводная часть до первого заголовка.
  final String lead;

  /// (заголовок, текст) разделов верхнего уровня, подразделы — внутри текста.
  final List<(String, String)> sections;

  String get url =>
      'https://ru.wikipedia.org/wiki/${Uri.encodeComponent(title.replaceAll(' ', '_'))}';

  /// Первый раздел, в заголовке которого есть одно из [keys]; текст — не длиннее [max] символов.
  String? section(List<String> keys, {int max = 1100}) {
    for (final (title, text) in sections) {
      final t = title.toLowerCase();
      if (keys.any(t.contains) && text.trim().isNotEmpty) {
        return clip(text.trim(), max);
      }
    }
    return null;
  }

  /// Весь текст статьи — для извлечения фактов (форма роста, высота).
  String get fullText => [lead, for (final (_, t) in sections) t].join('\n');
}

const _skip = {
  'примечания',
  'литература',
  'ссылки',
  'см. также',
  'галерея',
  'источники',
  'синонимы',
  'таксономия',
  'классификация',
};

/// Разбор plain-text выдачи MediaWiki (prop=extracts&explaintext): «== Раздел ==», «=== Подраздел ===».
WikiArticle parseWikiExtract(String title, String text) {
  final heading = RegExp(r'^(={2,})\s*(.*?)\s*=+\s*$');
  final lead = StringBuffer();
  final sections = <(String, StringBuffer)>[];
  for (final line in const LineSplitter().convert(text)) {
    final m = heading.firstMatch(line);
    if (m != null) {
      final level = m.group(1)!.length;
      final name = m.group(2)!;
      if (level == 2) {
        sections.add((name, StringBuffer()));
      } else if (sections.isNotEmpty) {
        sections.last.$2.write('\n$name.\n');
      }
      continue;
    }
    (sections.isEmpty ? lead : sections.last.$2).writeln(line);
  }
  String tidy(String s) =>
      s.replaceAll('́', '').replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
  return WikiArticle(
    title: title,
    lead: tidy(lead.toString()),
    sections: [
      for (final (name, body) in sections)
        if (!_skip.contains(name.toLowerCase())) (name, tidy(body.toString())),
    ],
  );
}

/// Обрезает текст до [max] символов по концу предложения.
String clip(String text, int max) {
  if (text.length <= max) return text;
  final cut = text.substring(0, max);
  final end = cut.lastIndexOf(RegExp(r'[.!?…](\s|$)'));
  return end > max * 0.5 ? cut.substring(0, end + 1) : '$cut…';
}

/// Форма роста по описанию: первое встретившееся из ключевых слов.
String? growthForm(String text) {
  const forms = {
    'полукустарник': 'Полукустарник',
    'кустарничек': 'Кустарничек',
    'кустарник': 'Кустарник',
    'дерево': 'Дерево',
    'деревья': 'Дерево',
    'лиана': 'Лиана',
    'суккулент': 'Суккулент',
    'эпифит': 'Эпифит',
    'травянист': 'Травянистое растение',
  };
  final t = text.toLowerCase();
  String? best;
  var at = 1 << 30;
  forms.forEach((key, label) {
    final i = t.indexOf(key);
    // «кустарник» внутри «полукустарник» не считаем отдельно.
    if (i >= 0 && i < at) {
      at = i;
      best = label;
    }
  });
  return best;
}

/// Продолжительность жизни по описанию.
String? lifespan(String text) {
  final t = text.toLowerCase();
  const kinds = {
    'многолетн': 'Многолетнее',
    'однолетн': 'Однолетнее',
    'двулетн': 'Двулетнее',
  };
  String? best;
  var at = 1 << 30;
  kinds.forEach((key, label) {
    final i = t.indexOf(key);
    if (i >= 0 && i < at) {
      at = i;
      best = label;
    }
  });
  if (best != null) return best;
  final form = growthForm(text);
  if (form == 'Дерево' || form == 'Кустарник' || form == 'Лиана') {
    return 'Многолетнее';
  }
  return null;
}

/// Высота по описанию: «до 20 м», «30–60 см».
String? plantHeight(String text) {
  final m = RegExp(
    r'(?:высот\w*|достига\w*|вырастает|растёт)[^.\n]{0,40}?(до\s+)?(\d+(?:[,.]\d+)?(?:\s*[–—-]\s*\d+(?:[,.]\d+)?)?)\s*(м|см|метр\w*)(?=[\s,.;)]|$)',
    caseSensitive: false,
  ).firstMatch(text);
  if (m == null) return null;
  final unit = m.group(3)!.startsWith('с') ? 'см' : 'м';
  return '${m.group(1) == null ? '' : 'до '}${m.group(2)!.replaceAll(' ', '')} $unit';
}

/// Тип растения по классу в систематике iNaturalist.
String? plantType(Map<String, String> ancestry) => switch (ancestry['class']) {
  'Magnoliopsida' => 'Цветковое, двудольное',
  'Liliopsida' => 'Цветковое, однодольное',
  'Pinopsida' => 'Хвойное',
  'Polypodiopsida' => 'Папоротник',
  'Lycopodiopsida' => 'Плаун',
  'Bryopsida' || 'Polytrichopsida' || 'Sphagnopsida' => 'Мох',
  'Cycadopsida' => 'Саговник',
  'Ginkgoopsida' => 'Гинкго',
  'Gnetopsida' => 'Гнетовое',
  _ => ancestry['subphylum'] == 'Angiospermae' ? 'Цветковое' : null,
};

/// Сорная или инвазивная репутация вида — по нашим спискам.
String weedPotential(InatTaxon t) {
  if (t.isIn(CatalogKind.invasiveIds)) {
    return 'Высокий: инвазивный вид, вытесняет местную флору';
  }
  if (t.isIn({...?CatalogKind.weeds.ids})) {
    return 'Есть: частый сорняк огородов и газонов';
  }
  return 'Не отмечен как сорняк или инвазивный вид';
}

enum ClimateZone {
  tropical(
    'Тропики',
    '18–27 °C круглый год; ниже 15 °C — стресс',
    'Тепло круглый год',
  ),
  subtropical(
    'Субтропики',
    '15–25 °C; зимой может быть прохладнее, 10–15 °C',
    'Тёплое лето, мягкая зима',
  ),
  temperate(
    'Умеренный пояс',
    'Выдерживает холодную зиму; в комнате — прохладная зимовка',
    'Смена сезонов',
  ),
  cold(
    'Холодный климат',
    'Морозостойкое растение северных широт',
    'Короткое лето, морозная зима',
  );

  const ClimateZone(this.label, this.temperature, this.season);
  final String label;
  final String temperature;
  final String season;
}

/// Где вид встречается в природе — доли наблюдений по климатическим поясам (данные GBIF).
class ClimateProfile {
  const ClimateProfile(this.counts);

  final Map<ClimateZone, int> counts;

  int get total => counts.values.fold(0, (a, b) => a + b);

  ClimateZone? get main {
    if (total < 10) return null;
    return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  double share(ClimateZone z) => total == 0 ? 0 : (counts[z] ?? 0) / total;
}

/// GBIF: ключ вида, климатический профиль, карта наблюдений.
class GbifClient {
  GbifClient({http.Client? client}) : _http = client ?? http.Client();

  final http.Client _http;

  Future<Map<String, dynamic>> _get(String path, String query) async {
    final res = await _http
        .get(Uri.parse('https://api.gbif.org/v1/$path?$query'))
        .timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) throw Exception('GBIF ${res.statusCode}');
    return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
  }

  Future<int?> speciesKey(String latin) async {
    final j = await _get(
      'species/match',
      'name=${Uri.encodeQueryComponent(latin)}&kingdom=Plantae',
    );
    if (j['matchType'] == 'NONE') return null;
    return (j['usageKey'] as num?)?.toInt();
  }

  Future<ClimateProfile> climate(int key) async {
    const bands = {
      ClimateZone.tropical: ['-23.5,23.5'],
      ClimateZone.subtropical: ['23.5,35', '-35,-23.5'],
      ClimateZone.temperate: ['35,55', '-55,-35'],
      ClimateZone.cold: ['55,90', '-90,-55'],
    };
    final counts = <ClimateZone, int>{};
    await Future.wait([
      for (final e in bands.entries)
        _get(
          'occurrence/search',
          'taxonKey=$key&hasCoordinate=true&occurrenceStatus=PRESENT&limit=0&'
              '${e.value.map((v) => 'decimalLatitude=$v').join('&')}',
        ).then((j) => counts[e.key] = (j['count'] as num).toInt()),
    ]);
    return ClimateProfile(counts);
  }

  /// Подложка и слой наблюдений одной картинкой мира (512 px).
  static (String, String) mapUrls(int key) => (
    'https://tile.gbif.org/3857/omt/0/0/0@1x.png?style=gbif-light',
    'https://api.gbif.org/v2/map/occurrence/density/0/0/0@1x.png?taxonKey=$key&style=classic.point',
  );
}

/// Русская Википедия: статья по русскому заголовку или латинскому названию (есть перенаправления).
class WikiClient {
  WikiClient({http.Client? client}) : _http = client ?? http.Client();

  final http.Client _http;

  Future<WikiArticle?> article({String? ruUrl, required String latin}) async {
    var title = latin;
    if (ruUrl != null && ruUrl.contains('ru.wikipedia.org/wiki/')) {
      title = Uri.decodeComponent(ruUrl.split('/wiki/').last)
          .replaceAll('_', ' ');
    }
    final uri = Uri.https('ru.wikipedia.org', '/w/api.php', {
      'action': 'query',
      'prop': 'extracts',
      'explaintext': '1',
      'redirects': '1',
      'titles': title,
      'format': 'json',
      'formatversion': '2',
      'origin': '*',
    });
    final res = await _http.get(uri).timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) return null;
    final j = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final page = ((j['query'] as Map?)?['pages'] as List?)?.firstOrNull as Map?;
    final text = page?['extract'] as String?;
    if (page == null ||
        page['missing'] == true ||
        text == null ||
        text.length < 200) {
      return null;
    }
    return parseWikiExtract(page['title'] as String, text);
  }
}

/// Всё, что удалось собрать о виде из открытых источников. Любая часть может отсутствовать.
class SpeciesProfile {
  const SpeciesProfile({
    this.taxon,
    this.wiki,
    this.gbifKey,
    this.climate,
    this.flowering,
  });

  final InatTaxon? taxon;
  final WikiArticle? wiki;
  final int? gbifKey;
  final ClimateProfile? climate;

  /// Наблюдения с цветками по месяцам.
  final Map<int, int>? flowering;

  /// Месяцы цветения: где наблюдений не меньше четверти от пика.
  List<int> get floweringMonths {
    final f = flowering;
    if (f == null || f.values.fold<int>(0, (a, b) => a + b) < 12) {
      return const [];
    }
    final peak = f.values.reduce((a, b) => a > b ? a : b);
    return [
      for (var m = 1; m <= 12; m++)
        if ((f[m] ?? 0) >= peak * 0.25) m,
    ];
  }

  String? get text => wiki?.fullText;
}

final gbifClientProvider = Provider((ref) => GbifClient());
final wikiClientProvider = Provider((ref) => WikiClient());

Future<T?> _safe<T>(Future<T?> Function() f) async {
  try {
    return await f();
  } catch (_) {
    return null;
  }
}

/// Профиль вида по латинскому названию; [taxonId] — если вид уже известен в iNaturalist.
final speciesProfileProvider =
    FutureProvider.family<SpeciesProfile, (String, int?)>((ref, key) async {
      final (latin, taxonId) = key;
      final inat = ref.read(inatClientProvider);
      final gbif = ref.read(gbifClientProvider);
      final place = ref.read(placeProvider);

      final taxonF = _safe(
        () => taxonId != null ? inat.detail(taxonId) : inat.byName(latin),
      );
      final gbifKeyF = _safe(() => gbif.speciesKey(latin));
      final taxon = await taxonF;
      final results = await Future.wait<Object?>([
        _safe(
          () => ref
              .read(wikiClientProvider)
              .article(ruUrl: taxon?.wikipediaUrl, latin: latin),
        ),
        gbifKeyF.then((k) => k == null ? null : _safe(() => gbif.climate(k))),
        if (taxon != null)
          _safe(
            () => inat.floweringByMonth(
              taxon.id,
              lat: place?.lat,
              lng: place?.lon,
            ),
          ),
      ]);
      return SpeciesProfile(
        taxon: taxon,
        wiki: results[0] as WikiArticle?,
        gbifKey: await gbifKeyF,
        climate: results[1] as ClimateProfile?,
        flowering: results.length > 2 ? results[2] as Map<int, int>? : null,
      );
    });
