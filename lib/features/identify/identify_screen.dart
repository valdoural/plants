import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/crop_screen.dart';
import '../../core/live_camera.dart';
import '../../core/photo_picker.dart';
import '../../core/settings.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/garden_controller.dart';
import '../../data/recognition/recognition_service.dart';
import '../diagnose/diagnose_result_screen.dart';
import 'identify_result_screen.dart';
import 'photo_guide.dart';
import 'recognition_errors.dart';

enum CameraMode { identify, diagnose }

/// Съёмка → распознавание (или диагностика). Живой видоискатель, спуск в центре, галерея слева.
class IdentifyScreen extends ConsumerStatefulWidget {
  const IdentifyScreen({super.key, this.mode = CameraMode.identify});

  final CameraMode mode;

  @override
  ConsumerState<IdentifyScreen> createState() => _IdentifyScreenState();
}

class _IdentifyScreenState extends ConsumerState<IdentifyScreen> {
  static const _maxPhotos = 3;
  final _camera = GlobalKey<LiveCameraState>();
  final _photos = <Uint8List>[];
  var _organ = PlantOrgan.auto;
  var _busy = false;

  /// Показывать живую камеру (а не последний снимок).
  var _live = true;
  var _cameraFailed = false;

  bool get _diagnose => widget.mode == CameraMode.diagnose;
  int get _limit => _diagnose ? 1 : _maxPhotos;

  Future<void> _gallery() async {
    final bytes = await pickPhoto(ImageSource.gallery);
    if (bytes != null && mounted) {
      setState(() {
        _photos.add(bytes);
        _live = false;
      });
    }
  }

  Future<void> _shoot() async {
    final cam = _camera.currentState;
    Uint8List? bytes;
    if (cam != null && cam.isReady) {
      bytes = await cam.capture();
    } else {
      // Камеры в браузере нет или доступ запрещён — системный выбор фото (на телефоне откроет камеру).
      bytes = await pickPhoto(ImageSource.camera);
    }
    if (bytes != null && mounted) {
      setState(() {
        _photos.add(bytes!);
        _live = false;
      });
    }
  }

