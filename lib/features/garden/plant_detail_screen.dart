import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/photo_picker.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/garden_controller.dart';
import '../../data/models.dart';
import '../identify/species_screen.dart';
import 'add_plant_sheet.dart';
import 'task_tile.dart';

/// Растение из сада: вкладки «Уход», «Дневник», «О растении».
class PlantDetailScreen extends ConsumerWidget {
  const PlantDetailScreen({super.key, required this.plantId});

  final String plantId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(gardenProvider).value;
    final plant = data?.plant(plantId);
    if (data == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (plant == null) {
      return Scaffold(appBar: AppBar(), body: const EmptyState(icon: Icons.search_off, title: 'Растение не найдено'));
    }
    final p = context.palette;
    final heroHeight = (MediaQuery.sizeOf(context).height * 0.5).clamp(320.0, 440.0);
    final subtitle = [
      if (plant.scientificName != null) plant.scientificName!,
      plant.location.label.toLowerCase(),
    ].join(' · ');

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        body: NestedScrollView(
          headerSliverBuilder: (context, _) => [
            SliverAppBar(
              expandedHeight: heroHeight,
              pinned: true,
              backgroundColor: p.bg,
              foregroundColor: p.ink,
              actions: [_PlantMenu(plant: plant)],
              flexibleSpace: FlexibleSpaceBar(
                collapseMode: CollapseMode.pin,
                background: Stack(fit: StackFit.expand, children: [
                  PlantImage(plant.photoUrl, radius: 0),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [p.bg.withValues(alpha: 0.4), p.bg.withValues(alpha: 0), p.bg.withValues(alpha: 0.9), p.bg],
                        stops: const [0, 0.3, 0.8, 1],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 24,
                    right: 24,
                    bottom: 64,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(plant.nickname,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 34, height: 1.1, fontWeight: FontWeight.w800, letterSpacing: -0.8)),
                        const SizedBox(height: 4),
                        Text(subtitle, style: TextStyle(fontSize: 16, fontStyle: FontStyle.italic, color: p.ink)),
                      ],
                    ),
                  ),
                ]),
              ),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(48),
                child: ColoredBox(
                  color: p.bg,
                  child: const TabBar(
                    tabAlignment: TabAlignment.start,
                    isScrollable: true,
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    tabs: [Tab(text: 'Уход'), Tab(text: 'Дневник'), Tab(text: 'О растении')],
                  ),
                ),
              ),
            ),
          ],
          body: TabBarView(
            children: [
              _CareTab(plant: plant, tasks: data.tasksFor(plant.id)),
              _NotesTab(plant: plant, notes: data.notesFor(plant.id)),
              _InfoTab(plant: plant),
            ],
          ),
        ),
      ),
    );
  }
}

/// Неделя вперёд: сегодняшний день выделен, точка — в этот день есть уход.
class _WeekStrip extends StatelessWidget {
  const _WeekStrip({required this.tasks});

  final List<CareTask> tasks;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final days = [for (var i = 0; i < 7; i++) today.add(Duration(days: i))];
    bool hasTask(DateTime d) => tasks.any((t) {
          if (!t.enabled) return false;
          final due = DateTime(t.nextDue.year, t.nextDue.month, t.nextDue.day);
          return d == today ? !due.isAfter(today) : due == d;
        });
    return Row(
      children: [
        for (final (i, d) in days.indexed) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: i == 0 ? p.inkButton : p.surface,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  Text(DateFormat('EE', 'ru').format(d),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: i == 0 ? FontWeight.w800 : FontWeight.w600,
                        color: i == 0 ? p.onInkButton : p.inkSecondary,
                      )),
                  const SizedBox(height: 6),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: hasTask(d) ? (i == 0 ? p.onInkButton : p.accent) : p.surfaceHigh,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _PlantMenu extends ConsumerWidget {
  const _PlantMenu({required this.plant});

  final Plant plant;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final garden = ref.read(gardenProvider.notifier);
    return PopupMenuButton<String>(
      onSelected: (v) async {
        switch (v) {
          case 'rename':
            final name = await _ask(context, 'Новое имя', plant.nickname);
            if (name != null && name.isNotEmpty) await garden.updatePlant(plant.copyWith(nickname: name));
          case 'photo':
            final bytes = await pickPhotoWithSheet(context, maxSide: 900);
            if (bytes != null) await garden.updatePlant(plant.copyWith(photoUrl: await garden.storePhoto(bytes)));
          case 'delete':
            final ok = await showDialog<bool>(
              context: context,
              builder: (c) => AlertDialog(
                title: Text('Удалить «${plant.nickname}»?'),
                content: const Text('Напоминания и записи дневника тоже удалятся.'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Отмена')),
                  FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Удалить')),
                ],
              ),
            );
            if (ok == true) {
              await garden.deletePlant(plant.id);
              if (context.mounted) context.pop();
            }
        }
      },
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'rename', child: Text('Переименовать')),
        PopupMenuItem(value: 'photo', child: Text('Сменить фото')),
        PopupMenuItem(value: 'delete', child: Text('Удалить из сада')),
      ],
    );
  }
}

Future<String?> _ask(BuildContext context, String title, String initial) {
  final c = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(controller: c, autofocus: true),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
        FilledButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('Сохранить')),
      ],
    ),
  );
}

class _CareTab extends ConsumerWidget {
  const _CareTab({required this.plant, required this.tasks});

