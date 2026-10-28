import 'dart:convert';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';

import '../models.dart';
import 'garden_repository.dart';

/// Данные хранятся на устройстве (в браузере — в localStorage).
/// Фото сохраняются уменьшенными, в виде data:-ссылок.
class LocalGardenRepository implements GardenRepository {
  LocalGardenRepository(this._prefs);

  final SharedPreferences _prefs;

  @override
  String get label => 'На этом устройстве';

  static const _plants = 'garden.plants';
  static const _tasks = 'garden.tasks';
  static const _notes = 'garden.notes';
  static const _idents = 'garden.identifications';
  static const _diags = 'garden.diagnoses';
  static const _collections = 'garden.collections';
  static const _wishlist = 'garden.wishlist';

  List<Map<String, dynamic>> _read(String key) {
    final raw = _prefs.getString(key);
    if (raw == null) return [];
    return (jsonDecode(raw) as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<void> _upsert(
    String key,
    Map<String, dynamic> item, {
    int? keepLast,
  }) async {
    final items = _read(key)..removeWhere((e) => e['id'] == item['id']);
    items.insert(0, item);
    if (keepLast != null && items.length > keepLast) {
      items.removeRange(keepLast, items.length);
    }
    await _prefs.setString(key, jsonEncode(items));
  }

  Future<void> _delete(
    String key,
    bool Function(Map<String, dynamic>) test,
  ) async {
    final items = _read(key)..removeWhere(test);
    await _prefs.setString(key, jsonEncode(items));
  }

  @override
  Future<GardenData> load() async => GardenData(
    plants: _read(_plants).map(Plant.fromJson).toList(),
    tasks: _read(_tasks).map(CareTask.fromJson).toList(),
    notes: _read(_notes).map(Note.fromJson).toList(),
    identifications: _read(_idents).map(IdentificationRecord.fromJson).toList(),
    diagnoses: _read(_diags).map(DiagnosisRecord.fromJson).toList(),
    collections: _read(_collections).map(PlantCollection.fromJson).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt)),
    wishlist: _read(_wishlist).map(WishItem.fromJson).toList(),
  );

  @override
  Future<void> savePlant(Plant plant) => _upsert(_plants, plant.toJson());

  @override
  Future<void> deletePlant(String id) async {
    await _delete(_plants, (e) => e['id'] == id);
    await _delete(_tasks, (e) => e['plant_id'] == id);
    await _delete(_notes, (e) => e['plant_id'] == id);
  }

  @override
  Future<void> saveTask(CareTask task) => _upsert(_tasks, task.toJson());

  @override
  Future<void> deleteTask(String id) => _delete(_tasks, (e) => e['id'] == id);

  @override
  Future<void> saveNote(Note note) => _upsert(_notes, note.toJson());

  @override
  Future<void> deleteNote(String id) => _delete(_notes, (e) => e['id'] == id);

  // История ограничена, чтобы не упереться в лимит localStorage (~5 МБ).
  @override
  Future<void> saveIdentification(IdentificationRecord record) =>
      _upsert(_idents, record.toJson(), keepLast: 30);

  @override
  Future<void> deleteIdentification(String id) =>
      _delete(_idents, (e) => e['id'] == id);

  @override
  Future<void> saveDiagnosis(DiagnosisRecord record) =>
      _upsert(_diags, record.toJson(), keepLast: 20);

  @override
  Future<void> deleteDiagnosis(String id) =>
      _delete(_diags, (e) => e['id'] == id);

  @override
  Future<void> saveCollection(PlantCollection collection) =>
      _upsert(_collections, collection.toJson());

  @override
  Future<void> deleteCollection(String id) =>
      _delete(_collections, (e) => e['id'] == id);

  @override
  Future<void> saveWish(WishItem item) => _upsert(_wishlist, item.toJson());

  @override
  Future<void> deleteWish(String id) =>
      _delete(_wishlist, (e) => e['id'] == id);

  @override
  Future<String> storePhoto(Uint8List jpegBytes) async =>
      'data:image/jpeg;base64,${base64Encode(jpegBytes)}';
}
