import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/responsive.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/discover/catalog.dart';
import '../../data/discover/discover_providers.dart';
import '../garden/add_plant_sheet.dart';
import 'discover_widgets.dart';

/// Поиск растения по названию (русскому или латинскому).
class PlantSearchScreen extends ConsumerStatefulWidget {
  const PlantSearchScreen({super.key});

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
    _debounce = Timer(const Duration(milliseconds: 350), () => setState(() => _query = v.trim()));
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final results = _query.length < 2 ? null : ref.watch(plantSearchProvider(_query));
    return Scaffold(
      appBar: AppBar(title: const Text('Поиск растений')),
      body: MaxWidth(
        maxWidth: 820,
        child: ListView(
          padding: EdgeInsets.fromLTRB(context.gutter, 4, context.gutter, 32),
          children: [
            TextField(
              controller: _q,
              autofocus: true,
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Например: монстера, фикус, Rosa'),
              onChanged: _onChanged,
            ),
            const SizedBox(height: 12),
            if (results == null)
              Padding(
                padding: const EdgeInsets.only(top: 24),
                child: Text('Введите хотя бы две буквы названия.', style: TextStyle(color: p.inkSecondary)),
              )
            else
              results.when(
                loading: () => const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
                error: (e, _) => Text('Поиск недоступен: $e', style: TextStyle(color: p.alert)),
                data: (list) => list.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.only(top: 24),
                        child: Text('Ничего не нашлось. Попробуйте латинское название.', style: TextStyle(color: p.inkSecondary)),
                      )
                    : Column(children: [
                        for (final t in list)
                          InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => context.push('/taxon/${t.id}'),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(children: [
                                PlantImage(t.photoUrl, size: 64, radius: 14),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text(t.displayName, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                                    Text(t.name, style: TextStyle(fontStyle: FontStyle.italic, color: p.inkSecondary)),
                                  ]),
                                ),
                                if (t.isIn(CatalogKind.toxicIds))
                                  Text('ядовито', style: TextStyle(color: p.alert, fontWeight: FontWeight.w800)),
                              ]),
                            ),
                          ),
                      ]),
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
              padding: EdgeInsets.fromLTRB(context.gutter, 0, context.gutter, 16),
              sliver: SliverToBoxAdapter(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(kind.subtitle, style: TextStyle(fontSize: 16, color: p.inkSecondary)),
                  const SizedBox(height: 4),
                  Row(children: [
                    Expanded(
                      child: Text(place == null ? 'Место не указано — показан общий список' : 'Рядом с: ${place.label}',
                          style: TextStyle(fontSize: 14, color: p.inkSecondary)),
                    ),
                    TextButton(onPressed: () => showPlacePicker(context), child: Text(place == null ? 'Указать' : 'Изменить')),
                  ]),
                  if (kind == CatalogKind.toxic)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: p.surface, borderRadius: BorderRadius.circular(16)),
                      child: Text(
                        'Не пробуйте растения на вкус и мойте руки после работы с ними. Борщевик Сосновского вызывает ожоги на солнце. '
                        'При отравлении звоните 103 или 112.',
                        style: TextStyle(fontSize: 14, height: 1.4, color: p.ink),
                      ),
                    ),
                ]),
              ),
            ),
            items.when(
              loading: () => const SliverFillRemaining(child: Center(child: CircularProgressIndicator())),
              error: (e, _) => SliverToBoxAdapter(
                child: Padding(padding: const EdgeInsets.all(24), child: Text('Не удалось загрузить: $e')),
              ),
              data: (list) => SliverPadding(
                padding: EdgeInsets.fromLTRB(context.gutter, 0, context.gutter, 40),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 200,
                    mainAxisSpacing: 18,
                    crossAxisSpacing: 14,
                    childAspectRatio: 0.66,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => LayoutBuilder(builder: (_, c) => TaxonTile(taxon: list[i], width: c.maxWidth)),
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

/// Карточка вида из каталога/поиска: фото, описание, предупреждение о ядовитости, «Добавить в сад».
class TaxonScreen extends ConsumerWidget {
  const TaxonScreen({super.key, required this.id});

  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final detail = ref.watch(taxonDetailProvider(id));
    return Scaffold(
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Scaffold(appBar: AppBar(), body: EmptyState(icon: Icons.cloud_off, title: 'Не удалось загрузить', message: '$e')),
        data: (t) {
          final photos = t.photos.isNotEmpty ? t.photos : [?t.photoUrl];
          final toxic = t.isIn(CatalogKind.toxicIds);
          final wide = !context.windowSize.isCompact;
          final hero = SizedBox(
            height: wide ? 520 : (MediaQuery.sizeOf(context).height * 0.48).clamp(300.0, 460.0),
            child: PageView(children: [for (final u in photos) PlantImage(u, radius: wide ? 28 : 0)]),
          );
          final info = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (photos.length > 1)
                Text('${photos.length} фото — листайте', style: TextStyle(fontSize: 13, color: p.inkSecondary)),
              const SizedBox(height: 8),
              Text(t.displayName, style: const TextStyle(fontSize: 32, height: 1.12, fontWeight: FontWeight.w800, letterSpacing: -0.8)),
              const SizedBox(height: 4),
              Text([t.name, if (t.family != null) t.family].join(' · '),
                  style: TextStyle(fontSize: 17, fontStyle: FontStyle.italic, color: p.inkSecondary)),
              if (toxic) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: p.surface, borderRadius: BorderRadius.circular(16)),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(Icons.warning_amber_rounded, color: p.alert),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text('Ядовитое растение. Держите подальше от детей и животных, работайте в перчатках.',
                          style: TextStyle(fontSize: 15, height: 1.4)),
                    ),
                  ]),
                ),
              ],
              if (t.summary != null && t.summary!.isNotEmpty) ...[
                const SizedBox(height: 18),
                Text(t.summary!, style: const TextStyle(fontSize: 16, height: 1.5)),
              ],
              const SizedBox(height: 22),
              FilledButton(
                onPressed: () async {
                  final plant = await showAddPlantSheet(context, ref, species: t.toCandidate());
                  if (plant != null && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('«${plant.nickname}» в вашем саду')));
                  }
                },
                child: const Text('Добавить в сад'),
              ),
              const SizedBox(height: 10),
              OutlinedButton(onPressed: () => openLink(t.wikipediaUrl ?? t.inatUrl), child: const Text('Подробнее в энциклопедии')),
              const SizedBox(height: 18),
              if (t.photoAttribution != null)
                Text('Фото: ${t.photoAttribution} · iNaturalist', style: TextStyle(fontSize: 12, color: p.inkSecondary)),
            ],
          );

          if (wide) {
            return SafeArea(
              child: MaxWidth(
                child: ListView(
                  padding: EdgeInsets.all(context.gutter),
                  children: [
                    Align(alignment: Alignment.centerLeft, child: BackButton(onPressed: () => context.pop())),
                    const SizedBox(height: 8),
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Expanded(flex: 6, child: hero),
                      const SizedBox(width: 32),
                      Expanded(flex: 5, child: info),
                    ]),
                  ],
                ),
              ),
            );
          }
          return CustomScrollView(slivers: [
            SliverAppBar(
              pinned: true,
              expandedHeight: 0,
              backgroundColor: p.bg,
              title: Text(t.displayName, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            SliverToBoxAdapter(child: hero),
            SliverPadding(padding: const EdgeInsets.fromLTRB(24, 12, 24, 40), sliver: SliverToBoxAdapter(child: info)),
          ]);
        },
      ),
    );
  }
}
