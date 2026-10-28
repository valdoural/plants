import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'responsive.dart';
import 'theme.dart';
import 'widgets.dart';

/// Полноэкранный просмотр фото: листание, увеличение щипком и двойным касанием,
/// стрелки и клавиши ← → на компьютере, лента миниатюр.
Future<void> showPhotoViewer(
  BuildContext context,
  List<String> urls, {
  int initial = 0,
  String? caption,
}) {
  if (urls.isEmpty) return Future.value();
  return Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierColor: Colors.black,
      transitionDuration: const Duration(milliseconds: 220),
      reverseTransitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (_, _, _) =>
          _Viewer(urls: urls, initial: initial, caption: caption),
      transitionsBuilder: (_, a, _, child) => FadeTransition(
        opacity: a,
        child: ScaleTransition(
          scale: Tween(
            begin: 0.96,
            end: 1.0,
          ).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
          child: child,
        ),
      ),
    ),
  );
}

class _Viewer extends StatefulWidget {
  const _Viewer({required this.urls, required this.initial, this.caption});

  final List<String> urls;
  final int initial;
  final String? caption;

  @override
  State<_Viewer> createState() => _ViewerState();
}

class _ViewerState extends State<_Viewer> {
  late final _pages = PageController(initialPage: widget.initial);
  late int _index = widget.initial;
  final _zoom = <int, TransformationController>{};
  var _zoomed = false;

  TransformationController _ctrl(int i) =>
      _zoom.putIfAbsent(i, TransformationController.new);

