import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'theme.dart';

enum ToastKind { info, error, warning }

OverlayEntry? _current;

/// Короткое всплывающее сообщение сверху: впрыгивает с отскоком, через несколько секунд уезжает.
/// Касание — закрыть сразу, смахнуть вверх — тоже; [actionLabel] — одна кнопка действия.
void showToast(
  BuildContext context,
  String message, {
  ToastKind kind = ToastKind.info,
  String? actionLabel,
  VoidCallback? onAction,
  Duration duration = const Duration(milliseconds: 3600),
}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  _current?.remove();
  _current = null;
  if (kind == ToastKind.error) HapticFeedback.mediumImpact();
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _Toast(
      message: message,
      kind: kind,
      actionLabel: actionLabel,
      onAction: onAction,
      duration: duration,
      onGone: () {
        if (_current == entry) _current = null;
        if (entry.mounted) entry.remove();
      },
    ),
  );
  _current = entry;
  overlay.insert(entry);
}

class _Toast extends StatefulWidget {
  const _Toast({
    required this.message,
    required this.kind,
    required this.duration,
    required this.onGone,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final ToastKind kind;
  final Duration duration;
  final VoidCallback onGone;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  State<_Toast> createState() => _ToastState();
}

class _ToastState extends State<_Toast> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
    reverseDuration: const Duration(milliseconds: 320),
  );
  Timer? _timer;
  var _drag = 0.0;

  @override
  void initState() {
    super.initState();
    _c.forward();
    _timer = Timer(widget.duration, _hide);
  }

  Future<void> _hide() async {
    _timer?.cancel();
    if (!mounted) return;
    await _c.reverse();
    widget.onGone();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final (icon, color) = switch (widget.kind) {
      ToastKind.error => (Icons.error_outline, p.alert),
      ToastKind.warning => (Icons.hourglass_bottom, p.alert),
      ToastKind.info => (Icons.check_circle_outline, p.accent),
    };
    return Positioned(
      left: 12,
      right: 12,
      top: MediaQuery.paddingOf(context).top + 8,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: AnimatedBuilder(
            animation: _c,
            builder: (context, child) {
              final forward = _c.status != AnimationStatus.reverse;
              final t = reduce
                  ? _c.value
                  : (forward ? Curves.elasticOut : Curves.easeInBack).transform(
                      _c.value,
                    );
              // Въезд сверху с отскоком; при уходе — подпрыгивает и уезжает вверх.
              return Opacity(
                opacity: _c.value.clamp(0.0, 1.0),
                child: Transform.translate(
                  offset: Offset(0, (1 - t) * -90 + _drag),
                  child: Transform.scale(
                    scale: reduce ? 1 : 0.9 + 0.1 * t.clamp(0.0, 1.2),
                    child: child,
                  ),
                ),
              );
            },
            child: GestureDetector(
              onTap: _hide,
              onVerticalDragUpdate: (d) => setState(
                () => _drag = (_drag + d.delta.dy).clamp(-80.0, 12.0),
              ),
              onVerticalDragEnd: (_) =>
                  _drag < -24 ? _hide() : setState(() => _drag = 0),
              child: Material(
                color: p.surfaceHigh,
                elevation: 6,
                shadowColor: Colors.black45,
                borderRadius: BorderRadius.circular(18),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                  child: Row(
                    children: [
                      Icon(icon, color: color, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          widget.message,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            height: 1.3,
                            fontWeight: FontWeight.w600,
                            color: p.ink,
                          ),
                        ),
                      ),
                      if (widget.actionLabel != null)
                        TextButton(
                          onPressed: () {
                            _hide();
                            widget.onAction?.call();
                          },
                          child: Text(widget.actionLabel!),
                        )
                      else
                        const SizedBox(width: 6),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
