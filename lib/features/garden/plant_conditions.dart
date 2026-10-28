import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/care_advice.dart';
import '../../data/garden_controller.dart';
import '../../data/models.dart';

/// Условия растения и расчёт полива по ним; кнопка — применить расчёт к напоминанию.
class PlantConditionsCard extends ConsumerWidget {
  const PlantConditionsCard({
    super.key,
    required this.plant,
    required this.tasks,
  });

  final Plant plant;
  final List<CareTask> tasks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final c = plant.conditions;
    final rows = [
      ('Возраст', c.age?.label),
      ('Свет', c.light?.label),
      ('Горшок', c.pot?.label),
      ('Дренаж', c.drainage == null ? null : (c.drainage! ? 'есть' : 'нет')),
      ('Диаметр', c.potCm == null ? null : '${c.potCm} см'),
    ];
    final water = tasks.where((t) => t.type == CareType.water).firstOrNull;
    final plan = waterPlan(
      baseDays: plant.species?.suggestedWateringDays ?? 7,
      conditions: c,
      location: plant.location,
      date: DateTime.now(),
    );
    final advice = conditionAdvice(plant);

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Условия',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
              ),
              TextButton(
                onPressed: () => showConditionsSheet(context, ref, plant),
                child: Text(c.isEmpty ? 'Указать' : 'Изменить'),
              ),
            ],
          ),
          if (c.isEmpty)
            Text(
              'Укажите свет, горшок и возраст — Leafy точнее рассчитает полив и подскажет, что поправить.',
              style: TextStyle(
                fontSize: 15,
                height: 1.4,
                color: p.inkSecondary,
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (label, value) in rows)
                  if (value != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: p.surfaceHigh,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: '$label  ',
                              style: TextStyle(color: p.inkSecondary),
                            ),
                            TextSpan(
                              text: value,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
              ],
            ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.water_drop, color: p.water, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      [
                        'Поливать ${everyLabel(plan.intervalDays)}',
                        if (plan.amountMl != null) 'по ${plan.amountMl} мл',
                      ].join(', '),
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      plan.reasons.join(' · '),
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: p.inkSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (water != null && water.intervalDays != plan.intervalDays) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton(
                onPressed: () => ref
                    .read(gardenProvider.notifier)
                    .saveTask(water.withInterval(plan.intervalDays)),
                child: Text(
                  'Напоминать ${everyLabel(plan.intervalDays)} '
                  '(сейчас ${everyLabel(water.intervalDays)})',
                ),
              ),
            ),
          ],
          for (final tip in advice) ...[
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.tips_and_updates_outlined,
                  color: p.accent,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    tip,
                    style: const TextStyle(fontSize: 14, height: 1.4),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Лист выбора условий растения.
Future<void> showConditionsSheet(
  BuildContext context,
  WidgetRef ref,
  Plant plant,
) async {
  var age = plant.conditions.age;
  var light = plant.conditions.light;
  var pot = plant.conditions.pot;
  var drainage = plant.conditions.drainage;
  var potCm = plant.conditions.potCm;

  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        Widget group<T>(
          String title,
          List<T> values,
          T? selected,
          String Function(T) label,
          ValueChanged<T?> onChanged,
        ) => Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final v in values)
                    ChoiceChip(
                      label: Text(label(v)),
                      selected: v == selected,
                      onSelected: (on) =>
                          setState(() => onChanged(on ? v : null)),
                    ),
                ],
              ),
            ],
          ),
        );
        final p = ctx.palette;
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.85,
          maxChildSize: 0.95,
          builder: (ctx, scroll) => ListView(
            controller: scroll,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            children: [
              const Text(
                'Условия растения',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                'Всё необязательно. Чем больше укажете, тем точнее расчёт полива.',
                style: TextStyle(fontSize: 14, color: p.inkSecondary),
              ),
              const SizedBox(height: 18),
              group(
                'Возраст',
                PlantAge.values,
                age,
                (v) => v.label,
                (v) => age = v,
              ),
              group(
                'Свет',
                PlantLight.values,
                light,
                (v) => v.label,
                (v) => light = v,
              ),
              if (light != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: Text(
                    light!.hint,
                    style: TextStyle(fontSize: 13, color: p.inkSecondary),
                  ),
                ),
              group(
                'Горшок',
                PotType.values,
                pot,
                (v) => v.label,
                (v) => pot = v,
              ),
              group(
                'Дренажные отверстия',
                const [true, false],
                drainage,
                (v) => v ? 'Есть' : 'Нет',
                (v) => drainage = v,
              ),
              if (pot != PotType.ground) ...[
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Диаметр горшка',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Text(
                      potCm == null ? 'не указан' : '$potCm см',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                Slider(
                  min: 6,
                  max: 40,
                  divisions: 34,
                  value: (potCm ?? 14).toDouble(),
                  label: '${potCm ?? 14} см',
                  onChanged: (v) => setState(() => potCm = v.round()),
                ),
              ],
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Сохранить'),
              ),
            ],
          ),
        );
      },
    ),
  );
  if (saved != true) return;
  await ref
      .read(gardenProvider.notifier)
      .updatePlant(
        plant.copyWith(
          conditions: PlantConditions(
            age: age,
            light: light,
            pot: pot,
            drainage: drainage,
            potCm: pot == PotType.ground ? null : potCm,
          ),
        ),
      );
}
