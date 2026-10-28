import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/photo_viewer.dart';
import '../../core/theme.dart';
import '../../core/toast.dart';
import '../../core/widgets.dart';
import '../../data/care_advice.dart';
import '../../data/care_text_ru.dart';
import '../../data/discover/catalog.dart';
import '../../data/discover/discover_providers.dart';
import '../../data/discover/species_profile.dart';
import '../../data/feedback.dart';
import '../../data/models.dart';
import '../../data/plant_problems.dart';
import '../discover/discover_screens.dart';
import '../home/seasonal_tips.dart';

/// Всё, что знаем о виде, в удобном виде для разделов карточки.
class SpeciesFacts {
  SpeciesFacts(this.c, this.profile);

  final PlantCandidate c;
  final SpeciesProfile? profile;

  String get name => c.displayName;
  String? get text => profile?.text;
  ClimateZone? get climate => profile?.climate?.main;

  bool get toxicByList => profile?.taxon?.isIn(CatalogKind.toxicIds) ?? false;

  String? get toxicity {
    final summary = toxicitySummaryRu(c.toxicity);
    if (summary != null) return summary;
    if (toxicByList) return 'Ядовито для людей и животных';
    return null;
  }

  String? get light => lightSummaryRu(c.light);
  String? get soil => soilSummaryRu(c.soil);

  String? get watering => c.wateringLevel == null
      ? null
      : '${_cap(everyLabel(c.suggestedWateringDays))}, когда верхний слой почвы подсохнет';

  bool? get likesSun {
    final l = preferredLight(c.light);
    if (l.isEmpty) return null;
    return l.contains(PlantLight.sun);
  }

