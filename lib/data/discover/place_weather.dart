import 'dart:convert';

import 'package:http/http.dart' as http;

/// Место пользователя: координаты и подпись (город, страна).
class UserPlace {
  const UserPlace({required this.lat, required this.lon, required this.label});

  final double lat;
  final double lon;
  final String label;

  Map<String, dynamic> toJson() => {'lat': lat, 'lon': lon, 'label': label};

  factory UserPlace.fromJson(Map<String, dynamic> j) =>
      UserPlace(lat: (j['lat'] as num).toDouble(), lon: (j['lon'] as num).toDouble(), label: j['label'] as String);
}

class DayForecast {
  const DayForecast({required this.date, required this.min, required this.max, required this.precipitation});

  final DateTime date;
  final double min;
  final double max;
  final double precipitation;
}

class Weather {
  const Weather({required this.temperature, required this.humidity, required this.days});

  final double temperature;
  final double humidity;
  final List<DayForecast> days;

  factory Weather.fromOpenMeteo(Map<String, dynamic> j) {
    final cur = Map<String, dynamic>.from(j['current'] as Map);
    final d = Map<String, dynamic>.from(j['daily'] as Map);
    final dates = (d['time'] as List).cast<String>();
    return Weather(
      temperature: (cur['temperature_2m'] as num).toDouble(),
      humidity: (cur['relative_humidity_2m'] as num).toDouble(),
      days: [
        for (var i = 0; i < dates.length; i++)
          DayForecast(
            date: DateTime.parse(dates[i]),
            min: ((d['temperature_2m_min'] as List)[i] as num).toDouble(),
            max: ((d['temperature_2m_max'] as List)[i] as num).toDouble(),
            precipitation: (((d['precipitation_sum'] as List)[i] as num?) ?? 0).toDouble(),
          ),
      ],
    );
  }
}

/// Погода и поиск городов — Open-Meteo (без ключа); название места по координатам — BigDataCloud.
class PlaceWeatherClient {
  PlaceWeatherClient({http.Client? client}) : _http = client ?? http.Client();

  final http.Client _http;

  Future<Map<String, dynamic>> _json(Uri uri) async {
    final res = await _http.get(uri).timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) throw Exception('${uri.host}: ${res.statusCode}');
    return Map<String, dynamic>.from(jsonDecode(utf8.decode(res.bodyBytes)) as Map);
  }

  Future<Weather> weather(UserPlace p) async {
    final j = await _json(Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': '${p.lat}',
      'longitude': '${p.lon}',
      'current': 'temperature_2m,relative_humidity_2m',
      'daily': 'temperature_2m_max,temperature_2m_min,precipitation_sum',
      'timezone': 'auto',
      'forecast_days': '4',
    }));
    return Weather.fromOpenMeteo(j);
  }

  /// Поиск города по названию.
  Future<List<UserPlace>> searchCity(String q) async {
    if (q.trim().length < 2) return const [];
    final j = await _json(Uri.https('geocoding-api.open-meteo.com', '/v1/search',
        {'name': q.trim(), 'count': '8', 'language': 'ru', 'format': 'json'}));
    return ((j['results'] as List?) ?? const []).map((e) {
      final m = Map<String, dynamic>.from(e as Map);
      final parts = [m['name'], m['admin1'], m['country']].whereType<String>().toSet().toList();
      return UserPlace(lat: (m['latitude'] as num).toDouble(), lon: (m['longitude'] as num).toDouble(), label: parts.join(', '));
    }).toList();
  }

  /// Название места по координатам (для автоопределения).
  Future<String> placeName(double lat, double lon) async {
    try {
      final j = await _json(Uri.https('api.bigdatacloud.net', '/data/reverse-geocode-client',
          {'latitude': '$lat', 'longitude': '$lon', 'localityLanguage': 'ru'}));
      final parts = [j['city'], j['locality'], j['countryName']]
          .whereType<String>()
          .where((s) => s.isNotEmpty)
          .toSet()
          .take(2)
          .toList();
      if (parts.isNotEmpty) return parts.join(', ');
    } catch (_) {
      // Без названия место всё равно работает — покажем координаты.
    }
    return '${lat.toStringAsFixed(2)}°, ${lon.toStringAsFixed(2)}°';
  }
}

/// Советы на ближайшие дни по прогнозу: заморозки, жара, дожди, сухой воздух.
List<String> weatherTips(Weather w, {bool hasOutdoor = true}) {
  final tips = <String>[];
  final next = w.days.take(3).toList();
  if (next.isEmpty) return tips;
  final minT = next.map((d) => d.min).reduce((a, b) => a < b ? a : b);
  final maxT = next.map((d) => d.max).reduce((a, b) => a > b ? a : b);
  final rain = next.fold<double>(0, (s, d) => s + d.precipitation);
  if (minT <= 0) {
    tips.add('Ночью до ${minT.round()}° — заморозки. Занесите балконные растения, укройте молодые посадки.');
  } else if (minT <= 5) {
    tips.add('Ночи холодные, до ${minT.round()}°. Теплолюбивые растения с балкона пора переносить в дом.');
  }
  if (maxT >= 28) {
    tips.add('Жара до ${maxT.round()}°. Проверяйте почву чаще, притеняйте растения от полуденного солнца.');
  }
  if (hasOutdoor && rain >= 10) {
    tips.add('В ближайшие дни ${rain.round()} мм осадков — уличные растения можно не поливать.');
  }
  if (w.humidity < 40) {
    tips.add('Влажность воздуха ${w.humidity.round()}%. Тропическим растениям поможет опрыскивание или поддон с водой.');
  }
  if (tips.isEmpty) tips.add('Погода спокойная — поливаем по графику, без поправок.');
  return tips;
}
