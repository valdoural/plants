import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models.dart';

/// Вид или род из iNaturalist: названия на русском, фото под свободной лицензией.
class InatTaxon {
  const InatTaxon({
    required this.id,
    required this.name,
    this.commonName,
    this.rank,
    this.photoUrl,
    this.photoAttribution,
    this.wikipediaUrl,
    this.summary,
    this.count,
    this.family,
    this.photos = const [],
    this.ancestorIds = const [],
  });

  final int id;
  final String name;
  final String? commonName;
  final String? rank;
  final String? photoUrl;

  /// Подпись автора фото — показываем мелко под снимком (условие лицензии CC).
  final String? photoAttribution;
  final String? wikipediaUrl;
  final String? summary;

  /// Сколько наблюдений рядом — мерило «популярности» в регионе.
  final int? count;
  final String? family;
  final List<String> photos;

  /// id всех предков (род, семейство…) — чтобы вид из ядовитого рода тоже считался ядовитым.
  final List<int> ancestorIds;

  bool isIn(Set<int> ids) => ids.contains(id) || ancestorIds.any(ids.contains);

  String get displayName {
    final c = commonName;
    if (c == null || c.isEmpty) return name;
    return c[0].toUpperCase() + c.substring(1);
  }

  String get inatUrl => 'https://www.inaturalist.org/taxa/$id';

  static String? _largeUrl(String? medium) => medium?.replaceFirst('/medium.', '/large.');

  factory InatTaxon.fromJson(Map<String, dynamic> j, {int? count}) {
    final photo = j['default_photo'] as Map?;
    final ancestors = (j['ancestors'] as List?) ?? const [];
    final family = ancestors.cast<Map>().where((a) => a['rank'] == 'family').map((a) => a['name'] as String?).firstOrNull;
    // Сначала фото под свободной лицензией (CC), снимки «все права защищены» — в конце.
    final taxonPhotos = ((j['taxon_photos'] as List?) ?? const []).map((tp) => (tp as Map)['photo'] as Map?).whereType<Map>().toList()
      ..sort((a, b) => (a['license_code'] == null ? 1 : 0).compareTo(b['license_code'] == null ? 1 : 0));
    final summary = j['wikipedia_summary'] as String?;
    return InatTaxon(
      id: (j['id'] as num).toInt(),
      name: j['name'] as String? ?? '—',
      commonName: j['preferred_common_name'] as String?,
      rank: j['rank'] as String?,
      photoUrl: photo?['medium_url'] as String?,
      photoAttribution: photo?['attribution'] as String?,
      wikipediaUrl: j['wikipedia_url'] as String?,
      summary: summary == null ? null : _stripHtml(summary),
      count: count,
      family: family,
      photos: taxonPhotos.map((ph) => _largeUrl(ph['medium_url'] as String?)).whereType<String>().toList(),
      ancestorIds: ((j['ancestor_ids'] as List?) ?? const []).map((e) => (e as num).toInt()).toList(),
    );
  }

  /// Для «Добавить в сад» и карточки вида.
  PlantCandidate toCandidate() => PlantCandidate(
        scientificName: name,
        probability: 1,
        commonNames: [?commonName],
        family: family,
        imageUrls: photos.isNotEmpty ? photos : [?_largeUrl(photoUrl)],
        description: summary,
        infoUrl: wikipediaUrl ?? inatUrl,
      );
}

/// Убирает HTML и знаки ударения из текстов Википедии.
String _stripHtml(String s) =>
    s.replaceAll(RegExp(r'<[^>]+>'), '').replaceAll('&nbsp;', ' ').replaceAll('\u0301', '').trim();

/// Клиент открытого API iNaturalist (без ключа, CORS разрешён).
class InatClient {
  InatClient({http.Client? client}) : _http = client ?? http.Client();

  final http.Client _http;
  static const _base = 'https://api.inaturalist.org/v1';
  static const plantae = 47126;

  Future<Map<String, dynamic>> _get(String path, Map<String, String> query) async {
    final uri = Uri.parse('$_base/$path').replace(queryParameters: {...query, 'locale': 'ru'});
    final res = await _http.get(uri).timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) throw Exception('iNaturalist: ${res.statusCode}');
    return Map<String, dynamic>.from(jsonDecode(utf8.decode(res.bodyBytes)) as Map);
  }

  /// Поиск растения по названию (русскому или латинскому).
  Future<List<InatTaxon>> search(String q) async {
    if (q.trim().length < 2) return const [];
    final d = await _get('taxa/autocomplete', {'q': q.trim(), 'per_page': '20', 'taxon_id': '$plantae'});
    return ((d['results'] as List?) ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .where((t) => t['iconic_taxon_name'] == 'Plantae')
        .map(InatTaxon.fromJson)
        .toList();
  }

  /// Самые наблюдаемые растения рядом (с фильтрами — культурные, цветущие, из списка видов).
  Future<List<InatTaxon>> speciesCounts({
    double? lat,
    double? lng,
    int radiusKm = 100,
    bool? captive,
    List<int>? taxonIds,
    bool flowering = false,
    List<int>? months,
    int perPage = 24,
  }) async {
    final q = <String, String>{
      'per_page': '$perPage',
      if (taxonIds == null) 'iconic_taxa': 'Plantae',
      if (taxonIds != null) 'taxon_id': taxonIds.join(','),
      if (lat != null && lng != null) ...{'lat': '$lat', 'lng': '$lng', 'radius': '$radiusKm'},
      if (captive != null) 'captive': '$captive',
      if (flowering) ...{'term_id': '12', 'term_value_id': '13'},
      if (months != null) 'month': months.join(','),
    };
    final d = await _get('observations/species_counts', q);
    return ((d['results'] as List?) ?? const []).map((e) {
      final m = Map<String, dynamic>.from(e as Map);
      return InatTaxon.fromJson(Map<String, dynamic>.from(m['taxon'] as Map), count: (m['count'] as num?)?.toInt());
    }).toList();
  }

  /// Виды по списку id — в заданном порядке (для каталога без геолокации).
  Future<List<InatTaxon>> byIds(List<int> ids) async {
    final d = await _get('taxa/${ids.join(',')}', {});
    final byId = {
      for (final t in ((d['results'] as List?) ?? const []).map((e) => InatTaxon.fromJson(Map<String, dynamic>.from(e as Map))))
        t.id: t,
    };
    return [for (final id in ids) ?byId[id]];
  }

  /// Подробности: описание из Википедии, все фото, семейство.
  Future<InatTaxon> detail(int id) async {
    final d = await _get('taxa/$id', {});
    return InatTaxon.fromJson(Map<String, dynamic>.from((d['results'] as List).first as Map));
  }
}
