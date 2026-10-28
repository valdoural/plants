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

enum PlantAge {
  seedling('Сеянец или черенок'),
  young('Молодое'),
  mature('Взрослое'),
  old('Старое, крупное');

  const PlantAge(this.label);
  final String label;
}

/// Освещение на месте, где стоит растение.
enum PlantLight {
  sun('Прямое солнце', 'Южное окно, солнце больше 4 часов'),
  bright('Яркий рассеянный', 'Восток или запад, рядом с окном'),
  partial('Полутень', '1–2 метра от окна'),
  shade('Тень', 'Северное окно или глубина комнаты');

  const PlantLight(this.label, this.hint);
  final String label;
  final String hint;
}

enum PotType {
  plastic('Пластик'),
  glazed('Керамика с глазурью'),
  terracotta('Терракота без глазури'),
  ground('В грунте');

  const PotType(this.label);
  final String label;
}

/// Условия растения: возраст, свет и горшок. Все поля необязательны.
class PlantConditions {
  const PlantConditions({
    this.age,
    this.light,
    this.pot,
    this.drainage,
    this.potCm,
  });

  final PlantAge? age;
  final PlantLight? light;
  final PotType? pot;

  /// Есть ли дренажные отверстия.
  final bool? drainage;

  /// Диаметр горшка, см.
  final int? potCm;

  bool get isEmpty =>
      age == null &&
      light == null &&
      pot == null &&
      drainage == null &&
      potCm == null;

  Map<String, dynamic> toJson() => {
    'age': age?.name,
    'light': light?.name,
    'pot': pot?.name,
    'drainage': drainage,
    'pot_cm': potCm,
  };

  factory PlantConditions.fromJson(Map<String, dynamic>? j) => j == null
      ? const PlantConditions()
      : PlantConditions(
          age: PlantAge.values.asNameMap()[j['age']],
          light: PlantLight.values.asNameMap()[j['light']],
          pot: PotType.values.asNameMap()[j['pot']],
          drainage: j['drainage'] as bool?,
          potCm: (j['pot_cm'] as num?)?.toInt(),
        );
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
    this.conditions = const PlantConditions(),
    this.collectionIds = const [],
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
  final PlantConditions conditions;

  /// Пользовательские папки, в которые входит растение.
  final List<String> collectionIds;

  Plant copyWith({
    String? nickname,
    String? photoUrl,
    PlantLocation? location,
    PlantConditions? conditions,
    List<String>? collectionIds,
  }) => Plant(
    id: id,
    nickname: nickname ?? this.nickname,
    scientificName: scientificName,
    commonName: commonName,
    photoUrl: photoUrl ?? this.photoUrl,
    location: location ?? this.location,
    createdAt: createdAt,
    species: species,
    conditions: conditions ?? this.conditions,
    collectionIds: collectionIds ?? this.collectionIds,
  );

  /// «Это не то растение»: тот же экземпляр, другой вид.
  Plant withSpecies(PlantCandidate s) => Plant(
    id: id,
    nickname: nickname,
    scientificName: s.scientificName,
    commonName: s.commonNames.firstOrNull,
    photoUrl: photoUrl ?? s.imageUrls.firstOrNull,
    location: location,
    createdAt: createdAt,
    species: s,
    conditions: conditions,
    collectionIds: collectionIds,
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
    'conditions': conditions.toJson(),
    'collection_ids': collectionIds,
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
    conditions: PlantConditions.fromJson(
      j['conditions'] == null
          ? null
          : Map<String, dynamic>.from(j['conditions'] as Map),
    ),
    collectionIds: _strings(j['collection_ids']),
  );
}

/// Своя папка в саду («Кухня», «Суккуленты»…).
class PlantCollection {
  const PlantCollection({
    required this.id,
    required this.name,
    required this.createdAt,
  });

  final String id;
  final String name;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'created_at': createdAt.toUtc().toIso8601String(),
  };

  factory PlantCollection.fromJson(Map<String, dynamic> j) => PlantCollection(
    id: j['id'] as String,
    name: j['name'] as String,
    createdAt: _date(j['created_at']) ?? DateTime.now(),
  );
}

/// Растение из списка желаний — вид, который хочется вырастить.
class WishItem {
  const WishItem({
    required this.id,
    required this.scientificName,
    required this.createdAt,
    this.taxonId,
    this.commonName,
    this.photoUrl,
  });

  final String id;
  final int? taxonId;
  final String scientificName;
  final String? commonName;
  final String? photoUrl;
  final DateTime createdAt;

  String get displayName => commonName == null || commonName!.isEmpty
      ? scientificName
      : _capitalize(commonName!);

  Map<String, dynamic> toJson() => {
    'id': id,
    'taxon_id': taxonId,
    'scientific_name': scientificName,
    'common_name': commonName,
    'photo_url': photoUrl,
    'created_at': createdAt.toUtc().toIso8601String(),
  };

  factory WishItem.fromJson(Map<String, dynamic> j) => WishItem(
    id: j['id'] as String,
    taxonId: (j['taxon_id'] as num?)?.toInt(),
    scientificName: j['scientific_name'] as String,
    commonName: j['common_name'] as String?,
    photoUrl: j['photo_url'] as String?,
    createdAt: _date(j['created_at']) ?? DateTime.now(),
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
    this.collections = const [],
    this.wishlist = const [],
  });

  final List<Plant> plants;
  final List<CareTask> tasks;
  final List<Note> notes;
  final List<IdentificationRecord> identifications;
  final List<DiagnosisRecord> diagnoses;
  final List<PlantCollection> collections;
  final List<WishItem> wishlist;

  bool isWished(int taxonId) => wishlist.any((w) => w.taxonId == taxonId);

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
