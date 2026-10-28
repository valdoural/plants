import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/responsive.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/garden_controller.dart';
import '../../data/models.dart';
import '../../data/plant_problems.dart';

IconData partIcon(PlantPart part) => switch (part) {
  PlantPart.leaves => Icons.eco_outlined,
  PlantPart.stem => Icons.grass,
  PlantPart.roots => Icons.yard_outlined,
  PlantPart.flowers => Icons.local_florist_outlined,
  PlantPart.pests => Icons.bug_report_outlined,
};

/// Плитки разделов справочника проблем.
class ProblemPartsGrid extends StatelessWidget {
  const ProblemPartsGrid({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final columns = c.maxWidth >= 640 ? 2 : 1;
        final width = (c.maxWidth - (columns - 1) * 10) / columns;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final part in PlantPart.values)
              SizedBox(
                width: width,
                child: NavTile(
                  icon: partIcon(part),
                  title: part.label,
                  subtitle: part.hint,
                  onTap: () => context.push('/problems/${part.name}'),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Список проблем одной части растения.
class ProblemsPartScreen extends StatelessWidget {
  const ProblemsPartScreen({super.key, required this.part});

  final PlantPart part;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final problems = plantProblems.where((x) => x.part == part).toList();
    final symptoms = Symptom.values.where((s) => s.part == part).toList();
    return Scaffold(
      appBar: AppBar(title: Text(part.label)),
      body: MaxWidth(
        maxWidth: 760,
        child: ListView(
          padding: EdgeInsets.fromLTRB(context.gutter, 0, context.gutter, 40),
          children: [
            Text(
              'Частые признаки: ${symptoms.map((s) => s.label.toLowerCase()).join('; ')}.',
              style: TextStyle(
                fontSize: 15,
                height: 1.45,
                color: p.inkSecondary,
              ),
            ),
            const SizedBox(height: 16),
            for (final x in problems) ...[
              _ProblemTile(problem: x),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProblemTile extends StatelessWidget {
  const _ProblemTile({required this.problem, this.note});

  final PlantProblem problem;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return PressScale(
      child: Material(
        color: p.surface,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => context.push('/problem/${problem.id}'),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  problem.title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  note ?? problem.summary,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    color: p.inkSecondary,
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

/// Карточка проблемы: описание, признаки, причины, что делать, профилактика.
class ProblemScreen extends StatelessWidget {
  const ProblemScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final x = problemById(id);
    if (x == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyState(icon: Icons.search_off, title: 'Не найдено'),
      );
    }
    Widget heading(String t) => Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8),
      child: Text(
        t,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
      ),
    );
    Widget bullet(String t, {bool numbered = false, int i = 0}) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 24,
            child: Text(
              numbered ? '${i + 1}.' : '•',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: p.accent,
              ),
            ),
          ),
          Expanded(
            child: Text(t, style: const TextStyle(fontSize: 16, height: 1.45)),
          ),
        ],
      ),
    );
    return Scaffold(
      appBar: AppBar(title: Text(x.part.label)),
      body: MaxWidth(
        maxWidth: 760,
        child: ListView(
          padding: EdgeInsets.fromLTRB(context.gutter, 0, context.gutter, 40),
          children: [
            Text(
              x.title,
              style: const TextStyle(
                fontSize: 30,
                height: 1.15,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.6,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              x.summary,
              style: TextStyle(
                fontSize: 17,
                height: 1.5,
                color: p.inkSecondary,
              ),
            ),
            heading('Признаки'),
            for (final s in x.signs) bullet(s.label),
            if (x.factors.isNotEmpty) ...[
              heading('Частые причины'),
              for (final f in x.factors) bullet(f.label),
            ],
            heading('Что делать'),
            for (final (i, t) in x.fix.indexed) bullet(t, numbered: true, i: i),
            if (x.prevent.isNotEmpty) ...[
              heading('Как не допустить'),
              for (final t in x.prevent) bullet(t),
            ],
            const SizedBox(height: 20),
            OutlinedButton(
              onPressed: () => context.push('/diagnose/survey'),
              child: const Text('Пройти анкету по уходу'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Анкета: что заметно на растении и как за ним ухаживают → вероятные проблемы и ошибки ухода.
class CareSurveyScreen extends ConsumerStatefulWidget {
  const CareSurveyScreen({super.key, this.plantId});

  final String? plantId;

  @override
  ConsumerState<CareSurveyScreen> createState() => _CareSurveyScreenState();
}

class _CareSurveyScreenState extends ConsumerState<CareSurveyScreen> {
  final _scroll = ScrollController();
  final _symptoms = <Symptom>{};
  WateringHabit? _watering;
  bool? _drainage;
  LightSpot? _light;
  FeedingHabit? _feeding;
  final _changes = <CareFactor>{};
  var _pests = false;
  var _showResult = false;

  @override
  void initState() {
    super.initState();
    // Что уже известно о растении из сада — подставляем.
    final plant = widget.plantId == null
        ? null
        : ref.read(gardenProvider).value?.plant(widget.plantId!);
    final c = plant?.conditions;
    _drainage = c?.drainage;
    _light = switch (c?.light) {
      PlantLight.sun => LightSpot.sun,
      PlantLight.bright || PlantLight.partial => LightSpot.bright,
      PlantLight.shade => LightSpot.far,
      null => null,
    };
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final factors = careFactors(
      watering: _watering,
      drainage: _drainage,
      light: _light,
      feeding: _feeding,
      changes: _changes,
      pestsSeen: _pests,
    );
    final matches = matchProblems(_symptoms, factors);
    final gap = const SizedBox(height: 22);

    return Scaffold(
      appBar: AppBar(title: const Text('Анкета по уходу')),
      body: MaxWidth(
        maxWidth: 760,
        child: ListView(
          controller: _scroll,
          padding: EdgeInsets.fromLTRB(context.gutter, 0, context.gutter, 40),
          children: [
            Text(
              'Отметьте, что видите, и расскажите об уходе. Многие проблемы — следствие условий, которых не видно на фото.',
              style: TextStyle(
                fontSize: 15,
                height: 1.45,
                color: p.inkSecondary,
              ),
            ),
            gap,
            const Text(
              'Что заметно на растении',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            for (final part in PlantPart.values) ...[
              const SizedBox(height: 14),
              Text(
                part.label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: p.inkSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final s in Symptom.values.where((s) => s.part == part))
                    FilterChip(
                      label: Text(s.label),
                      selected: _symptoms.contains(s),
                      onSelected: (on) => setState(
                        () => on ? _symptoms.add(s) : _symptoms.remove(s),
                      ),
                    ),
                ],
              ),
            ],
            gap,
            ChoiceGroup<WateringHabit>(
              title: 'Когда поливаете',
              values: WateringHabit.values,
              selected: _watering,
              label: (v) => v.label,
              onChanged: (v) => setState(() => _watering = v),
            ),
            gap,
            ChoiceGroup<bool>(
              title: 'Есть отверстия в горшке',
              values: const [true, false],
              selected: _drainage,
              label: (v) => v ? 'Да' : 'Нет',
              onChanged: (v) => setState(() => _drainage = v),
            ),
            gap,
            ChoiceGroup<LightSpot>(
              title: 'Где стоит',
              values: LightSpot.values,
              selected: _light,
              label: (v) => v.label,
              onChanged: (v) => setState(() => _light = v),
            ),
            gap,
            ChoiceGroup<FeedingHabit>(
              title: 'Подкормки',
              values: FeedingHabit.values,
              selected: _feeding,
              label: (v) => v.label,
              onChanged: (v) => setState(() => _feeding = v),
            ),
            gap,
            const Text(
              'Что менялось за месяц',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final f in recentChanges)
                  FilterChip(
                    label: Text(f.label),
                    selected: _changes.contains(f),
                    onSelected: (on) => setState(
                      () => on ? _changes.add(f) : _changes.remove(f),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Видел насекомых или паутинку'),
              value: _pests,
              onChanged: (v) => setState(() => _pests = v),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () {
                setState(() => _showResult = true);
                WidgetsBinding.instance.addPostFrameCallback(
                  (_) => _scroll.animateTo(
                    _scroll.position.maxScrollExtent,
                    duration: const Duration(milliseconds: 450),
                    curve: Curves.easeOutCubic,
                  ),
                );
              },
              child: const Text('Показать вывод'),
            ),
            if (_showResult) ...[
              gap,
              if (matches.isEmpty && factors.isEmpty)
                Text(
                  'Отметьте хотя бы один признак или ответ об уходе.',
                  style: TextStyle(fontSize: 15, color: p.inkSecondary),
                ),
              if (matches.isNotEmpty) ...[
                const Text(
                  'Вероятные проблемы',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                for (final m in matches) ...[
                  _ProblemTile(
                    problem: m.problem,
                    note: [
                      'Совпало: ${m.signs.map((s) => s.label.toLowerCase()).join(', ')}',
                      if (m.factors.isNotEmpty)
                        'Причина может быть в том, что ${m.factors.map((f) => f.label.toLowerCase()).join(', ')}',
                    ].join('. '),
                  ),
                  const SizedBox(height: 10),
                ],
              ] else if (_symptoms.isEmpty && factors.isNotEmpty)
                Text(
                  'Признаки не отмечены — показываем только ошибки ухода.',
                  style: TextStyle(fontSize: 15, color: p.inkSecondary),
                ),
              if (factors.isNotEmpty) ...[
                const SizedBox(height: 14),
                const Text(
                  'Ошибки и риски ухода',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                for (final f in factors)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.error_outline, color: p.alert, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: '${f.label}. ',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                TextSpan(text: f.advice),
                              ],
                            ),
                            style: const TextStyle(fontSize: 15, height: 1.45),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
              if (matches.isNotEmpty || factors.isNotEmpty)
                Text(
                  'Это подсказка по вашим ответам, а не диагноз. Если растению хуже, сфотографируйте больное место для проверки через Plant.id.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: p.inkSecondary,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
