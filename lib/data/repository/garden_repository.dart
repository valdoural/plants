import 'dart:typed_data';

import '../models.dart';

/// Хранилище данных сада. Две реализации: локальная (на устройстве) и Supabase.
abstract interface class GardenRepository {
  /// Короткое описание для экрана настроек.
  String get label;

  Future<GardenData> load();

  Future<void> savePlant(Plant plant);
  Future<void> deletePlant(String id);

  Future<void> saveTask(CareTask task);
  Future<void> deleteTask(String id);

  Future<void> saveNote(Note note);
  Future<void> deleteNote(String id);

  Future<void> saveIdentification(IdentificationRecord record);
  Future<void> deleteIdentification(String id);

  Future<void> saveDiagnosis(DiagnosisRecord record);
  Future<void> deleteDiagnosis(String id);

  Future<void> saveCollection(PlantCollection collection);
  Future<void> deleteCollection(String id);

  Future<void> saveWish(WishItem item);
  Future<void> deleteWish(String id);

  /// Сохраняет фото и возвращает ссылку (https:// или data:).
  Future<String> storePhoto(Uint8List jpegBytes);
}
