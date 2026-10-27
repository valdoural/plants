import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets.dart';
import '../../data/models.dart';
import '../garden/add_plant_sheet.dart';

class SpeciesArgs {
  const SpeciesArgs({required this.candidate, this.photo, this.photoUrl});

  final PlantCandidate candidate;

  /// Фото пользователя — станет обложкой растения в саду.
  final Uint8List? photo;
  final String? photoUrl;
}

/// Карточка вида: фото, описание, уход, ссылки.
class SpeciesScreen extends ConsumerWidget {
  const SpeciesScreen({super.key, required this.args});

  final SpeciesArgs args;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = args.candidate;
    final t = Theme.of(context);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: PlantImage(c.imageUrls.firstOrNull ?? args.photoUrl, radius: 0),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c.displayName, style: t.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(c.scientificName, style: t.textTheme.titleMedium?.copyWith(fontStyle: FontStyle.italic)),
                  if (c.commonNames.length > 1) ...[
                    const SizedBox(height: 8),
                    Text('Также: ${c.commonNames.skip(1).take(4).join(', ')}',
                        style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant)),
                  ],
                  const SizedBox(height: 16),
                  SpeciesCareFacts(candidate: c),
                  if (c.description != null) ...[
                    const SizedBox(height: 20),
                    Text('Описание', style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Text(c.description!, style: t.textTheme.bodyLarge),
                  ],
                  if (c.imageUrls.length > 1) ...[
                    const SizedBox(height: 20),
                    Text('Похожие фото', style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 110,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: c.imageUrls.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (_, i) => SizedBox(width: 110, child: PlantImage(c.imageUrls[i], radius: 12)),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  _Taxonomy(candidate: c),
                  if (c.infoUrl != null) ...[
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () => openLink(c.infoUrl!),
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('Больше о виде'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: FilledButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Добавить в мой сад'),
            onPressed: () async {
              final plant = await showAddPlantSheet(context, ref, species: c, photo: args.photo);
              if (plant != null && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('«${plant.nickname}» в вашем саду')));
                context.go('/garden');
                context.push('/plant/${plant.id}');
              }
            },
          ),
        ),
      ),
    );
  }
}

/// Плитки «полив / свет / почва / ядовитость».
class SpeciesCareFacts extends StatelessWidget {
  const SpeciesCareFacts({super.key, required this.candidate});

  final PlantCandidate candidate;

  @override
  Widget build(BuildContext context) {
    final c = candidate;
    final facts = <(IconData, String, String)>[
      (Icons.water_drop, 'Полив', c.wateringLevel == null ? 'нет данных' : everyLabel(c.suggestedWateringDays)),
      if (c.light != null) (Icons.wb_sunny, 'Свет', c.light!),
      if (c.soil != null) (Icons.grass, 'Почва', c.soil!),
      if (c.toxicity != null) (Icons.warning_amber, 'Ядовитость', c.toxicity!),
    ];
    if (c.wateringLevel == null && facts.length == 1) {
      return Card(
        child: ListTile(
          leading: const Icon(Icons.info_outline),
          title: const Text('Советы по уходу недоступны'),
          subtitle: const Text('Этот сервис возвращает только вид. Для советов по уходу используйте Plant.id.'),
        ),
      );
    }
    return Column(
      children: [
        for (final (icon, title, value) in facts)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Card(
              child: ListTile(
                leading: CircleAvatar(child: Icon(icon)),
                title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(value),
              ),
            ),
          ),
      ],
    );
  }
}

class _Taxonomy extends StatelessWidget {
  const _Taxonomy({required this.candidate});

  final PlantCandidate candidate;

  @override
  Widget build(BuildContext context) {
    final rows = [
      if (candidate.family != null) ('Семейство', candidate.family!),
      if (candidate.genus != null) ('Род', candidate.genus!),
      ('Вид', candidate.scientificName),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            for (final (k, v) in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(children: [
                  SizedBox(width: 110, child: Text(k, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant))),
                  Expanded(child: Text(v, style: const TextStyle(fontStyle: FontStyle.italic))),
                ]),
              ),
          ],
        ),
      ),
    );
  }
}
