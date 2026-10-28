import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'crop_screen.dart';
import 'theme.dart';

/// Живой видоискатель: задняя камера телефона, веб-камера компьютера или камера в Safari/PWA.
/// Снимок берётся через [LiveCameraState.capture] (по GlobalKey) и обрезается ровно по тому,
/// что было видно в видоискателе, с учётом зума.
class LiveCamera extends StatefulWidget {
  const LiveCamera({
    super.key,
    this.overlay,
    this.onUnavailable,
    this.onChanged,
  });

  /// Поверх изображения: рамка, подсказки.
  final Widget? overlay;

  /// Камера недоступна (нет устройства или запрещён доступ) — экран может предложить галерею.
  final ValueChanged<String>? onUnavailable;

  /// Камера включилась, сменилась, изменился зум — чтобы экран обновил кнопки.
  final VoidCallback? onChanged;

  @override
  State<LiveCamera> createState() => LiveCameraState();
}

class LiveCameraState extends State<LiveCamera> with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription> _cameras = const [];
  int _index = 0;
  String? _error;
  var _flash = false;

  /// Зум 1…[maxZoom]. Если камера умеет зум сама — он аппаратный, иначе цифровой (кадр обрезается).
  double _zoom = 1;
  double _maxNativeZoom = 1;
  double _baseZoom = 1;
  Size _viewport = Size.zero;

  static const double maxZoom = 4;

  bool get isReady => _controller?.value.isInitialized ?? false;
  bool get canSwitch => _cameras.length > 1;
  bool get hasFlash => !kIsWeb && isReady;
  bool get flashOn => _flash;
  double get zoom => _zoom;
  bool get _native => _maxNativeZoom > 1.01;
  bool get isFront =>
      _cameras.isNotEmpty &&
      _cameras[_index].lensDirection == CameraLensDirection.front;

  /// Цифровая часть зума: то, что дорисовывается увеличением и обрезкой.
  double get _digital =>
      _native ? _zoom / math.min(_zoom, _maxNativeZoom) : _zoom;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Камера освобождается, когда приложение уходит в фон, и включается снова при возврате.
    final c = _controller;
    if (c == null) return;
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _controller = null;
      c.dispose();
      if (mounted) setState(() {});
    } else if (state == AppLifecycleState.resumed) {
      _open();
    }
  }

  Future<void> _start() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        return _fail('Камера не найдена на этом устройстве.');
      }
      final back = _cameras.indexWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
      );
      _index = back >= 0 ? back : 0;
      await _open();
    } on CameraException catch (e) {
      _fail(_message(e));
    } catch (e) {
      _fail('Камера недоступна: $e');
    }
  }

  Future<void> _open() async {
    final old = _controller;
    _controller = null;
    await old?.dispose();
    // Повыше разрешение — чтобы после цифрового зума и обрезки осталось достаточно деталей.
    final c = CameraController(
      _cameras[_index],
      ResolutionPreset.veryHigh,
      enableAudio: false,
    );
    try {
      await c.initialize();
      if (!mounted) {
        await c.dispose();
        return;
      }
      var maxNative = 1.0;
      try {
        maxNative = await c.getMaxZoomLevel();
      } catch (_) {
        // Браузер или камера без аппаратного зума — будет цифровой.
      }
      setState(() {
        _controller = c;
        _error = null;
        _flash = false;
        _maxNativeZoom = maxNative;
        _zoom = 1;
      });
      widget.onChanged?.call();
    } on CameraException catch (e) {
      await c.dispose();
      _fail(_message(e));
    }
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() => _error = message);
    widget.onUnavailable?.call(message);
  }

  String _message(CameraException e) => switch (e.code) {
    'CameraAccessDenied' ||
    'cameraPermission' ||
    'CameraAccessDeniedWithoutPrompt' ||
    'permissionDenied' => 'Доступ к камере запрещён. Разрешите его в настройках браузера или телефона — или выберите фото из галереи.',
    'cameraNotFound' || 'notFound' => 'Камера не найдена на этом устройстве.',
    'cameraNotReadable' || 'notReadable' =>
      'Камера занята другим приложением. Закройте его и попробуйте снова.',
    _ => 'Камера недоступна (${e.code}). Можно выбрать фото из галереи.',
  };

  Future<void> setZoom(double value) async {
    final z = value.clamp(1.0, maxZoom);
    setState(() => _zoom = z);
    final c = _controller;
    if (_native && c != null) {
      try {
        await c.setZoomLevel(math.min(z, _maxNativeZoom));
      } catch (_) {}
    }
    widget.onChanged?.call();
  }

  /// Снимок в JPEG, обрезанный по видимой области; null — если камера ещё не готова.
  Future<Uint8List?> capture() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized || c.value.isTakingPicture) {
      return null;
    }
    await HapticFeedback.mediumImpact();
    final file = await c.takePicture();
    final bytes = await file.readAsBytes();
    if (_viewport.isEmpty) return bytes;
    try {
      return cropToViewport(bytes, viewport: _viewport, zoom: _digital);
    } catch (_) {
      return bytes;
    }
  }

  Future<void> switchCamera() async {
    if (!canSwitch) return;
    _index = (_index + 1) % _cameras.length;
    await _open();
  }

  Future<void> toggleFlash() async {
    final c = _controller;
    if (c == null) return;
    _flash = !_flash;
    await c.setFlashMode(_flash ? FlashMode.torch : FlashMode.off);
    if (mounted) setState(() {});
    widget.onChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final c = _controller;
    if (_error != null) {
      return ColoredBox(
        color: p.surface,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.no_photography_outlined,
                  size: 44,
                  color: p.inkSecondary,
                ),
                const SizedBox(height: 12),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, height: 1.4, color: p.ink),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _start,
                  child: const Text('Попробовать снова'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    if (c == null || !c.value.isInitialized) {
      return ColoredBox(
        color: Colors.black,
        child: Center(child: CircularProgressIndicator(color: p.accent)),
      );
    }
    final portrait = MediaQuery.orientationOf(context) == Orientation.portrait;
    final ar = portrait ? 1 / c.value.aspectRatio : c.value.aspectRatio;
    return LayoutBuilder(
      builder: (context, box) {
        _viewport = box.biggest;
        return GestureDetector(
          // Щипок — зум.
          onScaleStart: (_) => _baseZoom = _zoom,
          onScaleUpdate: (d) {
            if (d.pointerCount > 1) setZoom(_baseZoom * d.scale);
          },
          child: ColoredBox(
            color: Colors.black,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Изображение заполняет видоискатель без полос, лишнее обрезается;
                // цифровой зум — увеличение от центра.
                ClipRect(
                  child: Transform.scale(
                    scale: _digital,
                    child: FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: 1000,
                        height: 1000 / ar,
                        child: CameraPreview(c),
                      ),
                    ),
                  ),
                ),
                ?widget.overlay,
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Рамка фокуса: затемнение вокруг квадрата в центре, уголки и подсказка.
class FocusFrameOverlay extends StatelessWidget {
  const FocusFrameOverlay({super.key, this.hint});

  final String? hint;

  /// Сторона квадрата относительно меньшей стороны видоискателя.
  static const fraction = 0.64;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, c) {
          final side = c.biggest.shortestSide * fraction;
          final rect = Rect.fromCenter(
            center: c.biggest.center(Offset.zero),
            width: side,
            height: side,
          );
          return Stack(
            fit: StackFit.expand,
            children: [
              CustomPaint(painter: _FramePainter(rect)),
              if (hint != null)
                Positioned(
                  left: rect.left - 8,
                  width: rect.width + 16,
                  top: rect.bottom + 14,
                  child: Text(
                    hint!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      shadows: [Shadow(blurRadius: 6, color: Colors.black54)],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _FramePainter extends CustomPainter {
  _FramePainter(this.rect);

  final Rect rect;

  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(rect, const Radius.circular(22));
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Offset.zero & size),
        Path()..addRRect(r),
      ),
      Paint()..color = Colors.black.withValues(alpha: 0.38),
    );
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;
    final l = rect.shortestSide * 0.16;
    const rad = 22.0;
    for (final (corner, dx, dy) in [
      (rect.topLeft, 1.0, 1.0),
      (rect.topRight, -1.0, 1.0),
      (rect.bottomLeft, 1.0, -1.0),
      (rect.bottomRight, -1.0, -1.0),
    ]) {
      final path = Path()
        ..moveTo(corner.dx, corner.dy + dy * l)
        ..lineTo(corner.dx, corner.dy + dy * rad)
        ..quadraticBezierTo(
          corner.dx,
          corner.dy,
          corner.dx + dx * rad,
          corner.dy,
        )
        ..lineTo(corner.dx + dx * l, corner.dy);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_FramePainter old) => old.rect != rect;
}

/// Вертикальный ползунок зума справа: «+» сверху, «−» снизу, значение под ним.
class ZoomSlider extends StatelessWidget {
  const ZoomSlider({
    super.key,
    required this.value,
    required this.max,
    required this.onChanged,
  });

  final double value;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.add, color: Colors.white, size: 18),
          SizedBox(
            height: 150,
            child: RotatedBox(
              quarterTurns: 3,
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 3,
                  activeTrackColor: Colors.white,
                  inactiveTrackColor: Colors.white30,
                  thumbColor: Colors.white,
                  overlayShape: SliderComponentShape.noOverlay,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 8,
                  ),
                ),
                child: Slider(
                  min: 1,
                  max: max,
                  value: value.clamp(1, max),
                  onChanged: onChanged,
                ),
              ),
            ),
          ),
          const Icon(Icons.remove, color: Colors.white, size: 18),
          const SizedBox(height: 4),
          Text(
            '${value.toStringAsFixed(1)}×',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
