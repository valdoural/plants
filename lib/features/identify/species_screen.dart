import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/photo_viewer.dart';
import '../../core/responsive.dart';
import '../../core/theme.dart';
import '../../core/toast.dart';
import '../../core/widgets.dart';
import '../../data/care_text_ru.dart';
import '../../data/discover/species_profile.dart';
import '../../data/garden_controller.dart';
import '../../data/models.dart';
import '../garden/add_plant_sheet.dart';
import 'species_sections.dart';

class SpeciesArgs {
  const SpeciesArgs({
    required this.candidate,
    this.photo,
    this.photoUrl,
    this.taxonId,
  });

  final PlantCandidate candidate;

  /// Фото пользователя — станет обложкой растения в саду.
  final Uint8List? photo;
  final String? photoUrl;

  /// Вид уже найден в iNaturalist (из каталога или поиска).
  final int? taxonId;
}

/// Карточка вида по уровням: название → фото → основное → характеристика → инструкция →
/// условия ухода → гиды → вопросы → проблемы → применение, адаптации, история, название.
class SpeciesScreen extends ConsumerStatefulWidget {
  const SpeciesScreen({super.key, required this.args});

  final SpeciesArgs args;

  @override
  ConsumerState<SpeciesScreen> createState() => _SpeciesScreenState();
}

class _SpeciesScreenState extends ConsumerState<SpeciesScreen> {
  late PlantCandidate _c = widget.args.candidate;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final c = _c;
    final profileAsync = ref.watch(
      speciesProfileProvider((c.scientificName, widget.args.taxonId)),
    );
    final profile = profileAsync.value;
    final facts = SpeciesFacts(c, profile);
    final taxon = profile?.taxon;
    final names = {
      ...c.commonNames.skip(1),
      if (taxon?.commonName != null &&
          taxon!.commonName!.toLowerCase() != c.displayName.toLowerCase())
        taxon.commonName!,
    }.take(4).toList();
    final photos = <String>{...c.imageUrls, ...?taxon?.photos}.toList();
    final lead = profile?.wiki?.lead ?? c.description;
    final wide = !context.windowSize.isCompact;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          c.displayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (taxon != null)
            _WishIcon(taxonId: taxon.id, c: c, photo: photos.firstOrNull),
        ],
      ),
      body: MaxWidth(
        maxWidth: 860,
        child: ListView(
          padding: EdgeInsets.fromLTRB(context.gutter, 4, context.gutter, 40),
          children: [
            // 1. Название и латынь
            Text(
              c.displayName,
              style: const TextStyle(
                fontSize: 30,
                height: 1.12,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.6,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              c.scientificName,
              style: TextStyle(
                fontSize: 17,
                fontStyle: FontStyle.italic,
                color: p.inkSecondary,
              ),
            ),
            if (names.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'Также: ${names.join(', ')}',
                style: TextStyle(fontSize: 14, color: p.inkSecondary),
              ),
            ],
            const SizedBox(height: 16),
            // 2. Изображения
            _Gallery(
              photos: photos,
              userPhoto: widget.args.photo,
              height: wide ? 420 : 300,
            ),
            if (profileAsync.isLoading)
              const Padding(
                padding: EdgeInsets.only(top: 16),
                child: LinearProgressIndicator(minHeight: 2),
              ),
            if (lead != null && lead.isNotEmpty) ...[
              const SizedBox(height: 18),
              WikiLead(text: lead),
            ],
            // 3. Основное · 4. Характеристика
            MainInfoSection(facts: facts),
            CharacteristicsSection(facts: facts),
            // 5. Инструкция · 6. Условия ухода
            CareGuideSection(facts: facts),
            CareConditionsSection(
              facts: facts,
              onWrongSpecies: (n) => setState(() => _c = n),
            ),
            // 7. Гиды · 8. Вопросы · 9. Проблемы
            const GuidesSection(),
            FaqSection(facts: facts),
            CommonProblemsSection(facts: facts),
            // 10. Применение, адаптации, история и легенды, история названия
            ...wikiSections(profile?.wiki),
            const SizedBox(height: 24),
            _Sources(profile: profile, infoUrl: c.infoUrl),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: FilledButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Добавить в мой сад'),
            onPressed: () async {
              final plant = await showAddPlantSheet(
                context,
                ref,
                species: c,
                photo: widget.args.photo,
              );
              if (plant != null && context.mounted) {
                showToast(context, '«${plant.nickname}» в вашем саду');
                context.go('/garden');
                context.push('/plant/${plant.id}');
              }
            },
          ),
        ),
      ),
    );
  }
}

