import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/garden_controller.dart';
import '../../data/models.dart';
import 'add_plant_sheet.dart';

/// «Мой сад»: сетка растений с ближайшей задачей; фильтр по месту и своим папкам; список желаний.
class GardenScreen extends ConsumerStatefulWidget {
  const GardenScreen({super.key});

  @override
  ConsumerState<GardenScreen> createState() => _GardenScreenState();
}

/// Что показано в саду: всё, место, папка или список желаний.
sealed class _View {
  const _View();
}

class _All extends _View {
  const _All();
}

class _ByLocation extends _View {
  const _ByLocation(this.location);
  final PlantLocation location;
}

class _ByCollection extends _View {
  const _ByCollection(this.id);
  final String id;
}

class _Wishlist extends _View {
  const _Wishlist();
}

class _GardenScreenState extends ConsumerState<GardenScreen> {
  _View _view = const _All();
  var _query = '';

  bool _selected(_View v) => switch ((v, _view)) {
    (_All(), _All()) || (_Wishlist(), _Wishlist()) => true,
    (_ByLocation(location: final a), _ByLocation(location: final b)) => a == b,
    (_ByCollection(id: final a), _ByCollection(id: final b)) => a == b,
    _ => false,
  };

  Widget _chip(String label, _View v, {VoidCallback? onLongPress}) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: GestureDetector(
      onLongPress: onLongPress,
      child: ChoiceChip(
        label: Text(label),
        selected: _selected(v),
        onSelected: (_) => setState(() => _view = v),
      ),
    ),
  );

  Future<void> _newCollection() async {
    final name = await askText(context, 'Новая папка', hint: 'Например: Кухня');
    if (name == null || name.isEmpty) return;
    final c = await ref.read(gardenProvider.notifier).addCollection(name);
    if (mounted) setState(() => _view = _ByCollection(c.id));
  }

  Future<void> _editCollection(PlantCollection c) async {
    final garden = ref.read(gardenProvider.notifier);
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Переименовать'),
              onTap: () => Navigator.pop(ctx, 'rename'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Удалить папку'),
              subtitle: const Text('Растения останутся в саду'),
              onTap: () => Navigator.pop(ctx, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (action == 'rename') {
      final name = await askText(context, 'Название папки', initial: c.name);
      if (name != null && name.isNotEmpty) {
        await garden.renameCollection(c, name);
      }
    } else if (action == 'delete') {
      setState(() => _view = const _All());
      await garden.deleteCollection(c.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final garden = ref.watch(gardenProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Мой сад'),
        actions: [
          IconButton(
            tooltip: 'Добавить вручную',
            icon: const Icon(Icons.add),
            onPressed: () => showAddPlantSheet(context, ref),
          ),
        ],
      ),
      body: garden.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState(
          icon: Icons.cloud_off,
          title: 'Не удалось загрузить сад',
          message: '$e',
        ),
        data: (data) {
          if (data.plants.isEmpty && data.wishlist.isEmpty) {
            return EmptyState(
              icon: Icons.local_florist,
              title: 'В саду пока пусто',
              message: 'Сфотографируйте растение — мы узнаем вид и составим расписание ухода.',
              action: FilledButton.icon(
                onPressed: () => context.push('/identify'),
                icon: const Icon(Icons.center_focus_strong),
                label: const Text('Распознать растение'),
              ),
            );
          }
          // Папку могли удалить на другом устройстве.
          if (_view case _ByCollection(:final id)
              when !data.collections.any((c) => c.id == id)) {
            _view = const _All();
          }
          final q = _query.toLowerCase();
          final plants = data.plants
              .where(
                (p) => switch (_view) {
                  _All() || _Wishlist() => true,
                  _ByLocation(:final location) => p.location == location,
                  _ByCollection(:final id) => p.collectionIds.contains(id),
                },
              )
              .where(
                (p) =>
                    q.isEmpty ||
                    p.nickname.toLowerCase().contains(q) ||
                    (p.scientificName?.toLowerCase().contains(q) ?? false),
              )
              .toList();
          final wishes = data.wishlist
              .where(
                (w) =>
                    q.isEmpty ||
                    w.displayName.toLowerCase().contains(q) ||
                    w.scientificName.toLowerCase().contains(q),
              )
              .toList();
          final showWishes = _view is _Wishlist;
          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: TextField(
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      hintText: showWishes
                          ? 'Поиск в списке желаний'
                          : 'Поиск по саду',
                    ),
                    onChanged: (v) => setState(() => _query = v),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      _chip('Все · ${data.plants.length}', const _All()),
                      for (final l in PlantLocation.values)
                        if (data.plants.any((p) => p.location == l))
                          _chip(l.label, _ByLocation(l)),
                      for (final c in data.collections)
                        _chip(
                          c.name,
                          _ByCollection(c.id),
                          onLongPress: () => _editCollection(c),
                        ),
                      _chip(
                        'Хочу вырастить · ${data.wishlist.length}',
                        const _Wishlist(),
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.create_new_folder_outlined),
                        label: const Text('Папка'),
                        onPressed: _newCollection,
                      ),
                    ],
                  ),
                ),
              ),
              if (_view case _ByCollection(:final id))
                SliverToBoxAdapter(
                  child: _CollectionHint(
                    empty: plants.isEmpty,
                    onEdit: () => _editCollection(
                      data.collections.firstWhere((c) => c.id == id),
                    ),
                  ),
                ),
              if (showWishes && wishes.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyState(
                    icon: Icons.bookmark_border,
                    title: 'Список желаний пуст',
                    message: 'Откройте растение в каталоге или поиске и нажмите «Хочу вырастить».',
                  ),
                )
              else if (!showWishes && plants.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyState(
                    icon: Icons.filter_alt_off_outlined,
                    title: 'Здесь пока нет растений',
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 220,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 0.74,
                        ),
                    delegate: SliverChildBuilderDelegate(
                      (_, i) => showWishes
                          ? _WishCard(item: wishes[i])
                          : _PlantCard(
                              plant: plants[i],
                              tasks: data.tasksFor(plants[i].id),
                            ),
                      childCount: showWishes ? wishes.length : plants.length,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _CollectionHint extends StatelessWidget {
  const _CollectionHint({required this.empty, required this.onEdit});

  final bool empty;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              empty
                  ? 'Папка пуста. Добавить растение: карточка растения → меню → «Папки».'
                  : 'Растения добавляются в папку из меню карточки растения.',
              style: TextStyle(fontSize: 13, color: p.inkSecondary),
            ),
          ),
          TextButton(onPressed: onEdit, child: const Text('Изменить')),
        ],
      ),
    );
  }
}

