import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/garden_controller.dart';
import '../../data/models.dart';

/// Строка задачи ухода: фото, «Монстера — полив, сегодня», кнопки «Готово» и «Завтра».
class TaskTile extends ConsumerWidget {
  const TaskTile({super.key, required this.task, this.plant, this.showPlant = true});

  final CareTask task;
  final Plant? plant;
  final bool showPlant;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final overdue = task.daysLeft < 0;
    final garden = ref.read(gardenProvider.notifier);
    final withPlant = showPlant && plant != null;

    final title = withPlant ? plant!.nickname : task.type.label;
    final when = task.enabled ? dueLabel(task) : 'выключено';
    final subtitle = withPlant
        ? '${task.type.label} · $when'
        : '$when · ${everyLabel(task.intervalDays)}';

    return Material(
      color: p.surface,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: withPlant ? () => context.push('/plant/${plant!.id}') : null,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
          child: Row(
            children: [
              if (withPlant)
                PlantImage(plant!.photoUrl, size: 52, radius: 14)
              else
                SizedBox.square(dimension: 40, child: Icon(careIcon(task.type), color: careColor(context, task.type))),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 14, color: overdue ? p.alert : p.inkSecondary, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              if (task.isDue)
                withPlant
                    ? TextButton(
                        onPressed: () => garden.snoozeTask(task),
                        style: TextButton.styleFrom(foregroundColor: p.inkSecondary, minimumSize: const Size(44, 44)),
                        child: const Text('Завтра'),
                      )
                    : IconButton(
                        tooltip: 'Отложить на завтра',
                        onPressed: () => garden.snoozeTask(task),
                        icon: Icon(Icons.snooze, color: p.inkSecondary),
                      ),
              FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size(44, 40), padding: const EdgeInsets.symmetric(horizontal: 16),
                    textStyle: const TextStyle(fontFamily: 'Manrope', fontSize: 15, fontWeight: FontWeight.w700)),
                onPressed: () async {
                  await garden.completeTask(task);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('${task.type.label} отмечен. Следующий — через ${task.intervalDays} дн.'),
                      action: SnackBarAction(label: 'Отменить', onPressed: () => garden.saveTask(task)),
                    ));
                  }
                },
                child: const Text('Готово'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