  void _go(int delta) {
    final next = (_index + delta).clamp(0, widget.urls.length - 1);
    if (next == _index) return;
    _pages.animateToPage(
      next,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  void _toggleZoom(int i, Offset at) {
    final c = _ctrl(i);
    final zoomed = c.value.getMaxScaleOnAxis() > 1.01;
    c.value = zoomed
        ? Matrix4.identity()
        : (Matrix4.identity()
            ..translateByDouble(-at.dx * 1.5, -at.dy * 1.5, 0, 1)
            ..scaleByDouble(2.5, 2.5, 1, 1));
    setState(() => _zoomed = !zoomed);
  }

  @override
  void dispose() {
    _pages.dispose();
    for (final c in _zoom.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wide = kIsWeb || !context.windowSize.isCompact;
    final many = widget.urls.length > 1;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () => _go(-1),
        const SingleActivator(LogicalKeyboardKey.arrowRight): () => _go(1),
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.pop(context),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              PageView.builder(
                controller: _pages,
                physics: _zoomed ? const NeverScrollableScrollPhysics() : null,
                itemCount: widget.urls.length,
                onPageChanged: (i) => setState(() {
                  _index = i;
                  _zoomed = false;
                  for (final c in _zoom.values) {
                    c.value = Matrix4.identity();
                  }
                }),
                itemBuilder: (_, i) {
                  Offset tap = Offset.zero;
                  return GestureDetector(
                    onDoubleTapDown: (d) => tap = d.localPosition,
                    onDoubleTap: () => _toggleZoom(i, tap),
                    child: InteractiveViewer(
                      transformationController: _ctrl(i),
                      maxScale: 5,
                      onInteractionEnd: (_) => setState(
                        () =>
                            _zoomed = _ctrl(i).value.getMaxScaleOnAxis() > 1.01,
                      ),
                      child: Center(
                        child: PlantImage(
                          widget.urls[i],
                          radius: 0,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  );
                },
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    children: [
                      IconButton.filled(
                        tooltip: 'Закрыть',
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black54,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                      const Spacer(),
                      if (many)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            '${_index + 1} / ${widget.urls.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (wide && many) ...[
                _Arrow(left: true, enabled: _index > 0, onTap: () => _go(-1)),
                _Arrow(
                  left: false,
                  enabled: _index < widget.urls.length - 1,
                  onTap: () => _go(1),
                ),
              ],
              if (many)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: SafeArea(
                    top: false,
                    child: SizedBox(
                      height: 72,
                      child: Center(
                        child: ListView.separated(
                          shrinkWrap: true,
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          itemCount: widget.urls.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 6),
                          itemBuilder: (_, i) => GestureDetector(
                            onTap: () => _pages.animateToPage(
                              i,
                              duration: const Duration(milliseconds: 280),
                              curve: Curves.easeOutCubic,
                            ),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              width: 52,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: i == _index
                                      ? Colors.white
                                      : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                              child: Opacity(
                                opacity: i == _index ? 1 : 0.6,
                                child: PlantImage(widget.urls[i], radius: 8),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Arrow extends StatelessWidget {
  const _Arrow({
    required this.left,
    required this.enabled,
    required this.onTap,
  });

  final bool left;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Positioned(
    left: left ? 12 : null,
    right: left ? null : 12,
    top: 0,
    bottom: 0,
    child: Center(
      child: AnimatedOpacity(
        opacity: enabled ? 1 : 0.25,
        duration: const Duration(milliseconds: 150),
        child: IconButton.filled(
          iconSize: 30,
          style: IconButton.styleFrom(
            backgroundColor: Colors.black54,
            foregroundColor: Colors.white,
            minimumSize: const Size(52, 52),
          ),
          tooltip: left ? 'Предыдущее' : 'Следующее',
          onPressed: enabled ? onTap : null,
          icon: Icon(left ? Icons.chevron_left : Icons.chevron_right),
        ),
      ),
    ),
  );
}

/// Лента фото: на телефоне листается пальцем, в браузере и на компьютере — стрелками по бокам.
/// Касание открывает полноэкранный просмотр.
class PhotoStrip extends StatefulWidget {
  const PhotoStrip({
    super.key,
    required this.urls,
    this.height = 112,
    this.aspect = 1,
  });

  final List<String> urls;
  final double height;

  /// Ширина плитки к высоте.
  final double aspect;

  @override
  State<PhotoStrip> createState() => _PhotoStripState();
}

class _PhotoStripState extends State<PhotoStrip> {
  final _scroll = ScrollController();
  var _atStart = true;
  var _atEnd = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_update);
    WidgetsBinding.instance.addPostFrameCallback((_) => _update());
  }

  void _update() {
    if (!_scroll.hasClients) return;
    final p = _scroll.position;
    final start = p.pixels <= 1;
    final end = p.pixels >= p.maxScrollExtent - 1;
    if (start != _atStart || end != _atEnd) {
      setState(() {
        _atStart = start;
        _atEnd = end;
      });
    }
  }

  void _page(int dir) {
    final p = _scroll.position;
    _scroll.animateTo(
      (p.pixels + dir * p.viewportDimension * 0.8).clamp(0, p.maxScrollExtent),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final arrows = kIsWeb || !context.windowSize.isCompact;
    final w = widget.height * widget.aspect;
    return SizedBox(
      height: widget.height,
      child: Stack(
        children: [
          ListView.separated(
            controller: _scroll,
            scrollDirection: Axis.horizontal,
            itemCount: widget.urls.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (_, i) => SizedBox(
              width: w,
              child: PressScale(
                child: GestureDetector(
                  onTap: () =>
                      showPhotoViewer(context, widget.urls, initial: i),
                  child: PlantImage(widget.urls[i], radius: 14),
                ),
              ),
            ),
          ),
          if (arrows) ...[
            for (final left in [true, false])
              if (left ? !_atStart : !_atEnd)
                Positioned(
                  left: left ? 4 : null,
                  right: left ? null : 4,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: IconButton.filled(
                      style: IconButton.styleFrom(
                        backgroundColor: p.bg.withValues(alpha: 0.85),
                        foregroundColor: p.ink,
                      ),
                      tooltip: left ? 'Назад' : 'Вперёд',
                      onPressed: () => _page(left ? -1 : 1),
                      icon: Icon(
                        left ? Icons.chevron_left : Icons.chevron_right,
                      ),
                    ),
                  ),
                ),
          ],
        ],
      ),
    );
  }
}
