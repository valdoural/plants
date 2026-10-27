import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'theme.dart';

/// Знак Leafy «Живой лист»: изогнутый лист с прожилками в уголках видоискателя.
/// Геометрия — в координатах 100×100, как в SVG логотипа (assets/icon, холст дизайна).
abstract final class LeafyGeometry {
  static Path leaf() => Path()
    ..moveTo(33, 69)
    ..cubicTo(27, 55, 32, 40, 45, 32)
    ..cubicTo(54, 26.5, 64, 25, 74, 24.5)
    ..cubicTo(73.5, 35, 69.5, 47, 61, 56)
    ..cubicTo(52.5, 65, 43, 69.5, 33, 69)
    ..close();

  static Path midrib() => Path()
    ..moveTo(34, 68)
    ..cubicTo(42, 58, 54, 43, 71, 27.5);

  static Path veins() => Path()
    ..moveTo(41, 59)
    ..cubicTo(38, 56, 36.5, 52, 36.5, 48)
    ..moveTo(47, 52)
    ..cubicTo(44, 48.5, 42.5, 44.5, 43, 40.5)
    ..moveTo(53, 45.5)
    ..cubicTo(51, 42, 50.5, 38, 51.5, 34.5)
    ..moveTo(45, 56)
    ..cubicTo(49, 57.5, 53, 57.5, 57, 56)
    ..moveTo(51, 49)
    ..cubicTo(55, 50, 59, 49.5, 62.5, 47.5)
    ..moveTo(57.5, 41.5)
    ..cubicTo(61, 42, 64.5, 41, 67, 39);

  static Path petiole() => Path()
    ..moveTo(33.5, 68.5)
    ..cubicTo(30.5, 72.5, 27.5, 75, 23.5, 76.5);

  /// Четыре уголка рамки, каждый — от края к углу и дальше по другой стороне.
  static List<Path> corners() => [
    Path()
      ..moveTo(12, 30)
      ..lineTo(12, 19)
      ..quadraticBezierTo(12, 12, 19, 12)
      ..lineTo(30, 12),
    Path()
      ..moveTo(70, 12)
      ..lineTo(81, 12)
      ..quadraticBezierTo(88, 12, 88, 19)
      ..lineTo(88, 30),
    Path()
      ..moveTo(88, 70)
      ..lineTo(88, 81)
      ..quadraticBezierTo(88, 88, 81, 88)
      ..lineTo(70, 88),
    Path()
      ..moveTo(30, 88)
      ..lineTo(19, 88)
      ..quadraticBezierTo(12, 88, 12, 81)
      ..lineTo(12, 70),
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

  /// Цвет прожилок — цвет фона под знаком.
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
        ..strokeWidth = 3.2
        ..strokeCap = StrokeCap.round;
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
      // Лист растёт от черешка.
      canvas.translate(33, 69);
      canvas.scale(leaf);
      canvas.translate(-33, -69);
      canvas.drawPath(LeafyGeometry.leaf(), Paint()..color = color);
      canvas.drawPath(
        LeafyGeometry.petiole(),
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4
          ..strokeCap = StrokeCap.round,
      );
      if (veins) {
        final vein = Paint()
          ..color = cutout
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;
        canvas.drawPath(LeafyGeometry.midrib(), vein..strokeWidth = 1.7);
        canvas.drawPath(LeafyGeometry.veins(), vein..strokeWidth = 1.05);
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
        veins: size >= 28,
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
