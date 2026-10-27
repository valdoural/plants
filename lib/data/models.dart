import 'package:uuid/uuid.dart';

const _uuid = Uuid();
String newId() => _uuid.v4();

DateTime? _date(Object? v) =>
    v == null ? null : DateTime.parse(v as String).toLocal();
List<String> _strings(Object? v) =>
    (v as List?)?.map((e) => e.toString()).toList() ?? const [];

/// Один вариант вида, который вернул сервис распознавания.
class PlantCandidate {
  const PlantCandidate({
    required this.scientificName,
    required this.probability,
    this.commonNames = const [],
    this.family,
    this.genus,
    this.imageUrls = const [],
    this.description,
    this.infoUrl,
    this.wateringLevel,
    this.light,
    this.soil,
    this.toxicity,
    this.gbifId,
  });

  final String scientificName;
  final double probability;
  final List<String> commonNames;
  final String? family;
  final String? genus;
  final List<String> imageUrls;
  final String? description;
  final String? infoUrl;

  /// 1 — засухоустойчивое, 2 — умеренный полив, 3 — влаголюбивое.
  final double? wateringLevel;
  final String? light;
  final String? soil;
  final String? toxicity;
  final int? gbifId;

  String get displayName =>
      commonNames.isNotEmpty ? _capitalize(commonNames.first) : scientificName;

  /// Рекомендуемый интервал полива в днях.
  int get suggestedWateringDays {
    final w = wateringLevel;
    if (w == null) return 7;
    if (w <= 1.4) return 14;
    if (w >= 2.6) return 3;
    return 7;
  }

  Map<String, dynamic> toJson() => {
    'scientific_name': scientificName,
    'probability': probability,
    'common_names': commonNames,
    'family': family,
    'genus': genus,
    'image_urls': imageUrls,
    'description': description,
    'info_url': infoUrl,
    'watering_level': wateringLevel,
    'light': light,
    'soil': soil,
    'toxicity': toxicity,
    'gbif_id': gbifId,
  };

  factory PlantCandidate.fromJson(Map<String, dynamic> j) => PlantCandidate(
    scientificName: j['scientific_name'] as String,
    probability: (j['probability'] as num?)?.toDouble() ?? 0,
    commonNames: _strings(j['common_names']),
    family: j['family'] as String?,
    genus: j['genus'] as String?,
    imageUrls: _strings(j['image_urls']),
    description: j['description'] as String?,
    infoUrl: j['info_url'] as String?,
    wateringLevel: (j['watering_level'] as num?)?.toDouble(),
    light: j['light'] as String?,
    soil: j['soil'] as String?,
    toxicity: j['toxicity'] as String?,
    gbifId: (j['gbif_id'] as num?)?.toInt(),
  );
}

