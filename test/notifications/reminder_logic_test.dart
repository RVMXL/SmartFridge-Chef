/// Тесты логики напоминаний о сроках годности (Шаг 3):
/// план напоминаний и детерминированные идентификаторы.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:smart_fridge_chef/core/constants.dart';
import 'package:smart_fridge_chef/data/models/product.dart';
import 'package:smart_fridge_chef/notifications/reminder_logic.dart';

void main() {
  DateTime d(int y, int m, int day, [int h = 12]) => DateTime(y, m, day, h);

  Product product(
    String name,
    String expiry, {
    int? id = 1,
    ProductStatus status = ProductStatus.active,
  }) =>
      Product(
        id: id,
        name: name,
        category: ProductCategory.dairy,
        expiryDate: Product.parseDate(expiry),
        addedAt: d(2026, 10, 20),
        status: status,
      );

  group('buildReminders', () {
    test('пуш за 2 и за 1 день в выбранный час', () {
      final now = d(2026, 10, 24, 10);
      final reminders = buildReminders(
        products: [product('Молоко', '2026-10-30')],
        daysBefore: const [2, 1],
        hour: 9,
        now: now,
      );
      expect(reminders, hasLength(2));
      // Сортировка по времени срабатывания: раньше — за 2 дня.
      expect(reminders[0].daysBefore, 2);
      expect(reminders[0].fireAt, DateTime(2026, 10, 28, 9));
      expect(reminders[1].daysBefore, 1);
      expect(reminders[1].fireAt, DateTime(2026, 10, 29, 9));
      expect(reminders[0].productName, 'Молоко');
      expect(reminders[0].expiryDate, DateTime(2026, 10, 30));
    });

    test('момент в прошлом отбрасывается (час будильника уже прошёл)', () {
      final now = d(2026, 10, 28, 10);
      // Напоминание за 2 дня должно было сработать сегодня в 9:00 — поздно.
      final reminders = buildReminders(
        products: [product('Молоко', '2026-10-30')],
        daysBefore: const [2, 1],
        hour: 9,
        now: now,
      );
      expect(reminders, hasLength(1));
      expect(reminders.single.daysBefore, 1);
      expect(reminders.single.fireAt, DateTime(2026, 10, 29, 9));
    });

    test('просроченные продукты не получают напоминаний', () {
      final now = d(2026, 10, 24, 10);
      final reminders = buildReminders(
        products: [product('Сметана', '2026-10-20')],
        daysBefore: const [2, 1],
        hour: 9,
        now: now,
      );
      expect(reminders, isEmpty);
    });

    test('съеденные и выброшенные продукты игнорируются', () {
      final now = d(2026, 10, 24, 10);
      final reminders = buildReminders(
        products: [
          product('Кефир', '2026-10-30', status: ProductStatus.consumed),
          product('Йогурт', '2026-10-30', status: ProductStatus.discarded),
        ],
        daysBefore: const [2, 1],
        hour: 9,
        now: now,
      );
      expect(reminders, isEmpty);
    });

    test('несохранённый продукт (id = null) пропускается', () {
      final now = d(2026, 10, 24, 10);
      final reminders = buildReminders(
        products: [product('Молоко', '2026-10-30', id: null)],
        daysBefore: const [2, 1],
        hour: 9,
        now: now,
      );
      expect(reminders, isEmpty);
    });

    test('сегодня = expiry − daysBefore ещё успевает (час в будущем)', () {
      final now = d(2026, 10, 28, 8);
      final reminders = buildReminders(
        products: [product('Молоко', '2026-10-30')],
        daysBefore: const [2, 1],
        hour: 9,
        now: now,
      );
      expect(reminders, hasLength(2));
    });

    test('кап на максимум напоминаний берёт ближайшие', () {
      final now = d(2026, 10, 24, 10);
      final products = [
        for (var i = 1; i <= 60; i++)
          Product(
            id: i,
            name: 'Продукт $i',
            category: ProductCategory.other,
            expiryDate: Product.parseDate('2026-11-${(i % 28 + 1).toString().padLeft(2, '0')}'),
            addedAt: now,
          ),
      ];
      final reminders = buildReminders(
        products: products,
        daysBefore: const [2, 1],
        hour: 9,
        now: now,
        maxReminders: 50,
      );
      expect(reminders.length, 50);
      for (var i = 1; i < reminders.length; i++) {
        expect(
          reminders[i].fireAt.isAfter(reminders[i - 1].fireAt) ||
              !reminders[i - 1].fireAt.isAfter(reminders[i].fireAt),
          isTrue,
        );
      }
    });

    test('дефолт дней — из констант ТЗ (1 и 2)', () {
      expect(defaultDaysBefore(), kPushDaysBefore);
      expect(defaultDaysBefore(), [2, 1]);
    });
  });

  group('reminderId', () {
    test('детерминирован и уникален для продуктов и дней 1–2', () {
      final seen = <int>{};
      for (var productId = 1; productId <= 10000; productId++) {
        for (final days in const [1, 2]) {
          final id = reminderId(productId, days);
          expect(id, reminderId(productId, days), reason: 'стабильность');
          expect(id > 0, isTrue, reason: 'положительный int');
          expect(seen.add(id), isTrue, reason: 'уникальность $productId/$days');
        }
      }
    });

    test('укладывается в int32 даже для больших id (Android-ограничение)', () {
      final id = reminderId(999999999, 2);
      expect(id, lessThanOrEqualTo(0x7FFFFFFF));
      expect(id, greaterThan(0));
    });
  });
}
