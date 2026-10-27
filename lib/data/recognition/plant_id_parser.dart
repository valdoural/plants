import '../models.dart';

Map<String, dynamic> _map(Object? v) => v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
List<dynamic> _list(Object? v) => v is List ? v : const [];
String? _str(Object? v) {
  if (v is String) return v.isEmpty ? null : v;
  if (v is Map) return _str(v['value']);
  return null;
}

/// Разбор ответа POST /api/v3/identification.
IdentificationResult parsePlantIdIdentification(Map<String, dynamic> json) {
  final result = _map(json['result']);
  final suggestions = _list(_map(result['classification'])['suggestions']);
  return IdentificationResult(
    provider: 'Plant.id',
    isPlantProbability: (_map(result['is_plant'])['probability'] as num?)?.toDouble(),
    candidates: suggestions.map((s) {
      final m = _map(s);
      final d = _map(m['details']);
      final taxonomy = _map(d['taxonomy']);
      final watering = _map(d['watering']);
      final min = (watering['min'] as num?)?.toDouble();
      final max = (watering['max'] as num?)?.toDouble();
      final images = <String>[
        ?_str(d['image']),
        ..._list(m['similar_images']).map((i) => _str(_map(i)['url'])).whereType<String>(),
      ];
      return PlantCandidate(
        scientificName: m['name'] as String? ?? '—',
        probability: (m['probability'] as num?)?.toDouble() ?? 0,
        commonNames: _list(d['common_names']).map((e) => e.toString()).toList(),
        family: taxonomy['family'] as String?,
        genus: taxonomy['genus'] as String?,
        imageUrls: images,
        description: _str(d['description']),
        infoUrl: d['url'] as String?,
        wateringLevel: min == null && max == null ? null : ((min ?? max!) + (max ?? min!)) / 2,
        light: _str(d['best_light_condition']),
        soil: _str(d['best_soil_type']),
        toxicity: _str(d['toxicity']),
        gbifId: (d['gbif_id'] as num?)?.toInt(),
      );
    }).toList(),
  );
}

/// Разбор ответа POST /api/v3/health_assessment.
HealthResult parsePlantIdHealth(Map<String, dynamic> json) {
  final result = _map(json['result']);
  final healthy = _map(result['is_healthy']);
  final suggestions = _list(_map(result['disease'])['suggestions']);
  return HealthResult(
    healthyProbability: (healthy['probability'] as num?)?.toDouble() ?? 0,
    diseases: suggestions.map((s) {
      final m = _map(s);
      final d = _map(m['details']);
      final t = _map(d['treatment']);
      List<String> steps(String k) => _list(t[k]).map((e) => e.toString()).toList();
      return DiseaseSuggestion(
        name: (d['local_name'] as String?) ?? (m['name'] as String? ?? '—'),
        probability: (m['probability'] as num?)?.toDouble() ?? 0,
        description: _str(d['description']),
        cause: _str(d['cause']),
        biological: steps('biological'),
        chemical: steps('chemical'),
        prevention: steps('prevention'),
        imageUrls: _list(m['similar_images']).map((i) => _str(_map(i)['url'])).whereType<String>().toList(),
      );
    }).toList(),
  );
}
