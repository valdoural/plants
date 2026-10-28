import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/responsive.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/discover/catalog.dart';
import '../../data/discover/discover_providers.dart';
import '../../data/discover/inat.dart';
import '../../data/discover/place_weather.dart';

/// Поле «Найти растение» — ведёт на экран поиска.
class PlantSearchLauncher extends StatelessWidget {
  const PlantSearchLauncher({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return PressScale(
      scale: 0.98,
      child: Material(
        color: p.surface,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => context.push('/search'),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                Icon(Icons.search, color: p.inkSecondary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Найти растение по названию',
                    style: TextStyle(fontSize: 16, color: p.inkSecondary),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Блок «Ваш регион»: место, погода на 3 дня и советы по садоводству под неё.
class PlaceWeatherCard extends ConsumerWidget {
  const PlaceWeatherCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final place = ref.watch(placeProvider);
    final weather = ref.watch(weatherProvider);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(22),
      ),
      child: place == null
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Где растёт ваш сад?',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  'Укажите место — покажем погоду, советы на неделю, популярные растения региона и местные ядовитые растения.',
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.4,
                    color: p.inkSecondary,
                  ),
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: () => showPlacePicker(context),
                  icon: const Icon(Icons.my_location),
                  label: const Text('Указать место'),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.place_outlined, size: 20, color: p.accent),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        place.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => showPlacePicker(context),
                      child: const Text('Изменить'),
                    ),
                  ],
                ),
                weather.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(16),
                    child: LinearProgressIndicator(),
                  ),
                  error: (e, _) => Text(
                    'Погода недоступна: $e',
                    style: TextStyle(color: p.inkSecondary),
                  ),
                  data: (w) => w == null
                      ? const SizedBox.shrink()
                      : _WeatherBody(weather: w),
                ),
              ],
            ),
    );
  }
}

class _WeatherBody extends StatelessWidget {
  const _WeatherBody({required this.weather});

  final Weather weather;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final day = DateFormat('EE', 'ru');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${weather.temperature.round()}°',
              style: const TextStyle(
                fontSize: 52,
                height: 1,
                fontWeight: FontWeight.w800,
                letterSpacing: -2,
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  'влажность ${weather.humidity.round()}%',
                  maxLines: 2,
                  style: TextStyle(color: p.inkSecondary, fontSize: 15),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            for (final d in weather.days.skip(1).take(3))
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      day.format(d.date),
                      style: TextStyle(
                        fontSize: 13,
                        color: p.inkSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '${d.max.round()}° / ${d.min.round()}°',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (d.precipitation >= 1)
                      Text(
                        '${d.precipitation.round()} мм',
                        style: TextStyle(
                          fontSize: 13,
                          color: p.water,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        const Text(
          'Советы по садоводству',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
        for (final tip in weatherTips(weather))
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(tip, style: const TextStyle(fontSize: 15, height: 1.4)),
          ),
      ],
    );
  }
}

/// Выбор места: автоопределение или поиск города.
Future<void> showPlacePicker(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _PlacePicker(),
  );
}

class _PlacePicker extends ConsumerStatefulWidget {
  const _PlacePicker();

  @override
  ConsumerState<_PlacePicker> createState() => _PlacePickerState();
}

class _PlacePickerState extends ConsumerState<_PlacePicker> {
  final _q = TextEditingController();
  List<UserPlace> _results = const [];
  var _busy = false;
  String? _error;

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  Future<void> _search(String q) async {
    try {
      final r = await ref.read(placeWeatherClientProvider).searchCity(q);
      if (mounted && q == _q.text) setState(() => _results = r);
    } catch (e) {
      if (mounted) setState(() => _error = 'Поиск недоступен: $e');
    }
  }