/// Большая карусель фото с точками; касание — полноэкранный просмотр; ниже — лента миниатюр.
class _Gallery extends StatefulWidget {
  const _Gallery({required this.photos, required this.height, this.userPhoto});

  final List<String> photos;
  final Uint8List? userPhoto;
  final double height;

  @override
  State<_Gallery> createState() => _GalleryState();
}

class _GalleryState extends State<_Gallery> {
  final _pages = PageController();
  var _index = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final photos = widget.photos;
    if (photos.isEmpty) {
      return SizedBox(
        height: widget.height,
        child: widget.userPhoto != null
            ? PlantImage.memory(widget.userPhoto!, radius: 24)
            : const PlantImage(null, radius: 24),
      );
    }
    final many = photos.length > 1;
    final arrows = kIsWeb || !context.windowSize.isCompact;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: widget.height,
          child: Stack(
            children: [
              PageView.builder(
                controller: _pages,
                itemCount: photos.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (_, i) => GestureDetector(
                  onTap: () => showPhotoViewer(context, photos, initial: i),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: PlantImage(photos[i], radius: 24),
                  ),
                ),
              ),
              if (many)
                Positioned(
                  bottom: 12,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_index + 1} / ${photos.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              if (many && arrows)
                for (final left in [true, false])
                  Positioned(
                    left: left ? 8 : null,
                    right: left ? null : 8,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: IconButton.filled(
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black45,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => _pages.animateToPage(
                          (_index + (left ? -1 : 1)).clamp(
                            0,
                            photos.length - 1,
                          ),
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOutCubic,
                        ),
                        icon: Icon(
                          left ? Icons.chevron_left : Icons.chevron_right,
                        ),
                      ),
                    ),
                  ),
            ],
          ),
        ),
        if (many) ...[
          const SizedBox(height: 10),
          PhotoStrip(urls: photos, height: 72),
        ],
      ],
    );
  }
}

/// Вводная из Википедии с «Читать дальше».
class WikiLead extends StatefulWidget {
  const WikiLead({super.key, required this.text});

  final String text;

  @override
  State<WikiLead> createState() => _WikiLeadState();
}

class _WikiLeadState extends State<WikiLead> {
  var _open = false;

  @override
  Widget build(BuildContext context) {
    final long = widget.text.length > 300;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          alignment: Alignment.topCenter,
          child: Text(
            widget.text,
            maxLines: _open || !long ? null : 5,
            overflow: _open || !long ? null : TextOverflow.fade,
            style: const TextStyle(fontSize: 16, height: 1.5),
          ),
        ),
        if (long)
          TextButton(
            onPressed: () => setState(() => _open = !_open),
            style: TextButton.styleFrom(padding: EdgeInsets.zero),
            child: Text(_open ? 'Свернуть' : 'Читать дальше'),
          ),
      ],
    );
  }
}

class _WishIcon extends ConsumerWidget {
  const _WishIcon({required this.taxonId, required this.c, this.photo});

