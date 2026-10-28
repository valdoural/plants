import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:image/image.dart' as img;

class BlankPhotoException implements Exception {
  @override
  String toString() => 'пустой кадр';
}

/// Приводит снимок к JPEG не больше [maxSide] px.
/// Декодирует сам браузер или система — поэтому подходят HEIC с iPhone, WebP, PNG.
/// Почти однотонный чёрный кадр (камера не успела включиться) — [BlankPhotoException].
Future<Uint8List> normalizePhoto(Uint8List bytes, {int maxSide = 1280}) async {
  if (bytes.isEmpty) throw BlankPhotoException();
  final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
  // Размер подбирается по исходным размерам кадра; работает и в браузере, и на телефоне.
  final codec = await ui.instantiateImageCodecWithSize(
    buffer,
    getTargetSize: (w, h) {
      final k = math.min(1.0, maxSide / math.max(w, h));
      return ui.TargetImageSize(
        width: math.max(1, (w * k).round()),
        height: math.max(1, (h * k).round()),
      );
    },
  );
  final frame = await codec.getNextFrame();
  final image = frame.image;
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  final width = image.width, height = image.height;
  image.dispose();
  codec.dispose();
  if (data == null || width < 16 || height < 16) throw BlankPhotoException();
  final rgba = data.buffer.asUint8List();
  if (_isBlank(rgba)) throw BlankPhotoException();
  final out = img.Image.fromBytes(
    width: width,
    height: height,
    bytes: rgba.buffer,
    numChannels: 4,
  );
  return img.encodeJpg(out, quality: 85);
}

/// Кадр почти чёрный и однотонный.
bool _isBlank(Uint8List rgba) {
  var max = 0;
  final step = math.max(4, (rgba.length ~/ 4 ~/ 2000) * 4);
  for (var i = 0; i + 2 < rgba.length; i += step) {
    final v = math.max(rgba[i], math.max(rgba[i + 1], rgba[i + 2]));
    if (v > max) max = v;
    if (max > 24) return false;
  }
  return true;
}
