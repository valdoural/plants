import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../tools/tools_screens.dart';
import '../../core/responsive.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/garden_controller.dart';
import '../../data/discover/discover_providers.dart';
import '../../data/models.dart';
import '../discover/discover_widgets.dart';
import '../garden/task_tile.dart';
import '../identify/identify_result_screen.dart';
import 'seasonal_tips.dart';

/// «Сегодня» + «Для вас»: растение, которому нужен уход, задачи, погода с советами,
/// поиск, тенденции региона и каталог. На телефоне — одна колонка, на больших экранах — две.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(gardenProvider).value ?? const GardenData();
    final due = data.dueTasks;
    final upcoming = _upcoming(data);
    final size = context.windowSize;
    final g = context.gutter;

    Widget gap([double h = 28]) => SizedBox(height: h);

    final hero = _Hero(data: data, due: due, upcoming: upcoming);
    final tasks = [
      if (due.length > 1) ...[
        const _Heading('Ещё сегодня'),
        for (final t in due.skip(1))
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: TaskTile(task: t, plant: data.plant(t.plantId)),
          ),
      ],
    ];
    final week = upcoming.isEmpty
        ? const <Widget>[]
        : [
            const _Heading('Дальше на неделе'),
            _TileRow(
              children: [
                for (final t in upcoming)
                  _Tile(
                    photoUrl: data.plant(t.plantId)!.photoUrl,
                    title: data.plant(t.plantId)!.nickname,
                    subtitle: '${_verb(t.type)}, ${_weekday(t.nextDue)}',
                    onTap: () => context.push('/plant/${t.plantId}'),
                  ),
              ],
            ),
          ];
    final recent = data.identifications.take(10).toList();
    final recentBlock = recent.isEmpty
        ? const <Widget>[]
        : [
            _Heading(
              'Недавно распознано',
              action: 'История',
              onAction: () => context.push('/history'),
            ),
            _TileRow(
              children: [
                for (final r in recent)
                  _Tile(
                    photoUrl: r.photoUrl,
                    title: r.top?.displayName ?? 'Не распознано',
                    subtitle: r.top == null
                        ? r.provider
                        : '${(r.top!.probability * 100).round()}% · ${r.provider}',
                    onTap: () => context.push(
                      '/identify/result',
                      extra: IdentifyResultArgs(record: r),
                    ),
                  ),
              ],
            ),
          ];
    final tip = seasonalTip(DateTime.now());
    final seasonal = _SeasonalTip(tip: tip);

    const tools = [_Heading('Инструменты'), ToolsGrid()];

    final left = <Widget>[
      ...tasks,
      if (tasks.isNotEmpty) gap(),
      const PlaceWeatherCard(),
      gap(),
      ...week,
      if (week.isNotEmpty) gap(),
      seasonal,
      gap(),
      ...tools,
    ];
    final right = <Widget>[
      const PlantSearchLauncher(),
      gap(),
      TaxonShelf(
        title: TrendKind.cultivated.title,
        subtitle: TrendKind.cultivated.subtitle,
        items: ref.watch(trendsProvider(TrendKind.cultivated)),
      ),
      gap(),
      const CatalogTiles(),
      gap(),
      TaxonShelf(
        title: TrendKind.flowering.title,
        subtitle: TrendKind.flowering.subtitle,
        items: ref.watch(trendsProvider(TrendKind.flowering)),
        onMore: () => context.push('/catalog/flowers'),
      ),
      gap(),
      ...recentBlock,
    ];

    if (size.isCompact) {
      return Scaffold(
        body: RefreshIndicator(
          onRefresh: () => ref.refresh(gardenProvider.future),
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              SizedBox(
                height: (MediaQuery.sizeOf(context).height * 0.62).clamp(
                  420.0,
                  580.0,
                ),
                child: hero,
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(g, 8, g, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _Heading('Для вас'),
                    // На телефоне порядок: задачи → поиск → регион и советы → тенденции → каталог.
                    ...tasks,
                    if (tasks.isNotEmpty) gap(),
                    const PlantSearchLauncher(),
                    gap(),
                    const PlaceWeatherCard(),
                    gap(),
                    ...right.skip(2),
                    ...week,
                    if (week.isNotEmpty) gap(),
                    seasonal,
                    gap(),
                    ...tools,
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.refresh(gardenProvider.future),
          child: ListView(
            padding: EdgeInsets.fromLTRB(g, g, g, 48),
            children: [
              MaxWidth(
                maxWidth: 1320,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Для вас',
                      style: TextStyle(
                        fontSize: size == WindowSize.expanded ? 40 : 32,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 5,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(28),
                                child: SizedBox(height: 460, child: hero),
                              ),
                              gap(),
                              ...left,
                            ],
                          ),
                        ),
                        SizedBox(width: size == WindowSize.expanded ? 40 : 24),
                        Expanded(
                          flex: 7,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: right,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Задачи на 7 дней вперёд (не сегодняшние), по дате.
  static List<CareTask> _upcoming(GardenData data) {
    return data.tasks
        .where(
          (t) =>
              t.enabled &&
              !t.isDue &&
              t.daysLeft <= 7 &&
              data.plant(t.plantId) != null,
        )
        .toList()
      ..sort((a, b) => a.nextDue.compareTo(b.nextDue));
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.title, {this.action, this.onAction});

  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
          ),
          if (action != null)
            TextButton(onPressed: onAction, child: Text(action!)),
        ],
      ),
    );
  }
}