  final Plant plant;
  final List<CareTask> tasks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sorted = [...tasks]..sort((a, b) => a.nextDue.compareTo(b.nextDue));
    final missing = CareType.values.where((c) => !tasks.any((t) => t.type == c)).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      children: [
        _WeekStrip(tasks: tasks),
        const SizedBox(height: 16),
        if (sorted.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text('Напоминаний нет. Добавьте полив или другой уход ниже.', textAlign: TextAlign.center),
          ),
        for (final task in sorted)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: GestureDetector(
              onLongPress: () => _editTask(context, ref, task),
              child: TaskTile(task: task, plant: plant, showPlant: false),
            ),
          ),
        if (sorted.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 12),
            child: Text('Удерживайте задачу, чтобы изменить интервал или удалить.',
                style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center),
          ),
        if (missing.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final type in missing)
                ActionChip(
                  avatar: Icon(careIcon(type), size: 18, color: careColor(context, type)),
                  label: Text('+ ${type.label}'),
                  onPressed: () => ref.read(gardenProvider.notifier).saveTask(CareTask.create(plant.id, type)),
                ),
            ],
          ),
      ],
    );
  }

  Future<void> _editTask(BuildContext context, WidgetRef ref, CareTask task) async {
    var days = task.intervalDays;
    final garden = ref.read(gardenProvider.notifier);
    final result = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(task.type.label, style: Theme.of(ctx).textTheme.titleLarge),
                const SizedBox(height: 12),
                Row(children: [
                  const Expanded(child: Text('Интервал')),
                  IntervalStepper(days: days, onChanged: (v) => setState(() => days = v)),
                ]),
                Text(everyLabel(days), textAlign: TextAlign.end),
                const SizedBox(height: 16),
                FilledButton(onPressed: () => Navigator.pop(ctx, 'save'), child: const Text('Сохранить')),
                TextButton(onPressed: () => Navigator.pop(ctx, 'delete'), child: const Text('Удалить напоминание')),
              ],
            ),
          ),
        ),
      ),
    );
    if (result == 'save') await garden.saveTask(task.withInterval(days));
    if (result == 'delete') await garden.deleteTask(task.id);
  }
}

class _NotesTab extends ConsumerWidget {
  const _NotesTab({required this.plant, required this.notes});

  final Plant plant;
  final List<Note> notes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = Theme.of(context);
    final fmt = DateFormat('d MMMM y, HH:mm', 'ru');
    return Stack(
      children: [
        notes.isEmpty
            ? const EmptyState(
                icon: Icons.menu_book,
                title: 'Дневник пуст',
                message: 'Записывайте, как растёт растение: новые листья, цветение, проблемы.',
              )
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                itemCount: notes.length,
                itemBuilder: (_, i) {
                  final n = notes[i];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Card(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (n.photoUrl != null) SizedBox(height: 200, child: PlantImage(n.photoUrl, radius: 0)),
                          ListTile(
                            title: Text(n.text),
                            subtitle: Text(fmt.format(n.createdAt)),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => ref.read(gardenProvider.notifier).deleteNote(n.id),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton.extended(
            heroTag: 'note',
            onPressed: () => _addNote(context, ref),
            icon: const Icon(Icons.edit_note),
            label: const Text('Запись'),
            backgroundColor: t.colorScheme.primaryContainer,
          ),
        ),
      ],
    );
  }

  Future<void> _addNote(BuildContext context, WidgetRef ref) async {
    final text = TextEditingController();
    Uint8List? photo;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(ctx).bottom + 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: text,
                autofocus: true,
                maxLines: 4,
                minLines: 2,
                decoration: const InputDecoration(hintText: 'Что нового?'),
              ),
              const SizedBox(height: 12),
              if (photo != null) SizedBox(height: 120, child: PlantImage.memory(photo!)),
              Row(children: [
                IconButton(
                  icon: const Icon(Icons.add_a_photo_outlined),
                  onPressed: () async {
                    final p = await pickPhotoWithSheet(ctx, maxSide: 900);
                    if (p != null) setState(() => photo = p);
                  },
                ),
                const Spacer(),
                FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Сохранить')),
              ]),
            ],
          ),
        ),
      ),
    );
    if (ok == true && (text.text.trim().isNotEmpty || photo != null)) {
      await ref.read(gardenProvider.notifier).addNote(plant.id, text.text.trim(), photo: photo);
    }
  }
}

class _InfoTab extends StatelessWidget {
  const _InfoTab({required this.plant});

  final Plant plant;

  @override
  Widget build(BuildContext context) {
    final s = plant.species;
    final t = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Column(children: [
            ListTile(
              leading: const Icon(Icons.badge_outlined),
              title: Text(plant.commonName ?? plant.nickname),
              subtitle: plant.scientificName == null
                  ? null
                  : Text(plant.scientificName!, style: const TextStyle(fontStyle: FontStyle.italic)),
            ),
            ListTile(leading: const Icon(Icons.place_outlined), title: Text(plant.location.label)),
            ListTile(
              leading: const Icon(Icons.event_outlined),
              title: Text('В саду с ${DateFormat('d MMMM y', 'ru').format(plant.createdAt)}'),
            ),
          ]),
        ),
        const SizedBox(height: 12),
        if (s != null) ...[
          SpeciesCareFacts(candidate: s),
          if (s.description != null) ...[
            const SizedBox(height: 12),
            Text('Описание', style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(s.description!),
          ],
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => context.push('/species', extra: SpeciesArgs(candidate: s, photoUrl: plant.photoUrl)),
            icon: const Icon(Icons.local_florist_outlined),
            label: const Text('Карточка вида'),
          ),
        ] else
          const Card(
            child: ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('Вид не указан'),
              subtitle: Text('Растение добавлено вручную. Распознайте его по фото, чтобы получить сведения о виде.'),
            ),
          ),
      ],
    );
  }
}
