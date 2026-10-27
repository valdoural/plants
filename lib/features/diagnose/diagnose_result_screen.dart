import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/garden_controller.dart';
import '../../data/models.dart';

class DiagnoseResultArgs {
  const DiagnoseResultArgs({required this.record, this.photo});

  final DiagnosisRecord record;
  final Uint8List? photo;
}

/// Результат диагностики: общий статус здоровья, вероятные проблемы, лечение.
class DiagnoseResultScreen extends ConsumerWidget {
  const DiagnoseResultScreen({super.key, required this.args});

  final DiagnoseResultArgs args;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = args.record.result;
    final p = context.palette;
    final healthy = r.isHealthy;
    final diseases = r.diseases.where((d) => d.probability >= 0.05).toList();
    final photoHeight = (MediaQuery.sizeOf(context).height * 0.42).clamp(260.0, 400.0);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: SizedBox(
              height: photoHeight,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  args.photo != null ? PlantImage.memory(args.photo!, radius: 0) : PlantImage(args.record.photoUrl, radius: 0),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: -1,
                    height: 29,
                    child: DecoratedBox(
                      decoration: BoxDecoration(color: p.bg, borderRadius: const BorderRadius.vertical(top: Radius.circular(28))),
                    ),
                  ),
                  SafeArea(
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: IconButton.filled(
                          tooltip: 'Назад',
                          style: IconButton.styleFrom(backgroundColor: p.bg.withValues(alpha: 0.7), foregroundColor: p.ink),
                          onPressed: () => Navigator.of(context).maybePop(),
                          icon: const Icon(Icons.arrow_back),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
            sliver: SliverList.list(
              children: [
                Text(
                  'Здоровье ${(r.healthyProbability * 100).round()}%',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: healthy ? p.accent : p.alert),
                ),
                const SizedBox(height: 6),
                Text(
                  healthy ? 'Растение выглядит здоровым' : _cap(diseases.firstOrNull?.name ?? 'Есть признаки проблем'),
                  style: const TextStyle(fontSize: 32, height: 1.12, fontWeight: FontWeight.w800, letterSpacing: -0.8),
                ),
                if (!healthy && diseases.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text('Вероятность ${(diseases.first.probability * 100).round()}%. Подробности и лечение — ниже.',
                      style: TextStyle(fontSize: 16, color: p.inkSecondary)),
                ],
                if (diseases.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Text(healthy ? 'Возможные слабые признаки' : 'Вероятные причины',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  for (final (i, d) in diseases.indexed)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _DiseaseCard(disease: d, initiallyExpanded: i == 0 && !healthy),
                    ),
                ],
                const SizedBox(height: 16),
                if (args.record.plantId == null) _AttachToPlant(record: args.record),
                const SizedBox(height: 16),
                Text(
                  'Результат автоматический и может ошибаться. При серьёзных проблемах проконсультируйтесь со специалистом.',
                  style: TextStyle(fontSize: 13, color: p.inkSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DiseaseCard extends StatelessWidget {
  const _DiseaseCard({required this.disease, required this.initiallyExpanded});

  final DiseaseSuggestion disease;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    Widget section(String title, IconData icon, List<String> items) => items.isEmpty
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(icon, size: 18, color: p.accent),
                  const SizedBox(width: 6),
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                ]),
                for (final s in items) Padding(padding: const EdgeInsets.only(top: 4, left: 24), child: Text('•  $s')),
              ],
            ),
          );

    return Card(
      child: ExpansionTile(
        initiallyExpanded: initiallyExpanded,
        shape: const Border(),
        leading: disease.imageUrls.isEmpty
            ? const Icon(Icons.coronavirus_outlined)
            : SizedBox(width: 48, height: 48, child: PlantImage(disease.imageUrls.first, radius: 10)),
        title: Text(_cap(disease.name), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        iconColor: p.inkSecondary,
        collapsedIconColor: p.inkSecondary,
        trailing: ConfidenceBadge(disease.probability),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (disease.description != null) Text(disease.description!),
          if (disease.cause != null) ...[
            const SizedBox(height: 8),
            Text('Причина: ${disease.cause}', style: const TextStyle(fontStyle: FontStyle.italic)),
          ],
          section('Профилактика', Icons.shield_outlined, disease.prevention),
          section('Без химии', Icons.eco_outlined, disease.biological),
          section('Препараты', Icons.science_outlined, disease.chemical),
        ],
      ),
    );
  }
}

String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

/// «Сохранить в дневник растения» — запись с итогом диагноза.
class _AttachToPlant extends ConsumerWidget {
  const _AttachToPlant({required this.record});

  final DiagnosisRecord record;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plants = ref.watch(gardenProvider).value?.plants ?? const [];
    if (plants.isEmpty) return const SizedBox.shrink();
    return OutlinedButton.icon(
      icon: const Icon(Icons.bookmark_add_outlined),
      label: const Text('Записать в дневник растения'),
      onPressed: () async {
        final plant = await showModalBottomSheet<Plant>(
          context: context,
          builder: (ctx) => SafeArea(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final p in plants)
                  ListTile(
                    leading: SizedBox(width: 44, height: 44, child: PlantImage(p.photoUrl, radius: 10)),
                    title: Text(p.nickname),
                    onTap: () => Navigator.pop(ctx, p),
                  ),
              ],
            ),
          ),
        );
        if (plant == null) return;
        final r = record.result;
        final summary = r.isHealthy
            ? 'Диагностика: растение здорово (${(r.healthyProbability * 100).round()}%).'
            : 'Диагностика: ${r.diseases.take(3).map((d) => '${d.name} (${(d.probability * 100).round()}%)').join(', ')}.';
        await ref.read(gardenProvider.notifier).addNote(plant.id, summary);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Записано в дневник «${plant.nickname}»')));
        }
      },
    );
  }
}
