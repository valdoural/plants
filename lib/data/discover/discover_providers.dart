import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/settings.dart';
import 'catalog.dart';
import 'inat.dart';
import 'place_weather.dart';

final inatClientProvider = Provider<InatClient>((ref) => InatClient());
final placeWeatherClientProvider = Provider<PlaceWeatherClient>(
  (ref) => PlaceWeatherClient(),
);

/// Место пользователя: определяется по геолокации или выбирается вручную; хранится на устройстве.
final placeProvider = NotifierProvider<PlaceController, UserPlace?>(
  PlaceController.new,
);

class PlaceController extends Notifier<UserPlace?> {
  static const _key = 'place';

  @override
  UserPlace? build() {
    final raw = ref.read(sharedPrefsProvider).getString(_key);
    if (raw == null) return null;
    try {
      return UserPlace.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> set(UserPlace? place) async {
    state = place;
    final prefs = ref.read(sharedPrefsProvider);
    if (place == null) {
      await prefs.remove(_key);
    } else {
      await prefs.setString(_key, jsonEncode(place.toJson()));
    }
  }

  /// Спрашивает разрешение и берёт примерные координаты. Возвращает текст ошибки или null.
  Future<String?> detect() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return 'Доступ к геопозиции запрещён. Разрешите его в настройках браузера или телефона — или выберите город вручную.';
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 20),
        ),
      );
      final label = await ref
          .read(placeWeatherClientProvider)
          .placeName(pos.latitude, pos.longitude);
      await set(UserPlace(lat: pos.latitude, lon: pos.longitude, label: label));
      return null;
    } catch (e) {
      return 'Не удалось определить место ($e). Выберите город вручную.';
    }
  }
}

final weatherProvider = FutureProvider<Weather?>((ref) async {
  final place = ref.watch(placeProvider);
  if (place == null) return null;
  return ref.read(placeWeatherClientProvider).weather(place);
});

/// Тенденции региона: что выращивают садоводы и что сейчас цветёт рядом.
enum TrendKind {
  cultivated(
    'Выращивают рядом',
    'Популярные садовые и домашние растения у садоводов вашего региона',
  ),
  flowering('Сейчас цветёт', 'Что зацвело в округе в эти недели'),
  wild('Дикая природа рядом', 'Самые заметные дикорастущие растения округи');

  const TrendKind(this.title, this.subtitle);
  final String title;
  final String subtitle;
}

final trendsProvider = FutureProvider.family<List<InatTaxon>, TrendKind>((
  ref,
  kind,
) async {
  final place = ref.watch(placeProvider);
  final inat = ref.read(inatClientProvider);
  return switch (kind) {
    TrendKind.cultivated => inat.speciesCounts(
      lat: place?.lat,
      lng: place?.lon,
      captive: true,
      perPage: 16,
    ),
    TrendKind.flowering => inat.speciesCounts(
      lat: place?.lat,
      lng: place?.lon,
      flowering: true,
      months: seasonMonths(DateTime.now()),
      perPage: 16,
    ),
    TrendKind.wild => inat.speciesCounts(
      lat: place?.lat,
      lng: place?.lon,
      captive: false,
      perPage: 16,
    ),
  };
});

/// Раздел каталога: при известном месте — то, что встречается рядом; иначе — общий список.
final catalogProvider = FutureProvider.family<List<InatTaxon>, CatalogKind>((
  ref,
  kind,
) async {
  final place = ref.watch(placeProvider);
  final inat = ref.read(inatClientProvider);
  if (kind.flowering) {
    return inat.speciesCounts(
      lat: place?.lat,
      lng: place?.lon,
      flowering: true,
      months: seasonMonths(DateTime.now()),
      perPage: 40,
    );
  }
  final ids = kind.ids!;
  if (place != null) {
    final local = await inat.speciesCounts(
      lat: place.lat,
      lng: place.lon,
      radiusKm: 150,
      taxonIds: ids,
      captive: kind.captive,
      perPage: 40,
    );
    if (local.length >= 6) return local;
  }
  // Рядом мало наблюдений — показываем общий список популярных видов группы.
  return kind.ids!.length <= 30
      ? inat.byIds(ids)
      : inat.byIds(ids.take(30).toList());
});

final plantSearchProvider = FutureProvider.family<List<InatTaxon>, String>((
  ref,
  q,
) {
  return ref.read(inatClientProvider).search(q);
});

final taxonDetailProvider = FutureProvider.family<InatTaxon, int>((ref, id) {
  return ref.read(inatClientProvider).detail(id);
});
