import '../models.dart';

Map<String, dynamic> _map(Object? v) =>
    v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
List<dynamic> _list(Object? v) => v is List ? v : const [];

/// Разбор ответа POST /v2/identify/{project}.
IdentificationResult parsePlantNet(Map<String, dynamic> json) {
  final results = _list(json['results']);
  return IdentificationResult(
    provider: 'Pl@ntNet',
    candidates: results.map((r) {
      final m = _map(r);
      final species = _map(m['species']);
      final name = species['scientificNameWithoutAuthor'] as String? ?? '—';
      final gbifRaw = _map(m['gbif'])['id'];
      final gbif = gbifRaw is num
          ? gbifRaw.toInt()
          : int.tryParse('${gbifRaw ?? ''}');
      return PlantCandidate(
        scientificName: name,
        probability: (m['score'] as num?)?.toDouble() ?? 0,
        commonNames: _list(species['commonNames'])
            .map((e) => e.toString())
            .toList(),
        family:
            _map(species['family'])['scientificNameWithoutAuthor'] as String?,
        genus: _map(species['genus'])['scientificNameWithoutAuthor'] as String?,
        imageUrls: _list(m['images'])
            .map((i) => _map(_map(i)['url']))
            .map((u) => (u['m'] ?? u['o'] ?? u['s']) as String?)
            .whereType<String>()
            .toList(),
        infoUrl: gbif != null
            ? 'https://www.gbif.org/species/$gbif'
            : 'https://www.gbif.org/species/search?q=${Uri.encodeQueryComponent(name)}',
        gbifId: gbif,
      );
    }).toList(),
  );
}