  String? get type {
    final t = plantType(profile?.taxon?.ancestry ?? const {});
    final f = text == null ? null : growthForm(text!);
    final parts = [?f, ?t];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  String? get life => text == null ? null : lifespan(text!);
  String? get height => text == null ? null : plantHeight(text!);

  String? get floweringLabel {
    final m = profile?.floweringMonths ?? const [];
    if (m.isEmpty) return null;
    final f = DateFormat('LLLL', 'ru');
    String month(int i) => f.format(DateTime(2026, i));
    // Подряд идущие месяцы — диапазоном (с переходом через декабрь).
    if (m.length == 1) return _cap(month(m.first));
    final contiguous = [for (var i = 1; i < m.length; i++) m[i] - m[i - 1] == 1]
        .every((x) => x);
    return contiguous
        ? _cap('${month(m.first)} — ${month(m.last)}')
        : _cap(m.map(month).join(', '));
  }
}

String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

/// Заголовок раздела карточки вида.
class SpeciesSection extends StatelessWidget {
  const SpeciesSection({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.only(top: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
          if (subtitle != null)
            Text(
              subtitle!,
              style: TextStyle(fontSize: 13, color: p.inkSecondary),
            ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

/// Плашка-поверхность раздела.
class _Panel extends StatelessWidget {
  const _Panel({required this.child, this.padding = const EdgeInsets.all(16)});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Material(
    color: context.palette.surface,
    borderRadius: BorderRadius.circular(20),
    clipBehavior: Clip.antiAlias,
    child: Padding(padding: padding, child: child),
  );
}

/// Строка «значок · подпись · значение».
class _Row extends StatelessWidget {
  const _Row(this.icon, this.label, this.value, {this.color});

  final IconData icon;
  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: color ?? p.accent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 13, color: p.inkSecondary),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ───── Основная информация ─────

class MainInfoSection extends StatelessWidget {
  const MainInfoSection({super.key, required this.facts});

  final SpeciesFacts facts;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final pr = facts.profile;
    final taxon = pr?.taxon;
    final range = pr?.wiki?.section(['распространен', 'ареал'], max: 320);
    final rows = <Widget>[
      _Row(
        Icons.pets_outlined,
        'Опасность для людей и животных',
        facts.toxicity ??
            'Нет сведений о ядовитости — будьте осторожны с детьми и питомцами',
        color: facts.toxicity == null ? p.inkSecondary : p.alert,
      ),
      if (taxon != null && taxon.isIn(CatalogKind.allergenIds))
        _Row(
          Icons.air,
          'Аллерген',
          'Пыльца вызывает насморк и слезотечение в сезон цветения',
          color: p.water,
        ),
      if (taxon != null)
        _Row(Icons.grass, 'Потенциал сорняка', weedPotential(taxon)),
      if (facts.type != null)
        _Row(Icons.category_outlined, 'Тип растения', facts.type!),
      if (facts.life != null)
        _Row(Icons.hourglass_empty, 'Продолжительность жизни', facts.life!),
    ];
    return SpeciesSection(
      title: 'Основное',
      child: _Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ...rows,
            if (range != null || pr?.gbifKey != null) ...[
              const SizedBox(height: 8),
              Text(
                'Ареал',
                style: TextStyle(fontSize: 13, color: p.inkSecondary),
              ),
              const SizedBox(height: 6),
              if (pr?.gbifKey != null) RangeMap(gbifKey: pr!.gbifKey!),
              if (range != null) ...[
                const SizedBox(height: 8),
                Text(range, style: const TextStyle(fontSize: 15, height: 1.45)),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

/// Маленькая карта мира с точками наблюдений вида (GBIF). Касание — крупнее.
class RangeMap extends StatelessWidget {
  const RangeMap({super.key, required this.gbifKey});

  final int gbifKey;

  @override
  Widget build(BuildContext context) {
    final (base, dots) = GbifClient.mapUrls(gbifKey);
    // Тайл мира квадратный; полоса от ~70° с.ш. до ~55° ю.ш. — пропорция 2:1.
    Widget map() => ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: AspectRatio(
        aspectRatio: 2,
        child: FittedBox(
          fit: BoxFit.cover,
          alignment: const Alignment(0, -0.15),
          clipBehavior: Clip.hardEdge,
          child: SizedBox.square(
            dimension: 512,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.network(
                  base,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox(),
                ),
                Image.network(
                  dots,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return GestureDetector(
      onTap: () => showDialog<void>(
        context: context,
        builder: (c) => Dialog(
          insetPadding: const EdgeInsets.all(16),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                map(),
                const SizedBox(height: 8),
                Text(
                  'Точки — наблюдения вида по данным GBIF.org',
                  style: TextStyle(fontSize: 13, color: c.palette.inkSecondary),
                ),
              ],
            ),
          ),
        ),
      ),
      child: map(),
    );
  }
}

// ───── Характеристика ─────

class CharacteristicsSection extends StatelessWidget {
  const CharacteristicsSection({super.key, required this.facts});

  final SpeciesFacts facts;

  @override
  Widget build(BuildContext context) {
    final a = facts.profile?.taxon?.ancestry ?? const {};
    final tiles = <(String, String, bool)>[
      if (a['family'] != null || facts.c.family != null)
        ('Семейство', a['family'] ?? facts.c.family!, true),
      if (a['genus'] != null || facts.c.genus != null)
        ('Род', a['genus'] ?? facts.c.genus!, true),
      if (a['order'] != null) ('Порядок', a['order']!, true),
      if (facts.height != null) ('Высота', facts.height!, false),
      if (facts.climate != null) ('Климат родины', facts.climate!.label, false),
      if (facts.floweringLabel != null)
        ('Цветение', facts.floweringLabel!, false),
    ];
    if (tiles.isEmpty) return const SizedBox.shrink();
    final p = context.palette;
    final flowering = facts.profile?.flowering;
    return SpeciesSection(
      title: 'Характеристика',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, c) {
              final cols = c.maxWidth >= 520 ? 3 : 2;
              final w = (c.maxWidth - (cols - 1) * 10) / cols;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final (label, value, latin) in tiles)
                    Container(
                      width: w,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: p.surface,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            label,
                            style: TextStyle(
                              fontSize: 13,
                              color: p.inkSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            value,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              fontStyle: latin
                                  ? FontStyle.italic
                                  : FontStyle.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
          if (flowering != null && facts.floweringLabel != null) ...[
            const SizedBox(height: 12),
            _FloweringBars(counts: flowering),
          ],
        ],
      ),
    );
  }
}

/// Столбики цветения по месяцам.
class _FloweringBars extends StatelessWidget {
  const _FloweringBars({required this.counts});

  final Map<int, int> counts;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final peak = counts.values.fold<int>(1, (a, b) => a > b ? a : b);
    const letters = [
      'Я',
      'Ф',
      'М',
      'А',
      'М',
      'И',
      'И',
      'А',
      'С',
      'О',
      'Н',
      'Д',
    ];
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Наблюдения с цветками по месяцам',
            style: TextStyle(fontSize: 13, color: p.inkSecondary),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 64,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var m = 1; m <= 12; m++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Flexible(
                            child: FractionallySizedBox(
                              heightFactor: ((counts[m] ?? 0) / peak).clamp(
                                0.04,
                                1.0,
                              ),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: (counts[m] ?? 0) >= peak * 0.25
                                      ? p.accent
                                      : p.surfaceHigh,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            letters[m - 1],
                            style: TextStyle(
                              fontSize: 11,
                              color: p.inkSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ───── Инструкция по уходу ─────

class CareGuideSection extends StatelessWidget {
  const CareGuideSection({super.key, required this.facts});

  final SpeciesFacts facts;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final z = facts.climate;
    final outdoorHardy = z == ClimateZone.temperate || z == ClimateZone.cold;
    final steps = <(IconData, String, String)>[
      (
        Icons.water_drop_outlined,
        'Полив',
        facts.watering ?? 'Поливайте, когда верхние 2–3 см почвы просохнут; летом чаще, зимой реже. Вода не должна стоять в поддоне.',
      ),
      (
        Icons.wb_sunny_outlined,
        'Свет',
        facts.light ??
            (z == ClimateZone.tropical
                ? 'Яркий рассеянный свет, без полуденного солнца'
                : 'Светлое место; летом — защита от полуденного солнца'),
      ),
      (
        Icons.thermostat,
        'Температура',
        z?.temperature ?? 'Обычная комнатная температура, без сквозняков и холодного подоконника',
      ),
      (
        Icons.layers_outlined,
        'Почва',
        facts.soil ?? 'Рыхлая, воздухопроницаемая, с дренажом на дне горшка',
      ),
      (
        Icons.science_outlined,
        'Подкормка',
        'Весной и летом раз в 2–4 недели комплексным удобрением; осенью и зимой — перерыв.',
      ),
      (
        Icons.yard_outlined,
        outdoorHardy ? 'Посадка и пересадка' : 'Пересадка',
        outdoorHardy
            ? 'В саду — весной или в начале осени; в горшке — раз в 2–3 года в ёмкость на 2–4 см шире.'
            : 'Молодые растения — каждую весну, взрослые — раз в 2–3 года в горшок на 2–4 см шире.',
      ),
    ];
    return SpeciesSection(
      title: 'Инструкция по уходу',
      child: _Panel(
        child: Column(
          children: [
            for (final (i, (icon, title, text)) in steps.indexed) ...[
              if (i > 0) Divider(height: 20, color: p.surfaceHigh),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: p.surfaceHigh,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, size: 20, color: p.accent),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${i + 1}. $title',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          text,
                          style: const TextStyle(fontSize: 15, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ───── Условия ухода (с меню) ─────

class CareConditionsSection extends ConsumerWidget {
  const CareConditionsSection({
    super.key,
    required this.facts,
    this.onWrongSpecies,
  });

  final SpeciesFacts facts;

  /// Пользователь выбрал правильный вид.
  final ValueChanged<PlantCandidate>? onWrongSpecies;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final notes = ref
        .watch(feedbackProvider)
        .where((n) => n.species == facts.c.scientificName)
        .toList();
    final climate = facts.profile?.climate;
    final z = climate?.main;
    final rows = <Widget>[
      if (z != null)
        _Row(
          Icons.public,
          'Климат',
          '${z.label} (${(climate!.share(z) * 100).round()}% наблюдений в природе) · ${z.temperature}',
        ),
      _Row(
        Icons.water_drop_outlined,
        'Полив',
        facts.watering ?? 'Умеренный: по мере просыхания верхнего слоя',
        color: p.water,
      ),
      _Row(
        Icons.wb_sunny_outlined,
        'Солнце',
        facts.light ?? 'Нет точных данных — начните с яркого рассеянного света',
      ),
      _Row(Icons.layers_outlined, 'Почва', facts.soil ?? 'Рыхлая, с дренажом'),
      _Row(
        Icons.warning_amber_rounded,
        'Ядовитость',
        facts.toxicity ?? 'Нет сведений',
        color: facts.toxicity == null ? p.inkSecondary : p.alert,
      ),
    ];
    return SpeciesSection(
      title: 'Условия ухода',
      trailing: PopupMenuButton<FeedbackKind>(
        tooltip: 'Ещё',
        icon: const Icon(Icons.more_horiz),
        onSelected: (k) => _feedback(context, ref, k),
        itemBuilder: (_) => [
          for (final k in FeedbackKind.values)
            PopupMenuItem(
              value: k,
              child: Row(
                children: [
                  Icon(k.icon, size: 20),
                  const SizedBox(width: 12),
                  Text(k.label),
                ],
              ),
            ),
        ],
      ),
      child: _Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ...rows,
            if (notes.isNotEmpty) ...[
              Divider(height: 24, color: p.surfaceHigh),
              Text(
                'Мои заметки',
                style: TextStyle(fontSize: 13, color: p.inkSecondary),
              ),
              for (final n in notes)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(n.kind.icon, size: 18, color: p.accent),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          n.text.isEmpty
                              ? n.kind.label
                              : '${n.kind.label}: ${n.text}',
                          style: const TextStyle(fontSize: 15, height: 1.35),
                        ),
                      ),
                      InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () =>
                            ref.read(feedbackProvider.notifier).remove(n.id),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                            Icons.close,
                            size: 18,
                            color: p.inkSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _feedback(
    BuildContext context,
    WidgetRef ref,
    FeedbackKind kind,
  ) async {
    final note = TextEditingController();
    final p = context.palette;
    final extra = kind == FeedbackKind.moreTips
        ? _moreTips()
        : const <String>[];
    final hint = switch (kind) {
      FeedbackKind.like => 'Что понравилось или что хотите запомнить?',
      FeedbackKind.wrongId => 'Что не так? Например: листья другой формы',
      FeedbackKind.contentError => 'Какая информация неверна?',
      FeedbackKind.moreTips => 'Ваши наблюдения и вопросы по уходу',
    };
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          MediaQuery.viewInsetsOf(ctx).bottom + 16,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(kind.icon, color: p.accent),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      kind.label,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              for (final t in extra)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.tips_and_updates_outlined,
                        size: 18,
                        color: p.accent,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          t,
                          style: const TextStyle(fontSize: 15, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
              if (kind == FeedbackKind.wrongId && onWrongSpecies != null) ...[
                OutlinedButton.icon(
                  onPressed: () => Navigator.pop(ctx, '__pick'),
                  icon: const Icon(Icons.search),
                  label: const Text('Выбрать правильный вид'),
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: note,
                minLines: 2,
                maxLines: 5,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: hint,
                  labelText: 'Заметка',
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Заметки хранятся на этом устройстве и видны в блоке «Условия ухода».',
                style: TextStyle(fontSize: 12, color: p.inkSecondary),
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, note.text.trim()),
                child: const Text('Сохранить'),
              ),
            ],
          ),
        ),
      ),
    );
    if (result == null || !context.mounted) return;
    if (result == '__pick') {
      final c = await pickSpecies(context, ref);
      if (c != null) {
        await ref
            .read(feedbackProvider.notifier)
            .add(
              facts.c.scientificName,
              kind,
              'правильный вид — ${c.scientificName}',
            );
        onWrongSpecies?.call(c);
      }
      return;
    }
    await ref
        .read(feedbackProvider.notifier)
        .add(facts.c.scientificName, kind, result);
    if (context.mounted) showToast(context, 'Заметка сохранена');
  }

  List<String> _moreTips() {
    final z = facts.climate;
    final season = seasonalTip(DateTime.now());
    return [
      ...season.points.take(2),
      if (z == ClimateZone.tropical) 'Родом из тропиков: любит влажный воздух — поставьте рядом поддон с мокрым керамзитом, не ставьте у батареи.',
      if (z == ClimateZone.temperate || z == ClimateZone.cold) 'Растение умеренного климата: в комнате зимой ему полезна прохлада 10–15 °C и более редкий полив.',
      if (facts.likesSun == true)
        'Любит солнце: южное или западное окно, летом можно вынести на балкон.',
      if (facts.likesSun == false) 'Прямое солнце обжигает листья — держите в метре от южного окна или за тюлем.',
      if (facts.toxicity != null)
        'Ядовито: работайте в перчатках, держите подальше от детей и питомцев.',
    ];
  }
}

// ───── Гиды ─────

class GuidesSection extends StatelessWidget {
  const GuidesSection({super.key});

  @override
  Widget build(BuildContext context) {
    const guides = [
      (
        Icons.water_drop_outlined,
        'Как поливать',
        'Калькулятор полива',
        '/tools/water',
      ),
      (Icons.wb_sunny_outlined, 'Хватает ли света', 'Люксметр', '/tools/light'),
      (
        Icons.yard_outlined,
        'Когда пересаживать',
        'Проверка за минуту',
        '/tools/repot',
      ),
      (
        Icons.healing_outlined,
        'Что с растением',
        'Анкета по уходу',
        '/diagnose/survey',
      ),
    ];
    return SpeciesSection(
      title: 'Гиды',
      child: LayoutBuilder(
        builder: (context, c) {
          final cols = c.maxWidth >= 560 ? 2 : 1;
          final w = (c.maxWidth - (cols - 1) * 10) / cols;
          return Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final (icon, title, sub, route) in guides)
                SizedBox(
                  width: w,
                  child: NavTile(
                    icon: icon,
                    title: title,
                    subtitle: sub,
                    onTap: () => context.push(route),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

// ───── Популярные вопросы ─────

class FaqSection extends StatelessWidget {
  const FaqSection({super.key, required this.facts});

  final SpeciesFacts facts;

  @override
  Widget build(BuildContext context) {
    final n = facts.name;
    final z = facts.climate;
    final p = context.palette;
    final qa = <(String, String)>[
      (
        'Как часто поливать $n?',
        facts.watering ?? 'Ориентируйтесь на почву: поливайте, когда верхние 2–3 см просохнут. Точный интервал подскажет калькулятор полива.',
      ),
      (
        'Сколько света нужно $n?',
        facts.light ??
            (z == ClimateZone.tropical
                ? 'Как большинству тропических растений — много рассеянного света без прямого полуденного солнца.'
                : 'Светлое место. Проверить освещённость можно люксметром в разделе «Инструменты».'),
      ),
      (
        'Ядовито ли $n для кошек и собак?',
        facts.toxicity ?? 'Надёжных сведений о ядовитости нет. На всякий случай не давайте питомцам грызть листья.',
      ),
      if (facts.floweringLabel != null)
        (
          'Когда цветёт $n?',
          '${facts.floweringLabel} — по наблюдениям с цветками в iNaturalist.',
        ),
      if (z != null)
        (
          'Можно ли выращивать $n дома?',
          switch (z) {
            ClimateZone.tropical || ClimateZone.subtropical =>
              'Да: родом из тёплых мест, хорошо растёт в комнате при ${z.temperature.split(';').first}.',
            _ => 'Это растение умеренного климата: лучше растёт в саду. В комнате ему нужна прохладная зимовка.',
          },
        ),
      (
        'Почему у $n желтеют листья?',
        'Чаще всего — перелив, нехватка света или сухой воздух. Пройдите анкету по уходу в разделе «Диагноз», чтобы найти причину.',
      ),
    ];
    return SpeciesSection(
      title: 'Популярные вопросы',
      child: _Panel(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          children: [
            for (final (i, (q, a)) in qa.indexed) ...[
              if (i > 0)
                Divider(
                  height: 1,
                  indent: 16,
                  endIndent: 16,
                  color: p.surfaceHigh,
                ),
              Theme(
                data: Theme.of(context)
                    .copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  title: Text(
                    q,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                  expandedCrossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(a, style: const TextStyle(fontSize: 15, height: 1.45)),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ───── Общие проблемы ─────

class CommonProblemsSection extends StatelessWidget {
  const CommonProblemsSection({super.key, required this.facts});

  final SpeciesFacts facts;

  @override
  Widget build(BuildContext context) {
    final problems = likelyProblems(
      wateringLevel: facts.c.wateringLevel,
      likesSun: facts.likesSun,
      tropical: facts.climate == ClimateZone.tropical,
    );
    final t = MediaQuery.textScalerOf(context);
    return SpeciesSection(
      title: 'Общие проблемы',
      subtitle: 'Что чаще всего случается с такими растениями',
      child: SizedBox(
        height: 150 + 12 + t.scale(15) * 1.25 * 2 + t.scale(13) * 1.3 + 8,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: problems.length,
          separatorBuilder: (_, _) => const SizedBox(width: 12),
          itemBuilder: (_, i) => _ProblemCard(problem: problems[i]),
        ),
      ),
    );
  }
}

class _ProblemCard extends ConsumerWidget {
  const _ProblemCard({required this.problem});

  final PlantProblem problem;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final id = problem.inatTaxonId;
    final photos = id == null ? null : ref.watch(taxonDetailProvider(id)).value;
    final url = photos == null
        ? null
        : (photos.photos.isNotEmpty ? photos.photos.first : photos.photoUrl);
    final icon = switch (problem.part) {
      PlantPart.leaves => Icons.eco_outlined,
      PlantPart.stem => Icons.grass,
      PlantPart.roots => Icons.yard_outlined,
      PlantPart.flowers => Icons.local_florist_outlined,
      PlantPart.pests => Icons.bug_report_outlined,
    };
    return SizedBox(
      width: 168,
      child: PressScale(
        child: GestureDetector(
          onTap: () => context.push('/problem/${problem.id}'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 150,
                width: 168,
                child: url != null
                    ? GestureDetector(
                        onLongPress: () => showPhotoViewer(
                          context,
                          photos!.photos.isNotEmpty ? photos.photos : [url],
                        ),
                        child: PlantImage(url, radius: 16),
                      )
                    : Container(
                        decoration: BoxDecoration(
                          color: p.surface,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(icon, size: 48, color: p.accent),
                      ),
              ),
              const SizedBox(height: 8),
              Text(
                problem.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.25,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                problem.part.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.3,
                  color: p.inkSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ───── Разделы из Википедии ─────

/// Текстовый раздел с «Читать дальше».
class WikiTextSection extends StatefulWidget {
  const WikiTextSection({super.key, required this.title, required this.text});

  final String title;
  final String text;

  @override
  State<WikiTextSection> createState() => _WikiTextSectionState();
}

class _WikiTextSectionState extends State<WikiTextSection> {
  var _open = false;

  @override
  Widget build(BuildContext context) {
    final long = widget.text.length > 360;
    return SpeciesSection(
      title: widget.title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: Text(
              widget.text,
              maxLines: _open || !long ? null : 6,
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
      ),
    );
  }
}

/// Применение, адаптации, история и легенды, история названия — из разделов статьи.
List<Widget> wikiSections(WikiArticle? wiki) {
  if (wiki == null) return const [];
  final items = <(String, List<String>)>[
    ('Применение', ['применен', 'использован', 'хозяйственн', 'значение']),
    ('Стратегии адаптации', ['эколог', 'биолог', 'особенност', 'размножен']),
    (
      'История и легенды',
      ['в культуре', 'мифолог', 'легенд', 'символ', 'истори'],
    ),
    ('История названия', ['этимолог', 'назван']),
  ];
  return [
    for (final (title, keys) in items)
      if (wiki.section(keys) case final text?)
        WikiTextSection(title: title, text: text),
  ];
}
