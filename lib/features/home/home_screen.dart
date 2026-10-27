import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/garden_controller.dart';
import '../garden/task_tile.dart';
import '../identify/identify_result_screen.dart';
import 'seasonal_tips.dart';

/// Главная: приветствие, задачи на сегодня, быстрые действия, недавние распознавания, совет месяца.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 6) return 'Доброй ночи';
    if (h < 12) return 'Доброе утро';
    if (h < 18) return 'Добрый день';
    return 'Добрый вечер';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(gardenProvider).value;
    final t = Theme.of(context);
    final due = data?.dueTasks ?? const [];
    final recent = data?.identifications.take(10).toList() ?? const [];
    final tip = seasonalTip(DateTime.now());

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.refresh(gardenProvider.future),
          child: ListView(
            padding: const EdgeInsets.only(bottom: 100),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_greeting(), style: t.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(
                      due.isEmpty
                          ? 'Сегодня растениям ничего не нужно'
                          : 'Растениям нужен уход: ${due.length}',
                      style: t.textTheme.bodyLarge?.copyWith(color: t.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: _ActionCard(
                        icon: Icons.center_focus_strong,
                        title: 'Распознать',
                        subtitle: 'Узнать вид по фото',
                        color: LeafyColors.forest,
                        onTap: () => context.push('/identify'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ActionCard(
                        icon: Icons.healing,
                        title: 'Диагноз',
                        subtitle: 'Что с растением?',
                        color: LeafyColors.terracotta,
                        onTap: () => context.go('/diagnose'),
                      ),
                    ),
                  ],
                ),
              ),
              if (due.isNotEmpty) ...[
                SectionHeader('Задачи на сегодня', action: 'Все', onAction: () => context.push('/reminders')),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      for (final task in due.take(5))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: TaskTile(task: task, plant: data!.plant(task.plantId)),
                        ),
                    ],
                  ),
                ),
              ],
              if (recent.isNotEmpty) ...[
                SectionHeader('Недавно распознано', action: 'История', onAction: () => context.push('/history')),
                SizedBox(
                  height: 168,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    scrollDirection: Axis.horizontal,
                    itemCount: recent.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 12),
                    itemBuilder: (_, i) {
                      final r = recent[i];
                      return SizedBox(
                        width: 120,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => context.push('/identify/result', extra: IdentifyResultArgs(record: r)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(width: 120, height: 120, child: PlantImage(r.photoUrl)),
                              const SizedBox(height: 6),
                              Text(r.top?.displayName ?? 'Не распознано',
                                  maxLines: 2, overflow: TextOverflow.ellipsis, style: t.textTheme.bodySmall),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
              SectionHeader('Совет на ${tip.month}'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Card(
                  color: t.colorScheme.secondaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Icon(tip.icon, color: t.colorScheme.onSecondaryContainer),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(tip.title,
                                style: t.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700, color: t.colorScheme.onSecondaryContainer)),
                          ),
                        ]),
                        const SizedBox(height: 8),
                        for (final line in tip.points)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text('•  $line', style: TextStyle(color: t.colorScheme.onSecondaryContainer)),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({required this.icon, required this.title, required this.subtitle, required this.color, required this.onTap});

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: Colors.white, size: 32),
              const SizedBox(height: 16),
              Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
              Text(subtitle, style: const TextStyle(color: Colors.white70)),
            ],
          ),
        ),
      ),
    );
  }
}
