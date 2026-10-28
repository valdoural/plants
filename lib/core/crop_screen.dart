import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

import 'theme.dart';

/// Кадрирование фото перед распознаванием: квадратная рамка, масштаб жестом, поворот.
/// Возвращает JPEG или null, если отменили.
Future<Uint8List?> cropPhoto(BuildContext context, Uint8List bytes) =>
    Navigator.of(context).push<Uint8List>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _CropScreen(bytes: bytes),
      ),
    );

/// Вырезает квадрат [rect] (в пикселях исходника) после поворота на [quarterTurns]×90°.
Uint8List cropJpeg(
  Uint8List bytes, {
  required Rect rect,
  int quarterTurns = 0,
  int maxSide = 1280,
}) {
  var image = img.decodeImage(bytes)!;
  image = img.bakeOrientation(image);
  if (quarterTurns % 4 != 0) {
    image = img.copyRotate(image, angle: 90 * (quarterTurns % 4));
  }
  final x = rect.left.round().clamp(0, image.width - 1);
  final y = rect.top.round().clamp(0, image.height - 1);
  final w = rect.width.round().clamp(1, image.width - x);
  final h = rect.height.round().clamp(1, image.height - y);
  var out = img.copyCrop(image, x: x, y: y, width: w, height: h);
  if (out.width > maxSide || out.height > maxSide) {
    out = img.copyResize(
      out,
      width: out.width >= out.height ? maxSide : null,
      height: out.height > out.width ? maxSide : null,
      interpolation: img.Interpolation.average,
    );
  }
  return img.encodeJpg(out, quality: 85);
}

/// Обрезает снимок камеры ровно по видимой части видоискателя размером [viewport]
/// (превью заполняет его с обрезкой краёв) и дополнительно по цифровому зуму [zoom] от центра.
Uint8List cropToViewport(
  Uint8List bytes, {
  required Size viewport,
  double zoom = 1,
  int maxSide = 1600,
}) {
  var image = img.bakeOrientation(img.decodeImage(bytes)!);
  final rect = visibleRect(
    Size(image.width.toDouble(), image.height.toDouble()),
    viewport,
    zoom: zoom,
  );
  image = img.copyCrop(
    image,
    x: rect.left.round(),
    y: rect.top.round(),
    width: rect.width.round(),
    height: rect.height.round(),
  );
  if (image.width > maxSide || image.height > maxSide) {
    image = img.copyResize(
      image,
      width: image.width >= image.height ? maxSide : null,
      height: image.height > image.width ? maxSide : null,
      interpolation: img.Interpolation.average,
    );
  }
  return img.encodeJpg(image, quality: 88);
}

/// Какая часть снимка [photo] видна в окне [viewport] при заполнении с обрезкой и зуме [zoom].
Rect visibleRect(Size photo, Size viewport, {double zoom = 1}) {
  final scale = [
    viewport.width / photo.width,
    viewport.height / photo.height,
  ].reduce((a, b) => a > b ? a : b);
  final w = (viewport.width / scale / zoom).clamp(1.0, photo.width);
  final h = (viewport.height / scale / zoom).clamp(1.0, photo.height);
  return Rect.fromCenter(
    center: Offset(photo.width / 2, photo.height / 2),
    width: w,
    height: h,
  );
}

/// Увеличение готового фото от центра: оставляет 1/[zoom] по каждой стороне.
Uint8List zoomCenter(Uint8List bytes, double zoom) {
  if (zoom <= 1.01) return bytes;
  final image = img.bakeOrientation(img.decodeImage(bytes)!);
  final size = Size(image.width.toDouble(), image.height.toDouble());
  return cropJpeg(bytes, rect: visibleRect(size, size, zoom: zoom));
}

class _CropScreen extends StatefulWidget {
  const _CropScreen({required this.bytes});

  final Uint8List bytes;

  @override
  State<_CropScreen> createState() => _CropScreenState();
}

