import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../data/models.dart';

/// Ежедневная сводка задач ухода в выбранное время.
/// Работает на Android и iOS; в браузере расписание уведомлений недоступно — там остаётся счётчик в приложении.
class ReminderNotifications {
  ReminderNotifications._();
  static final instance = ReminderNotifications._();

  final _plugin = FlutterLocalNotificationsPlugin();
  var _ready = false;

  static bool get supported => !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  static const _channel = AndroidNotificationDetails(
    'care_reminders',
    'Напоминания об уходе',
    channelDescription: 'Ежедневная сводка: что полить, подкормить или пересадить',
    importance: Importance.defaultImportance,
  );
  static const _details = NotificationDetails(android: _channel, iOS: DarwinNotificationDetails());

  /// Сколько дней вперёд планировать (повторы после выполнения пересчитываются при следующем изменении сада).
  static const horizonDays = 30;

  Future<void> init() async {
    if (!supported || _ready) return;
    tzdata.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation((await FlutterTimezone.getLocalTimezone()).identifier));
    } catch (_) {
      // Неизвестная зона — остаётся UTC, сдвиг не критичен для напоминаний «на день».
    }
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    _ready = true;
  }

  /// Спрашивает разрешение на уведомления. Возвращает true, если разрешено.
  Future<bool> requestPermission() async {
    if (!supported) return false;
    await init();
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) return await android.requestNotificationsPermission() ?? false;
    final ios = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    return await ios?.requestPermissions(alert: true, badge: true, sound: true) ?? false;
  }

  /// Перепланирует все уведомления по текущему состоянию сада.
  Future<void> reschedule(GardenData data, {required bool enabled, required int hour, required int minute}) async {
    if (!supported) return;
    await init();
    await _plugin.cancelAll();
    if (!enabled) return;

    final now = tz.TZDateTime.now(tz.local);
    for (final day in buildDailyDigests(data, DateTime(now.year, now.month, now.day), horizonDays)) {
      final at = tz.TZDateTime(tz.local, day.date.year, day.date.month, day.date.day, hour, minute);
      if (!at.isAfter(now)) continue;
      await _plugin.zonedSchedule(
        id: day.date.year * 10000 + day.date.month * 100 + day.date.day,
        scheduledDate: at,
        notificationDetails: _details,
        // Неточное время (±несколько минут) не требует особого разрешения на Android 14+.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        title: day.title,
        body: day.body,
      );
    }
  }
}

class DailyDigest {
  const DailyDigest(this.date, this.title, this.body);

  final DateTime date;
  final String title;
  final String body;
}

/// Группирует задачи по дням: просроченные попадают на сегодня.
/// Отдельная функция без зависимостей от плагина — чтобы её можно было протестировать.
List<DailyDigest> buildDailyDigests(GardenData data, DateTime today, int horizonDays) {
  final byDay = <DateTime, List<CareTask>>{};
  for (final t in data.tasks) {
    if (!t.enabled || data.plant(t.plantId) == null) continue;
    var d = DateTime(t.nextDue.year, t.nextDue.month, t.nextDue.day);
    if (d.isBefore(today)) d = today;
    if (d.difference(today).inDays >= horizonDays) continue;
    byDay.putIfAbsent(d, () => []).add(t);
  }
  final days = byDay.keys.toList()..sort();
  return [
    for (final d in days)
      DailyDigest(
        d,
        byDay[d]!.length == 1 ? 'Растению нужен уход' : 'Растениям нужен уход: ${byDay[d]!.length}',
        _body(data, byDay[d]!),
      ),
  ];
}

String _body(GardenData data, List<CareTask> tasks) {
  final byType = <CareType, List<String>>{};
  for (final t in tasks) {
    byType.putIfAbsent(t.type, () => []).add(data.plant(t.plantId)!.nickname);
  }
  return byType.entries.map((e) => '${e.key.label}: ${e.value.join(', ')}').join(' · ');
}
