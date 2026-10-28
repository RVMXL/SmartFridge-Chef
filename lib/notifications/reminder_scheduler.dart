/// Планировщик напоминаний: контракт + реализация на flutter_local_notifications.
///
/// Контракт [ReminderScheduler] изолирует платформенные каналы, чтобы
/// ReminderSyncService тестировался фейковым планировщиком. Реализация
/// [LocalReminderScheduler] — тонкая обёртка над плагином: инициализация
/// часовых поясов, канал Android, права, планирование по id.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show MissingPluginException;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../core/constants.dart';

/// Абстракция над системными уведомлениями (для тестов — фейк).
abstract interface class ReminderScheduler {
  /// Запрашивает права на пуши (Android 13+, iOS). Возвращает, выданы ли.
  Future<bool> requestPermissions();

  /// Планирует (или перезаписывает) уведомление с числовым [id].
  Future<void> schedule({
    required int id,
    required DateTime when,
    required String title,
    required String body,
  });

  /// Отменяет уведомление по [id].
  Future<void> cancel(int id);

  /// Отменяет все запланированные приложением уведомления.
  Future<void> cancelAll();

  /// Идентификаторы всех запланированных уведомлений (для сверки при синхронизации).
  Future<Set<int>> pendingIds();
}

/// Реализация на flutter_local_notifications.
class LocalReminderScheduler implements ReminderScheduler {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool _exactAllowed = false;
  bool _usesUtcFallback = false;

  /// Инициализация таймзон, плагина и канала уведомлений Android.
  /// Идемпотентна — безопасно вызывать при каждом старте приложения.
  Future<void> init({
    required String channelName,
    required String channelDescription,
  }) async {
    if (_initialized) return;

    // База часовых поясов + локальная зона устройства. При сбое определения
    // остаёмся на UTC и компенсируем смещение в [_toTz] (офлайн-фолбэк).
    tzdata.initializeTimeZones();
    _usesUtcFallback = true;
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
      _usesUtcFallback = false;
    } catch (e) {
      debugPrint('LocalReminderScheduler: не удалось определить таймзону — $e');
    }

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      ),
    );
    await _plugin.initialize(settings: settings);

    final android = _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        kExpiryNotificationChannelId,
        'Сроки годности',
        description: 'Напоминания о продуктах, срок которых истекает',
        importance: Importance.high,
      ),
    );

    try {
      _exactAllowed = await android?.canScheduleExactNotifications() ?? false;
    } on MissingPluginException {
      _exactAllowed = false;
    }

    _initialized = true;
  }

  /// Перевод локального момента в TZDateTime плагина.
  tz.TZDateTime _toTz(DateTime when) {
    if (_usesUtcFallback) {
      return fallbackToTz(when);
    }
    return tz.TZDateTime.from(when, tz.local);
  }

  /// NOTIF-1 (аудит 2026-10-28): чистая конверсия для фолбэка, когда
  /// плагин таймзон недоступен и tz.local остаётся UTC. [when] — локальное
  /// «настенное» время; его платформенная интерпретация как момента уже
  /// корректна, поэтому ручное вычитание timeZoneOffset перед конверсией
  /// (двойной учёт смещения) не производится — старый код сдвигал
  /// будильники на |offset| часов (10:00 МСК приходили в 07:00).
  @visibleForTesting
  static tz.TZDateTime fallbackToTz(DateTime when) =>
      tz.TZDateTime.from(when, tz.UTC);

  @override
  Future<bool> requestPermissions() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      final granted = await android.requestNotificationsPermission();
      try {
        _exactAllowed = await android.canScheduleExactNotifications() ?? false;
      } on MissingPluginException {
        _exactAllowed = false;
      }
      return granted ?? true;
    }
    final ios = _plugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      final granted = await ios.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? true;
    }
    return true; // на других платформах права не нужны
  }

  @override
  Future<void> schedule({
    required int id,
    required DateTime when,
    required String title,
    required String body,
  }) async {
    final details = NotificationDetails(
      android: const AndroidNotificationDetails(
        kExpiryNotificationChannelId,
        'Сроки годности',
        channelDescription: 'Напоминания о продуктах, срок которых истекает',
        importance: Importance.high,
        priority: Priority.defaultPriority,
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentSound: true,
      ),
    );
    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: _toTz(when),
      notificationDetails: details,
      androidScheduleMode: _exactAllowed
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  @override
  Future<void> cancel(int id) => _plugin.cancel(id: id);

  @override
  Future<void> cancelAll() => _plugin.cancelAll();

  @override
  Future<Set<int>> pendingIds() async {
    final pending = await _plugin.pendingNotificationRequests();
    return pending.map((r) => r.id).toSet();
  }
}
