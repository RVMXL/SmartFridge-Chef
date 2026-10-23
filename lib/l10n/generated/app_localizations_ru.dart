// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appTitle => 'Умный Холодильник & Шеф-Планер';

  @override
  String get tabFridge => 'Холодильник';

  @override
  String get tabPlanner => 'Меню';

  @override
  String get tabSettings => 'Настройки';

  @override
  String get fridgeTitle => 'Мой холодильник';

  @override
  String get fridgePlaceholderTitle => 'Экран — Шаг 3';

  @override
  String get fridgePlaceholderBody =>
      'Список продуктов с цветовой индикацией свежести появится на Шаге 3. Слой данных (Шаг 1) уже работает — ниже реальное состояние локальной базы SQLite.';

  @override
  String get fridgeEmpty =>
      'Холодильник пуст. Продукты будут добавляться сканированием штрих-кода или быстрым ручным вводом.';

  @override
  String get statActive => 'В холодильнике';

  @override
  String statExpiring(int days) {
    return 'Истекает (≤ $days дн.)';
  }

  @override
  String get statExpired => 'Просрочено';

  @override
  String get plannerTitle => 'Мое меню';

  @override
  String get plannerPlaceholderTitle => 'Суперпланер — Шаги 2–3';

  @override
  String get plannerPlaceholderBody =>
      'Меню на неделю, генерируемое на устройстве из содержимого холодильника, вашего профиля питания и сезонности региона. Реализуется после подтверждения Шага 1.';

  @override
  String get settingsTitle => 'Настройки';

  @override
  String get settingsAppearance => 'Оформление';

  @override
  String get themeSystem => 'Системная';

  @override
  String get themeLight => 'Светлая';

  @override
  String get themeDark => 'Тёмная';

  @override
  String get settingsLanguage => 'Язык';

  @override
  String get langSystem => 'Системный';

  @override
  String get langRussian => 'Русский';

  @override
  String get langEnglish => 'English';

  @override
  String get settingsAbout => 'О приложении';

  @override
  String get settingsVersion => 'Версия';

  @override
  String get settingsStage => 'Стадия разработки';

  @override
  String get stageCurrent => 'Шаг 1 из 3 — локальная база данных и слой данных';

  @override
  String get settingsOffline =>
      'Offline-first: все данные остаются на устройстве. Без аналитики, серверов и аккаунтов.';

  @override
  String get dbOpenError => 'Не удалось открыть локальную базу данных';

  @override
  String get retry => 'Повторить';

  @override
  String get freshnessFresh => 'Свежий';

  @override
  String get freshnessExpiring => 'Истекает';

  @override
  String get freshnessExpired => 'Просрочен';
}