  final int taxonId;
  final PlantCandidate c;
  final String? photo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wished = ref.watch(gardenProvider).value?.isWished(taxonId) ?? false;
    return IconButton(
      tooltip: wished ? 'В списке желаний' : 'Хочу вырастить',
      icon: Icon(wished ? Icons.bookmark : Icons.bookmark_border),
      onPressed: () async {
        final added = await ref
            .read(gardenProvider.notifier)
            .toggleWish(
              taxonId: taxonId,
              scientificName: c.scientificName,
              commonName: c.commonNames.firstOrNull,
              photoUrl: photo,
            );
        if (context.mounted) {
          showToast(
            context,
            added ? 'В списке желаний' : 'Убрано из списка желаний',
          );
        }
      },
    );
  }
}

/// Откуда сведения — с лицензиями.
class _Sources extends StatelessWidget {
  const _Sources({required this.profile, this.infoUrl});

  final SpeciesProfile? profile;
  final String? infoUrl;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final wiki = profile?.wiki;
    final taxon = profile?.taxon;
    final links = <(String, String)>[
      if (wiki != null) ('Википедия', wiki.url),
      if (taxon != null) ('iNaturalist', taxon.inatUrl),
      if (profile?.gbifKey != null)
        ('GBIF', 'https://www.gbif.org/species/${profile!.gbifKey}'),
      if (infoUrl != null && wiki == null) ('Подробнее', infoUrl!),
    ];
    if (links.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Источники: тексты — Википедия (CC BY-SA), фото и цветение — iNaturalist (лицензии авторов), '
          'карта и климат — наблюдения GBIF.org, уход — Plant.id.',
          style: TextStyle(fontSize: 12, height: 1.4, color: p.inkSecondary),
        ),
        Wrap(
          spacing: 4,
          children: [
            for (final (label, url) in links)
              TextButton(onPressed: () => openLink(url), child: Text(label)),
          ],
        ),
      ],
    );
  }
}

/// Плитки «полив / свет / почва / ядовитость».
class SpeciesCareFacts extends StatelessWidget {
  const SpeciesCareFacts({super.key, required this.candidate});

  final PlantCandidate candidate;

  @override
  Widget build(BuildContext context) {
    final c = candidate;
    // (иконка, заголовок, кратко по-русски, полный текст сервиса если он на другом языке)
    final facts = <(IconData, String, String, String?)>[
      (
        Icons.water_drop,
        'Полив',
        c.wateringLevel == null
            ? 'нет данных'
            : everyLabel(c.suggestedWateringDays),
        null,
      ),
      if (c.light != null)
        _fact(Icons.wb_sunny, 'Свет', c.light!, lightSummaryRu(c.light)),
      if (c.soil != null)
        _fact(Icons.grass, 'Почва', c.soil!, soilSummaryRu(c.soil)),
      if (c.toxicity != null)
        _fact(
          Icons.warning_amber,
          'Ядовитость',
          c.toxicity!,
          toxicitySummaryRu(c.toxicity),
        ),
    ];
    if (c.wateringLevel == null && facts.length == 1) {
      return const Card(
        child: ListTile(
          leading: Icon(Icons.info_outline),
          title: Text('Советы по уходу недоступны'),
          subtitle: Text(
            'Этот сервис возвращает только вид. Для советов по уходу используйте Plant.id.',
          ),
        ),
      );
    }
    return Column(
      children: [
        for (final (icon, title, value, details) in facts)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Card(
              child: details == null
                  ? ListTile(
                      leading: CircleAvatar(child: Icon(icon)),
                      title: Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(value),
                    )
                  : ExpansionTile(
                      shape: const Border(),
                      leading: CircleAvatar(child: Icon(icon)),
                      title: Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(value),
                      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      expandedCrossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Подробнее (англ.)',
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          details,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
            ),
          ),
      ],
    );
  }

  /// Если сервис ответил не по-русски — показываем краткую сводку, а оригинал прячем в «подробнее».
  static (IconData, String, String, String?) _fact(
    IconData icon,
    String title,
    String raw,
    String? summary,
  ) {
    if (isRussian(raw)) return (icon, title, raw, null);
    return (icon, title, summary ?? 'Описание на английском', raw);
  }
}