/// Ряд плиток: на телефоне листается вбок, на широком экране переносится.
class _TileRow extends StatelessWidget {
  const _TileRow({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (context.windowSize.isCompact) {
      return SizedBox(
        height: 176,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: children.length,
          separatorBuilder: (_, _) => const SizedBox(width: 12),
          itemBuilder: (_, i) => children[i],
        ),
      );
    }
    return Wrap(spacing: 12, runSpacing: 16, children: children);
  }
}

class _SeasonalTip extends StatelessWidget {
  const _SeasonalTip({required this.tip});

  final SeasonalTip tip;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Совет на ${tip.month}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: p.accent,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            tip.title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          for (final line in tip.points)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                line,
                style: const TextStyle(fontSize: 15, height: 1.45),
              ),
            ),
        ],
      ),
    );
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
  final t = CareTask(
    id: '',
    plantId: '',
    type: CareType.water,
    intervalDays: 1,
    nextDue: d,
  );
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
    final plant = task != null
        ? data.plant(task.plantId)
        : data.plants.firstOrNull;
    final date = DateFormat('EEEE, d MMMM', 'ru').format(DateTime.now());

    final String kicker;
    final String headline;
    final String? line;
    final List<Widget> actions;
    if (task != null) {
      kicker = 'Сегодня · 1 из ${due.length}';
      headline = plant!.nickname;
      line =
          'Пора ${_verb(task.type)}${task.daysLeft < 0 ? ' — ${dueLabel(task)}' : ''}';
      actions = [
        FilledButton(
          onPressed: () => garden.completeTask(task),
          child: const Text('Готово'),
        ),
        OutlinedButton(
          onPressed: () => garden.snoozeTask(task),
          child: const Text('Завтра'),
        ),
      ];
    } else if (plant != null) {
      kicker = 'Сегодня';
      headline = 'Растениям ничего не нужно';
      final next = upcoming.firstOrNull;
      line = next == null
          ? null
          : 'Ближайшее: ${_verb(next.type)} «${data.plant(next.plantId)!.nickname}», ${_weekday(next.nextDue)}';
      actions = [
        OutlinedButton(
          onPressed: () => context.go('/garden'),
          child: const Text('Мой сад'),
        ),
      ];
    } else {
      kicker = 'Добро пожаловать';
      headline = 'Сфотографируйте первое растение';
      line = 'Узнаем вид и составим расписание ухода.';
      actions = [
        FilledButton(
          onPressed: () => context.push('/identify'),
          child: const Text('Распознать растение'),
        ),
      ];
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        if (plant?.photoUrl != null)
          PlantImage(plant!.photoUrl, radius: 0)
        else
          ColoredBox(color: p.surface),
        // Нейтральная подложка под текстом — единственный градиент в интерфейсе.
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                p.bg.withValues(alpha: 0.35),
                p.bg.withValues(alpha: 0),
                p.bg.withValues(alpha: 0.85),
                p.bg,
              ],
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
                Text(
                  _cap(date),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Text(
                  kicker,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: p.accent,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  headline,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 36,
                    height: 1.1,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1,
                  ),
                ),
                if (line != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    line,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
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
  const _Tile({
    required this.photoUrl,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String? photoUrl;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return SizedBox(
      width: 112,
      child: PressScale(
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PlantImage(photoUrl, size: 112, radius: 18),
              const SizedBox(height: 8),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, color: p.inkSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
