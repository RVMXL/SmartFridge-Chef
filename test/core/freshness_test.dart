/// Тесты логики свежести — цветовой индикации и порогов пушей.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:smart_fridge_chef/core/freshness.dart';

void main() {
  final now = DateTime(2026, 10, 24, 15, 30); // время в дате должно игнорироваться

  group('daysLeftUntil', () {
    test('считает полные дни, игнорируя время', () {
      expect(daysLeftUntil(DateTime(2026, 10, 27), now: now), 3);
      expect(daysLeftUntil(DateTime(2026, 10, 25, 9, 0), now: now), 1);
    });

    test('сегодня = 0, вчера = -1', () {
      expect(daysLeftUntil(DateTime(2026, 10, 24), now: now), 0);
      expect(daysLeftUntil(DateTime(2026, 10, 23), now: now), -1);
    });
  });

  group('freshnessFor', () {
    test('просрочено — красный', () {
      expect(freshnessFor(DateTime(2026, 10, 20), now: now),
          Freshness.expired);
    });

    test('сегодня и в пределах 2 дней — жёлтый (ТЗ: пуш за 1–2 дня)', () {
      expect(freshnessFor(DateTime(2026, 10, 24), now: now),
          Freshness.expiringSoon);
      expect(freshnessFor(DateTime(2026, 10, 26), now: now),
          Freshness.expiringSoon);
    });

    test('3+ дня — зелёный', () {
      expect(freshnessFor(DateTime(2026, 10, 27), now: now),
          Freshness.fresh);
    });

    test('порог настраивается', () {
      expect(
        freshnessFor(DateTime(2026, 10, 26), now: now, soonDays: 1),
        Freshness.fresh,
      );
      expect(
        freshnessFor(DateTime(2026, 10, 25), now: now, soonDays: 1),
        Freshness.expiringSoon,
      );
    });
  });
}
