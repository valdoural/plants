import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets.dart';
import '../../data/models.dart';
import 'species_screen.dart';

class IdentifyResultArgs {
  const IdentifyResultArgs({required this.record, this.photo});

  final IdentificationRecord record;
  final Uint8List? photo;
}

/// Результат распознавания: лучший кандидат крупно, остальные списком.
class IdentifyResultScreen extends StatelessWidget {
  const IdentifyResultScreen({super.key, required this.args});

  final IdentifyResultArgs args;

  @override
  Widget build(BuildContext context) {
    final record = args.record;
    final t = Theme.of(context);
    final top = record.top;

    void open(PlantCandidate c) =>
        context.push('/species', extra: SpeciesArgs(candidate: c, photo: args.photo, photoUrl: record.photoUrl));

    return Scaffold(
      appBar: AppBar(title: const Text('Результат')),
      body: top == null
          ? EmptyState(
              icon: Icons.search_off,
              title: 'Не удалось распознать',
              message: 'Попробуйте другое фото: ближе, при хорошем свете, с цветком или листом в кадре.',
              action: FilledButton(onPressed: () => context.pushReplacement('/identify'), child: const Text('Ещё раз')),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
              children: [
                Row(
                  children: [
                    SizedBox(
                      width: 96,
                      height: 96,
                      child: args.photo != null ? PlantImage.memory(args.photo!) : PlantImage(record.photoUrl),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Ваше фото', style: t.textTheme.labelMedium?.copyWith(color: t.colorScheme.onSurfaceVariant)),
                          const SizedBox(height: 4),
                          Text('Распознано: ${record.provider}', style: t.textTheme.bodyMedium),
                          if (top.probability < 0.3) ...[
                            const SizedBox(height: 6),
                            Text('Уверенность низкая — сравните фото вариантов ниже.',
                                style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.tertiary)),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _TopCandidateCard(candidate: top, onTap: () => open(top)),
                if (record.candidates.length > 1) ...[
                  const SizedBox(height: 24),
                  Text('Другие варианты', style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  for (final c in record.candidates.skip(1))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Card(
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(8),
                          leading: SizedBox(width: 56, height: 56, child: PlantImage(c.imageUrls.firstOrNull, radius: 12)),
                          title: Text(c.displayName, maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text(c.scientificName, style: const TextStyle(fontStyle: FontStyle.italic)),
                          trailing: ConfidenceBadge(c.probability),
                          onTap: () => open(c),
                        ),
                      ),
                    ),
                ],
              ],
            ),
    );
  }
}

class _TopCandidateCard extends StatelessWidget {
  const _TopCandidateCard({required this.candidate, required this.onTap});

  final PlantCandidate candidate;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final images = candidate.imageUrls.take(4).toList();
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (images.isNotEmpty)
              SizedBox(
                height: 200,
                child: Row(
                  children: [
                    Expanded(flex: 2, child: PlantImage(images.first, radius: 0)),
                    if (images.length > 1)
                      Expanded(
                        child: Column(
                          children: [
                            for (final u in images.skip(1).take(2))
                              Expanded(child: Padding(padding: const EdgeInsets.only(left: 2, bottom: 1), child: PlantImage(u, radius: 0))),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(candidate.displayName,
                            style: t.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                      ),
                      ConfidenceBadge(candidate.probability),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(candidate.scientificName, style: t.textTheme.bodyLarge?.copyWith(fontStyle: FontStyle.italic)),
                  if (candidate.family != null)
                    Text('Семейство: ${candidate.family}', style: t.textTheme.bodySmall?.copyWith(color: t.colorScheme.onSurfaceVariant)),
                  if (candidate.description != null) ...[
                    const SizedBox(height: 12),
                    Text(candidate.description!, maxLines: 3, overflow: TextOverflow.ellipsis),
                  ],
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(onPressed: onTap, icon: const Icon(Icons.arrow_forward), label: const Text('Подробнее')),
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
