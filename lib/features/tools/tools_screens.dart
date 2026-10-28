import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/live_camera.dart';
import '../../core/responsive.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/care_advice.dart';
import '../../data/garden_controller.dart';
import '../../data/light_meter.dart';
import '../../data/models.dart';

/// Инструменты садовода: плитки для экранов «Ещё» и «Для вас».
class ToolsGrid extends StatelessWidget {
  const ToolsGrid({super.key});

  static const tools = [
    (Icons.wb_sunny_outlined, 'Люксметр', 'Хватает ли света', '/tools/light'),
    (
      Icons.water_drop_outlined,
      'Калькулятор полива',
      'Как часто и сколько',
      '/tools/water',
    ),
    (
      Icons.yard_outlined,
      'Пора ли пересаживать',
      'Проверка за минуту',
      '/tools/repot',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final columns = c.maxWidth >= 560 ? 3 : 1;
        final width = (c.maxWidth - (columns - 1) * 10) / columns;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final (icon, title, subtitle, route) in tools)
              SizedBox(
                width: width,
                child: NavTile(
                  icon: icon,
                  title: title,
                  subtitle: subtitle,
                  onTap: () => context.push(route),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Общая рамка экрана инструмента.
class _ToolScaffold extends StatelessWidget {
  const _ToolScaffold({
    required this.title,
    required this.intro,
    required this.children,
  });

  final String title;
  final String intro;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: MaxWidth(
        maxWidth: 720,
        child: ListView(
          padding: EdgeInsets.fromLTRB(context.gutter, 0, context.gutter, 40),
          children: [
            Text(
              intro,
              style: TextStyle(
                fontSize: 15,
                height: 1.45,
                color: p.inkSecondary,
              ),
            ),
            const SizedBox(height: 18),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// Карточка результата: крупный заголовок, пояснение, дополнительные строки.
class _ResultCard extends StatelessWidget {
  const _ResultCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.text,
    this.children = const [],
  });

  final IconData icon;
  final Color color;
  final String title;
  final String text;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: Container(
        key: ValueKey(title + text),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 22,
                      height: 1.2,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(text, style: const TextStyle(fontSize: 15, height: 1.45)),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// Выбор растения из сада (необязательно): чипы с именами.
class _PlantPicker extends ConsumerWidget {
  const _PlantPicker({required this.selected, required this.onChanged});

  final String? selected;
  final ValueChanged<Plant?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plants = ref.watch(gardenProvider).value?.plants ?? const [];
    if (plants.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: ChoiceGroup<Plant>(
        title: 'Растение из сада',
        values: plants,
        selected: plants.where((p) => p.id == selected).firstOrNull,
        label: (p) => p.nickname,
        onChanged: onChanged,
      ),
    );
  }
}

// ───────────────────────── Люксметр ─────────────────────────

class LightMeterScreen extends ConsumerStatefulWidget {
  const LightMeterScreen({super.key});

  @override
  ConsumerState<LightMeterScreen> createState() => _LightMeterScreenState();
}

class _LightMeterScreenState extends ConsumerState<LightMeterScreen> {
  final _camera = GlobalKey<LiveCameraState>();

  /// В браузере снимок без EXIF — измерить нельзя, только оценить по окну.
  var _useCamera = !kIsWeb;
  var _busy = false;
  double? _lux;
  String? _cameraNote;

  var _side = WindowSide.eastWest;
  var _distance = WindowDistance.near;
  var _curtain = false;

  PlantLight get _light => _lux != null && _useCamera
      ? lightFromLux(_lux!)
      : estimateLight(side: _side, distance: _distance, sheerCurtain: _curtain);

  Future<void> _measure() async {
    setState(() => _busy = true);
    try {
      final bytes = await _camera.currentState?.capture();
      if (bytes == null) return;
      final exposure = await readExposure(bytes);
      if (exposure == null) {
        setState(() {
          _useCamera = false;
          _cameraNote = 'Камера не сообщила выдержку и ISO — измерить не получилось. Оцените свет по окну.';
        });
        return;
      }
      final mean = await _meanLuminance(bytes);
      setState(() => _lux = luxFromExposure(exposure, meanLinear: mean));
    } catch (e) {
      setState(() => _cameraNote = 'Не удалось измерить: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Средняя яркость по уменьшенной копии снимка.
  static Future<double> _meanLuminance(Uint8List jpeg) async {
    final codec = await ui.instantiateImageCodec(jpeg, targetWidth: 48);
    final frame = await codec.getNextFrame();
    final data = await frame.image.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    );
    frame.image.dispose();
    return data == null ? 0.18 : meanLinearLuminance(data.buffer.asUint8List());
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final light = _light;
    final plants = ref.watch(gardenProvider).value?.plants ?? const [];
    final fits = <Plant>[];
    final misfits = <Plant>[];
    for (final plant in plants) {
      final likes = preferredLight(plant.species?.light);
      if (likes.isEmpty) continue;
      (likes.contains(light) ? fits : misfits).add(plant);
    }
    final measured = _useCamera && _lux != null;

    return _ToolScaffold(
      title: 'Люксметр',
      intro: _useCamera
          ? 'Положите белый лист бумаги туда, где стоит растение, и наведите камеру так, чтобы лист занял весь кадр. Не загораживайте свет.'
          : 'Ответьте на три вопроса — Leafy оценит освещённость места.'
                '${kIsWeb ? ' В браузере камера не сообщает выдержку и ISO, поэтому точное измерение доступно в приложении для Android и iPhone.' : ''}',
      children: [
        if (_useCamera) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: AspectRatio(
              aspectRatio: 1,
              child: LiveCamera(
                key: _camera,
                onUnavailable: (m) => setState(() {
                  _useCamera = false;
                  _cameraNote = m;
                }),
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _busy ? null : _measure,
            icon: _busy
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.light_mode_outlined),
            label: Text(_lux == null ? 'Измерить' : 'Измерить ещё раз'),
          ),
          TextButton(
            onPressed: () => setState(() => _useCamera = false),
            child: const Text('Оценить без камеры'),
          ),
        ] else ...[
          if (_cameraNote != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Text(
                _cameraNote!,
                style: TextStyle(fontSize: 14, color: p.alert),
              ),
            ),
          ChoiceGroup<WindowSide>(
            title: 'Куда выходит ближайшее окно',
            values: WindowSide.values,
            selected: _side,
            label: (v) => v.label,
            onChanged: (v) => setState(() => _side = v ?? _side),
          ),
          const SizedBox(height: 18),
          if (_side != WindowSide.none) ...[
            ChoiceGroup<WindowDistance>(
              title: 'Расстояние до окна',
              values: WindowDistance.values,
              selected: _distance,
              label: (v) => v.label,
              onChanged: (v) => setState(() => _distance = v ?? _distance),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('На окне тюль или плёнка'),
              value: _curtain,
              onChanged: (v) => setState(() => _curtain = v),
            ),
          ],
          if (!kIsWeb)
            TextButton(
              onPressed: () => setState(() {
                _useCamera = true;
                _cameraNote = null;
              }),
              child: const Text('Измерить камерой'),
            ),
        ],
        const SizedBox(height: 18),
        if (!_useCamera || measured)
          _ResultCard(
            icon: Icons.wb_sunny,
            color: p.accent,
            title: measured
                ? '≈ ${_formatLux(_lux!)} лк · ${light.label}'
                : light.label,
            text: _lightText(light),
            children: [
              if (fits.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Подойдёт: ${fits.map((e) => e.nickname).join(', ')}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              if (misfits.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  'Не лучшее место для: ${misfits.map((e) => e.nickname).join(', ')}',
                  style: TextStyle(fontSize: 14, color: p.inkSecondary),
                ),
              ],
              if (plants.isNotEmpty) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton(
                    onPressed: () => _saveToPlant(light),
                    child: const Text('Записать в условия растения'),
                  ),
                ),
              ],
            ],
          ),
      ],
    );
  }

  Future<void> _saveToPlant(PlantLight light) async {
    final plants = ref.read(gardenProvider).value?.plants ?? const [];
    final plant = await showModalBottomSheet<Plant>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                'Для какого растения?',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
            ),
            for (final p in plants)
              ListTile(
                leading: PlantImage(p.photoUrl, size: 44, radius: 12),
                title: Text(p.nickname),
                onTap: () => Navigator.pop(ctx, p),
              ),
          ],
        ),
      ),
    );
    if (plant == null) return;
    final c = plant.conditions;
    await ref
        .read(gardenProvider.notifier)
        .updatePlant(
          plant.copyWith(
            conditions: PlantConditions(
              age: c.age,
              light: light,
              pot: c.pot,
              drainage: c.drainage,
              potCm: c.potCm,
            ),
          ),
        );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Свет записан: «${plant.nickname}»')),
      );
    }
  }

  static String _formatLux(double lux) {
    final rounded = lux >= 1000
        ? (lux / 100).round() * 100
        : (lux / 10).round() * 10;
    return rounded.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+$)'),
      (m) => '${m[1]} ',
    );
  }

  static String _lightText(PlantLight l) => switch (l) {
    PlantLight.sun => 'Много прямого солнца. Подходит кактусам, суккулентам, цитрусам, пеларгониям. Нежные листья здесь обгорят.',
    PlantLight.bright => 'Лучшее место для большинства комнатных растений: монстеры, фикусы, калатеи, орхидеи.',
    PlantLight.partial => 'Умеренный свет. Хорошо растут сансевиерия, замиокулькас, драцена, папоротники.',
    PlantLight.shade => 'Света мало. Выдержат аспидистра, сансевиерия, замиокулькас; остальным нужна фитолампа.',
  };
}

