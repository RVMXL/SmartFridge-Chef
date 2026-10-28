/// Настройки приложения (тема, язык) — SharedPreferences, вне базы SQLite.
///
/// Профиль питания — доменные данные, им место в SQLite; оформление
/// и язык — предпочтения интерфейса, им место здесь. Решение описано
/// в docs/ARCHITECTURE.md.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Locale, ThemeMode;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsController extends ChangeNotifier {
  SettingsController(this._prefs, {FlutterSecureStorage? secureStorage})
      : _secure = secureStorage;

  final SharedPreferences _prefs;

  /// KEYS-1 (аудит 2026-10-28): секреты пользователя (client secret
  /// Kroger, subscription-key Wegmans) не должны лежать в plaintext-
  /// prefs. Хранятся во flutter_secure_storage (Android Keystore /
  /// iOS Keychain); в памяти держатся только в runtime-кэше [_secrets].
  /// null (тесты без плагина) — прозрачный фолбэк на prefs.
  final FlutterSecureStorage? _secure;
  final Map<String, String> _secrets = <String, String>{};

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
  String get krogerClientId => _secretOrPref(_kKrogerClientId);

  Future<void> setKrogerClientId(String v) =>
      _writeSecret(_kKrogerClientId, v.trim());

  /// Client Secret приложения пользователя. KEYS-1: хранится в
  /// flutter_secure_storage (не в plaintext-prefs), отправляется только
  /// на api.kroger.com (обмен на токен).
  String get krogerClientSecret => _secretOrPref(_kKrogerClientSecret);

  Future<void> setKrogerClientSecret(String v) =>
      _writeSecret(_kKrogerClientSecret, v.trim());

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
  /// KEYS-1: хранится во flutter_secure_storage (не в plaintext-prefs).
  String get wegmansKey => _secretOrPref(_kWegmansKey);

  Future<void> setWegmansKey(String v) => _writeSecret(_kWegmansKey, v.trim());

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

  // ------------------------- экспорт/импорт настроек (v0.6.3)

  /// Белый список ключей для конверта резервной копии: оформление, язык,
  /// напоминания, настройки источников цен. Секреты (KEYS-1:
  /// _kKrogerClientId, _kKrogerClientSecret, _kWegmansKey) в экспорт
  /// НЕ входят — открытый JSON им не место, после импорта вводятся заново.
  static const List<String> _backupPrefKeys = [
    _kThemeMode,
    _kLanguage,
    _kNotifEnabled,
    _kNotifDays,
    _kNotifHour,
    _kPriceEnabled,
    _kPriceSource,
    _kPyatStoreCode,
    _kKrogerZip,
    _kKrogerLocationId,
    _kKrogerLocationLabel,
    _kWegmansStoreNumber,
    _kWegmansStoreLabel,
  ];

  /// Срез не-секретных настроек для блока `settings` конверта.
  /// Значения — фактические типы prefs (String/bool/int); отсутствующие
  /// ключи (дефолты) не включаются — импорт оставит дефолты.
  Map<String, Object?> exportSettings() {
    final out = <String, Object?>{};
    for (final key in _backupPrefKeys) {
      final value = _prefs.get(key);
      if (value != null) out[key] = value;
    }
    return out;
  }

  /// Применяет блок `settings` из конверта. Неизвестные ключи и ключи вне
  /// белого списка (в т.ч. секреты — от рук/подделки) игнорируются.
  /// Значения enum-подобных ключей (тема, язык, источник цен) проверяются —
  /// мусор из файла не должен дойти до UI. Возвращает число применённых.
  Future<int> applyBackupSettings(Map<String, Object?> settings) async {
    var applied = 0;
    Future<void> put(String key, Object? value) async {
      switch (value) {
        case final String s:
          await _prefs.setString(key, s);
          applied++;
        case final bool b:
          await _prefs.setBool(key, b);
          applied++;
        case final int i:
          await _prefs.setInt(key, i);
          applied++;
        case final num n:
          // JSON может выдать 9.0 для int-ключа — нормализуем.
          await _prefs.setInt(key, n.round());
          applied++;
        default:
          break; // null/список/карта — не настройки prefs, пропускаем
      }
    }

    for (final entry in settings.entries) {
      final key = entry.key;
      if (!_backupPrefKeys.contains(key)) continue;
      final value = entry.value;
      // Санитизация enum-подобных ключей: неизвестное значение опасно
      // тем, что живёт в prefs дольше одной сессии.
      if (key == _kThemeMode &&
          ![_themeSystem, _themeLight, _themeDark].contains(value)) {
        continue;
      }
      if (key == _kLanguage &&
          !['system', 'ru', 'en'].contains(value)) {
        continue;
      }
      if (key == _kPriceSource &&
          ![
            'pyaterochka',
            'kroger',
            'open_prices',
            'mercadona',
            'aldi',
            'wegmans',
          ].contains(value)) {
        continue;
      }
      if (key == _kNotifHour) {
        final hour = value is int
            ? value
            : value is num
                ? value.round()
                : -1;
        if (hour < 0 || hour > 23) continue;
        await put(key, hour);
        continue;
      }
      await put(key, value);
    }
    notifyListeners();
    return applied;
  }

  /// Загрузка предпочтений до runApp, чтобы не мигать темой при старте.
  static Future<SettingsController> load() async {
    final prefs = await SharedPreferences.getInstance();
    final controller = SettingsController(
      prefs,
      secureStorage: const FlutterSecureStorage(),
    );
    await controller._loadSecrets();
    return controller;
  }

  // ------------------------- секреты: чтение/запись/миграция (KEYS-1)

  String _secretOrPref(String key) {
    final inMemory = _secrets[key];
    if (inMemory != null) return inMemory;
    // До миграции (или в тестовом фолбэке) значение может быть в prefs.
    return _prefs.getString(key) ?? '';
  }

  Future<void> _writeSecret(String key, String value) async {
    _secrets[key] = value;
    final secure = _secure;
    if (secure != null) {
      if (value.isEmpty) {
        await secure.delete(key: key);
      } else {
        await secure.write(key: key, value: value);
      }
      // Смыть plaintext-остаток из prefs (миграция/защита от возврата).
      if (_prefs.containsKey(key)) await _prefs.remove(key);
    } else {
      // Тестовый фолбэк без плагина: поведение как раньше.
      await _prefs.setString(key, value);
    }
    notifyListeners();
  }

  /// Однократная миграция при старте: секреты из prefs переезжают в
  /// secure storage, plaintext-копии удаляются.
  Future<void> _loadSecrets() async {
    final secure = _secure;
    if (secure == null) return;
    for (final key in const [
      _kKrogerClientId,
      _kKrogerClientSecret,
      _kWegmansKey,
    ]) {
      final stored = await secure.read(key: key);
      if (stored != null) {
        _secrets[key] = stored;
        if (_prefs.containsKey(key)) await _prefs.remove(key);
        continue;
      }
      final legacy = _prefs.getString(key);
      if (legacy != null && legacy.isNotEmpty) {
        _secrets[key] = legacy;
        await secure.write(key: key, value: legacy);
      }
      if (_prefs.containsKey(key)) await _prefs.remove(key);
    }
  }
}
