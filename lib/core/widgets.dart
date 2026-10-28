import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/models.dart';
import 'theme.dart';
import 'toast.dart';

/// Ширины, под которые запрашиваем и декодируем картинки: немного вариантов — лучше работает кэш.
int _bucket(double px) {
  for (final w in const [160, 320, 480, 720, 1080, 1600]) {
    if (px <= w) return w;
  }
  return 1600;
}

String _resized(String url, int width) =>
    'https://wsrv.nl/?url=${Uri.encodeComponent(url)}&w=$width&we&output=jpg&q=82';

/// data:-фото из хранилища декодируются один раз: те же байты — та же картинка в кэше, без мерцания.
final _dataCache = <String, Uint8List>{};
Uint8List _dataBytes(String uri) {
  final key = '${uri.length}:${uri.hashCode}';
  final hit = _dataCache.remove(key);
  if (hit != null) return _dataCache[key] = hit;
  final bytes = base64Decode(uri.substring(uri.indexOf(',') + 1));
  if (_dataCache.length >= 40) _dataCache.remove(_dataCache.keys.first);
  return _dataCache[key] = bytes;
}

/// Картинка по https:// или data:-ссылке, с заглушкой.
class PlantImage extends StatelessWidget {
  const PlantImage(
    this.url, {
    super.key,
    this.size,
    this.radius = 16,
    this.fit = BoxFit.cover,
  }) : bytes = null;

  const PlantImage.memory(
    Uint8List this.bytes, {
    super.key,
    this.size,
    this.radius = 16,
    this.fit = BoxFit.cover,
  }) : url = null;

  final String? url;
  final Uint8List? bytes;
  final double? size;
  final double radius;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final placeholder = Container(
      width: size,
      height: size,
      color: p.surfaceHigh,
      child: Icon(
        Icons.local_florist_outlined,
        color: p.inkSecondary,
        size: (size ?? 64) * 0.4,
      ),
    );
    final u = url;
    final Widget child;
    if (bytes == null && (u == null || u.isEmpty)) {
      child = placeholder;
    } else {
      child = LayoutBuilder(
        builder: (context, c) {
          // Декодируем под размер на экране, а не в полном разрешении — меньше памяти, плавнее прокрутка.
          final dpr = MediaQuery.devicePixelRatioOf(context);
          final logical =
              size ??
              (c.hasBoundedWidth
                  ? c.maxWidth
                  : (c.hasBoundedHeight ? c.maxHeight : 600));
          final px = _bucket(logical * dpr);
          if (bytes != null || u!.startsWith('data:')) {
            return Image.memory(
              bytes ?? _dataBytes(u!),
              width: size,
              height: size,
              fit: fit,
              cacheWidth: px,
              gaplessPlayback: true,
              errorBuilder: (_, _, _) => placeholder,
            );
          }
          Widget original() => Image.network(
            u,
            width: size,
            height: size,
            fit: fit,
            cacheWidth: px,
            webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
            errorBuilder: (_, _, _) => placeholder,
          );
          if (!kIsWeb) return original();
          // В браузере берём уменьшенную копию с CORS через wsrv.nl: иначе снимки с сайтов без CORS
          // показываются HTML-вставками, и на iPhone прокрутка дёргается. Не загрузилось — оригинал.
          return Image.network(
            _resized(u, px),
            width: size,
            height: size,
            fit: fit,
            gaplessPlayback: true,
            frameBuilder: (_, image, frame, sync) => frame == null && !sync
                ? ColoredBox(
                    color: p.surfaceHigh,
                    child: SizedBox(width: size, height: size),
                  )
                : image,
            errorBuilder: (_, _, _) => original(),
          );
        },
      );
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
      padding: const EdgeInsets.fromLTRB(24, 28, 12, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontSize: 20),
            ),
          ),
          if (action != null)
            TextButton(onPressed: onAction, child: Text(action!)),
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
  });

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
            Icon(icon, size: 48, color: context.palette.inkSecondary),
            const SizedBox(height: 16),
            Text(
              title,
              style: t.textTheme.headlineSmall?.copyWith(fontSize: 22),
              textAlign: TextAlign.center,
            ),
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(
                message!,
                style: t.textTheme.bodyMedium?.copyWith(
                  color: t.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[const SizedBox(height: 20), action!],
          ],
        ),
      ),
    );
  }
}

