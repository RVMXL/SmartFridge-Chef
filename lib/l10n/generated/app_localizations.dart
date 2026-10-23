import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ru.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ru'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Smart Fridge & Chef Planner'**
  String get appTitle;

  /// No description provided for @tabFridge.
  ///
  /// In en, this message translates to:
  /// **'Fridge'**
  String get tabFridge;

  /// No description provided for @tabPlanner.
  ///
  /// In en, this message translates to:
  /// **'Menu'**
  String get tabPlanner;

  /// No description provided for @tabSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get tabSettings;

  /// No description provided for @fridgeTitle.
  ///
  /// In en, this message translates to:
  /// **'My Fridge'**
  String get fridgeTitle;

  /// No description provided for @fridgePlaceholderTitle.
  ///
  /// In en, this message translates to:
  /// **'Screen at Step 3'**
  String get fridgePlaceholderTitle;

  /// No description provided for @fridgePlaceholderBody.
  ///
  /// In en, this message translates to:
  /// **'The product list with colour-coded freshness will appear at Step 3. The data layer (Step 1) is already live — below is the real state of the local SQLite database.'**
  String get fridgePlaceholderBody;

  /// No description provided for @fridgeEmpty.
  ///
  /// In en, this message translates to:
  /// **'The fridge is empty. Products will be added by barcode scanning or quick manual input.'**
  String get fridgeEmpty;

  /// No description provided for @statActive.
  ///
  /// In en, this message translates to:
  /// **'In the fridge'**
  String get statActive;

  /// No description provided for @statExpiring.
  ///
  /// In en, this message translates to:
  /// **'Expiring soon (≤ {days} days)'**
  String statExpiring(int days);

  /// No description provided for @statExpired.
  ///
  /// In en, this message translates to:
  /// **'Already expired'**
  String get statExpired;

  /// No description provided for @plannerTitle.
  ///
  /// In en, this message translates to:
  /// **'My Menu'**
  String get plannerTitle;

  /// No description provided for @plannerPlaceholderTitle.
  ///
  /// In en, this message translates to:
  /// **'Superplanner — Steps 2–3'**
  String get plannerPlaceholderTitle;

  /// No description provided for @plannerPlaceholderBody.
  ///
  /// In en, this message translates to:
  /// **'A weekly menu generated on-device from the fridge contents, your nutrition profile and regional seasonality. Implemented after Step 1 is confirmed.'**
  String get plannerPlaceholderBody;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsAppearance;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// No description provided for @langSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get langSystem;

  /// No description provided for @langRussian.
  ///
  /// In en, this message translates to:
  /// **'Русский'**
  String get langRussian;

  /// No description provided for @langEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get langEnglish;

  /// No description provided for @settingsAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsAbout;

  /// No description provided for @settingsVersion.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get settingsVersion;

  /// No description provided for @settingsStage.
  ///
  /// In en, this message translates to:
  /// **'Development stage'**
  String get settingsStage;

  /// No description provided for @stageCurrent.
  ///
  /// In en, this message translates to:
  /// **'Step 1 of 3 — local database and data layer'**
  String get stageCurrent;

  /// No description provided for @settingsOffline.
  ///
  /// In en, this message translates to:
  /// **'Offline-first: all data stays on this device. No analytics, no servers, no accounts.'**
  String get settingsOffline;

  /// No description provided for @dbOpenError.
  ///
  /// In en, this message translates to:
  /// **'Failed to open the local database'**
  String get dbOpenError;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @freshnessFresh.
  ///
  /// In en, this message translates to:
  /// **'Fresh'**
  String get freshnessFresh;

  /// No description provided for @freshnessExpiring.
  ///
  /// In en, this message translates to:
  /// **'Expiring soon'**
  String get freshnessExpiring;

  /// No description provided for @freshnessExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get freshnessExpired;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ru'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ru':
      return AppLocalizationsRu();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
