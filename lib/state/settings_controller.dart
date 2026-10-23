/// Настройки приложения (тема, язык) — SharedPreferences, вне базы SQLite.
///
/// Профиль питания — доменные данные, им место в SQLite; оформление
/// и язык — предпочтения интерфейса, им место здесь. Решение описано
/// в docs/ARCHITECTURE.md.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Locale, ThemeMode;
import 'package:shared_preferences/shared_preferences.dart';

class SettingsController extends ChangeNotifier {
  SettingsController(this._prefs);

  final SharedPreferences _prefs;

  static const String _kThemeMode = 'pref_theme_mode';
  static const String _kLanguage = 'pref_language';

  // Шаг 3: настройки напоминаний о сроках годности.
  static const String _kNotifEnabled = 'pref_notif_enabled';
  static const String _kNotifDays = 'pref_notif_days';
  static const String _kNotifHour = 'pref_notif_hour';

  static const String _themeSystem = 'system';
  static const String _themeLight = 'light';
  static const String _themeDark = 'dark';

  ThemeMode get themeMode {
    switch (_prefs.getString(_kThemeMode)) {
      case _themeLight:
        return ThemeMode.light;
      case _themeDark:
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  /// 'system' | 'ru' | 'en'
  String get language => _prefs.getString(_kLanguage) ?? 'system';

  /// null → следовать языку системы.
  Locale? get locale {
    final lang = language;
    return (lang == 'system') ? null : Locale(lang);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    final value = switch (mode) {
      ThemeMode.light => _themeLight,
      ThemeMode.dark => _themeDark,
      ThemeMode.system => _themeSystem,
    };
    await _prefs.setString(_kThemeMode, value);
    notifyListeners();
  }

  Future<void> setLanguage(String lang) async {
    assert(['system', 'ru', 'en'].contains(lang));
    await _prefs.setString(_kLanguage, lang);
    notifyListeners();
  }

  // ------------------------------------------------ уведомления (Шаг 3)

  /// Включены ли напоминания о сроках годности.
  bool get notificationsEnabled => _prefs.getBool(_kNotifEnabled) ?? true;

  Future<void> setNotificationsEnabled(bool enabled) async {
    await _prefs.setBool(_kNotifEnabled, enabled);
    notifyListeners();
  }

  /// За сколько дней до истечения срока пушим. Возможные значения — 1 и/или 2
  /// (ТЗ: «за 1–2 дня»). Хранение — CSV «2,1»; пусто/битое → дефолт [2, 1].
  List<int> get notificationDaysBefore {
    final raw = _prefs.getString(_kNotifDays);
    if (raw == null || raw.isEmpty) return [2, 1];
    final parsed = raw
        .split(',')
        .map((s) => int.tryParse(s.trim()))
        .whereType<int>()
        .where((d) => d >= 1 && d <= 2)
        .toSet();
    final days = parsed.toList()..sort((a, b) => b.compareTo(a));
    return days.isEmpty ? [2, 1] : days;
  }

  /// Устанавливает набор дней (подмножество {1, 2}, не пустое).
  Future<void> setNotificationDaysBefore(List<int> days) async {
    final cleaned = days.toSet().where((d) => d >= 1 && d <= 2).toList()
      ..sort((a, b) => b.compareTo(a));
    assert(cleaned.isNotEmpty, 'Должен остаться хотя бы один день');
    await _prefs.setString(_kNotifDays, cleaned.join(','));
    notifyListeners();
  }

  /// Час суток (0–23), в который приходит напоминание.
  int get notificationHour => _prefs.getInt(_kNotifHour) ?? 9;

  Future<void> setNotificationHour(int hour) async {
    assert(hour >= 0 && hour <= 23);
    await _prefs.setInt(_kNotifHour, hour);
    notifyListeners();
  }

  /// Загрузка предпочтений до runApp, чтобы не мигать темой при старте.
  static Future<SettingsController> load() async {
    final prefs = await SharedPreferences.getInstance();
    return SettingsController(prefs);
  }
}
