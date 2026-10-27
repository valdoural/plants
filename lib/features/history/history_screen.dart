import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/widgets.dart';
import '../../data/garden_controller.dart';
import '../identify/identify_result_screen.dart';

/// История распознаваний.
class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(gardenProvider).value?.identifications ?? const [];
    final fmt = DateFormat('d MMM y, HH:mm', 'ru');
    return Scaffold(
      appBar: AppBar(title: const Text('История распознаваний')),
      body: items.isEmpty
          ? const EmptyState(icon: Icons.history, title: 'История пуста', message: 'Здесь появятся распознанные растения.')
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
              itemCount: items.length,
              itemBuilder: (_, i) {
                final r = items[i];
                return Dismissible(
                  key: ValueKey(r.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 24),
                    child: const Icon(Icons.delete_outline),
                  ),
                  onDismissed: (_) => ref.read(gardenProvider.notifier).deleteIdentification(r.id),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Card(
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(8),
                        leading: SizedBox(width: 56, height: 56, child: PlantImage(r.photoUrl, radius: 12)),
                        title: Text(r.top?.displayName ?? 'Не распознано', maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text('${fmt.format(r.createdAt)} · ${r.provider}'),
                        trailing: r.top == null ? null : ConfidenceBadge(r.top!.probability),
                        onTap: () => context.push('/identify/result', extra: IdentifyResultArgs(record: r)),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
