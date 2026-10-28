import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:leafy/core/crop_screen.dart';

void main() {
  test('кадрирование вырезает нужный квадрат и учитывает поворот', () {
    // 200×100: левая половина красная, правая синяя.
    final src = img.Image(width: 200, height: 100);
    for (var y = 0; y < 100; y++) {
      for (var x = 0; x < 200; x++) {
        src.setPixelRgb(x, y, x < 100 ? 255 : 0, 0, x < 100 ? 0 : 255);
      }
    }
    final jpeg = img.encodeJpg(src, quality: 95);

    final right = img.decodeJpg(
      cropJpeg(jpeg, rect: const Rect.fromLTWH(100, 0, 100, 100)),
    )!;
    expect(right.width, 100);
    expect(right.height, 100);
    expect(right.getPixel(50, 50).b, greaterThan(200));

    // После поворота на 90° по часовой картинка 100×200, красная половина сверху.
    final top = img.decodeJpg(
      cropJpeg(
        jpeg,
        rect: const Rect.fromLTWH(0, 0, 100, 100),
        quarterTurns: 1,
      ),
    )!;
    expect(top.getPixel(50, 50).r, greaterThan(200));

    // Большие снимки уменьшаются до maxSide.
    final small = img.decodeJpg(
      cropJpeg(jpeg, rect: const Rect.fromLTWH(0, 0, 100, 100), maxSide: 40),
    )!;
    expect(small.width, 40);
  });

  test('видимая часть снимка: заполнение с обрезкой и зум', () {
    // Кадр 1920×1080, окно-видоискатель портретное 360×640: видна центральная полоса.
    final r = visibleRect(const Size(1920, 1080), const Size(360, 640));
    expect(r.height, closeTo(1080, 0.01));
    expect(r.width, closeTo(607.5, 0.01));
    expect(r.center, const Offset(960, 540));
    // Зум ×2 — вдвое меньше по каждой стороне, центр тот же.
    final z = visibleRect(
      const Size(1920, 1080),
      const Size(360, 640),
      zoom: 2,
    );
    expect(z.width, closeTo(303.75, 0.01));
    expect(z.center, const Offset(960, 540));
  });
}
