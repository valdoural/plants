import 'package:flutter/material.dart';

/// Размер окна: телефон, планшет, компьютер (пороги Material 3).
enum WindowSize {
  compact,
  medium,
  expanded;

  static WindowSize of(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    if (w < 600) return compact;
    if (w < 1024) return medium;
    return expanded;
  }

  bool get isCompact => this == compact;
}

extension ResponsiveX on BuildContext {
  WindowSize get windowSize => WindowSize.of(this);

  /// Боковой отступ контента: на телефоне 16, на больших экранах — шире.
  double get gutter => switch (windowSize) {
        WindowSize.compact => 16,
        WindowSize.medium => 24,
        WindowSize.expanded => 32,
      };
}

/// Ограничивает ширину контента и центрирует его — чтобы строки не растягивались на весь монитор.
class MaxWidth extends StatelessWidget {
  const MaxWidth({super.key, required this.child, this.maxWidth = 1200});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(constraints: BoxConstraints(maxWidth: maxWidth), child: child),
    );
  }
}
