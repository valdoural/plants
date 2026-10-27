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
    final p = context.palette;
    final fmt = DateFormat('d MMMM, HH:mm', 'ru');

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
          children: [
            const Text('Что с растением?',
                style: TextStyle(fontSize: 36, height: 1.1, fontWeight: FontWeight.w800, letterSpacing: -1)),
            const SizedBox(height: 10),
            Text(
              'Сфотографируйте больное место крупно: пятна, пожелтевший лист, вредителей. '
              'Определим вероятную причину и подскажем, как лечить.',
              style: TextStyle(fontSize: 17, height: 1.45, color: p.inkSecondary),
            ),
            const SizedBox(height: 20),
            if (!settings.canDiagnose)
              const _NeedPlantIdKey()
            else
              FilledButton.icon(
                onPressed: _busy ? null : _start,
                icon: _busy
                    ? SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2, color: p.onInkButton))
                    : const Icon(Icons.photo_camera_outlined),
                label: Text(_busy ? 'Анализируем…' : 'Сфотографировать'),
              ),
            if (history.isNotEmpty) ...[
              const SizedBox(height: 32),
              const Text('История', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              for (final d in history)
                InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => context.push('/diagnose/result', extra: DiagnoseResultArgs(record: d)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        PlantImage(d.photoUrl, size: 60, radius: 14),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                d.result.isHealthy ? 'Растение здорово' : _cap(d.result.diseases.firstOrNull?.name ?? 'Есть проблемы'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                              ),
                              Text(fmt.format(d.createdAt), style: TextStyle(fontSize: 14, color: p.inkSecondary)),
                            ],
                          ),
                        ),
                        Text(
                          d.result.isHealthy ? 'здорово' : 'проблема',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: d.result.isHealthy ? p.accent : p.alert,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

class _NeedPlantIdKey extends StatelessWidget {
  const _NeedPlantIdKey();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Диагностика работает через Plant.id: у Pl@ntNet нет определения болезней.',
            style: TextStyle(fontSize: 15, color: context.palette.inkSecondary)),
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