String _capitalize(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

class IdentificationResult {
  const IdentificationResult({
    required this.provider,
    required this.candidates,
    this.isPlantProbability,
  });

  final String provider;
  final List<PlantCandidate> candidates;
  final double? isPlantProbability;
}

class DiseaseSuggestion {
  const DiseaseSuggestion({
    required this.name,
    required this.probability,
    this.description,
    this.cause,
    this.biological = const [],
    this.chemical = const [],
    this.prevention = const [],
    this.imageUrls = const [],
  });

  final String name;
  final double probability;
  final String? description;
  final String? cause;
  final List<String> biological;
  final List<String> chemical;
  final List<String> prevention;
  final List<String> imageUrls;

  Map<String, dynamic> toJson() => {
    'name': name,
    'probability': probability,
    'description': description,
    'cause': cause,
    'biological': biological,
    'chemical': chemical,
    'prevention': prevention,
    'image_urls': imageUrls,
  };

  factory DiseaseSuggestion.fromJson(Map<String, dynamic> j) =>
      DiseaseSuggestion(
        name: j['name'] as String,
        probability: (j['probability'] as num?)?.toDouble() ?? 0,
        description: j['description'] as String?,
        cause: j['cause'] as String?,
        biological: _strings(j['biological']),
        chemical: _strings(j['chemical']),
        prevention: _strings(j['prevention']),
        imageUrls: _strings(j['image_urls']),
      );
}

class HealthResult {
  const HealthResult({
    required this.healthyProbability,
    required this.diseases,
  });

  final double healthyProbability;
  final List<DiseaseSuggestion> diseases;

  bool get isHealthy => healthyProbability >= 0.5;

  Map<String, dynamic> toJson() => {
    'healthy_probability': healthyProbability,
    'diseases': diseases.map((d) => d.toJson()).toList(),
  };

  factory HealthResult.fromJson(Map<String, dynamic> j) => HealthResult(
    healthyProbability: (j['healthy_probability'] as num).toDouble(),
    diseases: ((j['diseases'] as List?) ?? const [])
        .map(
          (e) =>
              DiseaseSuggestion.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList(),
  );
}

enum PlantLocation {
  indoor('Дома'),
  outdoor('На улице'),
  balcony('Балкон');

  const PlantLocation(this.label);
  final String label;
}

/// Растение в «Моём саду».
class Plant {
  const Plant({
    required this.id,
    required this.nickname,
    required this.createdAt,
    this.scientificName,
    this.commonName,
    this.photoUrl,
    this.location = PlantLocation.indoor,
    this.species,
  });

  final String id;
  final String nickname;
  final String? scientificName;
  final String? commonName;
  final String? photoUrl;
  final PlantLocation location;
  final DateTime createdAt;

  /// Снимок данных о виде на момент добавления.
  final PlantCandidate? species;

  Plant copyWith({
    String? nickname,
    String? photoUrl,
    PlantLocation? location,
  }) => Plant(
    id: id,
    nickname: nickname ?? this.nickname,
    scientificName: scientificName,
    commonName: commonName,
    photoUrl: photoUrl ?? this.photoUrl,
    location: location ?? this.location,
    createdAt: createdAt,
    species: species,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'nickname': nickname,
    'scientific_name': scientificName,
    'common_name': commonName,
    'photo_url': photoUrl,
    'location': location.name,
    'created_at': createdAt.toUtc().toIso8601String(),
    'species': species?.toJson(),
  };

  factory Plant.fromJson(Map<String, dynamic> j) => Plant(
    id: j['id'] as String,
    nickname: j['nickname'] as String,
    scientificName: j['scientific_name'] as String?,
    commonName: j['common_name'] as String?,
    photoUrl: j['photo_url'] as String?,
    location:
        PlantLocation.values.asNameMap()[j['location']] ?? PlantLocation.indoor,
    createdAt: _date(j['created_at']) ?? DateTime.now(),
    species: j['species'] == null
        ? null
        : PlantCandidate.fromJson(
            Map<String, dynamic>.from(j['species'] as Map),
          ),
  );
}

enum CareType {
  water('Полив'),
  fertilize('Подкормка'),
  mist('Опрыскивание'),
  repot('Пересадка'),
  prune('Обрезка'),
  rotate('Повернуть к свету');

  const CareType(this.label);
  final String label;

  int get defaultIntervalDays => switch (this) {
    CareType.water => 7,
    CareType.fertilize => 30,
    CareType.mist => 3,
    CareType.repot => 365,
    CareType.prune => 90,
    CareType.rotate => 14,
  };
}

/// Регулярная задача ухода (напоминание).
class CareTask {
  const CareTask({
    required this.id,
    required this.plantId,
    required this.type,
    required this.intervalDays,
    required this.nextDue,
    this.lastDone,
    this.enabled = true,
  });

  final String id;
  final String plantId;
  final CareType type;
  final int intervalDays;
  final DateTime nextDue;
  final DateTime? lastDone;
  final bool enabled;

  factory CareTask.create(String plantId, CareType type, {int? intervalDays}) {
    final today = DateTime.now();
    return CareTask(
      id: newId(),
      plantId: plantId,
      type: type,
      intervalDays: intervalDays ?? type.defaultIntervalDays,
      nextDue: DateTime(today.year, today.month, today.day),
    );
  }

  bool get isDue => enabled && !nextDue.isAfter(DateTime.now());

  int get daysLeft {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(nextDue.year, nextDue.month, nextDue.day);
    return due.difference(today).inDays;
  }

  CareTask complete() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return _copy(
      lastDone: now,
      nextDue: today.add(Duration(days: intervalDays)),
    );
  }

  CareTask snooze([int days = 1]) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return _copy(nextDue: today.add(Duration(days: days)));
  }

  CareTask withInterval(int days) {
    final base = lastDone ?? DateTime.now();
    final start = DateTime(base.year, base.month, base.day);
    return _copy(
      intervalDays: days,
      nextDue: lastDone == null ? nextDue : start.add(Duration(days: days)),
    );
  }

  CareTask _copy({int? intervalDays, DateTime? nextDue, DateTime? lastDone}) =>
      CareTask(
        id: id,
        plantId: plantId,
        type: type,
        intervalDays: intervalDays ?? this.intervalDays,
        nextDue: nextDue ?? this.nextDue,
        lastDone: lastDone ?? this.lastDone,
        enabled: enabled,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'plant_id': plantId,
    'type': type.name,
    'interval_days': intervalDays,
    'next_due': nextDue.toUtc().toIso8601String(),
    'last_done': lastDone?.toUtc().toIso8601String(),
    'enabled': enabled,
  };

  factory CareTask.fromJson(Map<String, dynamic> j) => CareTask(
    id: j['id'] as String,
    plantId: j['plant_id'] as String,
    type: CareType.values.asNameMap()[j['type']] ?? CareType.water,
    intervalDays: (j['interval_days'] as num).toInt(),
    nextDue: _date(j['next_due'])!,
    lastDone: _date(j['last_done']),
    enabled: j['enabled'] as bool? ?? true,
  );
}

