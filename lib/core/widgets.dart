import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/models.dart';
import 'theme.dart';

/// Картинка по https:// или data:-ссылке, с заглушкой.
class PlantImage extends StatelessWidget {
  const PlantImage(this.url, {super.key, this.size, this.radius = 16, this.fit = BoxFit.cover}) : bytes = null;

  const PlantImage.memory(Uint8List this.bytes, {super.key, this.size, this.radius = 16, this.fit = BoxFit.cover})
      : url = null;

  final String? url;
  final Uint8List? bytes;
  final double? size;
  final double radius;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      width: size,
      height: size,
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Icon(Icons.local_florist, color: Theme.of(context).colorScheme.primary, size: (size ?? 64) * 0.45),
    );
    final u = url;
    Widget child;
    if (bytes != null) {
      child = Image.memory(bytes!, width: size, height: size, fit: fit, gaplessPlayback: true);
    } else if (u == null || u.isEmpty) {
      child = placeholder;
    } else if (u.startsWith('data:')) {
      child = Image.memory(base64Decode(u.substring(u.indexOf(',') + 1)),
          width: size, height: size, fit: fit, gaplessPlayback: true);
    } else {
      child = Image.network(u, width: size, height: size, fit: fit, errorBuilder: (_, _, _) => placeholder);
    }
    return ClipRRect(borderRadius: BorderRadius.circular(radius), child: child);
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.action, this.onAction});

  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 12, 8),
      child: Row(
        children: [
          Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700))),
          if (action != null) TextButton(onPressed: onAction, child: Text(action!)),
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, this.message, this.action});

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: t.colorScheme.primaryContainer,
              child: Icon(icon, size: 40, color: t.colorScheme.primary),
            ),
            const SizedBox(height: 16),
            Text(title, style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700), textAlign: TextAlign.center),
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(message!, style: t.textTheme.bodyMedium?.copyWith(color: t.colorScheme.onSurfaceVariant), textAlign: TextAlign.center),
            ],
            if (action != null) ...[const SizedBox(height: 20), action!],
          ],
        ),
      ),
    );
  }
}

/// Плашка уверенности распознавания: зелёная/жёлтая/оранжевая.
class ConfidenceBadge extends StatelessWidget {
  const ConfidenceBadge(this.probability, {super.key});

  final double probability;

  @override
  Widget build(BuildContext context) {
    final pct = (probability * 100).clamp(0, 100).round();
    final color = probability >= 0.7
        ? LeafyColors.forest
        : probability >= 0.3
            ? const Color(0xFFB8860B)
            : LeafyColors.terracotta;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Text('$pct%', style: TextStyle(color: color, fontWeight: FontWeight.w700)),
    );
  }
}

IconData careIcon(CareType type) => switch (type) {
      CareType.water => Icons.water_drop,
      CareType.fertilize => Icons.science,
      CareType.mist => Icons.shower,
      CareType.repot => Icons.yard,
      CareType.prune => Icons.content_cut,
      CareType.rotate => Icons.wb_sunny,
    };

Color careColor(CareType type) => switch (type) {
      CareType.water => LeafyColors.water,
      CareType.fertilize => LeafyColors.moss,
      CareType.mist => const Color(0xFF5BA4A4),
      CareType.repot => LeafyColors.terracotta,
      CareType.prune => const Color(0xFF7A6A9C),
      CareType.rotate => const Color(0xFFD4A017),
    };

String dueLabel(CareTask t) {
  final d = t.daysLeft;
  if (d < 0) return 'просрочено на ${_days(-d)}';
  if (d == 0) return 'сегодня';
  if (d == 1) return 'завтра';
  return 'через ${_days(d)}';
}

String everyLabel(int days) {
  if (days == 1) return 'каждый день';
  if (days % 7 == 0 && days < 60) return 'раз в ${_plural(days ~/ 7, 'неделю', 'недели', 'недель', omitOne: true)}';
  return 'раз в ${_days(days)}';
}

String _days(int n) => _plural(n, 'день', 'дня', 'дней');

String _plural(int n, String one, String few, String many, {bool omitOne = false}) {
  final m10 = n % 10, m100 = n % 100;
  final word = m10 == 1 && m100 != 11
      ? one
      : (m10 >= 2 && m10 <= 4 && (m100 < 12 || m100 > 14))
          ? few
          : many;
  return omitOne && n == 1 ? word : '$n $word';
}

Future<void> openLink(String url) => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

void showError(BuildContext context, Object error) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString()), behavior: SnackBarBehavior.floating));
}