/// Вид из списка желаний: касание — карточка вида, удержание — убрать.
class _WishCard extends ConsumerWidget {
  const _WishCard({required this.item});

  final WishItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    return PressScale(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: item.taxonId == null
            ? null
            : () => context.push('/taxon/${item.taxonId}'),
        onLongPress: () async {
          final ok = await showDialog<bool>(
            context: context,
            builder: (c) => AlertDialog(
              title: Text('Убрать «${item.displayName}» из списка желаний?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(c, false),
                  child: const Text('Отмена'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(c, true),
                  child: const Text('Убрать'),
                ),
              ],
            ),
          );
          if (ok == true) {
            await ref.read(gardenProvider.notifier).deleteWish(item.id);
          }
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  PlantImage(item.photoUrl, radius: 20),
                  Positioned(
                    right: 10,
                    top: 10,
                    child: Icon(Icons.bookmark, color: p.accent),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              item.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            Text(
              item.scientificName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontStyle: FontStyle.italic,
                color: p.inkSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlantCard extends StatelessWidget {
  const _PlantCard({required this.plant, required this.tasks});

  final Plant plant;
  final List<CareTask> tasks;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final next =
        (tasks.where((x) => x.enabled).toList()
              ..sort((a, b) => a.nextDue.compareTo(b.nextDue)))
            .firstOrNull;
    return PressScale(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => context.push('/plant/${plant.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  PlantImage(plant.photoUrl, radius: 20),
                  if (next != null && next.isDue)
                    Positioned(
                      left: 10,
                      top: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: p.inkButton,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          next.type.label,
                          style: TextStyle(
                            color: p.onInkButton,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              plant.nickname,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            if (next != null)
              Text(
                '${next.type.label} ${dueLabel(next)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  color: next.daysLeft < 0 ? p.alert : p.inkSecondary,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
