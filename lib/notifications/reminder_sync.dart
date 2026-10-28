/// Синхронизация напоминаний: приводит запланированные системные пуши
/// к текущему состоянию холодильника и настроек.
///
/// Вызывается при старте приложения, после любого изменения продуктов
/// и при смене настроек напоминаний. Детерминированные id (reminderId)
/// позволяют просто сверять множества: лишние — отменить, нужные —
/// перезапланировать (перезапись по тому же id).
///
/// NOTIF-3 (аудит 2026-10-28): синхронизации сериализуются Future-замком —
/// стартовый refresh и мутация из другого среза больше не пересекаются
/// и не могут отменить только что запланированный id.
///
/// NOTIF-4 (аудит 2026-10-28): diff по отпечатку — id, уже запланированный
/// с тем же временем/заголовком/текстом, не дёргает zonedSchedule повторно
/// (раньше каждая правка продукта вызывала до 100 перезаписей).
library;

import 'dart:ui' show Locale;

import 'package:intl/intl.dart';

import '../core/freshness.dart';
import '../data/models/product.dart';
import '../l10n/generated/app_localizations.dart';
import '../state/settings_controller.dart';
import 'reminder_logic.dart';
import 'reminder_scheduler.dart';

/// Сервис синхронизации пушей о сроках годности.
class ReminderSyncService {
  ReminderSyncService({required this.scheduler, required this.settings});

  final ReminderScheduler scheduler;
  final SettingsController settings;

  /// NOTIF-3: хвост очереди синхронизаций (сериализация вызовов).
  Future<void> _queue = Future.value();

  /// Отпечаток последней запланированной версии каждого id (NOTIF-4).
  final Map<int, String> _lastScheduled = <int, String>{};

  /// Полная синхронизация: отмена лишних + планирование нужных.
  ///
  /// [products] — активные продукты холодильника (обычно из ProductDao).
  /// [localeTag] — 'ru' | 'en' (язык текстов пушей на момент планирования).
  ///
  /// Вызовы сериализуются: параллельные sync выполняются строго друг за
  /// другом в порядке вызова, исключение одной не роняет очередь.
  Future<void> sync({
    required List<Product> products,
    DateTime? now,
    String localeTag = 'ru',
  }) {
    final task =
        _queue.then((_) => _syncNow(products: products, now: now, localeTag: localeTag));
    // Очередь не должна застрять на упавшем шаге.
    _queue = task.then<void>((_) {}, onError: (Object _) {});
    return task;
  }

  Future<void> _syncNow({
    required List<Product> products,
    required DateTime? now,
    required String localeTag,
  }) async {
    if (!settings.notificationsEnabled) {
      await scheduler.cancelAll();
      _lastScheduled.clear();
      return;
    }

    final l = await AppLocalizations.delegate.load(
      localeTag.startsWith('ru') ? const Locale('ru') : const Locale('en'),
    );

    final desired = buildReminders(
      products: products,
      daysBefore: settings.notificationDaysBefore,
      hour: settings.notificationHour,
      now: now,
    );
    final desiredById = <int, ReminderPlan>{
      for (final r in desired) reminderId(r.productId, r.daysBefore): r,
    };

    // Отменяем всё, что больше не должно звонить: продукт съеден/удалён,
    // дата передвинута, изменился набор дней или час.
    final pending = await scheduler.pendingIds();
    for (final id in pending) {
      if (!desiredById.containsKey(id)) {
        await scheduler.cancel(id);
        _lastScheduled.remove(id);
      }
    }

    for (final entry in desiredById.entries) {
      final r = entry.value;
      final left = daysLeftUntil(r.expiryDate, now: now);
      final title = l.notifTitle;
      final body = l.notifBody(
        r.productName,
        _formatDate(r.expiryDate, localeTag),
        left,
      );
      // NOTIF-4: перезапись по тому же id идёт только если содержимое
      // (момент срабатывания, заголовок, текст) изменилось.
      final fingerprint = '${r.fireAt.toIso8601String()}|$title|$body';
      if (pending.contains(entry.key) &&
          _lastScheduled[entry.key] == fingerprint) {
        continue;
      }
      await scheduler.schedule(
        id: entry.key,
        when: r.fireAt,
        title: title,
        body: body,
      );
      _lastScheduled[entry.key] = fingerprint;
    }
  }

  /// Дата в формате локали; при недоступных intl-символах — ISO.
  String _formatDate(DateTime d, String localeTag) {
    try {
      return DateFormat('d MMM y', localeTag).format(d);
    } catch (_) {
      return Product.formatDate(d);
    }
  }
}
