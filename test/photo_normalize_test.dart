import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:leafy/core/photo_normalize.dart';
import 'package:leafy/data/recognition/recognition_service.dart';

void main() {
  testWidgets('большой PNG становится JPEG до 1280 px, чёрный кадр — ошибка', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final big = img.Image(width: 2000, height: 1000);
      img.fill(big, color: img.ColorRgb8(40, 160, 60));
      final out = await normalizePhoto(img.encodePng(big));
      expect(imageMimeType(out), 'image/jpeg');
      final back = img.decodeJpg(out)!;
      expect(back.width, 1280);
      expect(back.height, 640);

      final black = img.Image(width: 640, height: 480);
      await expectLater(
        normalizePhoto(img.encodeJpg(black)),
        throwsA(isA<BlankPhotoException>()),
      );
    });
  });
}
