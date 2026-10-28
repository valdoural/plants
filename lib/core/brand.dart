import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'theme.dart';

/// Знак Leafy: лист в уголках видоискателя (идея 1 с холста логотипов).
/// Геометрия — в координатах 100×100, как в SVG логотипа (assets/icon, холст дизайна).
abstract final class LeafyGeometry {
  static Path leaf() => Path()
    ..moveTo(30, 70)
    ..cubicTo(30, 46, 46, 30, 70, 30)
    ..cubicTo(70, 54, 54, 70, 30, 70)
    ..close();

  static Path midrib() => Path()
    ..moveTo(33, 67)
    ..lineTo(64, 36);

  /// Четыре прямых уголка рамки, каждый — от края к углу и дальше по другой стороне.
  static List<Path> corners() => [
    Path()
      ..moveTo(12, 28)
      ..lineTo(12, 12)
      ..lineTo(28, 12),
    Path()
      ..moveTo(72, 12)
      ..lineTo(88, 12)
      ..lineTo(88, 28),
    Path()
      ..moveTo(88, 72)
      ..lineTo(88, 88)
      ..lineTo(72, 88),
    Path()
      ..moveTo(28, 88)
      ..lineTo(12, 88)
      ..lineTo(12, 72),
  ];
}

/// Рисует знак. [frame] — насколько прорисованы уголки (0…1), [leaf] — масштаб листа (0…1+).
class LeafyMarkPainter extends CustomPainter {
  LeafyMarkPainter({
    required this.color,
    required this.cutout,
    this.frame = 1,
    this.leaf = 1,
    this.veins = true,
  });

  final Color color;

  /// Цвет жилки — цвет фона под знаком.
  final Color cutout;
  final double frame;
  final double leaf;
  final bool veins;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide / 100;
    canvas.save();
    canvas.translate((size.width - 100 * s) / 2, (size.height - 100 * s) / 2);
    canvas.scale(s);

    if (frame > 0) {
      final stroke = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      for (final c in LeafyGeometry.corners()) {
        for (final m in c.computeMetrics()) {
          // Уголок вырастает из своей вершины в обе стороны.
          final mid = m.length / 2;
          final half = mid * frame.clamp(0, 1);
          canvas.drawPath(m.extractPath(mid - half, mid + half), stroke);
        }
      }
    }

    if (leaf > 0) {
      canvas.save();
      // Лист растёт от основания.
      canvas.translate(30, 70);
      canvas.scale(leaf);
      canvas.translate(-30, -70);
      canvas.drawPath(LeafyGeometry.leaf(), Paint()..color = color);
      if (veins) {
        canvas.drawPath(
          LeafyGeometry.midrib(),
          Paint()
            ..color = cutout
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.6
            ..strokeCap = StrokeCap.round,
        );
      }
      canvas.restore();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(LeafyMarkPainter old) =>
      old.frame != frame ||
      old.leaf != leaf ||
      old.color != color ||
      old.cutout != cutout ||
      old.veins != veins;
}

/// Знак Leafy заданного размера в цветах темы.
class LeafyMark extends StatelessWidget {
  const LeafyMark({super.key, this.size = 40, this.color, this.background});

  final double size;
  final Color? color;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return CustomPaint(
      size: Size.square(size),
      painter: LeafyMarkPainter(
        color: color ?? p.accent,
        cutout: background ?? p.bg,
        veins: size >= 20,
      ),
    );
  }
}

/// Заставка при запуске: листья кружат, слетаются к центру и становятся знаком Leafy,
/// уголки рамки прорисовываются, появляется надпись. Касание — пропустить.
class IntroSplash extends StatefulWidget {
  const IntroSplash({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  State<IntroSplash> createState() => _IntroSplashState();
}

class _IntroSplashState extends State<IntroSplash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  var _finished = false;

  static const _total = Duration(milliseconds: 2700);

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: _total)
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) _finish();
      });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
      if (reduce) {
        // Без движения: показываем знак и спокойно растворяем.
        _c.value = 0.78;
        _c.animateTo(1, duration: const Duration(milliseconds: 700));
      } else {
        _c.forward();
      }
    });
  }

  void _finish() {
    if (_finished) return;
    _finished = true;
    widget.onDone();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  /// Доля [t] внутри отрезка [a, b], 0…1.
  static double _seg(double t, double a, double b) =>
      ((t - a) / (b - a)).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _finish,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = _c.value;
          final fadeOut = 1 - Curves.easeIn.transform(_seg(t, 0.84, 1));
          final swirl = _seg(t, 0, 0.55); // листья кружат и слетаются
          final grow = Curves.easeOutBack.transform(
            _seg(t, 0.42, 0.66),
          ); // главный лист
          final frame = Curves.easeOutCubic.transform(
            _seg(t, 0.55, 0.78),
          ); // уголки
          final word = Curves.easeOutCubic.transform(
            _seg(t, 0.64, 0.84),
          ); // надпись
          return Opacity(
            opacity: fadeOut,
            child: Material(
              color: p.bg,
              child: LayoutBuilder(
                builder: (context, box) {
                  final markSize = math.min(box.maxWidth, box.maxHeight) * 0.42;
                  final center = Offset(
                    box.maxWidth / 2,
                    box.maxHeight / 2 - markSize * 0.12,
                  );
                  return Stack(
                    children: [
                      // Кружащие листья.
                      if (swirl < 1)
                        for (var i = 0; i < 9; i++)
                          _orbitLeaf(i, swirl, center, markSize, p),
                      Positioned(
                        left: center.dx - markSize / 2,
                        top: center.dy - markSize / 2,
                        child: CustomPaint(
                          size: Size.square(markSize),
                          painter: LeafyMarkPainter(
                            color: p.accent,
                            cutout: p.bg,
                            frame: frame,
                            leaf: grow,
                          ),
                        ),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        top: center.dy + markSize / 2 + 18 - 16 * (1 - word),
                        child: Opacity(
                          opacity: word,
                          child: Text(
                            'Leafy',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: (markSize * 0.26).clamp(30, 56),
                              fontWeight: FontWeight.w800,
                              letterSpacing: -1.2,
                              color: p.ink,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }

  /// Один кружащий лист: по спирали к центру, сам вращается, у центра растворяется.
  Widget _orbitLeaf(
    int i,
    double t,
    Offset center,
    double markSize,
    LeafyPalette p,
  ) {
    final ease = Curves.easeInOutCubic.transform(t);
    final start = i * 2 * math.pi / 9 + (i.isEven ? 0.3 : -0.2);
    final angle = start + ease * math.pi * 1.6;
    final radius = markSize * (1.25 + (i % 3) * 0.18) * (1 - ease);
    final size = markSize * (0.26 + (i % 3) * 0.05);
    final pos = center + Offset(math.cos(angle), math.sin(angle)) * radius;
    final opacity = (_seg(t, 0, 0.12) * (1 - _seg(t, 0.75, 1))).clamp(0.0, 1.0);
    return Positioned(
      left: pos.dx - size / 2,
      top: pos.dy - size / 2,
      child: Opacity(
        opacity: opacity * (i.isEven ? 0.95 : 0.6),
        child: Transform.rotate(
          angle: angle * 1.4 + i,
          child: CustomPaint(
            size: Size.square(size),
            painter: LeafyMarkPainter(
              color: p.accent,
              cutout: p.bg,
              frame: 0,
              veins: false,
            ),
          ),
        ),
      ),
    );
  }
}
