import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/garden_controller.dart';

/// Нижняя навигация: Главная · Диагноз · [камера] · Мой сад · Ещё.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final due = ref.watch(gardenProvider).value?.dueTasks.length ?? 0;
    final scheme = Theme.of(context).colorScheme;

    Widget item(int index, IconData icon, IconData selectedIcon, String label, {int badge = 0}) {
      final selected = shell.currentIndex == index;
      final color = selected ? scheme.primary : scheme.onSurfaceVariant;
      return Expanded(
        child: InkResponse(
          onTap: () => shell.goBranch(index, initialLocation: index == shell.currentIndex),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Badge(
                isLabelVisible: badge > 0,
                label: Text('$badge'),
                child: Icon(selected ? selectedIcon : icon, color: color),
              ),
              const SizedBox(height: 4),
              Text(label,
                  style: TextStyle(fontSize: 12, color: color, fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: shell,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: FloatingActionButton.large(
        heroTag: 'identify',
        tooltip: 'Распознать растение',
        shape: const CircleBorder(),
        onPressed: () => context.push('/identify'),
        child: const Icon(Icons.center_focus_strong, size: 36),
      ),
      bottomNavigationBar: BottomAppBar(
        height: 72,
        padding: EdgeInsets.zero,
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        child: Row(
          children: [
            item(0, Icons.home_outlined, Icons.home, 'Главная', badge: due),
            item(1, Icons.healing_outlined, Icons.healing, 'Диагноз'),
            const SizedBox(width: 96),
            item(2, Icons.local_florist_outlined, Icons.local_florist, 'Мой сад'),
            item(3, Icons.more_horiz, Icons.more_horiz, 'Ещё'),
          ],
        ),
      ),
    );
  }
}
