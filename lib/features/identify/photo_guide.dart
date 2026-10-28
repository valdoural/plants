import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// «Как снимать»: примеры удачных и неудачных кадров (рисованные схемы) и короткие советы.
Future<void> showPhotoGuide(BuildContext context) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  builder: (ctx) => DraggableScrollableSheet(
    expand: false,
    initialChildSize: 0.8,
    maxChildSize: 0.95,
    builder: (ctx, scroll) => ListView(
      controller: scroll,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: const [
        Text(
          'Как сделать хорошее фото',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
        SizedBox(height: 14),
        _Grid(good: true),
        SizedBox(height: 18),
        _Grid(good: false),
        SizedBox(height: 18),
        _Tip(
          'Несколько ракурсов',
          'До трёх фото одного растения: лист, цветок, всё растение. Точность заметно растёт.',
        ),
        _Tip(
          'Мягкий свет',
          'Днём у окна, без резких теней и бликов от вспышки.',
        ),
        _Tip(
          'Обрежьте лишнее',
          'После съёмки нажмите значок кадрирования, чтобы оставить в кадре только растение.',
        ),
      ],
    ),
  ),
);

class _Tip extends StatelessWidget {
  const _Tip(this.title, this.text);

  final String title;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 2),
        Text(
          text,
          style: TextStyle(
            fontSize: 15,
            height: 1.4,
            color: context.palette.inkSecondary,
          ),
        ),
      ],
    ),
  );
}

enum _Example {
  leaf('Лист крупно', true),
  flower('Цветок крупно', true),
  whole('Растение целиком', true),
  far('Слишком далеко', false),
  blur('Размыто', false),
  many('Несколько растений', false);

  const _Example(this.label, this.good);
  final String label;
  final bool good;
}

class _Grid extends StatelessWidget {
  const _Grid({required this.good});

  final bool good;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final items = _Example.values.where((e) => e.good == good).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          good ? 'Так хорошо' : 'Так хуже',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: good ? p.accent : p.alert,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final (i, e) in items.indexed) ...[
              if (i > 0) const SizedBox(width: 10),
              Expanded(child: _Card(example: e)),
            ],
          ],
        ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.example});

  final _Example example;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    Widget plant(IconData icon, double size) =>
        Icon(icon, size: size, color: p.accent);
    final art = switch (example) {
      _Example.leaf => plant(Icons.eco, 64),
      _Example.flower => plant(Icons.local_florist, 64),
      _Example.whole => plant(Icons.park, 64),
      _Example.far => plant(Icons.local_florist, 18),
      _Example.blur => ImageFiltered(
        imageFilter: ui.ImageFilter.blur(sigmaX: 4, sigmaY: 4),
        child: plant(Icons.local_florist, 56),
      ),
      _Example.many => Wrap(
        alignment: WrapAlignment.center,
        children: [
          plant(Icons.eco, 26),
          plant(Icons.local_florist, 26),
          plant(Icons.grass, 26),
          plant(Icons.spa, 26),
        ],
      ),
    };
    return Column(
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: Container(
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Stack(
              children: [
                Center(child: art),
                Positioned(
                  right: 6,
                  top: 6,
                  child: Icon(
                    example.good ? Icons.check_circle : Icons.cancel,
                    size: 20,
                    color: example.good ? p.accent : p.alert,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          example.label,
          textAlign: TextAlign.center,
          maxLines: 2,
          style: const TextStyle(
            fontSize: 13,
            height: 1.25,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
