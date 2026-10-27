import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/photo_picker.dart';
import '../../core/settings.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/garden_controller.dart';
import '../../data/recognition/recognition_service.dart';
import 'identify_result_screen.dart';

/// Съёмка/выбор фото → распознавание. Видоискатель во весь экран, спуск в центре.
class IdentifyScreen extends ConsumerStatefulWidget {
  const IdentifyScreen({super.key});

  @override
  ConsumerState<IdentifyScreen> createState() => _IdentifyScreenState();
}

class _IdentifyScreenState extends ConsumerState<IdentifyScreen> {
  static const _maxPhotos = 3;
  final _photos = <Uint8List>[];
  var _organ = PlantOrgan.auto;
  var _busy = false;

  Future<void> _add(ImageSource source) async {
    final bytes = await pickPhoto(source);
    if (bytes != null && mounted) setState(() => _photos.add(bytes));
  }

  Future<void> _identify({RecognitionProviderId? provider}) async {
    setState(() => _busy = true);
    try {
      final result = await ref.read(recognitionServiceProvider).identify(_photos, organ: _organ, provider: provider);
      final record = await ref.read(gardenProvider.notifier).addIdentification(result, _photos.first);
      if (!mounted) return;
      context.pushReplacement('/identify/result', extra: IdentifyResultArgs(record: record, photo: _photos.first));
    } on RecognitionException catch (e) {
      if (!mounted) return;
      final settings = ref.read(settingsProvider);
      final canRetry = e.provider == RecognitionProviderId.plantNet && settings.hasKeyFor(RecognitionProviderId.plantId);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.message),
        duration: const Duration(seconds: 10),
        action: canRetry
            ? SnackBarAction(label: 'Через Plant.id', onPressed: () => _identify(provider: RecognitionProviderId.plantId))
            : null,
      ));
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final p = context.palette;
    final hasKey = settings.hasKeyFor(settings.provider);
    final full = _photos.length >= _maxPhotos;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 16, 4),
              child: Row(
                children: [
                  IconButton(tooltip: 'Закрыть', onPressed: () => context.pop(), icon: const Icon(Icons.close)),
                  const Expanded(child: Text('Распознать', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800))),
                  Material(
                    color: p.surface,
                    shape: const StadiumBorder(),
                    child: InkWell(
                      customBorder: const StadiumBorder(),
                      onTap: () => _chooseProvider(context, settings),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Text(settings.provider.short, style: const TextStyle(fontWeight: FontWeight.w700)),
                          const SizedBox(width: 4),
                          Icon(Icons.expand_more, size: 18, color: p.inkSecondary),
                        ]),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (!hasKey) _MissingKey(provider: settings.provider),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (_photos.isEmpty)
                        ColoredBox(color: p.surface, child: _Viewfinder(color: p.accent, hint: p.inkSecondary))
                      else
                        PlantImage.memory(_photos.last, radius: 0),
                      if (_busy)
                        const ColoredBox(
                          color: Colors.black54,
                          child: Center(
                            child: Column(mainAxisSize: MainAxisSize.min, children: [
                              CircularProgressIndicator(color: Colors.white),
                              SizedBox(height: 14),
                              Text('Сравниваем с базой растений…',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
                            ]),
                          ),
                        ),
                      if (_photos.isNotEmpty)
                        Positioned(
                          left: 12,
                          right: 12,
                          bottom: 12,
                          child: _Thumbs(
                            photos: _photos,
                            onRemove: _busy ? null : (i) => setState(() => _photos.removeAt(i)),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            if (settings.provider == RecognitionProviderId.plantNet)
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
              child: _photos.isEmpty
                  ? Row(
                      children: [
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: OutlinedButton.icon(
                              onPressed: () => _add(ImageSource.gallery),
                              icon: const Icon(Icons.photo_library_outlined),
                              label: const Text('Галерея'),
                            ),
                          ),
                        ),
                        _Shutter(onPressed: () => _add(ImageSource.camera)),
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(onPressed: () => _showTips(context), child: const Text('Как снимать')),
                          ),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        IconButton.filledTonal(
                          tooltip: full ? 'Не больше $_maxPhotos фото' : 'Добавить ещё фото',
                          style: IconButton.styleFrom(backgroundColor: p.surface, minimumSize: const Size(54, 54)),
                          onPressed: full || _busy ? null : () => _add(ImageSource.camera),
                          icon: const Icon(Icons.add_a_photo_outlined),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton(
                            onPressed: _busy || !hasKey ? null : _identify,
                            child: Text(_busy ? 'Распознаём…' : 'Распознать'),
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

  void _showTips(BuildContext context) {
    final p = context.palette;
    Widget tip(String title, String text) => Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(text, style: TextStyle(fontSize: 15, color: p.inkSecondary)),
          ]),
        );
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Как сделать хорошее фото', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 16),
              tip('Одно растение в кадре', 'Растение в центре и в фокусе, занимает большую часть кадра.'),
              tip('Цветок или лист крупно', 'Это самые узнаваемые части. Добавьте 2–3 фото с разных сторон.'),
              tip('Мягкий свет', 'Без сильных теней и бликов; у окна днём — идеально.'),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _chooseProvider(BuildContext context, AppSettings settings) async {
    final p = context.palette;
    final chosen = await showModalBottomSheet<RecognitionProviderId>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final id in RecognitionProviderId.values)
              ListTile(
                leading: Icon(id == settings.provider ? Icons.radio_button_checked : Icons.radio_button_off,
                    color: id == settings.provider ? p.accent : p.inkSecondary),
                title: Text(id.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(settings.hasKeyFor(id) ? id.pros.first : 'Ключ не задан'),
                onTap: () => Navigator.pop(context, id),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (chosen != null) await ref.read(settingsProvider.notifier).update((s) => s.copyWith(provider: chosen));
  }
}

/// Крупная круглая кнопка спуска, как в «Камере».
class _Shutter extends StatelessWidget {
  const _Shutter({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      button: true,
      label: 'Сфотографировать',
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          width: 78,
          height: 78,
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: p.ink, width: 4)),
          child: DecoratedBox(decoration: BoxDecoration(shape: BoxShape.circle, color: p.ink)),
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
        Padding(padding: const EdgeInsets.all(36), child: CustomPaint(painter: _CornersPainter(color))),
        Center(
          child: Padding(
            padding: const EdgeInsets.all(48),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.eco_outlined, size: 56, color: color),
              const SizedBox(height: 14),
              const Text('Наведите камеру на растение',
                  textAlign: TextAlign.center, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text('Лучше всего — цветок или лист крупным планом', textAlign: TextAlign.center, style: TextStyle(color: hint)),
            ]),
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
    for (final (x, y, dx, dy) in [(0.0, 0.0, 1.0, 1.0), (w, 0.0, -1.0, 1.0), (0.0, h, 1.0, -1.0), (w, h, -1.0, -1.0)]) {
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
                          child: Icon(Icons.close, size: 14, color: Colors.white, semanticLabel: 'Убрать фото'),
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
      child: Material(
        color: p.surface,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => context.push('/settings'),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Нужен API-ключ ${provider.short}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  Text('Добавьте его в настройках — пара минут.', style: TextStyle(color: p.inkSecondary)),
                ]),
              ),
              Icon(Icons.chevron_right, color: p.inkSecondary),
            ]),
          ),
        ),
      ),
    );
  }
}