/// Уверенность распознавания: акцентом, когда уверенно, приглушённо — когда нет.
class ConfidenceBadge extends StatelessWidget {
  const ConfidenceBadge(this.probability, {super.key});

  final double probability;

  @override
  Widget build(BuildContext context) {
    final pct = (probability * 100).clamp(0, 100).round();
    final p = context.palette;
    return Text(
      '$pct%',
      style: TextStyle(
        color: probability >= 0.5 ? p.accent : p.inkSecondary,
        fontWeight: FontWeight.w800,
        fontSize: 16,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
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

/// Цветом выделяется только вода; остальной уход различается подписью и значком.
Color careColor(BuildContext context, CareType type) => type == CareType.water
    ? context.palette.water
    : context.palette.inkSecondary;

String dueLabel(CareTask t) {
  final d = t.daysLeft;
  if (d < 0) return 'просрочено на ${_days(-d)}';
  if (d == 0) return 'сегодня';
  if (d == 1) return 'завтра';
  return 'через ${_days(d)}';
}

String everyLabel(int days) {
  if (days == 1) return 'каждый день';
  if (days % 7 == 0 && days < 60) {
    return 'раз в ${_plural(days ~/ 7, 'неделю', 'недели', 'недель', omitOne: true)}';
  }
  return 'раз в ${_days(days)}';
}

String _days(int n) => _plural(n, 'день', 'дня', 'дней');

String _plural(
  int n,
  String one,
  String few,
  String many, {
  bool omitOne = false,
}) {
  final m10 = n % 10, m100 = n % 100;
  final word = m10 == 1 && m100 != 11
      ? one
      : (m10 >= 2 && m10 <= 4 && (m100 < 12 || m100 > 14))
      ? few
      : many;
  return omitOne && n == 1 ? word : '$n $word';
}

Future<void> openLink(String url) =>
    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

void showError(BuildContext context, Object error) {
  final text = error.toString();
  showToast(
    context,
    text.length > 90 ? 'Что-то пошло не так.' : text,
    kind: ToastKind.error,
    actionLabel: text.length > 90 ? 'Подробнее' : null,
    onAction: () => showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        content: SelectableText(text),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Понятно'),
          ),
        ],
      ),
    ),
  );
}

/// Мягкий отклик на нажатие: элемент чуть уменьшается под пальцем и плавно возвращается.
/// Не перехватывает нажатия (слушает указатель), при «уменьшении движения» в системе — без анимации.
class PressScale extends StatefulWidget {
  const PressScale({super.key, required this.child, this.scale = 0.96});

  final Widget child;
  final double scale;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  var _down = false;

  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return Listener(
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _down && !reduce ? widget.scale : 1,
        duration: Duration(milliseconds: _down ? 110 : 260),
        curve: _down ? Curves.easeOut : Curves.easeOutBack,
        child: widget.child,
      ),
    );
  }
}

/// Диалог с одним полем ввода. Возвращает введённый текст без пробелов по краям или null.
Future<String?> askText(
  BuildContext context,
  String title, {
  String initial = '',
  String? hint,
}) {
  final c = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: c,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(hintText: hint),
        onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, c.text.trim()),
          child: const Text('Сохранить'),
        ),
      ],
    ),
  );
}

/// Заголовок и ряд чипов с одиночным выбором; повторное касание снимает выбор.
class ChoiceGroup<T> extends StatelessWidget {
  const ChoiceGroup({
    super.key,
    required this.title,
    required this.values,
    required this.selected,
    required this.label,
    required this.onChanged,
  });

  final String title;
  final List<T> values;
  final T? selected;
  final String Function(T) label;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final v in values)
            ChoiceChip(
              label: Text(label(v)),
              selected: v == selected,
              onSelected: (on) => onChanged(on ? v : null),
            ),
        ],
      ),
    ],
  );
}

/// Плитка-переход: значок в квадрате, заголовок, подпись, стрелка. Мягко сжимается при нажатии.
class NavTile extends StatelessWidget {
  const NavTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return PressScale(
      child: Material(
        color: p.surface,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: p.surfaceHigh,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: p.accent),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 13, color: p.inkSecondary),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right, color: p.inkSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
