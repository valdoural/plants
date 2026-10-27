import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/garden_controller.dart';
import 'responsive.dart';
import 'theme.dart';

/// Навигация «Витрины»: на телефоне — нижняя панель с камерой в центре,
/// на планшете — узкая боковая, на компьютере — боковое меню с подписями.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  // Порядок веток в роутере: 0 — сегодня, 1 — диагноз, 2 — сад, 3 — ещё.
  static const _items = [
    (0, 'Сегодня', Icons.wb_twilight_outlined),
    (2, 'Сад', Icons.local_florist_outlined),
    (1, 'Диагноз', Icons.healing_outlined),
    (3, 'Ещё', Icons.more_horiz),
  ];

  void _go(int branch) => shell.goBranch(branch, initialLocation: branch == shell.currentIndex);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final due = ref.watch(gardenProvider).value?.dueTasks.length ?? 0;
    final size = context.windowSize;
    if (size.isCompact) return _bottom(context, due);

    final p = context.palette;
    final expanded = size == WindowSize.expanded;
    return Scaffold(
      body: Row(
        children: [
          Material(
            color: p.bar,
            child: SafeArea(
              right: false,
              child: SizedBox(
                width: expanded ? 240 : 96,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: expanded ? 16 : 8, vertical: 20),
                  child: Column(
                    crossAxisAlignment: expanded ? CrossAxisAlignment.stretch : CrossAxisAlignment.center,
                    children: [
                      Padding(
                        padding: EdgeInsets.only(left: expanded ? 8 : 0, bottom: 20),
                        child: Text('Leafy',
                            style: TextStyle(fontSize: expanded ? 26 : 18, fontWeight: FontWeight.w800, letterSpacing: -0.6)),
                      ),
                      if (expanded)
                        FilledButton.icon(
                          onPressed: () => context.push('/identify'),
                          icon: const Icon(Icons.center_focus_weak),
                          label: const Text('Распознать'),
                        )
                      else
                        _CameraButton(onTap: () => context.push('/identify')),
                      const SizedBox(height: 20),
                      for (final (branch, label, icon) in _items)
                        _SideItem(
                          label: label,
                          icon: icon,
                          selected: shell.currentIndex == branch,
                          badge: branch == 0 ? due : 0,
                          expanded: expanded,
                          onTap: () => _go(branch),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Expanded(child: shell),
        ],
      ),
    );
  }

  Widget _bottom(BuildContext context, int due) {
    final p = context.palette;

    Widget tab(int branch, String label, {int badge = 0}) {
      final selected = shell.currentIndex == branch;
      return Expanded(
        child: Semantics(
          selected: selected,
          button: true,
          child: InkResponse(
            onTap: () => _go(branch),
            radius: 36,
            child: SizedBox(
              height: 56,
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.fade,
                        softWrap: false,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                          color: selected ? p.accent : p.inkSecondary,
                        ),
                      ),
                    ),
                    // На телефоне — точка вместо числа, чтобы подпись не обрезалась.
                    if (badge > 0) ...[
                      const SizedBox(width: 4),
                      Container(width: 7, height: 7, decoration: BoxDecoration(color: p.accent, shape: BoxShape.circle)),
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
                tab(0, 'Сегодня', badge: due),
                tab(2, 'Сад'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: _CameraButton(onTap: () => context.push('/identify')),
                ),
                tab(1, 'Диагноз'),
                tab(3, 'Ещё'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.count);

  final int count;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(color: p.accent, borderRadius: BorderRadius.circular(10)),
      child: Text('$count', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: p.bg)),
    );
  }
}

class _CameraButton extends StatelessWidget {
  const _CameraButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Tooltip(
      message: 'Распознать растение',
      child: Material(
        color: p.inkButton,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox.square(dimension: 56, child: Icon(Icons.center_focus_weak, size: 28, color: p.onInkButton)),
        ),
      ),
    );
  }
}

class _SideItem extends StatelessWidget {
  const _SideItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.badge,
    required this.expanded,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final int badge;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final color = selected ? p.ink : p.inkSecondary;
    final content = expanded
        ? Row(children: [
            Icon(icon, color: selected ? p.accent : p.inkSecondary),
            const SizedBox(width: 14),
            Expanded(
              child: Text(label,
                  style: TextStyle(fontSize: 16, fontWeight: selected ? FontWeight.w800 : FontWeight.w600, color: color)),
            ),
            if (badge > 0) _Badge(badge),
          ])
        : Column(mainAxisSize: MainAxisSize.min, children: [
            Badge(
              isLabelVisible: badge > 0,
              label: Text('$badge'),
              child: Icon(icon, color: selected ? p.accent : p.inkSecondary),
            ),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 12, fontWeight: selected ? FontWeight.w800 : FontWeight.w600, color: color)),
          ]);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: selected ? p.surface : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: expanded ? 14 : 4, vertical: expanded ? 14 : 10),
            child: content,
          ),
        ),
      ),
    );
  }
}
