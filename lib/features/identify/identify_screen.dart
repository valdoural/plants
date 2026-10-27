import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/photo_picker.dart';
import '../../core/settings.dart';
import '../../core/widgets.dart';
import '../../data/garden_controller.dart';
import '../../data/recognition/recognition_service.dart';
import 'identify_result_screen.dart';

/// Съёмка/выбор фото → распознавание.
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

  Future<void> _identify() async {
    setState(() => _busy = true);
    try {
      final result = await ref.read(recognitionServiceProvider).identify(_photos, organ: _organ);
      final record = await ref.read(gardenProvider.notifier).addIdentification(result, _photos.first);
      if (!mounted) return;
      context.pushReplacement('/identify/result', extra: IdentifyResultArgs(record: record, photo: _photos.first));
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final t = Theme.of(context);
    final hasKey = settings.hasKeyFor(settings.provider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Распознать растение'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ActionChip(
              avatar: const Icon(Icons.swap_horiz, size: 18),
              label: Text(settings.provider.short),
              onPressed: () => _chooseProvider(context, settings),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (!hasKey) _MissingKeyCard(provider: settings.provider),
            AspectRatio(
              aspectRatio: 1,
              child: _photos.isEmpty
                  ? _Viewfinder(onCamera: () => _add(ImageSource.camera), onGallery: () => _add(ImageSource.gallery))
                  : Stack(
                      fit: StackFit.expand,
                      children: [
                        PlantImage.memory(_photos.last),
                        if (_busy) const _ScanningOverlay(),
                      ],
                    ),
            ),
            if (_photos.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 72,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (var i = 0; i < _photos.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Stack(
                          children: [
                            SizedBox(width: 72, height: 72, child: PlantImage.memory(_photos[i], radius: 12)),
                            Positioned(
                              right: 0,
                              top: 0,
                              child: GestureDetector(
                                onTap: _busy ? null : () => setState(() => _photos.removeAt(i)),
                                child: const CircleAvatar(radius: 11, child: Icon(Icons.close, size: 14)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (_photos.length < _maxPhotos)
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(minimumSize: const Size(72, 72), padding: EdgeInsets.zero),
                        onPressed: _busy ? null : () => _add(ImageSource.gallery),
                        child: const Icon(Icons.add_photo_alternate_outlined),
                      ),
                  ],
                ),
              ),
              Text('Можно добавить до $_maxPhotos фото одного растения — так точнее.',
                  style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant)),
            ],
            if (settings.provider == RecognitionProviderId.plantNet) ...[
              const SizedBox(height: 16),
              Text('Что на фото?', style: t.textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final o in PlantOrgan.values)
                    ChoiceChip(label: Text(o.label), selected: _organ == o, onSelected: (_) => setState(() => _organ = o)),
                ],
              ),
            ],
            const SizedBox(height: 20),
            const _Tips(),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: FilledButton.icon(
            onPressed: _photos.isEmpty || _busy || !hasKey ? null : _identify,
            icon: _busy
                ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.search),
            label: Text(_busy ? 'Распознаём…' : 'Распознать'),
          ),
        ),
      ),
    );
  }

  Future<void> _chooseProvider(BuildContext context, AppSettings settings) async {
    final chosen = await showModalBottomSheet<RecognitionProviderId>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final p in RecognitionProviderId.values)
              ListTile(
                leading: Icon(p == settings.provider ? Icons.radio_button_checked : Icons.radio_button_off),
                title: Text(p.title),
                subtitle: Text(settings.hasKeyFor(p) ? p.pros.first : 'Ключ не задан'),
                onTap: () => Navigator.pop(context, p),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (chosen != null) await ref.read(settingsProvider.notifier).update((s) => s.copyWith(provider: chosen));
  }
}

class _Viewfinder extends StatelessWidget {
  const _Viewfinder({required this.onCamera, required this.onGallery});

  final VoidCallback onCamera;
  final VoidCallback onGallery;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.3), width: 2),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.local_florist, size: 72, color: scheme.primary),
          const SizedBox(height: 12),
          const Text('Наведите камеру на растение', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FilledButton.icon(onPressed: onCamera, icon: const Icon(Icons.photo_camera), label: const Text('Камера')),
              const SizedBox(width: 12),
              OutlinedButton.icon(onPressed: onGallery, icon: const Icon(Icons.photo_library), label: const Text('Галерея')),
            ],
          ),
        ],
      ),
    );
  }
}

class _ScanningOverlay extends StatelessWidget {
  const _ScanningOverlay();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        color: Colors.black38,
        alignment: Alignment.center,
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 12),
            Text('Сравниваем с базой растений…', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _MissingKeyCard extends StatelessWidget {
  const _MissingKeyCard({required this.provider});

  final RecognitionProviderId provider;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.tertiaryContainer,
      margin: const EdgeInsets.only(bottom: 16),
      child: ListTile(
        leading: const Icon(Icons.key),
        title: Text('Нужен API-ключ ${provider.short}'),
        subtitle: const Text('Добавьте ключ в настройках — это займёт пару минут.'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('/settings'),
      ),
    );
  }
}

class _Tips extends StatelessWidget {
  const _Tips();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    Widget tip(IconData i, String s) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(children: [
            Icon(i, size: 20, color: t.colorScheme.primary),
            const SizedBox(width: 10),
            Expanded(child: Text(s)),
          ]),
        );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Как сделать хорошее фото', style: t.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            tip(Icons.center_focus_strong, 'Растение в центре и в фокусе, занимает большую часть кадра'),
            tip(Icons.wb_sunny_outlined, 'Хорошее освещение, без сильных теней'),
            tip(Icons.local_florist_outlined, 'Цветок или лист крупным планом — лучше всего'),
          ],
        ),
      ),
    );
  }
}
