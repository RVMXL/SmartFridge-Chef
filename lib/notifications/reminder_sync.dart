/// Синхронизация напоминаний: приводит запланированные системные пуши
/// к текущему состоянию холодильника и настроек.
///
/// Вызывается при старте приложения, после любого изменения продуктов
/// и при смене настроек напоминаний. Детерминированные id (reminderId)
/// позволяют просто сверять множества: лишние — отменить, нужные —
/// перезапланировать (перезапись по тому же id).
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

  /// Полная синхронизация: отмена лишних + планирование нужных.
  ///
  /// [products] — активные продукты холодильника (обычно из ProductDao).
  /// [localeTag] — 'ru' | 'en' (язык текстов пушей на момент планирования).
  Future<void> sync({
    required List<Product> products,
    DateTime? now,
    String localeTag = 'ru',
  }) async {
    if (!settings.notificationsEnabled) {
      await scheduler.cancelAll();
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
      if (!desiredById.containsKey(id)) await scheduler.cancel(id);
    }

    for (final entry in desiredById.entries) {
      final r = entry.value;
      final left = daysLeftUntil(r.expiryDate, now: now);
      await scheduler.schedule(
        id: entry.key,
        when: r.fireAt,
        title: l.notifTitle,
        body: l.notifBody(
          r.productName,
          _formatDate(r.expiryDate, localeTag),
          left,
        ),
      );
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
