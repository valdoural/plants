import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/notifications.dart';
import '../../core/settings.dart';
import '../../data/recognition/quota.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/garden_controller.dart';

/// Настройки: выбор сервиса распознавания с подсказками, ключи, язык, Supabase.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final ctrl = ref.read(settingsProvider.notifier);
    final supabaseReady = ref.watch(supabaseReadyProvider);
    final t = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Настройки')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
        children: [
          const SectionHeader('Сервис распознавания'),
          for (final p in RecognitionProviderId.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: ProviderCard(
                provider: p,
                selected: s.provider == p,
                apiKey: p == RecognitionProviderId.plantId
                    ? s.plantIdKey
                    : s.plantNetKey,
                onSelect: () => ctrl.update((x) => x.copyWith(provider: p)),
                onKeyChanged: (k) => ctrl.update(
                  (x) => p == RecognitionProviderId.plantId
                      ? x.copyWith(plantIdKey: k.trim())
                      : x.copyWith(plantNetKey: k.trim()),
                ),
              ),
            ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.lightbulb_outline),
              title: const Text('Что выбрать?'),
              subtitle: const Text(
                'Для личного сада удобно так: Pl@ntNet — основной (бесплатно), а ключ Plant.id добавить '
                'для диагностики болезней и советов по уходу. Сервис можно переключать прямо на экране камеры.',
              ),
            ),
          ),
          const SectionHeader('Оформление'),
          SegmentedButton<ThemeMode>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: ThemeMode.system,
                label: Text('Как в системе'),
              ),
              ButtonSegment(value: ThemeMode.light, label: Text('Светлая')),
              ButtonSegment(value: ThemeMode.dark, label: Text('Тёмная')),
            ],
            selected: {s.themeMode},
            onSelectionChanged: (v) =>
                ctrl.update((x) => x.copyWith(themeMode: v.first)),
          ),
          const SectionHeader('Уведомления'),
          const _NotificationsCard(),
          const SectionHeader('Язык результатов'),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'ru', label: Text('Русский')),
              ButtonSegment(value: 'en', label: Text('English')),
            ],
            selected: {s.language},
            onSelectionChanged: (v) =>
                ctrl.update((x) => x.copyWith(language: v.first)),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'Названия и описания приходят от сервиса; если перевода нет, будет английский или латынь.',
              style: t.textTheme.bodySmall,
            ),
          ),
          const SectionHeader('Облако (Supabase)'),
          _SupabaseCard(settings: s, ready: supabaseReady),
          const SizedBox(height: 12),
          Card(
            child: SwitchListTile(
              value: s.useServerProxy,
              onChanged: s.supabaseConfigured
                  ? (v) => ctrl.update((x) => x.copyWith(useServerProxy: v))
                  : null,
              title: const Text('Распознавать через сервер'),
              subtitle: const Text(
                'Ключи хранятся в Supabase, а не в приложении. Нужно для браузера, если сервис блокирует прямые запросы (CORS).',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ProviderCard extends StatefulWidget {
  const ProviderCard({
    super.key,
    required this.provider,
    required this.selected,
    required this.apiKey,
    required this.onSelect,
    required this.onKeyChanged,
  });

  final RecognitionProviderId provider;
  final bool selected;
  final String apiKey;
  final VoidCallback onSelect;
  final ValueChanged<String> onKeyChanged;

  @override
  State<ProviderCard> createState() => _ProviderCardState();
}

class _ProviderCardState extends State<ProviderCard> {
  late final _key = TextEditingController(text: widget.apiKey);
  var _obscure = true;

  @override
  void dispose() {
    _key.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final p = widget.provider;
    return PressScale(
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: widget.selected ? t.colorScheme.primary : Colors.transparent,
            width: 2,
          ),
        ),
        child: InkWell(
          onTap: widget.onSelect,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      widget.selected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                      color: t.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        p.title,
                        style: t.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (widget.apiKey.isNotEmpty)
                      Icon(
                        Icons.vpn_key,
                        size: 18,
                        color: context.palette.accent,
                      ),
                  ],
                ),
                if (widget.apiKey.isNotEmpty)
                  Consumer(
                    builder: (context, ref, _) {
                      final q = ref.watch(quotaProvider(p)).value;
                      if (q == null) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 6, left: 32),
                        child: Text(
                          q.exhausted
                              ? 'Лимит исчерпан (${q.total} ${q.period})'
                              : 'Осталось ${q.remaining} из ${q.total} ${q.period}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: q.low
                                ? context.palette.alert
                                : context.palette.inkSecondary,
                          ),
                        ),
                      );
                    },
                  ),
                const SizedBox(height: 10),
                for (final s in p.pros)
                  _Point(
                    icon: Icons.check,
                    color: context.palette.accent,
                    text: s,
                  ),
                for (final s in p.cons)
                  _Point(
                    icon: Icons.info_outline,
                    color: t.colorScheme.tertiary,
                    text: s,
                  ),
                const SizedBox(height: 12),
                TextField(
                  controller: _key,
                  obscureText: _obscure,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: InputDecoration(
                    labelText: 'API-ключ ${p.short}',
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscure ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  onChanged: widget.onKeyChanged,
                ),
                TextButton.icon(
                  onPressed: () => openLink(p.keyUrl),
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: Text('Получить ключ: ${Uri.parse(p.keyUrl).host}'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Point extends StatelessWidget {
  const _Point({required this.icon, required this.color, required this.text});

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(child: Text(text)),
      ],
    ),
  );
}

