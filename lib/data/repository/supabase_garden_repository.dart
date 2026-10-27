import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models.dart';
import 'garden_repository.dart';

/// Данные в Supabase: синхронизируются между устройствами, фото — в Storage.
/// Схема и политики доступа: supabase/migrations.
class SupabaseGardenRepository implements GardenRepository {
  SupabaseGardenRepository(this._db);

  final SupabaseClient _db;

  @override
  String get label => 'Supabase (облако)';

  Future<List<Map<String, dynamic>>> _select(
    String table, {
    String order = 'created_at',
  }) async {
    final rows = await _db.from(table).select().order(order, ascending: false);
    return rows.map(Map<String, dynamic>.from).toList();
  }

  @override
  Future<GardenData> load() async {
    final results = await Future.wait([
      _select('plants'),
      _select('care_tasks', order: 'next_due'),
      _select('notes'),
      _select('identifications'),
      _select('diagnoses'),
    ]);
    return GardenData(
      plants: results[0].map(Plant.fromJson).toList(),
      tasks: results[1].map(CareTask.fromJson).toList(),
      notes: results[2].map(Note.fromJson).toList(),
      identifications: results[3].map(IdentificationRecord.fromJson).toList(),
      diagnoses: results[4].map(DiagnosisRecord.fromJson).toList(),
    );
  }

  Future<void> _upsert(String table, Map<String, dynamic> row) =>
      _db.from(table).upsert(row);
  Future<void> _delete(String table, String id) =>
      _db.from(table).delete().eq('id', id);

  @override
  Future<void> savePlant(Plant plant) => _upsert('plants', plant.toJson());

  // Задачи и заметки удаляются каскадно (on delete cascade).
  @override
  Future<void> deletePlant(String id) => _delete('plants', id);

  @override
  Future<void> saveTask(CareTask task) => _upsert('care_tasks', task.toJson());

  @override
  Future<void> deleteTask(String id) => _delete('care_tasks', id);

  @override
  Future<void> saveNote(Note note) => _upsert('notes', note.toJson());

  @override
  Future<void> deleteNote(String id) => _delete('notes', id);

  @override
  Future<void> saveIdentification(IdentificationRecord record) =>
      _upsert('identifications', record.toJson());

  @override
  Future<void> deleteIdentification(String id) =>
      _delete('identifications', id);

  @override
  Future<void> saveDiagnosis(DiagnosisRecord record) =>
      _upsert('diagnoses', record.toJson());

  @override
  Future<void> deleteDiagnosis(String id) => _delete('diagnoses', id);

  @override
  Future<String> storePhoto(Uint8List jpegBytes) async {
    final uid = _db.auth.currentUser!.id;
    final path = '$uid/${newId()}.jpg';
    await _db.storage
        .from('photos')
        .uploadBinary(
          path,
          jpegBytes,
          fileOptions: const FileOptions(contentType: 'image/jpeg'),
        );
    return _db.storage.from('photos').getPublicUrl(path);
  }
}
