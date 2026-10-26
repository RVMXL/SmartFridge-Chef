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

  // ------------------------------------ источники цен (v0.5.5–v0.5.6, эксп.)

  static const String _kPriceEnabled = 'pref_pyat_enabled'; // ключ с 0.5.5
  static const String _kPriceSource = 'pref_price_source';
  static const String _kPyatStoreCode = 'pref_pyat_store_code';

  static const String _kKrogerClientId = 'pref_kroger_client_id';
  static const String _kKrogerClientSecret = 'pref_kroger_client_secret';
  static const String _kKrogerZip = 'pref_kroger_zip';
  static const String _kKrogerLocationId = 'pref_kroger_location_id';
  static const String _kKrogerLocationLabel = 'pref_kroger_location_label';

  static const String _kWegmansKey = 'pref_wegmans_key';
  static const String _kWegmansStoreNumber = 'pref_wegmans_store_number';
  static const String _kWegmansStoreLabel = 'pref_wegmans_store_label';

  /// Подставлять цены при добавлении продукта (источник — [priceSourceKind]).
  /// Выключено по умолчанию: фича экспериментальная.
  bool get priceLookupEnabled => _prefs.getBool(_kPriceEnabled) ?? false;

  Future<void> setPriceLookupEnabled(bool on) async {
    await _prefs.setBool(_kPriceEnabled, on);
    notifyListeners();
  }

  /// Выбранный источник цены: 'pyaterochka' | 'kroger' | 'open_prices' |
  /// 'mercadona' | 'aldi' | 'wegmans'. По умолчанию 'pyaterochka'
  /// (наследует поведение пользователей 0.5.5, у которых был включён
  /// pref_pyat_enabled).
  String get priceSourceKind => _prefs.getString(_kPriceSource) ?? 'pyaterochka';

  Future<void> setPriceSourceKind(String kind) async {
    assert([
      'pyaterochka',
      'kroger',
      'open_prices',
      'mercadona',
      'aldi',
      'wegmans',
    ].contains(kind));
    await _prefs.setString(_kPriceSource, kind);
    notifyListeners();
  }

  /// SAP-код магазина Пятёрочки (4 символа, напр. «35XY») — цены этого
  /// магазина. Пусто — автоподстановка не работает.
  String get pyaterochkaStoreCode => _prefs.getString(_kPyatStoreCode) ?? '';

  Future<void> setPyaterochkaStoreCode(String code) async {
    await _prefs.setString(_kPyatStoreCode, code.trim());
    notifyListeners();
  }

  // ------------------------------- Kroger (США): ключи пользователя

  /// Client ID приложения пользователя (developer.kroger.com).
  String get krogerClientId => _prefs.getString(_kKrogerClientId) ?? '';

  Future<void> setKrogerClientId(String v) async {
    await _prefs.setString(_kKrogerClientId, v.trim());
    notifyListeners();
  }

  /// Client Secret приложения пользователя. Хранится только локально,
  /// никуда не отправляется кроме api.kroger.com (обмен на токен).
  String get krogerClientSecret => _prefs.getString(_kKrogerClientSecret) ?? '';

  Future<void> setKrogerClientSecret(String v) async {
    await _prefs.setString(_kKrogerClientSecret, v.trim());
    notifyListeners();
  }

  /// ZIP-код района пользователя (только запрос списка магазинов Kroger).
  String get krogerZip => _prefs.getString(_kKrogerZip) ?? '';

  Future<void> setKrogerZip(String v) async {
    await _prefs.setString(_kKrogerZip, v.trim());
    notifyListeners();
  }

  /// Выбранный магазин (locationId из Locations API). Пусто — не выбран.
  String get krogerLocationId => _prefs.getString(_kKrogerLocationId) ?? '';

  Future<void> setKrogerLocationId(String id, String label) async {
    await _prefs.setString(_kKrogerLocationId, id.trim());
    await _prefs.setString(_kKrogerLocationLabel, label);
    notifyListeners();
  }

  /// Человекочитаемое описание выбранного магазина («RALPHS — Ralphs…, …»).  
  String get krogerLocationLabel =>
      _prefs.getString(_kKrogerLocationLabel) ?? '';

  // ------------------------------- Wegmans (США): ключ пользователя

  /// Subscription key приложения пользователя (developer.wegmans.io).
  String get wegmansKey => _prefs.getString(_kWegmansKey) ?? '';

  Future<void> setWegmansKey(String v) async {
    await _prefs.setString(_kWegmansKey, v.trim());
    notifyListeners();
  }

  /// Номер выбранного магазина Wegmans (в путях цен). Пусто — не выбран.
  String get wegmansStoreNumber =>
      _prefs.getString(_kWegmansStoreNumber) ?? '';

  Future<void> setWegmansStore(String number, String label) async {
    await _prefs.setString(_kWegmansStoreNumber, number.trim());
    await _prefs.setString(_kWegmansStoreLabel, label);
    notifyListeners();
  }

  /// Человекочитаемое описание выбранного магазина («Wegmans — Pittsford…»).  
  String get wegmansStoreLabel => _prefs.getString(_kWegmansStoreLabel) ?? '';

  /// Готов ли источник цены к работе (без диалогов в форме продукта).
  bool get priceSourceReady {
    switch (priceSourceKind) {
      case 'pyaterochka':
        return pyaterochkaStoreCode.trim().isNotEmpty;
      case 'kroger':
        return krogerClientId.trim().isNotEmpty &&
            krogerClientSecret.trim().isNotEmpty &&
            krogerLocationId.trim().isNotEmpty;
      case 'open_prices':
      case 'mercadona':
      case 'aldi':
        return true; // ключей и настроек не требует
      case 'wegmans':
        return wegmansKey.trim().isNotEmpty &&
            wegmansStoreNumber.trim().isNotEmpty;
    }
    return false;
  }

  /// Загрузка предпочтений до runApp, чтобы не мигать темой при старте.
  static Future<SettingsController> load() async {
    final prefs = await SharedPreferences.getInstance();
    return SettingsController(prefs);
  }
}
