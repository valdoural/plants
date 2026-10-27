import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/garden_controller.dart';
import 'theme.dart';

/// Нижняя панель «Витрины»: Сегодня · Сад · [камера] · Диагноз · Ещё.
/// Вкладки — подписи без иконок; единственная «кнопка» в панели — камера.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  // Порядок веток в роутере: 0 — сегодня, 1 — диагноз, 2 — сад, 3 — ещё.
  static const _today = 0, _diagnose = 1, _garden = 2, _more = 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final due = ref.watch(gardenProvider).value?.dueTasks.length ?? 0;
    final p = context.palette;

    Widget tab(int branch, String label, {int badge = 0}) {
      final selected = shell.currentIndex == branch;
      return Expanded(
        child: Semantics(
          selected: selected,
          button: true,
          child: InkResponse(
            onTap: () => shell.goBranch(branch, initialLocation: branch == shell.currentIndex),
            radius: 36,
            child: SizedBox(
              height: 56,
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                        color: selected ? p.accent : p.inkSecondary,
                      ),
                    ),
                    if (badge > 0) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(color: p.accent, borderRadius: BorderRadius.circular(10)),
                        child: Text('$badge', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: p.bg)),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: shell,
      bottomNavigationBar: Material(
        color: p.bar,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
            child: Row(
              children: [
                tab(_today, 'Сегодня', badge: due),
                tab(_garden, 'Сад'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Tooltip(
                    message: 'Распознать растение',
                    child: Material(
                      color: p.inkButton,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => context.push('/identify'),
                        child: SizedBox.square(
                          dimension: 56,
                          child: Icon(Icons.center_focus_weak, size: 28, color: p.onInkButton),
                        ),
                      ),
                    ),
                  ),
                ),
                tab(_diagnose, 'Диагноз'),
                tab(_more, 'Ещё'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
