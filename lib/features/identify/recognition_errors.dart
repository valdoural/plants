import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/settings.dart';
import '../../core/theme.dart';
import '../../core/toast.dart';
import '../../core/widgets.dart';
import '../../data/recognition/quota.dart';
import '../../data/recognition/recognition_service.dart';

/// Показывает ошибку распознавания: лимит — отдельным уведомлением, остальное — коротким сообщением.
/// [retryWith] — повторить через другой сервис, если для него есть ключ.
void presentRecognitionError(
  BuildContext context,
  WidgetRef ref,
  Object error, {
  void Function(RecognitionProviderId other)? retryWith,
}) {
  final settings = ref.read(settingsProvider);
  if (error is! RecognitionException) {
    showToast(
      context,
      'Что-то пошло не так. Попробуйте ещё раз.',
      kind: ToastKind.error,
      actionLabel: 'Подробнее',
      onAction: () => _details(context, 'Ошибка', '$error'),
    );
    return;
  }
  final failed = error.provider;
  final other = failed == null
      ? null
      : RecognitionProviderId.values.firstWhere((p) => p != failed);
  final canRetry =
      retryWith != null && other != null && settings.hasKeyFor(other);

  if (error.kind == RecognitionErrorKind.limit && failed != null) {
    ref.invalidate(quotaProvider(failed));
    showLimitNotice(
      context,
      failed,
      onSwitch: canRetry ? () => retryWith(other) : null,
    );
    return;
  }
  showToast(
    context,
    error.message,
    kind: ToastKind.error,
    duration: const Duration(milliseconds: 4200),
    actionLabel: canRetry ? 'Через ${other.short}' : 'Подробнее',
    onAction: canRetry
        ? () => retryWith(other)
        : () => _details(context, error.message, _hint(error)),
  );
}

String _hint(RecognitionException e) {
  final tip = switch (e.kind) {
    RecognitionErrorKind.network => 'Проверьте интернет. Если связь есть — возможно, запрос блокирует VPN или блокировщик рекламы.',
    RecognitionErrorKind.timeout =>
      'Сервис отвечал дольше 45 секунд. Попробуйте ещё раз при хорошей связи.',
    RecognitionErrorKind.key => 'Проверьте ключ в «Ещё → Настройки».',
    RecognitionErrorKind.domain => 'Откройте my.plantnet.org → Settings → Authorized domains и добавьте адрес сайта вместе с https://.',
    RecognitionErrorKind.emptyPhoto => 'Камера могла не успеть включиться. Снимите ещё раз или выберите фото из галереи.',
    _ => 'Попробуйте ещё раз чуть позже.',
  };
  return [tip, if (e.detail != null) 'Подробности: ${e.detail}'].join('\n\n');
}

void _details(BuildContext context, String title, String text) =>
    showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(title),
        content: SelectableText(text),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Понятно'),
          ),
        ],
      ),
    );

/// Уведомление «лимит исчерпан»: что случилось, когда обновится, что сделать.
Future<void> showLimitNotice(
  BuildContext context,
  RecognitionProviderId id, {
  VoidCallback? onSwitch,
}) {
  final p = context.palette;
  final text = switch (id) {
    RecognitionProviderId.plantId =>
      'Бесплатные кредиты Plant.id закончились — они не обновляются сами. '
          'Пополнить баланс или выпустить новый ключ можно в кабинете Kindwise.',
    RecognitionProviderId.plantNet =>
      'На сегодня закончились 500 бесплатных распознаваний Pl@ntNet. '
          'Лимит обновится завтра.',
  };
  return showModalBottomSheet<void>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(Icons.hourglass_bottom, size: 40, color: p.alert),
            const SizedBox(height: 12),
            Text(
              'Лимит ${id.short} исчерпан',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                height: 1.45,
                color: p.inkSecondary,
              ),
            ),
            const SizedBox(height: 20),
            if (onSwitch != null) ...[
              FilledButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  onSwitch();
                },
                child: Text(
                  'Распознать через ${RecognitionProviderId.values.firstWhere((x) => x != id).short}',
                ),
              ),
              const SizedBox(height: 10),
            ],
            OutlinedButton(
              onPressed: () => openLink(id.keyUrl),
              child: const Text('Открыть кабинет сервиса'),
            ),
          ],
        ),
      ),
    ),
  );
}

/// После удачного распознавания: если запросов осталось мало — предупредить.
Future<void> warnIfQuotaLow(
  BuildContext context,
  WidgetRef ref,
  RecognitionProviderId id,
) async {
  ref.invalidate(quotaProvider(id));
  final q = await ref.read(quotaProvider(id).future);
  if (q == null || !q.low || !context.mounted) return;
  showToast(
    context,
    q.exhausted
        ? 'Лимит ${id.short} исчерпан'
        : 'Осталось ${q.remaining} распознаваний ${id.short} (${q.period})',
    kind: ToastKind.warning,
  );
}