class Note {
  const Note({
    required this.id,
    required this.plantId,
    required this.text,
    required this.createdAt,
    this.photoUrl,
  });

  final String id;
  final String plantId;
  final String text;
  final String? photoUrl;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'plant_id': plantId,
    'text': text,
    'photo_url': photoUrl,
    'created_at': createdAt.toUtc().toIso8601String(),
  };

  factory Note.fromJson(Map<String, dynamic> j) => Note(
    id: j['id'] as String,
    plantId: j['plant_id'] as String,
    text: j['text'] as String? ?? '',
    photoUrl: j['photo_url'] as String?,
    createdAt: _date(j['created_at']) ?? DateTime.now(),
  );
}

/// Запись в истории распознаваний.
class IdentificationRecord {
  const IdentificationRecord({
    required this.id,
    required this.provider,
    required this.candidates,
    required this.createdAt,
    this.photoUrl,
  });

  final String id;
  final String provider;
  final String? photoUrl;
  final List<PlantCandidate> candidates;
  final DateTime createdAt;

  PlantCandidate? get top => candidates.isEmpty ? null : candidates.first;

  Map<String, dynamic> toJson() => {
    'id': id,
    'provider': provider,
    'photo_url': photoUrl,
    'candidates': candidates.map((c) => c.toJson()).toList(),
    'created_at': createdAt.toUtc().toIso8601String(),
  };

  factory IdentificationRecord.fromJson(Map<String, dynamic> j) =>
      IdentificationRecord(
        id: j['id'] as String,
        provider: j['provider'] as String,
        photoUrl: j['photo_url'] as String?,
        candidates: ((j['candidates'] as List?) ?? const [])
            .map(
              (e) =>
                  PlantCandidate.fromJson(Map<String, dynamic>.from(e as Map)),
            )
            .toList(),
        createdAt: _date(j['created_at']) ?? DateTime.now(),
      );
}

class DiagnosisRecord {
  const DiagnosisRecord({
    required this.id,
    required this.result,
    required this.createdAt,
    this.photoUrl,
    this.plantId,
  });

  final String id;
  final String? plantId;
  final String? photoUrl;
  final HealthResult result;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'plant_id': plantId,
    'photo_url': photoUrl,
    'result': result.toJson(),
    'created_at': createdAt.toUtc().toIso8601String(),
  };

  factory DiagnosisRecord.fromJson(Map<String, dynamic> j) => DiagnosisRecord(
    id: j['id'] as String,
    plantId: j['plant_id'] as String?,
    photoUrl: j['photo_url'] as String?,
    result: HealthResult.fromJson(
      Map<String, dynamic>.from(j['result'] as Map),
    ),
    createdAt: _date(j['created_at']) ?? DateTime.now(),
  );
}

class GardenData {
  const GardenData({
    this.plants = const [],
    this.tasks = const [],
    this.notes = const [],
    this.identifications = const [],
    this.diagnoses = const [],
  });

  final List<Plant> plants;
  final List<CareTask> tasks;
  final List<Note> notes;
  final List<IdentificationRecord> identifications;
  final List<DiagnosisRecord> diagnoses;

  Plant? plant(String id) => plants.where((p) => p.id == id).firstOrNull;
  List<CareTask> tasksFor(String plantId) =>
      tasks.where((t) => t.plantId == plantId).toList();
  List<Note> notesFor(String plantId) =>
      notes.where((n) => n.plantId == plantId).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  List<CareTask> get dueTasks =>
      tasks.where((t) => t.isDue && plant(t.plantId) != null).toList()
        ..sort((a, b) => a.nextDue.compareTo(b.nextDue));
}
