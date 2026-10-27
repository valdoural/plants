import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets.dart';
import '../../data/garden_controller.dart';
import '../../data/models.dart';

/// Строка задачи ухода: «Полить Фикус — сегодня» + кнопки «Готово» и «Отложить».
class TaskTile extends ConsumerWidget {
  const TaskTile({super.key, required this.task, this.plant, this.showPlant = true});

  final CareTask task;
  final Plant? plant;
  final bool showPlant;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context);
    final overdue = task.daysLeft < 0;
    final garden = ref.read(gardenProvider.notifier);
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
        onTap: showPlant && plant != null ? () => context.push('/plant/${plant!.id}') : null,
        leading: showPlant && plant != null
            ? SizedBox(
                width: 52,
                height: 52,
                child: Stack(children: [
                  PlantImage(plant!.photoUrl, size: 52, radius: 14),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: CircleAvatar(
                      radius: 11,
                      backgroundColor: careColor(task.type),
                      child: Icon(careIcon(task.type), size: 13, color: Colors.white),
                    ),
                  ),
                ]),
              )
            : CircleAvatar(
                backgroundColor: careColor(task.type).withValues(alpha: 0.15),
                child: Icon(careIcon(task.type), color: careColor(task.type)),
              ),
        title: Text(
          showPlant && plant != null ? '${task.type.label}: ${plant!.nickname}' : task.type.label,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${task.enabled ? dueLabel(task) : 'выключено'} · ${everyLabel(task.intervalDays)}',
          style: TextStyle(color: overdue ? t.colorScheme.error : null),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (task.isDue)
              IconButton(
                tooltip: 'Отложить на день',
                icon: const Icon(Icons.snooze),
                onPressed: () => garden.snoozeTask(task),
              ),
            IconButton.filledTonal(
              tooltip: 'Готово',
              icon: const Icon(Icons.check),
              onPressed: () async {
                await garden.completeTask(task);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('${task.type.label} отмечен. Следующий — через ${task.intervalDays} дн.'),
                    behavior: SnackBarBehavior.floating,
                    action: SnackBarAction(label: 'Отменить', onPressed: () => garden.saveTask(task)),
                  ));
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
