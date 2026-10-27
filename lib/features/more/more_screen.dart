import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/settings.dart';
import '../../data/garden_controller.dart';

class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final storage = ref.watch(gardenRepositoryProvider).label;
    final data = ref.watch(gardenProvider).value;

    Widget tile(IconData icon, String title, String? subtitle, String route) => Card(
          child: ListTile(
            leading: Icon(icon),
            title: Text(title),
            subtitle: subtitle == null ? null : Text(subtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(route),
          ),
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Ещё')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
        children: [
          tile(Icons.notifications_outlined, 'Напоминания', '${data?.dueTasks.length ?? 0} на сегодня', '/reminders'),
          const SizedBox(height: 8),
          tile(Icons.history, 'История распознаваний', '${data?.identifications.length ?? 0} записей', '/history'),
          const SizedBox(height: 8),
          tile(Icons.settings_outlined, 'Настройки', 'Распознавание: ${settings.provider.short} · Данные: $storage',
              '/settings'),
          const SizedBox(height: 24),
          Center(
            child: Text('Leafy · личный помощник для растений',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ),
        ],
      ),
    );
  }
}