// ───────────────────────── Калькулятор полива ─────────────────────────

class WaterCalculatorScreen extends ConsumerStatefulWidget {
  const WaterCalculatorScreen({super.key});

  @override
  ConsumerState<WaterCalculatorScreen> createState() =>
      _WaterCalculatorScreenState();
}

/// Потребность вида во влаге, если растение не выбрано из сада.
enum _Need {
  dry('Засухоустойчивое', 14),
  medium('Умеренный полив', 7),
  wet('Влаголюбивое', 3);

  const _Need(this.label, this.days);
  final String label;
  final int days;
}

class _WaterCalculatorScreenState extends ConsumerState<WaterCalculatorScreen> {
  String? _plantId;
  var _need = _Need.medium;
  var _location = PlantLocation.indoor;
  PlantLight? _light;
  PotType? _pot;
  bool? _drainage = true;
  int? _potCm = 14;

  void _select(Plant? plant) => setState(() {
    _plantId = plant?.id;
    if (plant == null) return;
    final c = plant.conditions;
    _location = plant.location;
    _light = c.light;
    _pot = c.pot;
    _drainage = c.drainage;
    _potCm = c.potCm ?? _potCm;
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final data = ref.watch(gardenProvider).value;
    final plant = _plantId == null ? null : data?.plant(_plantId!);
    final base = plant?.species?.suggestedWateringDays ?? _need.days;
    final conditions = PlantConditions(
      age: plant?.conditions.age,
      light: _light,
      pot: _pot,
      drainage: _drainage,
      potCm: _pot == PotType.ground ? null : _potCm,
    );
    final plan = waterPlan(
      baseDays: base,
      conditions: conditions,
      location: _location,
      date: DateTime.now(),
    );
    final water = plant == null
        ? null
        : data!
              .tasksFor(plant.id)
              .where((t) => t.type == CareType.water)
              .firstOrNull;

    return _ToolScaffold(
      title: 'Калькулятор полива',
      intro:
          'Сколько воды и как часто — по виду, свету, горшку и времени года. '
          'Перед поливом всё равно проверьте пальцем: верхние 2–3 см почвы должны просохнуть.',
      children: [
        _PlantPicker(selected: _plantId, onChanged: _select),
        if (plant == null) ...[
          ChoiceGroup<_Need>(
            title: 'Растение',
            values: _Need.values,
            selected: _need,
            label: (v) => v.label,
            onChanged: (v) => setState(() => _need = v ?? _need),
          ),
          const SizedBox(height: 18),
        ],
        ChoiceGroup<PlantLocation>(
          title: 'Где растёт',
          values: PlantLocation.values,
          selected: _location,
          label: (v) => v.label,
          onChanged: (v) => setState(() => _location = v ?? _location),
        ),
        const SizedBox(height: 18),
        ChoiceGroup<PlantLight>(
          title: 'Свет',
          values: PlantLight.values,
          selected: _light,
          label: (v) => v.label,
          onChanged: (v) => setState(() => _light = v),
        ),
        const SizedBox(height: 18),
        ChoiceGroup<PotType>(
          title: 'Горшок',
          values: PotType.values,
          selected: _pot,
          label: (v) => v.label,
          onChanged: (v) => setState(() => _pot = v),
        ),
        const SizedBox(height: 18),
        if (_pot != PotType.ground) ...[
          ChoiceGroup<bool>(
            title: 'Дренажные отверстия',
            values: const [true, false],
            selected: _drainage,
            label: (v) => v ? 'Есть' : 'Нет',
            onChanged: (v) => setState(() => _drainage = v),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Диаметр горшка',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),
              Text(
                '${_potCm ?? 14} см',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          Slider(
            min: 6,
            max: 40,
            divisions: 34,
            value: (_potCm ?? 14).toDouble(),
            label: '${_potCm ?? 14} см',
            onChanged: (v) => setState(() => _potCm = v.round()),
          ),
        ],
        const SizedBox(height: 12),
        _ResultCard(
          icon: Icons.water_drop,
          color: p.water,
          title: [
            'Раз в ${plan.intervalDays} дн.',
            if (plan.amountMl != null) '${plan.amountMl} мл',
          ].join(' · '),
          text: plan.reasons.join(' · '),
          children: [
            if (water != null && water.intervalDays != plan.intervalDays) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton(
                  onPressed: () async {
                    final garden = ref.read(gardenProvider.notifier);
                    await garden.saveTask(
                      water.withInterval(plan.intervalDays),
                    );
                    await garden.updatePlant(
                      plant.copyWith(conditions: conditions),
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Полив «${plant.nickname}»: ${everyLabel(plan.intervalDays)}',
                          ),
                        ),
                      );
                    }
                  },
                  child: Text('Применить к «${plant!.nickname}»'),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

// ───────────────────────── Пересадка ─────────────────────────

class RepotCheckScreen extends ConsumerStatefulWidget {
  const RepotCheckScreen({super.key});

  @override
  ConsumerState<RepotCheckScreen> createState() => _RepotCheckScreenState();
}

class _RepotCheckScreenState extends ConsumerState<RepotCheckScreen> {
  String? _plantId;
  final _signs = <RepotSign>{};

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final verdict = repotVerdict(_signs, month: DateTime.now().month);
    final data = ref.watch(gardenProvider).value;
    final plant = _plantId == null ? null : data?.plant(_plantId!);
    final color = switch (verdict.urgency) {
      RepotUrgency.rescue => p.alert,
      RepotUrgency.now => p.accent,
      RepotUrgency.soon => p.water,
      RepotUrgency.notYet => p.inkSecondary,
    };
    return _ToolScaffold(
      title: 'Пора ли пересаживать',
      intro: 'Отметьте, что замечаете. Вывод обновляется сразу.',
      children: [
        _PlantPicker(
          selected: _plantId,
          onChanged: (v) => setState(() => _plantId = v?.id),
        ),
        for (final s in RepotSign.values)
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: _signs.contains(s),
            title: Text(
              s.label,
              style: const TextStyle(fontSize: 15, height: 1.35),
            ),
            onChanged: (v) =>
                setState(() => v == true ? _signs.add(s) : _signs.remove(s)),
          ),
        const SizedBox(height: 12),
        _ResultCard(
          icon: verdict.urgency == RepotUrgency.rescue
              ? Icons.warning_amber_rounded
              : Icons.yard,
          color: color,
          title: verdict.title,
          text: verdict.text,
          children: [
            if (verdict.urgency != RepotUrgency.notYet) ...[
              const SizedBox(height: 12),
              for (final tip in repotTips)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    '•  $tip',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.4,
                      color: p.inkSecondary,
                    ),
                  ),
                ),
            ],
            if (plant != null &&
                verdict.urgency.index >= RepotUrgency.now.index) ...[
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton(
                  onPressed: () async {
                    final garden = ref.read(gardenProvider.notifier);
                    final task =
                        data!
                            .tasksFor(plant.id)
                            .where((t) => t.type == CareType.repot)
                            .firstOrNull ??
                        CareTask.create(plant.id, CareType.repot);
                    await garden.completeTask(task);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Пересадка «${plant.nickname}» отмечена, следующая — через год',
                          ),
                        ),
                      );
                    }
                  },
                  child: const Text('Пересадил сегодня'),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
