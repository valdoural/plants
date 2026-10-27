import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/garden_controller.dart';
import '../data/models.dart';
import 'notifications.dart';
import 'settings.dart';

/// Невидимая обёртка приложения: при любом изменении сада или настроек
/// перепланирует ежедневные уведомления.
class ReminderScheduler extends ConsumerStatefulWidget {
  const ReminderScheduler({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<ReminderScheduler> createState() => _ReminderSchedulerState();
}

class _ReminderSchedulerState extends ConsumerState<ReminderScheduler> {
  @override
  void initState() {
    super.initState();
    if (!ReminderNotifications.supported) return;
    ref.listenManual<AsyncValue<GardenData>>(
      gardenProvider,
      (_, next) => _sync(),
      fireImmediately: true,
    );
    ref.listenManual<AppSettings>(settingsProvider, (prev, next) {
      if (prev?.notificationsEnabled != next.notificationsEnabled ||
          prev?.reminderHour != next.reminderHour ||
          prev?.reminderMinute != next.reminderMinute) {
        _sync();
      }
    });
  }

  Future<void> _sync() async {
    final data = ref.read(gardenProvider).value;
    if (data == null) return;
    final s = ref.read(settingsProvider);
    try {
      await ReminderNotifications.instance.reschedule(
        data,
        enabled: s.notificationsEnabled,
        hour: s.reminderHour,
        minute: s.reminderMinute,
      );
    } catch (e) {
      debugPrint('Не удалось запланировать уведомления: $e');
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
