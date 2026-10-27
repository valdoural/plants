import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/care_text_ru.dart';
import '../../data/models.dart';
import '../garden/add_plant_sheet.dart';
import 'species_screen.dart';

class IdentifyResultArgs {
  const IdentifyResultArgs({required this.record, this.photo});

  final IdentificationRecord record;
  final Uint8List? photo;
}

/// Результат распознавания: ваше фото сверху, на «листе» снизу — вид, уверенность, уход и действие.
class IdentifyResultScreen extends ConsumerWidget {
  const IdentifyResultScreen({super.key, required this.args});

  final IdentifyResultArgs args;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final record = args.record;
    final top = record.top;
    final p = context.palette;
    final photoHeight = (MediaQuery.sizeOf(context).height * 0.5).clamp(
      300.0,
      480.0,
    );

    void open(PlantCandidate c) => context.push(
      '/species',
      extra: SpeciesArgs(
        candidate: c,
        photo: args.photo,
        photoUrl: record.photoUrl,
      ),
    );

    Future<void> add(PlantCandidate c) async {
      final plant = await showAddPlantSheet(
        context,
        ref,
        species: c,
        photo: args.photo,
      );
      if (plant != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('«${plant.nickname}» в вашем саду')),
        );
        context.go('/garden');
        context.push('/plant/${plant.id}');
      }
    }

    final photo = args.photo != null
        ? PlantImage.memory(args.photo!, radius: 0)
        : PlantImage(record.photoUrl, radius: 0);

    if (top == null) {
      return Scaffold(
        appBar: AppBar(),
        body: EmptyState(
          icon: Icons.search_off,
          title: 'Не удалось распознать',
          message: 'Попробуйте другое фото: ближе, при хорошем свете, с цветком или листом в кадре.',
          action: FilledButton(
            onPressed: () => context.pushReplacement('/identify'),
            child: const Text('Снять ещё раз'),
          ),
        ),
      );
    }

    final facts = <(String, String)>[
      (
        'Полив',
        top.wateringLevel == null ? '' : everyLabel(top.suggestedWateringDays),
      ),
      ('Свет', lightSummaryRu(top.light) ?? ''),
      ('Ядовитость', toxicitySummaryRu(top.toxicity) ?? ''),
    ].where((f) => f.$2.isNotEmpty).toList();

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: SizedBox(
              height: photoHeight,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  photo,
                  // «Лист» с результатом заходит на фото скруглённым краем.
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: -1,
                    height: 29,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: p.bg,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(28),
                        ),
                      ),
                    ),
                  ),
                  SafeArea(
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: IconButton.filled(
                          tooltip: 'Назад',
                          style: IconButton.styleFrom(
                            backgroundColor: p.bg.withValues(alpha: 0.7),
                            foregroundColor: p.ink,
                          ),
                          onPressed: () => context.pop(),
                          icon: const Icon(Icons.arrow_back),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Container(
              color: p.bg,
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Совпадение ${(top.probability * 100).round()}% · ${record.provider}',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: top.probability >= 0.5 ? p.accent : p.inkSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    top.displayName,
                    style: const TextStyle(
                      fontSize: 32,
                      height: 1.12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.8,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    [
                      top.scientificName,
                      if (top.family != null) top.family,
                    ].join(' · '),
                    style: TextStyle(
                      fontSize: 17,
                      fontStyle: FontStyle.italic,
                      color: p.inkSecondary,
                    ),
                  ),
                  if (top.probability < 0.3) ...[
                    const SizedBox(height: 10),
                    Text(
                      'Уверенность низкая — сравните с вариантами ниже.',
                      style: TextStyle(
                        fontSize: 15,
                        color: p.alert,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  if (facts.isEmpty)
                    Text(
                      'Этот сервис определяет только вид. Советы по уходу даёт Plant.id.',
                      style: TextStyle(fontSize: 15, color: p.inkSecondary),
                    )
                  else
                    for (final (label, value) in facts)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 120,
                              child: Text(
                                label,
                                style: TextStyle(
                                  fontSize: 17,
                                  color: p.inkSecondary,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                value,
                                textAlign: TextAlign.end,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => add(top),
                    child: const Text('Добавить в сад'),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: () => open(top),
                    child: const Text('Подробнее о виде'),
                  ),
                  if (record.candidates.length > 1) ...[
                    const SizedBox(height: 28),
                    const Text(
                      'Другие варианты',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    for (final c in record.candidates.skip(1))
                      InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => open(c),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            children: [
                              PlantImage(
                                c.imageUrls.firstOrNull,
                                size: 56,
                                radius: 14,
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      c.displayName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Text(
                                      c.scientificName,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontStyle: FontStyle.italic,
                                        color: p.inkSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              ConfidenceBadge(c.probability),
                            ],
                          ),
                        ),
                      ),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