  Future<void> _detect() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final err = await ref.read(placeProvider.notifier).detect();
    if (!mounted) return;
    if (err == null) {
      Navigator.pop(context);
    } else {
      setState(() {
        _busy = false;
        _error = err;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        0,
        24,
        MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Ваше место',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            'Нужно для погоды и растений региона. Хранится только на этом устройстве.',
            style: TextStyle(color: p.inkSecondary),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _busy ? null : _detect,
            icon: _busy
                ? SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: p.onInkButton,
                    ),
                  )
                : const Icon(Icons.my_location),
            label: const Text('Определить автоматически'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _q,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Или найдите город',
            ),
            textInputAction: TextInputAction.search,
            onChanged: _search,
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: p.alert)),
          ],
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 280),
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final r in _results)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.place_outlined),
                    title: Text(r.label),
                    onTap: () async {
                      await ref.read(placeProvider.notifier).set(r);
                      if (context.mounted) Navigator.pop(context);
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Плитка вида: фото, русское и латинское название, сколько раз встречали рядом.
class TaxonTile extends StatelessWidget {
  const TaxonTile({super.key, required this.taxon, this.width = 148});

  final InatTaxon taxon;
  final double width;

  /// Высота плитки с учётом системного размера шрифта: фото + две строки названия + латынь + счётчик.
  static double heightFor(BuildContext context, double width) {
    final t = MediaQuery.textScalerOf(context);
    return width + 8 + t.scale(14) * 1.2 * 2 + t.scale(12) * 1.4 * 2 + 6;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final toxic = taxon.isIn(CatalogKind.toxicIds);
    return SizedBox(
      width: width,
      child: PressScale(
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => context.push('/taxon/${taxon.id}'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    PlantImage(taxon.photoUrl, radius: 18),
                    if (toxic)
                      Positioned(
                        left: 8,
                        top: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: p.alert,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'ядовито',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: p.bg,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                taxon.displayName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                ),
              ),
              Text(
                taxon.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: p.inkSecondary,
                ),
              ),
              if (taxon.count != null)
                Text(
                  _obs(taxon.count!),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: p.accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

String _obs(int n) {
  final m10 = n % 10, m100 = n % 100;
  final w = m10 == 1 && m100 != 11
      ? 'наблюдение'
      : (m10 >= 2 && m10 <= 4 && (m100 < 12 || m100 > 14))
      ? 'наблюдения'
      : 'наблюдений';
  return '$n $w рядом';
}

/// Полка видов: на телефоне листается вбок, на больших экранах — сетка.
class TaxonShelf extends StatelessWidget {
  const TaxonShelf({
    super.key,
    required this.title,
    this.subtitle,
    required this.items,
    this.onMore,
    this.maxItems = 12,
  });

  final String title;
  final String? subtitle;
  final AsyncValue<List<InatTaxon>> items;
  final VoidCallback? onMore;
  final int maxItems;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final compact = context.windowSize.isCompact;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: TextStyle(fontSize: 14, color: p.inkSecondary),
                    ),
                ],
              ),
            ),
            if (onMore != null)
              TextButton(onPressed: onMore, child: const Text('Все')),
          ],
        ),
        const SizedBox(height: 12),
        items.when(
          loading: () => LayoutBuilder(
            builder: (context, c) {
              final w = compact ? 148.0 : 170.0;
              final n = (c.maxWidth / (w + 12)).floor().clamp(1, 8);
              return SizedBox(
                height: TaxonTile.heightFor(context, w),
                child: Row(
                  children: [
                    for (var i = 0; i < n; i++) ...[
                      if (i > 0) const SizedBox(width: 12),
                      Expanded(
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: AspectRatio(
                            aspectRatio: 1,
                            child: Container(
                              decoration: BoxDecoration(
                                color: p.surface,
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
          error: (e, _) => Text(
            'Не удалось загрузить: $e',
            style: TextStyle(color: p.inkSecondary),
          ),
          data: (list) {
            final shown = list.take(maxItems).toList();
            if (shown.isEmpty) {
              return Text(
                'Пока нет данных для этого места.',
                style: TextStyle(color: p.inkSecondary),
              );
            }
            if (compact) {
              return SizedBox(
                height: TaxonTile.heightFor(context, 148),
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: shown.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 12),
                  itemBuilder: (_, i) => TaxonTile(taxon: shown[i]),
                ),
              );
            }
            return LayoutBuilder(
              builder: (context, c) {
                final cols = (c.maxWidth / 170).floor().clamp(2, 8);
                final w = (c.maxWidth - (cols - 1) * 14) / cols;
                return Wrap(
                  spacing: 14,
                  runSpacing: 18,
                  children: [
                    for (final t in shown.take(cols * 2))
                      TaxonTile(taxon: t, width: w),
                  ],
                );
              },
            );
          },
        ),
      ],
    );
  }
}

/// Плитки каталога: обложка — фото первого вида раздела.
class CatalogTiles extends ConsumerWidget {
  const CatalogTiles({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final place = ref.watch(placeProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          place == null ? 'Каталог растений' : 'Растения региона',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        Text(
          place == null
              ? 'Укажите место — покажем то, что растёт рядом'
              : 'Что встречается рядом: ${place.label}',
          style: TextStyle(fontSize: 14, color: p.inkSecondary),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, c) {
            const kinds = CatalogKind.values;
            final cols = c.maxWidth < 560 ? 2 : (c.maxWidth < 900 ? 3 : 4);
            final w = (c.maxWidth - (cols - 1) * 12) / cols;
            // Часть плиток растягивается на две колонки, чтобы ряды заполнились без дыр:
            // в ряду с широкой плиткой — она и ещё cols−2 обычных.
            final extra = (cols - kinds.length % cols) % cols;
            final wideAt = {for (var j = 0; j < extra; j++) j * (cols - 1)};
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final (i, k) in kinds.indexed)
                  SizedBox(
                    width: wideAt.contains(i) ? w * 2 + 12 : w,
                    height: w / 0.9,
                    child: _CatalogTile(kind: k),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _CatalogTile extends ConsumerWidget {
  const _CatalogTile({required this.kind});

  final CatalogKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final cover = ref
        .watch(catalogProvider(kind))
        .value
        ?.firstWhere(
          (t) => t.photoUrl != null,
          orElse: () => const InatTaxon(id: 0, name: ''),
        );
    return PressScale(
      child: SizedBox.expand(
        child: Material(
          color: p.surface,
          borderRadius: BorderRadius.circular(20),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => context.push('/catalog/${kind.name}'),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (cover?.photoUrl != null)
                  PlantImage(cover!.photoUrl, radius: 0),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0),
                        Colors.black.withValues(alpha: 0.72),
                      ],
                      stops: const [0.35, 1],
                    ),
                  ),
                ),
                Positioned(
                  left: 14,
                  right: 14,
                  bottom: 12,
                  child: Text(
                    kind.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      height: 1.15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
