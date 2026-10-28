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

import 'package:flutter/foundation.dart' show visibleForTesting;
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

  /// ST-6 (аудит 2026-10-28, v0.6.2): отпечаток входов последнего
  /// успешного sync. refresh() вызывается после КАЖДОЙ мутации;
  /// если входы (продукты/настройки/локаль/день) не менялись — resync
  /// не нужен, sync возвращается сразу, без buildReminders/diff/pending.
  String? _lastInputFingerprint;

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
      _lastInputFingerprint = null;
      return;
    }

    final resolvedNow = now ?? DateTime.now();

    // ST-6: идемпотентность по входам. Дата в отпечатке — потому что
    // окно напоминаний зависит от «сегодня» (продукт входит в окно
    // за N дней — в полночь состав запланированных пушей меняется).
    final inputFingerprint = [
      localeTag,
      '${resolvedNow.year}-${resolvedNow.month}-${resolvedNow.day}',
      ...(settings.notificationDaysBefore.toList()..sort()),
      '${settings.notificationHour}',
      for (final p in products) '${p.id}:${p.expiryDate.toIso8601String()}',
    ].join('|');
    if (inputFingerprint == _lastInputFingerprint &&
        _lastScheduled.isNotEmpty) {
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
        formatExpiryDate(r.expiryDate, localeTag),
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

    // ST-6: отметка успешного прохода — до него подрядные sync не скипаются.
    _lastInputFingerprint = inputFingerprint;
  }

  /// Дата в формате локали; при недоступных intl-символах — запасной вид.
  ///
  /// ST-3 (аудит 2026-10-28, v0.6.2): раньше формат всегда падал в запасной
  /// ISO-вид — intl-символы локалей не инициализированы (main.dart теперь
  /// вызывает initializeDateFormatting). Публичный и статический —
  /// для теста «дата в пуше не ISO».
  @visibleForTesting
  static String formatExpiryDate(DateTime d, String localeTag) {
    try {
      return DateFormat('d MMM y', localeTag).format(d);
    } catch (_) {
      return Product.formatDate(d);
    }
  }
}
