import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/photo_picker.dart';
import '../../core/settings.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/garden_controller.dart';
import '../../data/recognition/recognition_service.dart';
import 'diagnose_result_screen.dart';

/// Диагностика: фото больного растения → болезни и лечение (через Plant.id).
class DiagnoseScreen extends ConsumerStatefulWidget {
  const DiagnoseScreen({super.key});

  @override
  ConsumerState<DiagnoseScreen> createState() => _DiagnoseScreenState();
}

class _DiagnoseScreenState extends ConsumerState<DiagnoseScreen> {
  var _busy = false;

  Future<void> _start() async {
    final photo = await pickPhotoWithSheet(context);
    if (photo == null) return;
    await _diagnose(photo);
  }

  Future<void> _diagnose(Uint8List photo) async {
    setState(() => _busy = true);
    try {
      final result = await ref.read(recognitionServiceProvider).diagnose([photo]);
      final record = await ref.read(gardenProvider.notifier).addDiagnosis(result, photo);
      if (mounted) context.push('/diagnose/result', extra: DiagnoseResultArgs(record: record, photo: photo));
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final history = ref.watch(gardenProvider).value?.diagnoses ?? const [];
    final t = Theme.of(context);
    final fmt = DateFormat('d MMM, HH:mm', 'ru');

    return Scaffold(
      appBar: AppBar(title: const Text('Диагностика')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
        children: [
          Card(
            color: t.colorScheme.tertiaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.healing, size: 40, color: t.colorScheme.onTertiaryContainer),
                  const SizedBox(height: 12),
                  Text('Что случилось с растением?',
                      style: t.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700, color: t.colorScheme.onTertiaryContainer)),
                  const SizedBox(height: 6),
                  Text('Сфотографируйте поражённые листья или стебель крупным планом — мы определим проблему и подскажем лечение.',
                      style: TextStyle(color: t.colorScheme.onTertiaryContainer)),
                  const SizedBox(height: 16),
                  if (!settings.canDiagnose)
                    _NeedPlantIdKey()
                  else
                    FilledButton.icon(
                      onPressed: _busy ? null : _start,
                      icon: _busy
                          ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.photo_camera),
                      label: Text(_busy ? 'Анализируем…' : 'Сделать фото'),
                    ),
                ],
              ),
            ),
          ),
          if (history.isNotEmpty) ...[
            const SectionHeader('История'),
            for (final d in history)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(8),
                    leading: SizedBox(width: 56, height: 56, child: PlantImage(d.photoUrl, radius: 12)),
                    title: Text(
                      d.result.isHealthy ? 'Здоровое' : (d.result.diseases.firstOrNull?.name ?? 'Есть проблемы'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(fmt.format(d.createdAt)),
                    trailing: Icon(
                      d.result.isHealthy ? Icons.check_circle : Icons.error_outline,
                      color: d.result.isHealthy ? context.palette.accent : context.palette.alert,
                    ),
                    onTap: () => context.push('/diagnose/result', extra: DiagnoseResultArgs(record: d)),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _NeedPlantIdKey extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Диагностика работает только через Plant.id: у Pl@ntNet нет определения болезней.'),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () => context.push('/settings'),
          icon: const Icon(Icons.key),
          label: const Text('Добавить ключ Plant.id'),
        ),
      ],
    );
  }
}
