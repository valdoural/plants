import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets.dart';
import '../../data/garden_controller.dart';
import '../../data/models.dart';
import '../garden/task_tile.dart';

/// Все напоминания: просроченные, сегодня, на неделе, позже.
class RemindersScreen extends ConsumerWidget {
  const RemindersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(gardenProvider).value;
    final tasks =
        (data?.tasks ?? const <CareTask>[])
            .where((t) => t.enabled && data!.plant(t.plantId) != null)
            .toList()
          ..sort((a, b) => a.nextDue.compareTo(b.nextDue));

    final groups = <String, List<CareTask>>{
      'Просрочено': tasks.where((t) => t.daysLeft < 0).toList(),
      'Сегодня': tasks.where((t) => t.daysLeft == 0).toList(),
      'Ближайшие 7 дней': tasks
          .where((t) => t.daysLeft > 0 && t.daysLeft <= 7)
          .toList(),
      'Позже': tasks.where((t) => t.daysLeft > 7).toList(),
    }..removeWhere((_, v) => v.isEmpty);

    return Scaffold(
      appBar: AppBar(title: const Text('Напоминания')),
      body: tasks.isEmpty
          ? const EmptyState(
              icon: Icons.notifications_none,
              title: 'Напоминаний пока нет',
              message: 'Они появятся, когда вы добавите растения в сад.',
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
              children: [
                for (final e in groups.entries) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
                    child: Text(
                      '${e.key} · ${e.value.length}',
                      style: Theme.of(context).textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  for (final task in e.value)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: TaskTile(
                        task: task,
                        plant: data!.plant(task.plantId),
                      ),
                    ),
                ],
              ],
            ),
    );
  }
}
