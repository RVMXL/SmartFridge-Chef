// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Smart Fridge & Chef Planner';

  @override
  String get tabFridge => 'Fridge';

  @override
  String get tabPlanner => 'Menu';

  @override
  String get tabSettings => 'Settings';

  @override
  String get fridgeTitle => 'My Fridge';

  @override
  String get fridgePlaceholderTitle => 'Screen at Step 3';

  @override
  String get fridgePlaceholderBody =>
      'The product list with colour-coded freshness will appear at Step 3. The data layer (Step 1) is already live — below is the real state of the local SQLite database.';

  @override
  String get fridgeEmpty =>
      'The fridge is empty. Products will be added by barcode scanning or quick manual input.';

  @override
  String get statActive => 'In the fridge';

  @override
  String statExpiring(int days) {
    return 'Expiring soon (≤ $days days)';
  }

  @override
  String get statExpired => 'Already expired';

  @override
  String get plannerTitle => 'My Menu';

  @override
  String get plannerPlaceholderTitle => 'Superplanner — Steps 2–3';

  @override
  String get plannerPlaceholderBody =>
      'A weekly menu generated on-device from the fridge contents, your nutrition profile and regional seasonality. Implemented after Step 1 is confirmed.';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsAppearance => 'Appearance';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get langSystem => 'System';

  @override
  String get langRussian => 'Русский';

  @override
  String get langEnglish => 'English';

  @override
  String get settingsAbout => 'About';

  @override
  String get settingsVersion => 'Version';

  @override
  String get settingsStage => 'Development stage';

  @override
  String get stageCurrent => 'Step 1 of 3 — local database and data layer';

  @override
  String get settingsOffline =>
      'Offline-first: all data stays on this device. No analytics, no servers, no accounts.';

  @override
  String get dbOpenError => 'Failed to open the local database';

  @override
  String get retry => 'Retry';

  @override
  String get freshnessFresh => 'Fresh';

  @override
  String get freshnessExpiring => 'Expiring soon';

  @override
  String get freshnessExpired => 'Expired';
}
