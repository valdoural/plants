import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/garden_controller.dart';
import '../../data/models.dart';
import 'add_plant_sheet.dart';

/// «Мой сад»: сетка растений с ближайшей задачей, фильтр по месту.
class GardenScreen extends ConsumerStatefulWidget {
  const GardenScreen({super.key});

  @override
  ConsumerState<GardenScreen> createState() => _GardenScreenState();
}

class _GardenScreenState extends ConsumerState<GardenScreen> {
  PlantLocation? _filter;
  var _query = '';

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
          if (data.plants.isEmpty) {
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
          final q = _query.toLowerCase();
          final plants = data.plants
              .where((p) => _filter == null || p.location == _filter)
              .where(
                (p) =>
                    q.isEmpty ||
                    p.nickname.toLowerCase().contains(q) ||
                    (p.scientificName?.toLowerCase().contains(q) ?? false),
              )
              .toList();
          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: TextField(
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Поиск по саду',
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
                      ChoiceChip(
                        label: Text('Все · ${data.plants.length}'),
                        selected: _filter == null,
                        onSelected: (_) => setState(() => _filter = null),
                      ),
                      for (final l in PlantLocation.values)
                        if (data.plants.any((p) => p.location == l))
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: ChoiceChip(
                              label: Text(l.label),
                              selected: _filter == l,
                              onSelected: (_) => setState(() => _filter = l),
                            ),
                          ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 220,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.74,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => _PlantCard(
                      plant: plants[i],
                      tasks: data.tasksFor(plants[i].id),
                    ),
                    childCount: plants.length,
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
