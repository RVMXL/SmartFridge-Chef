/// Тесты конверсии времени напоминаний (NOTIF-1, аудит 2026-10-28):
/// UTC-fallback планировщика должен сохранять «настенное» время —
/// раньше фолбэк вычитал timeZoneOffset из уже-локального DateTime и
/// будильники уходили на |offset| часов (10:00 МСК приходили в 07:00).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tz_data;

import 'package:smart_fridge_chef/notifications/reminder_scheduler.dart';

void main() {
  setUpAll(tz_data.initializeTimeZones);

  group('LocalReminderScheduler.fallbackToTz (UTC-fallback, NOTIF-1)', () {
    test('10:00 локального «настенного» времени остаётся 10:00', () {
      final moment = LocalReminderScheduler.fallbackToTz(
        DateTime(2026, 11, 2, 10, 0),
      );
      // То же мгновение, что DateTime.utc(10:00) — сдвига на offset нет.
      expect(
        moment.millisecondsSinceEpoch,
        DateTime.utc(2026, 11, 2, 10, 0).millisecondsSinceEpoch,
      );
      expect(moment.hour, 10, reason: 'настенное время сохраняется');
      expect(moment.minute, 0);
      expect(moment.day, 2);
      expect(moment.month, 11);
    });

    test('произвольное время конвертируется без сдвига на offset', () {
      // Баг был: when.subtract(timeZoneOffset) перед конверсией — 07:30
      // превращалось в 04:30 при UTC+3. Теперь сдвига нет.
      final moment = LocalReminderScheduler.fallbackToTz(
        DateTime(2026, 6, 15, 7, 30),
      );
      expect(
        moment.millisecondsSinceEpoch,
        DateTime.utc(2026, 6, 15, 7, 30).millisecondsSinceEpoch,
      );
      expect(moment.hour, 7);
      expect(moment.minute, 30);
    });
  });
}
