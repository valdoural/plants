import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/responsive.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/discover/catalog.dart';
import '../../data/discover/discover_providers.dart';
import '../../data/discover/inat.dart';
import '../../data/models.dart';
import '../identify/species_screen.dart';
import 'discover_widgets.dart';

/// Выбор вида по названию: открывает поиск и возвращает полные сведения о выбранном виде.
/// Нужен для «Это не то растение» — когда распознавание ошиблось.
Future<PlantCandidate?> pickSpecies(BuildContext context, WidgetRef ref) async {
  final taxon = await context.push<InatTaxon>('/search?pick=1');
  if (taxon == null) return null;
  try {
    return (await ref.read(taxonDetailProvider(taxon.id).future)).toCandidate();
  } catch (_) {
    return taxon.toCandidate();
  }
}

/// Поиск растения по названию (русскому или латинскому).
/// В режиме [pick] касание возвращает вид вызвавшему экрану.
class PlantSearchScreen extends ConsumerStatefulWidget {
  const PlantSearchScreen({super.key, this.pick = false});

  final bool pick;

  @override
  ConsumerState<PlantSearchScreen> createState() => _PlantSearchScreenState();
}

class _PlantSearchScreenState extends ConsumerState<PlantSearchScreen> {
  final _q = TextEditingController();
  Timer? _debounce;
  var _query = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _q.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 350),
      () => setState(() => _query = v.trim()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final results = _query.length < 2
        ? null
        : ref.watch(plantSearchProvider(_query));
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.pick ? 'Выберите вид' : 'Поиск растений'),
      ),
      body: MaxWidth(
        maxWidth: 820,
        child: ListView(
          padding: EdgeInsets.fromLTRB(context.gutter, 4, context.gutter, 32),
          children: [
            TextField(
              controller: _q,
              autofocus: true,
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Например: монстера, фикус, Rosa',
              ),
              onChanged: _onChanged,
            ),
            const SizedBox(height: 12),
            if (results == null)
              Padding(
                padding: const EdgeInsets.only(top: 24),
                child: Text(
                  'Введите хотя бы две буквы названия.',
                  style: TextStyle(color: p.inkSecondary),
                ),
              )
            else
              results.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Text(
                  'Поиск недоступен: $e',
                  style: TextStyle(color: p.alert),
                ),
                data: (list) => list.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.only(top: 24),
                        child: Text(
                          'Ничего не нашлось. Попробуйте латинское название.',
                          style: TextStyle(color: p.inkSecondary),
                        ),
                      )
                    : Column(
                        children: [
                          for (final t in list)
                            PressScale(
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () => widget.pick
                                    ? context.pop(t)
                                    : context.push('/taxon/${t.id}'),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  child: Row(
                                    children: [
                                      PlantImage(
                                        t.photoUrl,
                                        size: 64,
                                        radius: 14,
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              t.displayName,
                                              style: const TextStyle(
                                                fontSize: 17,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                            Text(
                                              t.name,
                                              style: TextStyle(
                                                fontStyle: FontStyle.italic,
                                                color: p.inkSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      if (t.isIn(CatalogKind.toxicIds))
                                        Text(
                                          'ядовито',
                                          style: TextStyle(
                                            color: p.alert,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Раздел каталога: сетка видов с фото.
class CatalogScreen extends ConsumerWidget {
  const CatalogScreen({super.key, required this.kind});

  final CatalogKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final place = ref.watch(placeProvider);
    final items = ref.watch(catalogProvider(kind));
    return Scaffold(
      appBar: AppBar(title: Text(kind.title)),
      body: MaxWidth(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                context.gutter,
                0,
                context.gutter,
                16,
              ),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      kind.subtitle,
                      style: TextStyle(fontSize: 16, color: p.inkSecondary),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            place == null
                                ? 'Место не указано — показан общий список'
                                : 'Рядом с: ${place.label}',
                            style: TextStyle(
                              fontSize: 14,
                              color: p.inkSecondary,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => showPlacePicker(context),
                          child: Text(place == null ? 'Указать' : 'Изменить'),
                        ),
                      ],
                    ),
                    if (kind.note case final note?)
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: p.surface,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          note,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.4,
                            color: p.ink,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            items.when(
              loading: () => const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Не удалось загрузить: $e'),
                ),
              ),
              data: (list) => SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  context.gutter,
                  0,
                  context.gutter,
                  40,
                ),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 200,
                    mainAxisSpacing: 18,
                    crossAxisSpacing: 14,
                    childAspectRatio: 0.66,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => LayoutBuilder(
                      builder: (_, c) =>
                          TaxonTile(taxon: list[i], width: c.maxWidth),
                    ),
                    childCount: list.length,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Карточка вида из каталога или поиска — та же подробная карточка, что после распознавания.
class TaxonScreen extends ConsumerWidget {
  const TaxonScreen({super.key, required this.id});

  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(taxonDetailProvider(id))
        .when(
          loading: () => Scaffold(
            appBar: AppBar(),
            body: const Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Scaffold(
            appBar: AppBar(),
            body: EmptyState(
              icon: Icons.cloud_off,
              title: 'Не удалось загрузить',
              message: '$e',
            ),
          ),
          data: (t) => SpeciesScreen(
            args: SpeciesArgs(candidate: t.toCandidate(), taxonId: t.id),
          ),
        );
  }
}
