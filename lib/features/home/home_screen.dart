import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/garden_controller.dart';
import '../../data/models.dart';
import '../garden/task_tile.dart';
import '../identify/identify_result_screen.dart';
import 'seasonal_tips.dart';

/// «Сегодня»: растение, которому нужен уход, — во весь экран, действие прямо на фото.
/// Ниже — остальные задачи дня, неделя вперёд, недавние распознавания и сезонный совет.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(gardenProvider).value ?? const GardenData();
    final p = context.palette;
    final due = data.dueTasks;
    final upcoming = _upcoming(data);
    final recent = data.identifications.take(10).toList();
    final tip = seasonalTip(DateTime.now());
    final screen = MediaQuery.sizeOf(context);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(gardenProvider.future),
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: SizedBox(
                height: (screen.height * 0.62).clamp(420.0, 580.0),
                child: _Hero(data: data, due: due, upcoming: upcoming),
              ),
            ),
            if (due.length > 1) ...[
              const SliverToBoxAdapter(child: SectionHeader('Ещё сегодня')),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList.separated(
                  itemCount: due.length - 1,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => TaskTile(task: due[i + 1], plant: data.plant(due[i + 1].plantId)),
                ),
              ),
            ],
            if (upcoming.isNotEmpty) ...[
              const SliverToBoxAdapter(child: SectionHeader('Дальше на неделе')),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 176,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    scrollDirection: Axis.horizontal,
                    itemCount: upcoming.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 12),
                    itemBuilder: (_, i) {
                      final t = upcoming[i];
                      final plant = data.plant(t.plantId)!;
                      return _Tile(
                        photoUrl: plant.photoUrl,
                        title: plant.nickname,
                        subtitle: '${_verb(t.type)}, ${_weekday(t.nextDue)}',
                        onTap: () => context.push('/plant/${plant.id}'),
                      );
                    },
                  ),
                ),
              ),
            ],
            if (recent.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: SectionHeader('Недавно распознано', action: 'История', onAction: () => context.push('/history')),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 176,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    scrollDirection: Axis.horizontal,
                    itemCount: recent.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 12),
                    itemBuilder: (_, i) {
                      final r = recent[i];
                      return _Tile(
                        photoUrl: r.photoUrl,
                        title: r.top?.displayName ?? 'Не распознано',
                        subtitle: r.top == null ? r.provider : '${(r.top!.probability * 100).round()}% · ${r.provider}',
                        onTap: () => context.push('/identify/result', extra: IdentifyResultArgs(record: r)),
                      );
                    },
                  ),
                ),
              ),
            ],
            SliverToBoxAdapter(child: SectionHeader('Совет на ${tip.month}')),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: p.surface, borderRadius: BorderRadius.circular(22)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tip.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                      for (final line in tip.points)
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Text(line, style: TextStyle(fontSize: 15, height: 1.45, color: p.ink)),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Задачи на 7 дней вперёд (не сегодняшние), по дате.
  static List<CareTask> _upcoming(GardenData data) {
    return data.tasks
        .where((t) => t.enabled && !t.isDue && t.daysLeft <= 7 && data.plant(t.plantId) != null)
        .toList()
      ..sort((a, b) => a.nextDue.compareTo(b.nextDue));
  }
}

String _verb(CareType type) => switch (type) {
      CareType.water => 'полить',
      CareType.fertilize => 'подкормить',
      CareType.mist => 'опрыскать',
      CareType.repot => 'пересадить',
      CareType.prune => 'обрезать',
      CareType.rotate => 'повернуть к свету',
    };

String _weekday(DateTime d) {
  final t = CareTask(id: '', plantId: '', type: CareType.water, intervalDays: 1, nextDue: d);
  if (t.daysLeft == 1) return 'завтра';
  return DateFormat('EEEE', 'ru').format(d);
}

/// Первый экран: фото растения, которому нужен уход, и действие на нём.
class _Hero extends ConsumerWidget {
  const _Hero({required this.data, required this.due, required this.upcoming});

  final GardenData data;
  final List<CareTask> due;
  final List<CareTask> upcoming;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final garden = ref.read(gardenProvider.notifier);
    final task = due.firstOrNull;
    final plant = task != null ? data.plant(task.plantId) : data.plants.firstOrNull;
    final date = DateFormat('EEEE, d MMMM', 'ru').format(DateTime.now());

    final String kicker;
    final String headline;
    final String? line;
    final List<Widget> actions;
    if (task != null) {
      kicker = 'Сегодня · 1 из ${due.length}';
      headline = plant!.nickname;
      line = 'Пора ${_verb(task.type)}${task.daysLeft < 0 ? ' — ${dueLabel(task)}' : ''}';
      actions = [
        FilledButton(onPressed: () => garden.completeTask(task), child: const Text('Готово')),
        OutlinedButton(onPressed: () => garden.snoozeTask(task), child: const Text('Завтра')),
      ];
    } else if (plant != null) {
      kicker = 'Сегодня';
      headline = 'Растениям ничего не нужно';
      final next = upcoming.firstOrNull;
      line = next == null ? null : 'Ближайшее: ${_verb(next.type)} «${data.plant(next.plantId)!.nickname}», ${_weekday(next.nextDue)}';
      actions = [OutlinedButton(onPressed: () => context.go('/garden'), child: const Text('Мой сад'))];
    } else {
      kicker = 'Добро пожаловать';
      headline = 'Сфотографируйте первое растение';
      line = 'Узнаем вид и составим расписание ухода.';
      actions = [FilledButton(onPressed: () => context.push('/identify'), child: const Text('Распознать растение'))];
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        if (plant?.photoUrl != null) PlantImage(plant!.photoUrl, radius: 0) else ColoredBox(color: p.surface),
        // Нейтральная подложка под текстом — единственный градиент в интерфейсе.
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [p.bg.withValues(alpha: 0.35), p.bg.withValues(alpha: 0), p.bg.withValues(alpha: 0.85), p.bg],
              stops: const [0, 0.25, 0.72, 1],
            ),
          ),
        ),
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_cap(date), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                const Spacer(),
                Text(kicker, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: p.accent)),
                const SizedBox(height: 8),
                Text(headline,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 36, height: 1.1, fontWeight: FontWeight.w800, letterSpacing: -1)),
                if (line != null) ...[
                  const SizedBox(height: 6),
                  Text(line, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                ],
                const SizedBox(height: 16),
                Wrap(spacing: 10, runSpacing: 10, children: actions),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

class _Tile extends StatelessWidget {
  const _Tile({required this.photoUrl, required this.title, required this.subtitle, required this.onTap});

  final String? photoUrl;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return SizedBox(
      width: 112,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PlantImage(photoUrl, size: 112, radius: 18),
            const SizedBox(height: 8),
            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: p.inkSecondary)),
          ],
        ),
      ),
    );
  }
}
