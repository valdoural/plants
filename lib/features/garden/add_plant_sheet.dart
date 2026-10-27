import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/notifications.dart';
import '../../core/photo_picker.dart';
import '../../core/settings.dart';
import '../../core/widgets.dart';
import '../../data/garden_controller.dart';
import '../../data/models.dart';

/// Нижний лист «Добавить растение»: имя, место, расписание ухода.
Future<Plant?> showAddPlantSheet(
  BuildContext context,
  WidgetRef ref, {
  PlantCandidate? species,
  Uint8List? photo,
}) {
  return showModalBottomSheet<Plant>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _AddPlantSheet(species: species, photo: photo),
  );
}

class _AddPlantSheet extends ConsumerStatefulWidget {
  const _AddPlantSheet({this.species, this.photo});

  final PlantCandidate? species;
  final Uint8List? photo;

  @override
  ConsumerState<_AddPlantSheet> createState() => _AddPlantSheetState();
}

class _AddPlantSheetState extends ConsumerState<_AddPlantSheet> {
  late final _name = TextEditingController(
    text: widget.species?.displayName ?? '',
  );
  late Uint8List? _photo = widget.photo;
  var _location = PlantLocation.indoor;
  late final Map<CareType, int> _care = {
    CareType.water:
        widget.species?.suggestedWateringDays ??
        CareType.water.defaultIntervalDays,
    CareType.fertilize: CareType.fertilize.defaultIntervalDays,
  };
  var _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      final plant = await ref
          .read(gardenProvider.notifier)
          .addPlant(
            nickname: _name.text.trim(),
            species: widget.species,
            photo: _photo,
            location: _location,
            care: _care,
          );
      // Первое растение — подходящий момент спросить разрешение на напоминания.
      if (ref.read(settingsProvider).notificationsEnabled) {
        unawaited(ReminderNotifications.instance.requestPermission());
      }
      if (mounted) Navigator.pop(context, plant);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        showError(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Новое растение',
              style: t.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                GestureDetector(
                  onTap: () async {
                    final p = await pickPhotoWithSheet(context, maxSide: 900);
                    if (p != null) setState(() => _photo = p);
                  },
                  child: SizedBox(
                    width: 80,
                    height: 80,
                    child: _photo != null
                        ? PlantImage.memory(_photo!)
                        : Stack(
                            fit: StackFit.expand,
                            children: [
                              PlantImage(widget.species?.imageUrls.firstOrNull),
                              const Align(
                                alignment: Alignment.bottomRight,
                                child: CircleAvatar(
                                  radius: 14,
                                  child: Icon(Icons.photo_camera, size: 16),
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _name,
                    autofocus: widget.species == null,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Как назовём?',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text('Где растёт', style: t.textTheme.titleSmall),
            const SizedBox(height: 8),
            SegmentedButton<PlantLocation>(
              segments: [
                for (final l in PlantLocation.values)
                  ButtonSegment(value: l, label: Text(l.label)),
              ],
              selected: {_location},
              onSelectionChanged: (s) => setState(() => _location = s.first),
            ),
            const SizedBox(height: 20),
            Text('Напоминания', style: t.textTheme.titleSmall),
            const SizedBox(height: 4),
            for (final type in [
              CareType.water,
              CareType.fertilize,
              CareType.mist,
              CareType.repot,
            ])
              _CareRow(
                type: type,
                days: _care[type],
                onChanged: (v) => setState(
                  () => v == null ? _care.remove(type) : _care[type] = v,
                ),
              ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Добавить в сад'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CareRow extends StatelessWidget {
  const _CareRow({
    required this.type,
    required this.days,
    required this.onChanged,
  });

  final CareType type;
  final int? days;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    final on = days != null;
    return Row(
      children: [
        Icon(careIcon(type), color: careColor(context, type)),
        const SizedBox(width: 12),
        Expanded(child: Text(type.label)),
        if (on) IntervalStepper(days: days!, onChanged: onChanged),
        Switch(
          value: on,
          onChanged: (v) => onChanged(v ? type.defaultIntervalDays : null),
        ),
      ],
    );
  }
}

/// «− 7 дн. +» для интервала ухода.
class IntervalStepper extends StatelessWidget {
  const IntervalStepper({
    super.key,
    required this.days,
    required this.onChanged,
  });

  final int days;
  final ValueChanged<int> onChanged;

  int _step(int d) => d < 14
      ? 1
      : d < 60
      ? 7
      : 30;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          visualDensity: VisualDensity.compact,
          onPressed: days > 1
              ? () => onChanged((days - _step(days - 1)).clamp(1, 730))
              : null,
          icon: const Icon(Icons.remove_circle_outline),
        ),
        SizedBox(
          width: 52,
          child: Text('$days дн.', textAlign: TextAlign.center),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          onPressed: () => onChanged((days + _step(days)).clamp(1, 730)),
          icon: const Icon(Icons.add_circle_outline),
        ),
      ],
    );
  }
}