  Future<void> _submit({RecognitionProviderId? provider}) async {
    setState(() => _busy = true);
    try {
      if (_diagnose) {
        final result = await ref.read(recognitionServiceProvider).diagnose([
          _photos.first,
        ]);
        final record = await ref
            .read(gardenProvider.notifier)
            .addDiagnosis(result, _photos.first);
        if (!mounted) return;
        context.pushReplacement(
          '/diagnose/result',
          extra: DiagnoseResultArgs(record: record, photo: _photos.first),
        );
        return;
      }
      final result = await ref
          .read(recognitionServiceProvider)
          .identify(_photos, organ: _organ, provider: provider);
      final record = await ref
          .read(gardenProvider.notifier)
          .addIdentification(result, _photos.first);
      if (!mounted) return;
      final router = GoRouter.of(context);
      final used = provider ?? ref.read(settingsProvider).provider;
      // Экран камеры сейчас закроется — предупреждение показываем через корневой навигатор.
      warnIfQuotaLow(
        Navigator.of(context, rootNavigator: true).context,
        ref,
        used,
      );
      router.pushReplacement(
        '/identify/result',
        extra: IdentifyResultArgs(record: record, photo: _photos.first),
      );
    } catch (e) {
      if (!mounted) return;
      presentRecognitionError(
        context,
        ref,
        e,
        retryWith: _diagnose ? null : (other) => _submit(provider: other),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final p = context.palette;
    final hasKey = _diagnose
        ? settings.canDiagnose
        : settings.hasKeyFor(settings.provider);
    final full = _photos.length >= _limit;
    final showLive = _live && !full;
    final cam = _camera.currentState;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 16, 4),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Закрыть',
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.close),
                  ),
                  Expanded(
                    child: Text(
                      _diagnose ? 'Диагностика' : 'Распознать',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (!_diagnose)
                    PressScale(
                      child: Material(
                        color: p.surface,
                        shape: const StadiumBorder(),
                        child: InkWell(
                          customBorder: const StadiumBorder(),
                          onTap: () => _chooseProvider(context, settings),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  settings.provider.short,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.expand_more,
                                  size: 18,
                                  color: p.inkSecondary,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (!hasKey)
              _MissingKey(
                provider: _diagnose
                    ? RecognitionProviderId.plantId
                    : settings.provider,
              ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (showLive)
                        LiveCamera(
                          key: _camera,
                          overlay: Padding(
                            padding: const EdgeInsets.all(28),
                            child: CustomPaint(
                              painter: _CornersPainter(Colors.white70),
                            ),
                          ),
                          onUnavailable: (_) =>
                              setState(() => _cameraFailed = true),
                        )
                      else if (_photos.isNotEmpty)
                        PlantImage.memory(_photos.last, radius: 0)
                      else
                        ColoredBox(
                          color: p.surface,
                          child: _Viewfinder(
                            color: p.accent,
                            hint: p.inkSecondary,
                          ),
                        ),
                      if (showLive && cam != null && cam.isReady)
                        Positioned(
                          top: 12,
                          right: 12,
                          child: Column(
                            children: [
                              if (cam.canSwitch)
                                _RoundIcon(
                                  icon: Icons.cameraswitch_outlined,
                                  tooltip: 'Сменить камеру',
                                  onTap: () async {
                                    await cam.switchCamera();
                                    setState(() {});
                                  },
                                ),
                              if (cam.hasFlash) ...[
                                const SizedBox(height: 8),
                                _RoundIcon(
                                  icon: cam.flashOn
                                      ? Icons.flash_on
                                      : Icons.flash_off,
                                  tooltip: 'Подсветка',
                                  onTap: () async {
                                    await cam.toggleFlash();
                                    setState(() {});
                                  },
                                ),
                              ],
                            ],
                          ),
                        ),
                      if (!showLive && _photos.isNotEmpty && !_busy)
                        Positioned(
                          top: 12,
                          right: 12,
                          child: _RoundIcon(
                            icon: Icons.crop,
                            tooltip: 'Кадрировать',
                            onTap: () async {
                              final last = _photos.length - 1;
                              final cropped = await cropPhoto(
                                context,
                                _photos[last],
                              );
                              if (cropped != null && mounted) {
                                setState(() => _photos[last] = cropped);
                              }
                            },
                          ),
                        ),
                      if (_busy)
                        ColoredBox(
                          color: Colors.black54,
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const CircularProgressIndicator(
                                  color: Colors.white,
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  _diagnose
                                      ? 'Ищем признаки болезней…'
                                      : 'Сравниваем с базой растений…',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      if (_photos.isNotEmpty)
                        Positioned(
                          left: 12,
                          bottom: 12,
                          right: 80,
                          child: _Thumbs(
                            photos: _photos,
                            onRemove: _busy
                                ? null
                                : (i) => setState(() {
                                    _photos.removeAt(i);
                                    if (_photos.isEmpty) _live = true;
                                  }),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            if (!_diagnose &&
                settings.provider == RecognitionProviderId.plantNet)
              SizedBox(
                height: 56,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  children: [
                    for (final o in PlantOrgan.values)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          showCheckmark: false,
                          label: Text(o.label),
                          selected: _organ == o,
                          onSelected: (_) => setState(() => _organ = o),
                        ),
                      ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              child: showLive
                  ? Row(
                      children: [
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: OutlinedButton.icon(
                              onPressed: _busy ? null : _gallery,
                              icon: const Icon(Icons.photo_library_outlined),
                              label: const Text('Галерея'),
                            ),
                          ),
                        ),
                        _Shutter(onPressed: _busy ? null : _shoot),
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: _photos.isNotEmpty
                                ? TextButton(
                                    onPressed: () =>
                                        setState(() => _live = false),
                                    child: const Text('Готово'),
                                  )
                                : TextButton(
                                    onPressed: () => showPhotoGuide(context),
                                    child: const Text('Как снимать'),
                                  ),
                          ),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        if (!full)
                          Padding(
                            padding: const EdgeInsets.only(right: 10),
                            child: IconButton.filledTonal(
                              tooltip: 'Добавить ещё фото',
                              style: IconButton.styleFrom(
                                backgroundColor: p.surface,
                                minimumSize: const Size(54, 54),
                              ),
                              onPressed: _busy
                                  ? null
                                  : () => setState(() => _live = true),
                              icon: const Icon(Icons.add_a_photo_outlined),
                            ),
                          ),
                        Expanded(
                          child: FilledButton(
                            onPressed: _busy || !hasKey || _photos.isEmpty
                                ? null
                                : _submit,
                            child: Text(
                              _busy
                                  ? (_diagnose ? 'Анализируем…' : 'Распознаём…')
                                  : (_diagnose
                                        ? 'Проверить здоровье'
                                        : 'Распознать'),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
            if (_cameraFailed && showLive)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                child: Text(
                  'Кнопка спуска откроет системную съёмку или выбор фото.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: p.inkSecondary),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _chooseProvider(
    BuildContext context,
    AppSettings settings,
  ) async {
    final p = context.palette;
    final chosen = await showModalBottomSheet<RecognitionProviderId>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final id in RecognitionProviderId.values)
              ListTile(
                leading: Icon(
                  id == settings.provider
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: id == settings.provider ? p.accent : p.inkSecondary,
                ),
                title: Text(
                  id.title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  settings.hasKeyFor(id) ? id.pros.first : 'Ключ не задан',
                ),
                onTap: () => Navigator.pop(context, id),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (chosen != null) {
      await ref
          .read(settingsProvider.notifier)
          .update((s) => s.copyWith(provider: chosen));
    }
  }
}

/// Крупная круглая кнопка спуска, как в «Камере».
class _Shutter extends StatelessWidget {
  const _Shutter({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      button: true,
      label: 'Сфотографировать',
      child: PressScale(
        scale: 0.9,
        child: GestureDetector(
          onTap: onPressed,
          child: Container(
            width: 78,
            height: 78,
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: p.ink, width: 4),
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(shape: BoxShape.circle, color: p.ink),
            ),
          ),
        ),
      ),
    );
  }
}

/// Пустой видоискатель: уголки рамки и подсказка.
class _Viewfinder extends StatelessWidget {
  const _Viewfinder({required this.color, required this.hint});

  final Color color;
  final Color hint;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Padding(
          padding: const EdgeInsets.all(36),
          child: CustomPaint(painter: _CornersPainter(color)),
        ),
        Center(
          child: Padding(
            padding: const EdgeInsets.all(48),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.eco_outlined, size: 56, color: color),
                const SizedBox(height: 14),
                const Text(
                  'Наведите камеру на растение',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  'Лучше всего — цветок или лист крупным планом',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: hint),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CornersPainter extends CustomPainter {
  _CornersPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    const l = 36.0;
    final w = size.width, h = size.height;
    for (final (x, y, dx, dy) in [
      (0.0, 0.0, 1.0, 1.0),
      (w, 0.0, -1.0, 1.0),
      (0.0, h, 1.0, -1.0),
      (w, h, -1.0, -1.0),
    ]) {
      canvas.drawPath(
        Path()
          ..moveTo(x, y + dy * l)
          ..lineTo(x, y)
          ..lineTo(x + dx * l, y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_CornersPainter old) => old.color != color;
}

class _Thumbs extends StatelessWidget {
  const _Thumbs({required this.photos, required this.onRemove});

  final List<Uint8List> photos;
  final void Function(int)? onRemove;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < photos.length; i++)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: PlantImage.memory(photos[i], size: 56, radius: 12),
                ),
                if (onRemove != null)
                  Positioned(
                    right: -6,
                    top: -6,
                    child: Material(
                      color: Colors.black87,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => onRemove!(i),
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(
                            Icons.close,
                            size: 14,
                            color: Colors.white,
                            semanticLabel: 'Убрать фото',
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _MissingKey extends StatelessWidget {
  const _MissingKey({required this.provider});

  final RecognitionProviderId provider;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: PressScale(
        child: Material(
          color: p.surface,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => context.push('/settings'),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Нужен API-ключ ${provider.short}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          'Добавьте его в настройках — пара минут.',
                          style: TextStyle(color: p.inkSecondary),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: p.inkSecondary),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressScale(
      child: Material(
        color: Colors.black54,
        shape: const CircleBorder(),
        child: IconButton(
          tooltip: tooltip,
          onPressed: onTap,
          icon: Icon(icon, color: Colors.white),
        ),
      ),
    );
  }
}
