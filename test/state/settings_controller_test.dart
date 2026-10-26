/// Тесты настроек напоминаний (Шаг 3): вкл/выкл, набор дней, час.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:smart_fridge_chef/state/settings_controller.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('дефолты: включены, дни [2, 1], час 9', () async {
    final prefs = await SharedPreferences.getInstance();
    final s = SettingsController(prefs);
    expect(s.notificationsEnabled, isTrue);
    expect(s.notificationDaysBefore, [2, 1]);
    expect(s.notificationHour, 9);
  });

  test('вкл/выкл уведомлений сохраняется', () async {
    final prefs = await SharedPreferences.getInstance();
    final s = SettingsController(prefs);
    await s.setNotificationsEnabled(false);
    expect(s.notificationsEnabled, isFalse);
    await s.setNotificationsEnabled(true);
    expect(s.notificationsEnabled, isTrue);
  });

  test('набор дней: только 1 и/или 2, сортировка по убыванию', () async {
    final prefs = await SharedPreferences.getInstance();
    final s = SettingsController(prefs);

    await s.setNotificationDaysBefore([1]);
    expect(s.notificationDaysBefore, [1]);

    await s.setNotificationDaysBefore([1, 2]);
    expect(s.notificationDaysBefore, [2, 1]);

    await s.setNotificationDaysBefore([2]);
    expect(s.notificationDaysBefore, [2]);
  });

  test('битое значение дней в хранилище → безопасный дефолт', () async {
    SharedPreferences.setMockInitialValues({'pref_notif_days': 'abc,7,'});
    final prefs = await SharedPreferences.getInstance();
    final s = SettingsController(prefs);
    expect(s.notificationDaysBefore, [2, 1]);
  });

  test('час 0–23 сохраняется', () async {
    final prefs = await SharedPreferences.getInstance();
    final s = SettingsController(prefs);
    await s.setNotificationHour(0);
    expect(s.notificationHour, 0);
    await s.setNotificationHour(22);
    expect(s.notificationHour, 22);
  });

  // ------------------------------------ источники цен (v0.5.6–v0.5.8)

  test('источник цены: новые виды сохраняются, готовность по настройкам',
      () async {
    final prefs = await SharedPreferences.getInstance();
    final s = SettingsController(prefs);

    // Новые источники v0.5.8 принимаются без настроек (кроме Wegmans).
    await s.setPriceSourceKind('mercadona');
    expect(s.priceSourceKind, 'mercadona');
    expect(s.priceSourceReady, isTrue);

    await s.setPriceSourceKind('aldi');
    expect(s.priceSourceKind, 'aldi');
    expect(s.priceSourceReady, isTrue);

    // Wegmans готов только с ключом и магазином.
    await s.setPriceSourceKind('wegmans');
    expect(s.priceSourceReady, isFalse);
    await s.setWegmansKey(' key-123 ');
    await s.setWegmansStore('68', 'Pittsford (#68)');
    expect(s.wegmansKey, 'key-123'); // trim
    expect(s.wegmansStoreNumber, '68');
    expect(s.wegmansStoreLabel, 'Pittsford (#68)');
    expect(s.priceSourceReady, isTrue);
  });
}
