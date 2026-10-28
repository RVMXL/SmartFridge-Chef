/// Тесты экспорта/импорта настроек (v0.6.3): белый список не-секретных
/// ключей, санитизация enum-подобных значений, round-trip.
///
/// Секреты (KEYS-1) в тестах лежат в prefs (фолбэк без плагина) —
/// это удобный способ проверить, что они НЕ попадают в экспорт.
library;

import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:smart_fridge_chef/state/settings_controller.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('exportSettings', () {
    test('включает оформление, язык, напоминания, магазин', () async {
      final prefs = await SharedPreferences.getInstance();
      final s = SettingsController(prefs);
      await s.setThemeMode(ThemeMode.dark);
      await s.setLanguage('en');
      await s.setNotificationsEnabled(false);
      await s.setNotificationHour(7);
      await s.setNotificationDaysBefore([1]);
      await s.setPyaterochkaStoreCode('35XY');

      final exported = s.exportSettings();
      expect(exported['pref_theme_mode'], 'dark');
      expect(exported['pref_language'], 'en');
      expect(exported['pref_notif_enabled'], false);
      expect(exported['pref_notif_hour'], 7);
      expect(exported['pref_notif_days'], '1');
      expect(exported['pref_pyat_store_code'], '35XY');
    });

    test('секреты НЕ попадают в экспорт (KEYS-1)', () async {
      final prefs = await SharedPreferences.getInstance();
      final s = SettingsController(prefs);
      // Фолбэк без плагина: секреты пишутся в prefs — как у пользователей
      // до миграции; в реальном приложении то же значение сидит в secure
      // storage, в prefs экспорта оно попадать не должно в обоих случаях.
      await s.setKrogerClientId('cid-123');
      await s.setKrogerClientSecret('secret-456');
      await s.setWegmansKey('weg-789');

      final exported = s.exportSettings();
      expect(exported.containsKey('pref_kroger_client_id'), isFalse,
          reason: 'client id хранится в secure storage и не экспортируется');
      expect(exported.containsKey('pref_kroger_client_secret'), isFalse);
      expect(exported.containsKey('pref_wegmans_key'), isFalse);
      expect(exported.values.where((v) => v == 'secret-456'), isEmpty);
    });
  });

  group('applyBackupSettings', () {
    test('применяет белый список и уведомляет слушателей', () async {
      final prefs = await SharedPreferences.getInstance();
      var notified = 0;
      final s = SettingsController(prefs)..addListener(() => notified++);

      final applied = await s.applyBackupSettings({
        'pref_theme_mode': 'dark',
        'pref_language': 'en',
        'pref_notif_hour': 8,
        'pref_notif_enabled': false,
        'pref_pyat_store_code': '12AB',
      });

      expect(applied, 5);
      expect(notified, 1, reason: 'одно уведомление после всего пакета');
      expect(s.themeMode, ThemeMode.dark);
      expect(s.language, 'en');
      expect(s.notificationHour, 8);
      expect(s.notificationsEnabled, isFalse);
      expect(s.pyaterochkaStoreCode, '12AB');
    });

    test('ключи вне белого списка (в т.ч. секреты) игнорируются', () async {
      final prefs = await SharedPreferences.getInstance();
      final s = SettingsController(prefs);

      final applied = await s.applyBackupSettings({
        'pref_kroger_client_secret': 'подделка',
        'pref_kroger_client_id': 'подделка',
        'pref_wegmans_key': 'подделка',
        'unknown_key': 'мусор',
        'pref_theme_mode': 'dark',
      });

      expect(applied, 1);
      expect(s.krogerClientSecret, isEmpty);
      expect(s.krogerClientId, isEmpty);
      expect(s.wegmansKey, isEmpty);
      expect(s.themeMode, ThemeMode.dark);
    });

    test('мусорные значения enum-подобных ключей отбрасываются', () async {
      final prefs = await SharedPreferences.getInstance();
      final s = SettingsController(prefs);

      final applied = await s.applyBackupSettings({
        'pref_theme_mode': 'hacker',
        'pref_language': 'de',
        'pref_price_source': 'darknet',
        'pref_notif_hour': 99,
      });

      expect(applied, 0);
      expect(s.themeMode, ThemeMode.system);
      expect(s.language, 'system');
      expect(s.priceSourceKind, 'pyaterochka');
      expect(s.notificationHour, 9);
    });

    test('double из JSON нормализуется в int для часового ключа', () async {
      final prefs = await SharedPreferences.getInstance();
      final s = SettingsController(prefs);

      final applied = await s.applyBackupSettings({
        'pref_notif_hour': 9.0,
      });

      expect(applied, 1);
      expect(s.notificationHour, 9);
      expect(prefs.getInt('pref_notif_hour'), 9);
    });

    test('round-trip: export → apply в новый контроллер', () async {
      final prefs1 = await SharedPreferences.getInstance();
      final source = SettingsController(prefs1);
      await source.setThemeMode(ThemeMode.light);
      await source.setLanguage('ru');
      await source.setNotificationHour(10);
      await source.setNotificationsEnabled(false);
      await source.setKrogerClientSecret('не должен переехать');

      final snapshot = source.exportSettings();

      // НОВЫЙ стор prefs (setMockInitialValues сбрасывает глобальный мок):
      // иначе секрет, лежащий в shared-сторе, «переехал» бы мимо снапшота.
      SharedPreferences.setMockInitialValues({});
      final prefs2 = await SharedPreferences.getInstance();
      final target = SettingsController(prefs2);
      await target.applyBackupSettings(snapshot);

      expect(target.themeMode, ThemeMode.light);
      expect(target.language, 'ru');
      expect(target.notificationHour, 10);
      expect(target.notificationsEnabled, isFalse);
      expect(target.krogerClientSecret, isEmpty,
          reason: 'секреты через бэкап не переносятся');
    });
  });
}
