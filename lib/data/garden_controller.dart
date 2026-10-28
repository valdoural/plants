import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models.dart';
import 'repository/garden_repository.dart';

final gardenRepositoryProvider = Provider<GardenRepository>(
  (ref) => throw UnimplementedError('override in main'),
);

final gardenProvider = AsyncNotifierProvider<GardenController, GardenData>(
  GardenController.new,
);

/// Состояние «Моего сада»: растения, задачи ухода, заметки и история.
/// После каждого изменения данные перечитываются из хранилища — просто и надёжно для объёмов одного пользователя.
class GardenController extends AsyncNotifier<GardenData> {
  GardenRepository get _repo => ref.read(gardenRepositoryProvider);

  @override
  Future<GardenData> build() => ref.watch(gardenRepositoryProvider).load();

  Future<void> _run(Future<void> Function() change) async {
    await change();
    state = AsyncData(await _repo.load());
  }

  Future<String> storePhoto(Uint8List bytes) => _repo.storePhoto(bytes);

  Future<Plant> addPlant({
    required String nickname,
    PlantCandidate? species,
    Uint8List? photo,
    PlantLocation location = PlantLocation.indoor,
    Map<CareType, int> care = const {CareType.water: 7},
  }) async {
    final photoUrl = photo != null
        ? await _repo.storePhoto(photo)
        : species?.imageUrls.firstOrNull;
    final plant = Plant(
      id: newId(),
      nickname: nickname,
      scientificName: species?.scientificName,
      commonName: species?.commonNames.firstOrNull,
      photoUrl: photoUrl,
      location: location,
      createdAt: DateTime.now(),
      species: species,
    );
    await _run(() async {
      await _repo.savePlant(plant);
      for (final e in care.entries) {
        await _repo.saveTask(
          CareTask.create(plant.id, e.key, intervalDays: e.value),
        );
      }
    });
    return plant;
  }

  Future<void> updatePlant(Plant plant) => _run(() => _repo.savePlant(plant));
  Future<void> deletePlant(String id) => _run(() => _repo.deletePlant(id));

  Future<void> saveTask(CareTask task) => _run(() => _repo.saveTask(task));
  Future<void> deleteTask(String id) => _run(() => _repo.deleteTask(id));
  Future<void> completeTask(CareTask task) => saveTask(task.complete());
  Future<void> snoozeTask(CareTask task, [int days = 1]) =>
      saveTask(task.snooze(days));

  Future<void> addNote(String plantId, String text, {Uint8List? photo}) async {
    final photoUrl = photo == null ? null : await _repo.storePhoto(photo);
    await _run(
      () => _repo.saveNote(
        Note(
          id: newId(),
          plantId: plantId,
          text: text,
          photoUrl: photoUrl,
          createdAt: DateTime.now(),
        ),
      ),
    );
  }

  Future<void> deleteNote(String id) => _run(() => _repo.deleteNote(id));

  Future<IdentificationRecord> addIdentification(
    IdentificationResult result,
    Uint8List photo,
  ) async {
    final record = IdentificationRecord(
      id: newId(),
      provider: result.provider,
      photoUrl: await _repo.storePhoto(photo),
      candidates: result.candidates,
      createdAt: DateTime.now(),
    );
    await _run(() => _repo.saveIdentification(record));
    return record;
  }

  Future<void> deleteIdentification(String id) =>
      _run(() => _repo.deleteIdentification(id));

  Future<DiagnosisRecord> addDiagnosis(
    HealthResult result,
    Uint8List photo, {
    String? plantId,
  }) async {
    final record = DiagnosisRecord(
      id: newId(),
      plantId: plantId,
      photoUrl: await _repo.storePhoto(photo),
      result: result,
      createdAt: DateTime.now(),
    );
    await _run(() => _repo.saveDiagnosis(record));
    return record;
  }

  Future<void> deleteDiagnosis(String id) =>
      _run(() => _repo.deleteDiagnosis(id));

  Future<PlantCollection> addCollection(String name) async {
    final c = PlantCollection(
      id: newId(),
      name: name,
      createdAt: DateTime.now(),
    );
    await _run(() => _repo.saveCollection(c));
    return c;
  }

  Future<void> renameCollection(PlantCollection c, String name) => _run(
    () => _repo.saveCollection(
      PlantCollection(id: c.id, name: name, createdAt: c.createdAt),
    ),
  );

  /// Удаляет папку; растения остаются в саду.
  Future<void> deleteCollection(String id) => _run(() async {
    final data = await _repo.load();
    for (final p in data.plants.where((p) => p.collectionIds.contains(id))) {
      await _repo.savePlant(
        p.copyWith(
          collectionIds: p.collectionIds.where((c) => c != id).toList(),
        ),
      );
    }
    await _repo.deleteCollection(id);
  });

  /// Добавляет вид в список желаний или убирает, если он уже там.
  Future<bool> toggleWish({
    required int taxonId,
    required String scientificName,
    String? commonName,
    String? photoUrl,
  }) async {
    final existing = state.value?.wishlist
        .where((w) => w.taxonId == taxonId)
        .firstOrNull;
    if (existing != null) {
      await _run(() => _repo.deleteWish(existing.id));
      return false;
    }
    await _run(
      () => _repo.saveWish(
        WishItem(
          id: newId(),
          taxonId: taxonId,
          scientificName: scientificName,
          commonName: commonName,
          photoUrl: photoUrl,
          createdAt: DateTime.now(),
        ),
      ),
    );
    return true;
  }

  Future<void> deleteWish(String id) => _run(() => _repo.deleteWish(id));
}
