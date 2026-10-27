import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'theme.dart';

/// Живой видоискатель: задняя камера телефона, веб-камера компьютера или камера в Safari/PWA.
/// Снимок берётся через [LiveCameraState.capture] (по GlobalKey).
class LiveCamera extends StatefulWidget {
  const LiveCamera({super.key, this.overlay, this.onUnavailable});

  /// Поверх изображения: рамка, подсказки.
  final Widget? overlay;

  /// Камера недоступна (нет устройства или запрещён доступ) — экран может предложить галерею.
  final ValueChanged<String>? onUnavailable;

  @override
  State<LiveCamera> createState() => LiveCameraState();
}

class LiveCameraState extends State<LiveCamera> with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription> _cameras = const [];
  int _index = 0;
  String? _error;
  var _flash = false;

  bool get isReady => _controller?.value.isInitialized ?? false;
  bool get canSwitch => _cameras.length > 1;
  bool get hasFlash => !kIsWeb && isReady;

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
    final c = CameraController(
      _cameras[_index],
      ResolutionPreset.high,
      enableAudio: false,
    );
    try {
      await c.initialize();
      if (!mounted) {
        await c.dispose();
        return;
      }
      setState(() {
        _controller = c;
        _error = null;
        _flash = false;
      });
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

  /// Снимок в JPEG; null — если камера ещё не готова.
  Future<Uint8List?> capture() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized || c.value.isTakingPicture) {
      return null;
    }
    await HapticFeedback.mediumImpact();
    final file = await c.takePicture();
    return file.readAsBytes();
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
  }

  bool get flashOn => _flash;

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
    return ColoredBox(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Изображение камеры заполняет видоискатель без полос, лишнее обрезается.
          ClipRect(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: 1000,
                height: 1000 / ar,
                child: CameraPreview(c),
              ),
            ),
          ),
          ?widget.overlay,
        ],
      ),
    );
  }
}
