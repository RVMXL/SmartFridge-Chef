/// Логика напоминаний о сроках годности (Шаг 3) — чистые вычисления
/// без платформенных зависимостей.
///
/// ТЗ: «За 1–2 дня до конца срока приложение присылает пуш». Для каждого
/// активного продукта планируем пуши за N дней до истечения в фиксированный
/// час суток. Всё, что уже в прошлом, не планируется.
library;

import '../core/constants.dart';
import '../core/freshness.dart';
import '../data/models/product.dart';

/// Максимум активных напоминаний одновременно (ограничение ОС на будильники —
/// сотни; берём запас с приоритетом ближайших дат).
const int kMaxScheduledReminders = 100;

/// Одно запланированное напоминание.
class ReminderPlan {
  const ReminderPlan({
    required this.productId,
    required this.productName,
    required this.expiryDate,
    required this.daysBefore,
    required this.fireAt,
  });

  /// Идентификатор продукта в SQLite (не null — синхронизируем сохранённые).
  final int productId;

  /// Название для текста уведомления (снимок на момент планирования).
  final String productName;

  /// Дата истечения срока продукта.
  final DateTime expiryDate;

  /// За сколько дней до истечения срока сработает пуш (1–2 по ТЗ).
  final int daysBefore;

  /// Момент срабатывания (локальная дата и час).
  final DateTime fireAt;
}

/// Стабильный числовой идентификатор уведомления для пары
/// (продукт, дней до истечения).
///
/// Детерминизм критичен: по этому же id старые пуши отменяются при
/// правке/удалении продукта или смене настроек. Формула (productId * 10 +
/// daysBefore) даёт уникальность для дней 1–9; маска 0x7FFFFFFF удерживает
/// результат в пределах int32 (требование Android).
int reminderId(int productId, int daysBefore) =>
    (productId * 10 + daysBefore) & 0x7FFFFFFF;

/// Строит план напоминаний для списка продуктов.
///
/// Правила:
///  - учитываются только активные продукты (consumed/discarded — мимо);
///  - для уже просроченных напоминаний нет — пуш о прошлом бесполезен;
///  - момент «истечение − [daysBefore] дней, час [hour]:00» в прошлом
///    отбрасывается (например, срок завтра, а час будильника уже прошёл);
///  - результат отсортирован по времени срабатывания и обрезан до
///    [maxReminders] (ближайшие важнее).
List<ReminderPlan> buildReminders({
  required List<Product> products,
  required List<int> daysBefore,
  required int hour,
  DateTime? now,
  int maxReminders = kMaxScheduledReminders,
}) {
  assert(hour >= 0 && hour <= 23, 'Час напоминания — 0..23');
  final at = now ?? DateTime.now();
  final today = dateOnly(at);
  final result = <ReminderPlan>[];

  for (final product in products) {
    final id = product.id;
    if (id == null) continue; // не сохранён в базе — напоминать нечего
    if (product.status != ProductStatus.active) continue;
    if (daysLeftUntil(product.expiryDate, now: today) < 0) continue;

    for (final days in daysBefore) {
      final day = dateOnly(product.expiryDate).subtract(Duration(days: days));
      final fireAt = DateTime(day.year, day.month, day.day, hour);
      // Сравнение с ПОЛНЫМ «сейчас»: час будильника мог уже пройти.
      if (!fireAt.isAfter(at)) continue;
      result.add(
        ReminderPlan(
          productId: id,
          productName: product.name.trim(),
          expiryDate: dateOnly(product.expiryDate),
          daysBefore: days,
          fireAt: fireAt,
        ),
      );
    }
  }

  result.sort((a, b) => a.fireAt.compareTo(b.fireAt));
  return result.length > maxReminders
      ? result.sublist(0, maxReminders)
      : result;
}

/// Стандартный набор дней из констант, нормализованный (по убыванию).
List<int> defaultDaysBefore() => List<int>.from(kPushDaysBefore);