class _SupabaseCard extends ConsumerStatefulWidget {
  const _SupabaseCard({required this.settings, required this.ready});

  final AppSettings settings;
  final bool ready;

  @override
  ConsumerState<_SupabaseCard> createState() => _SupabaseCardState();
}

class _SupabaseCardState extends ConsumerState<_SupabaseCard> {
  late final _url = TextEditingController(text: widget.settings.supabaseUrl);
  late final _key = TextEditingController(
    text: widget.settings.supabaseAnonKey,
  );

  @override
  void dispose() {
    _url.dispose();
    _key.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final storage = ref.watch(gardenRepositoryProvider).label;
    final changed =
        _url.text.trim() != widget.settings.supabaseUrl ||
        _key.text.trim() != widget.settings.supabaseAnonKey;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  widget.ready ? Icons.cloud_done : Icons.cloud_off,
                  color: widget.ready ? context.palette.accent : null,
                ),
                const SizedBox(width: 8),
                Expanded(child: Text('Сейчас данные хранятся: $storage')),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Подключите Supabase, чтобы сад синхронизировался между телефоном и браузером.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _url,
              decoration: const InputDecoration(
                labelText: 'Project URL',
                hintText: 'https://xxxx.supabase.co',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _key,
              decoration: const InputDecoration(
                labelText: 'Anon / publishable key',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            FilledButton.tonal(
              onPressed: changed
                  ? () async {
                      await ref
                          .read(settingsProvider.notifier)
                          .update(
                            (x) => x.copyWith(
                              supabaseUrl: _url.text.trim(),
                              supabaseAnonKey: _key.text.trim(),
                            ),
                          );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Сохранено. Перезапустите приложение, чтобы подключиться.',
                            ),
                          ),
                        );
                      }
                    }
                  : null,
              child: const Text('Сохранить'),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationsCard extends ConsumerWidget {
  const _NotificationsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final ctrl = ref.read(settingsProvider.notifier);
    if (!ReminderNotifications.supported) {
      return const Card(
        child: ListTile(
          leading: Icon(Icons.notifications_off_outlined),
          title: Text('В браузере уведомления по расписанию недоступны'),
          subtitle: Text(
            'Задачи на сегодня видны на главной и в счётчике на вкладке. '
            'В приложении для Android и iOS придёт ежедневная сводка.',
          ),
        ),
      );
    }
    final time = TimeOfDay(hour: s.reminderHour, minute: s.reminderMinute);
    return Card(
      child: Column(
        children: [
          SwitchListTile(
            value: s.notificationsEnabled,
            title: const Text('Ежедневная сводка ухода'),
            subtitle: const Text(
              'Одно уведомление в день: что полить, подкормить, пересадить',
            ),
            onChanged: (v) async {
              if (v &&
                  !await ReminderNotifications.instance.requestPermission()) {
                if (context.mounted) {
                  showError(
                    context,
                    'Уведомления запрещены. Разрешите их для Leafy в настройках телефона.',
                  );
                }
                return;
              }
              await ctrl.update((x) => x.copyWith(notificationsEnabled: v));
            },
          ),
          ListTile(
            enabled: s.notificationsEnabled,
            leading: const Icon(Icons.schedule),
            title: const Text('Время'),
            trailing: Text(
              time.format(context),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            onTap: () async {
              final picked = await showTimePicker(
                context: context,
                initialTime: time,
              );
              if (picked != null) {
                await ctrl.update(
                  (x) => x.copyWith(
                    reminderHour: picked.hour,
                    reminderMinute: picked.minute,
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}
