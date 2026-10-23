/// Логика свежести продукта — основа цветовой индикации экрана
/// «Мой холодильник» и будущих локальных пушей (Шаг 3).
///
/// Даты сравниваются только по календарному дню (без времени и таймзоны):
/// срок «2026-10-26» при today «2026-10-24» — 2 дня, «истекает скоро».
library;

import 'constants.dart';

/// Цветовая индикация свежести.
enum Freshness {
  /// Зелёный: до истечения срока больше [kExpiringSoonDays] дней.
  fresh,

  /// Жёлтый: срок истекает сегодня или в течение [kExpiringSoonDays] дней.
  expiringSoon,

  /// Красный: срок уже истёк.
  expired,
}

/// Отбрасывает время, оставляя только календарную дату (локальная).
DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Сколько полных дней осталось до даты [expiryDate] относительно [now].
///
/// Отрицательное значение — срок уже истёк.
int daysLeftUntil(DateTime expiryDate, {DateTime? now}) {
  final today = dateOnly(now ?? DateTime.now());
  final expiry = dateOnly(expiryDate);
  return expiry.difference(today).inDays;
}

/// Вычисляет индикацию свежести по дате истечения срока.
Freshness freshnessFor(
  DateTime expiryDate, {
  DateTime? now,
  int soonDays = kExpiringSoonDays,
}) {
  final left = daysLeftUntil(expiryDate, now: now);
  if (left < 0) return Freshness.expired;
  if (left <= soonDays) return Freshness.expiringSoon;
  return Freshness.fresh;
}
