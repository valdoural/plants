import 'dart:math' as math;
import 'dart:typed_data';

import 'package:exif/exif.dart';

import 'models.dart';

/// Параметры съёмки из EXIF снимка.
class Exposure {
  const Exposure({
    required this.seconds,
    required this.fNumber,
    required this.iso,
  });

  final double seconds;
  final double fNumber;
  final double iso;

  /// Экспозиционное число, приведённое к ISO 100.
  double get ev100 => _log2(fNumber * fNumber / seconds) - _log2(iso / 100);
}

double _log2(double x) => math.log(x) / math.ln2;

/// Читает выдержку, диафрагму и ISO из JPEG. В браузере снимки без EXIF — вернётся null.
Future<Exposure?> readExposure(Uint8List jpeg) async {
  try {
    final tags = await readExifFromBytes(jpeg);
    double? num(String key) {
      final v = tags[key]?.values;
      if (v == null || v.length == 0) return null;
      final first = v.toList().first;
      return switch (first) {
        Ratio r => r.denominator == 0 ? null : r.numerator / r.denominator,
        int i => i.toDouble(),
        double d => d,
        _ => null,
      };
    }

    final t = num('EXIF ExposureTime');
    final f = num('EXIF FNumber');
    final iso =
        num('EXIF ISOSpeedRatings') ?? num('EXIF PhotographicSensitivity');
    if (t == null || f == null || iso == null || t <= 0 || f <= 0 || iso <= 0) {
      return null;
    }
    return Exposure(seconds: t, fNumber: f, iso: iso);
  } catch (_) {
    return null;
  }
}

/// Освещённость (люкс) по снимку белого листа бумаги на месте растения.
/// [meanLinear] — средняя яркость кадра в линейной шкале (0…1); камера стремится сделать её ≈0,18.
/// Яркость листа L = 0,125·2^EV100·(meanLinear/0,18) кд/м², освещённость E = π·L/отражение.
double luxFromExposure(
  Exposure e, {
  required double meanLinear,
  double reflectance = 0.8,
}) {
  final luminance = 0.125 * math.pow(2, e.ev100) * (meanLinear / 0.18);
  return math.pi * luminance / reflectance;
}

/// Категория света по освещённости — те же, что в условиях растения.
PlantLight lightFromLux(double lux) {
  if (lux >= 25000) return PlantLight.sun;
  if (lux >= 10000) return PlantLight.bright;
  if (lux >= 2500) return PlantLight.partial;
  return PlantLight.shade;
}

/// Перевод sRGB-значения канала (0…255) в линейную яркость.
double srgbToLinear(int v) {
  final c = v / 255;
  return c <= 0.04045
      ? c / 12.92
      : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
}

/// Средняя линейная яркость по пикселям RGBA.
double meanLinearLuminance(Uint8List rgba) {
  var sum = 0.0;
  var n = 0;
  for (var i = 0; i + 3 < rgba.length; i += 4) {
    sum +=
        0.2126 * srgbToLinear(rgba[i]) +
        0.7152 * srgbToLinear(rgba[i + 1]) +
        0.0722 * srgbToLinear(rgba[i + 2]);
    n++;
  }
  return n == 0 ? 0 : sum / n;
}

enum WindowSide {
  south('Юг'),
  eastWest('Восток или запад'),
  north('Север'),
  none('Окна рядом нет');

  const WindowSide(this.label);
  final String label;
}

enum WindowDistance {
  sill('На подоконнике'),
  near('До 1 м от окна'),
  mid('1–2 м'),
  far('Дальше 2 м');

  const WindowDistance(this.label);
  final String label;
}

/// Оценка света без камеры: по стороне света, расстоянию до окна и шторам.
PlantLight estimateLight({
  required WindowSide side,
  required WindowDistance distance,
  bool sheerCurtain = false,
}) {
  if (side == WindowSide.none) return PlantLight.shade;
  // 0 — солнце, 3 — тень.
  var level = switch (side) {
    WindowSide.south => 0,
    WindowSide.eastWest => 1,
    WindowSide.north => 2,
    WindowSide.none => 3,
  };
  level += switch (distance) {
    WindowDistance.sill => 0,
    WindowDistance.near => 1,
    WindowDistance.mid => 1,
    WindowDistance.far => 2,
  };
  if (distance == WindowDistance.mid && side == WindowSide.south) level += 1;
  if (sheerCurtain && level == 0) level = 1;
  return PlantLight.values[level.clamp(0, 3)];
}
