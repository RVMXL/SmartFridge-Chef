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

  /// Загрузка предпочтений до runApp, чтобы не мигать темой при старте.
  static Future<SettingsController> load() async {
    final prefs = await SharedPreferences.getInstance();
    return SettingsController(prefs);
  }
}