class _CropScreenState extends State<_CropScreen> {
  final _transform = TransformationController();
  Size? _imageSize;
  var _turns = 0;
  var _busy = false;

  /// Размер видимого квадрата и масштаб «подогнанного» изображения — из последней раскладки.
  double _side = 0;
  double _fit = 1;

  @override
  void initState() {
    super.initState();
    _readSize();
  }

  Future<void> _readSize() async {
    final codec = await ui.instantiateImageCodec(widget.bytes);
    final frame = await codec.getNextFrame();
    final size = Size(
      frame.image.width.toDouble(),
      frame.image.height.toDouble(),
    );
    frame.image.dispose();
    if (mounted) setState(() => _imageSize = size);
  }

  Size get _rotated {
    final s = _imageSize!;
    return _turns.isOdd ? Size(s.height, s.width) : s;
  }

  void _resetTransform() {
    final s = _rotated;
    final w = s.width * _fit;
    final h = s.height * _fit;
    _transform.value = Matrix4.translationValues(
      -(w - _side) / 2,
      -(h - _side) / 2,
      0,
    );
  }

  Future<void> _done() async {
    setState(() => _busy = true);
    // Видимый квадрат в координатах подогнанного изображения → в пиксели исходника.
    final inverse = Matrix4.inverted(_transform.value);
    final tl = MatrixUtils.transformPoint(inverse, Offset.zero);
    final br = MatrixUtils.transformPoint(inverse, Offset(_side, _side));
    final rect = Rect.fromPoints(tl / _fit, br / _fit);
    // Даём кадру отрисовать индикатор, затем считаем.
    await Future<void>.delayed(const Duration(milliseconds: 16));
    final out = cropJpeg(widget.bytes, rect: rect, quarterTurns: _turns);
    if (mounted) Navigator.pop(context, out);
  }

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Кадрирование'),
        actions: [
          IconButton(
            tooltip: 'Повернуть',
            onPressed: _imageSize == null || _busy
                ? null
                : () => setState(() {
                    _turns = (_turns + 1) % 4;
                    _resetTransform();
                  }),
            icon: const Icon(Icons.rotate_90_degrees_cw_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _imageSize == null
                  ? Center(child: CircularProgressIndicator(color: p.accent))
                  : LayoutBuilder(
                      builder: (context, c) {
                        final side = (c.biggest.shortestSide - 32).clamp(
                          120.0,
                          720.0,
                        );
                        final s = _rotated;
                        final fit = side / s.shortestSide;
                        if (side != _side || fit != _fit) {
                          _side = side;
                          _fit = fit;
                          // Контроллер нельзя менять во время раскладки — после кадра.
                          WidgetsBinding.instance.addPostFrameCallback(
                            (_) => _resetTransform(),
                          );
                        }
                        return Center(
                          child: SizedBox.square(
                            dimension: side,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                ClipRect(
                                  child: InteractiveViewer(
                                    transformationController: _transform,
                                    constrained: false,
                                    minScale: 1,
                                    maxScale: 5,
                                    boundaryMargin: EdgeInsets.zero,
                                    child: SizedBox(
                                      width: s.width * fit,
                                      height: s.height * fit,
                                      child: RotatedBox(
                                        quarterTurns: _turns,
                                        child: Image.memory(
                                          widget.bytes,
                                          fit: BoxFit.fill,
                                          gaplessPlayback: true,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                IgnorePointer(
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 2,
                                      ),
                                    ),
                                    child: CustomPaint(painter: _GridPainter()),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'Сдвиньте и приблизьте так, чтобы лист или цветок занял почти весь квадрат.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white38),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Отмена'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                      ),
                      onPressed: _imageSize == null || _busy ? null : _done,
                      child: _busy
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Готово'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Сетка «третей» поверх рамки.
class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white38
      ..strokeWidth = 1;
    for (var i = 1; i < 3; i++) {
      final x = size.width * i / 3;
      final y = size.height * i / 3;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) => false;
}
