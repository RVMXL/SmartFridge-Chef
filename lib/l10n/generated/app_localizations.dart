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
  /// **'Screen — Step 3'**
  String get fridgePlaceholderTitle;

  /// No description provided for @fridgePlaceholderBody.
  ///
  /// In en, this message translates to:
  /// **'The product list with freshness color coding will appear in Step 3. The data layer (Step 1) already works — below is the real state of the local SQLite database.'**
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
  /// **'Expiring (≤ {days} d.)'**
  String statExpiring(int days);

  /// No description provided for @statExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get statExpired;

  /// No description provided for @plannerTitle.
  ///
  /// In en, this message translates to:
  /// **'My Menu'**
  String get plannerTitle;

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
  /// **'Done: barcode auto-lookup, offline planner, scanner, expiry notifications (v0.4.0)'**
  String get stageCurrent;

  /// No description provided for @settingsOffline.
  ///
  /// In en, this message translates to:
  /// **'Offline-first: all data stays on the device. No analytics, servers or accounts.'**
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
  /// **'Expiring'**
  String get freshnessExpiring;

  /// No description provided for @freshnessExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get freshnessExpired;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// No description provided for @commonDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commonDelete;

  /// No description provided for @commonAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get commonAdd;

  /// No description provided for @commonDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get commonDone;

  /// No description provided for @commonClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get commonClose;

  /// No description provided for @commonError.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get commonError;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search by name'**
  String get searchHint;

  /// No description provided for @sortTooltip.
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get sortTooltip;

  /// No description provided for @sortExpiry.
  ///
  /// In en, this message translates to:
  /// **'By expiry date'**
  String get sortExpiry;

  /// No description provided for @sortName.
  ///
  /// In en, this message translates to:
  /// **'By name'**
  String get sortName;

  /// No description provided for @sortCategory.
  ///
  /// In en, this message translates to:
  /// **'By category'**
  String get sortCategory;

  /// No description provided for @emptySearchTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing found'**
  String get emptySearchTitle;

  /// No description provided for @emptySearchBody.
  ///
  /// In en, this message translates to:
  /// **'Try a different query — the fridge list is empty.'**
  String get emptySearchBody;

  /// No description provided for @fridgeAddTooltip.
  ///
  /// In en, this message translates to:
  /// **'Add products'**
  String get fridgeAddTooltip;

  /// No description provided for @fridgeEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'The fridge is empty'**
  String get fridgeEmptyTitle;

  /// No description provided for @fridgeEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Add your first product: scan a barcode, photograph a receipt or type it manually.'**
  String get fridgeEmptyBody;

  /// No description provided for @fridgeAddBarcode.
  ///
  /// In en, this message translates to:
  /// **'Scan barcode'**
  String get fridgeAddBarcode;

  /// No description provided for @fridgeAddReceipt.
  ///
  /// In en, this message translates to:
  /// **'Receipt photo (OCR)'**
  String get fridgeAddReceipt;

  /// No description provided for @fridgeAddManual.
  ///
  /// In en, this message translates to:
  /// **'Enter manually'**
  String get fridgeAddManual;

  /// No description provided for @fridgeLegend.
  ///
  /// In en, this message translates to:
  /// **'Freshness legend'**
  String get fridgeLegend;

  /// No description provided for @swipeHint.
  ///
  /// In en, this message translates to:
  /// **'Swipe a card to mark it as eaten or discarded.'**
  String get swipeHint;

  /// No description provided for @daysLeft.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =0{expires today} =1{1 day left} other{{days} days left}}'**
  String daysLeft(int days);

  /// No description provided for @expiryOn.
  ///
  /// In en, this message translates to:
  /// **'Expiry: {date}'**
  String expiryOn(String date);

  /// No description provided for @actionAte.
  ///
  /// In en, this message translates to:
  /// **'Ate it'**
  String get actionAte;

  /// No description provided for @actionDiscard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get actionDiscard;

  /// No description provided for @actionDeleted.
  ///
  /// In en, this message translates to:
  /// **'Deleted'**
  String get actionDeleted;

  /// No description provided for @snackbarUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get snackbarUndo;

  /// No description provided for @confirmDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete product?'**
  String get confirmDeleteTitle;

  /// No description provided for @confirmDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'“{name}” will disappear from the fridge without a trace in the history.'**
  String confirmDeleteBody(String name);

  /// No description provided for @duplicateTitle.
  ///
  /// In en, this message translates to:
  /// **'Already in the fridge'**
  String get duplicateTitle;

  /// No description provided for @duplicateBody.
  ///
  /// In en, this message translates to:
  /// **'“{name}” is already on the shelf (until {date}). Add another one — we will increase the quantity.'**
  String duplicateBody(String name, String date);

  /// No description provided for @duplicateAddOne.
  ///
  /// In en, this message translates to:
  /// **'Add +1'**
  String get duplicateAddOne;

  /// No description provided for @duplicateOpen.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get duplicateOpen;

  /// No description provided for @productNew.
  ///
  /// In en, this message translates to:
  /// **'New product'**
  String get productNew;

  /// No description provided for @productEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit product'**
  String get productEditTitle;

  /// No description provided for @productFieldName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get productFieldName;

  /// No description provided for @productNameHint.
  ///
  /// In en, this message translates to:
  /// **'For example, Milk 3.2%'**
  String get productNameHint;

  /// No description provided for @productFieldCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get productFieldCategory;

  /// No description provided for @productFieldQuantity.
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get productFieldQuantity;

  /// No description provided for @productFieldExpiry.
  ///
  /// In en, this message translates to:
  /// **'Expiry date'**
  String get productFieldExpiry;

  /// No description provided for @productExpiryPick.
  ///
  /// In en, this message translates to:
  /// **'Pick a date'**
  String get productExpiryPick;

  /// No description provided for @productQuickPlus2.
  ///
  /// In en, this message translates to:
  /// **'+2 days'**
  String get productQuickPlus2;

  /// No description provided for @productQuickPlus7.
  ///
  /// In en, this message translates to:
  /// **'+7 days'**
  String get productQuickPlus7;

  /// No description provided for @productDefaultShelf.
  ///
  /// In en, this message translates to:
  /// **'Typical shelf life: {days} days'**
  String productDefaultShelf(int days);

  /// No description provided for @productFieldBarcode.
  ///
  /// In en, this message translates to:
  /// **'Barcode'**
  String get productFieldBarcode;

  /// No description provided for @productBarcodeEmpty.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get productBarcodeEmpty;

  /// No description provided for @productFieldNotes.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get productFieldNotes;

  /// No description provided for @productNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a name'**
  String get productNameRequired;

  /// No description provided for @productSaveError.
  ///
  /// In en, this message translates to:
  /// **'Failed to save the product'**
  String get productSaveError;

  /// No description provided for @scanTitle.
  ///
  /// In en, this message translates to:
  /// **'Barcode scanner'**
  String get scanTitle;

  /// No description provided for @scanHint.
  ///
  /// In en, this message translates to:
  /// **'Point the camera at the product barcode'**
  String get scanHint;

  /// No description provided for @scanManualEntry.
  ///
  /// In en, this message translates to:
  /// **'Enter the code manually'**
  String get scanManualEntry;

  /// No description provided for @scanManualHint.
  ///
  /// In en, this message translates to:
  /// **'Barcode'**
  String get scanManualHint;

  /// No description provided for @scanInvalidCode.
  ///
  /// In en, this message translates to:
  /// **'The code was not recognized'**
  String get scanInvalidCode;

  /// No description provided for @scanCameraError.
  ///
  /// In en, this message translates to:
  /// **'Camera unavailable. Check the permission or enter the code manually.'**
  String get scanCameraError;

  /// No description provided for @scanLookupWaiting.
  ///
  /// In en, this message translates to:
  /// **'Searching the open product database…'**
  String get scanLookupWaiting;

  /// No description provided for @scanLookupMiss.
  ///
  /// In en, this message translates to:
  /// **'Not found in the open database — fill in manually'**
  String get scanLookupMiss;

  /// No description provided for @receiptTitle.
  ///
  /// In en, this message translates to:
  /// **'Products from the receipt'**
  String get receiptTitle;

  /// No description provided for @receiptPickCamera.
  ///
  /// In en, this message translates to:
  /// **'Photograph the receipt'**
  String get receiptPickCamera;

  /// No description provided for @receiptPickGallery.
  ///
  /// In en, this message translates to:
  /// **'Pick a photo from the gallery'**
  String get receiptPickGallery;

  /// No description provided for @receiptRecognizing.
  ///
  /// In en, this message translates to:
  /// **'Recognizing text…'**
  String get receiptRecognizing;

  /// No description provided for @receiptFound.
  ///
  /// In en, this message translates to:
  /// **'Items found: {count}'**
  String receiptFound(int count);

  /// No description provided for @receiptNotFound.
  ///
  /// In en, this message translates to:
  /// **'Could not recognize any items. Try a sharper photo or add products manually.'**
  String get receiptNotFound;

  /// No description provided for @receiptOcrNote.
  ///
  /// In en, this message translates to:
  /// **'Receipt OCR recognizes Latin script; Cyrillic receipts may fail — enter items manually.'**
  String get receiptOcrNote;

  /// No description provided for @receiptEditHint.
  ///
  /// In en, this message translates to:
  /// **'Check the names — OCR can be wrong. Uncheck the lines you do not need.'**
  String get receiptEditHint;

  /// No description provided for @receiptAddSelected.
  ///
  /// In en, this message translates to:
  /// **'Add selected ({count})'**
  String receiptAddSelected(int count);

  /// No description provided for @receiptAdded.
  ///
  /// In en, this message translates to:
  /// **'Items added: {count}'**
  String receiptAdded(int count);

  /// No description provided for @menuGenerate.
  ///
  /// In en, this message translates to:
  /// **'Superplanner: weekly menu'**
  String get menuGenerate;

  /// No description provided for @menuGenerateShort.
  ///
  /// In en, this message translates to:
  /// **'Generate menu'**
  String get menuGenerateShort;

  /// No description provided for @menuGenerating.
  ///
  /// In en, this message translates to:
  /// **'Assembling the menu…'**
  String get menuGenerating;

  /// No description provided for @menuRegenerate.
  ///
  /// In en, this message translates to:
  /// **'Another option'**
  String get menuRegenerate;

  /// No description provided for @menuSavePlan.
  ///
  /// In en, this message translates to:
  /// **'Save plan'**
  String get menuSavePlan;

  /// No description provided for @menuSaved.
  ///
  /// In en, this message translates to:
  /// **'Plan saved'**
  String get menuSaved;

  /// No description provided for @menuShopping.
  ///
  /// In en, this message translates to:
  /// **'Shopping list'**
  String get menuShopping;

  /// No description provided for @menuHistory.
  ///
  /// In en, this message translates to:
  /// **'Plan history'**
  String get menuHistory;

  /// No description provided for @menuKcalPerDay.
  ///
  /// In en, this message translates to:
  /// **'~{kcal} kcal/day'**
  String menuKcalPerDay(int kcal);

  /// No description provided for @menuTarget.
  ///
  /// In en, this message translates to:
  /// **'Target: {kcal} kcal'**
  String menuTarget(int kcal);

  /// No description provided for @menuUsesExpiring.
  ///
  /// In en, this message translates to:
  /// **'Eat first: {items}'**
  String menuUsesExpiring(String items);

  /// No description provided for @menuEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'The menu is not assembled yet'**
  String get menuEmptyTitle;

  /// No description provided for @menuEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'The Superplanner looks into your fridge, takes calories, diet, allergies and seasonality into account — and assembles a 7-day menu right on the device.'**
  String get menuEmptyBody;

  /// No description provided for @menuPlanError.
  ///
  /// In en, this message translates to:
  /// **'Failed to assemble the menu'**
  String get menuPlanError;

  /// No description provided for @menuDraftBadge.
  ///
  /// In en, this message translates to:
  /// **'Draft'**
  String get menuDraftBadge;

  /// No description provided for @menuSavedBadge.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get menuSavedBadge;

  /// No description provided for @menuHistoryEmpty.
  ///
  /// In en, this message translates to:
  /// **'No saved plans yet'**
  String get menuHistoryEmpty;

  /// No description provided for @menuDeletePlan.
  ///
  /// In en, this message translates to:
  /// **'Delete plan'**
  String get menuDeletePlan;

  /// No description provided for @menuCookMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String menuCookMinutes(int minutes);

  /// No description provided for @menuServings.
  ///
  /// In en, this message translates to:
  /// **'{count} servings'**
  String menuServings(int count);

  /// No description provided for @menuIngredients.
  ///
  /// In en, this message translates to:
  /// **'Ingredients'**
  String get menuIngredients;

  /// No description provided for @menuSteps.
  ///
  /// In en, this message translates to:
  /// **'Cooking'**
  String get menuSteps;

  /// No description provided for @menuWeekOf.
  ///
  /// In en, this message translates to:
  /// **'Week of {date}'**
  String menuWeekOf(String date);

  /// No description provided for @shoppingTitle.
  ///
  /// In en, this message translates to:
  /// **'Shopping list'**
  String get shoppingTitle;

  /// No description provided for @shoppingFromPlan.
  ///
  /// In en, this message translates to:
  /// **'From the weekly menu plan'**
  String get shoppingFromPlan;

  /// No description provided for @shoppingEmpty.
  ///
  /// In en, this message translates to:
  /// **'Everything you need is already in the fridge — nothing to buy.'**
  String get shoppingEmpty;

  /// No description provided for @shoppingChecked.
  ///
  /// In en, this message translates to:
  /// **'Bought: {done} of {total}'**
  String shoppingChecked(int done, int total);

  /// No description provided for @shoppingClearChecked.
  ///
  /// In en, this message translates to:
  /// **'Remove bought'**
  String get shoppingClearChecked;

  /// No description provided for @shoppingNoPlan.
  ///
  /// In en, this message translates to:
  /// **'Assemble the menu first — the missing-ingredients list will appear here.'**
  String get shoppingNoPlan;

  /// No description provided for @settingsProfile.
  ///
  /// In en, this message translates to:
  /// **'Nutrition profile'**
  String get settingsProfile;

  /// No description provided for @profileTitle.
  ///
  /// In en, this message translates to:
  /// **'Nutrition profile'**
  String get profileTitle;

  /// No description provided for @profileCalories.
  ///
  /// In en, this message translates to:
  /// **'Daily calories, kcal'**
  String get profileCalories;

  /// No description provided for @profileBju.
  ///
  /// In en, this message translates to:
  /// **'Macros, g/day'**
  String get profileBju;

  /// No description provided for @profileProtein.
  ///
  /// In en, this message translates to:
  /// **'Protein'**
  String get profileProtein;

  /// No description provided for @profileFat.
  ///
  /// In en, this message translates to:
  /// **'Fat'**
  String get profileFat;

  /// No description provided for @profileCarbs.
  ///
  /// In en, this message translates to:
  /// **'Carbs'**
  String get profileCarbs;

  /// No description provided for @profileAutoBju.
  ///
  /// In en, this message translates to:
  /// **'Recalculate 30/30/40'**
  String get profileAutoBju;

  /// No description provided for @profileDiet.
  ///
  /// In en, this message translates to:
  /// **'Diet'**
  String get profileDiet;

  /// No description provided for @profileAllergies.
  ///
  /// In en, this message translates to:
  /// **'Allergies and intolerances'**
  String get profileAllergies;

  /// No description provided for @profileMedicalDiets.
  ///
  /// In en, this message translates to:
  /// **'Medical diets (Pevzner tables)'**
  String get profileMedicalDiets;

  /// No description provided for @profileMedicalDietsHint.
  ///
  /// In en, this message translates to:
  /// **'The menu will exclude meals with restricted foods. A table is prescribed by a doctor — confirm your choice with them'**
  String get profileMedicalDietsHint;

  /// No description provided for @profileMedicalDietsAbout.
  ///
  /// In en, this message translates to:
  /// **'What the tables mean'**
  String get profileMedicalDietsAbout;

  /// No description provided for @medicalDietsDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Pevzner dietary tables'**
  String get medicalDietsDialogTitle;

  /// No description provided for @medicalDietsForbiddenLabel.
  ///
  /// In en, this message translates to:
  /// **'Excludes:'**
  String get medicalDietsForbiddenLabel;

  /// No description provided for @medicalDietsNoRestrictions.
  ///
  /// In en, this message translates to:
  /// **'No restrictions in the recipe base'**
  String get medicalDietsNoRestrictions;

  /// No description provided for @medicalDietsDialogFooter.
  ///
  /// In en, this message translates to:
  /// **'Descriptions are for reference only and do not replace your doctor\'s instructions'**
  String get medicalDietsDialogFooter;

  /// No description provided for @profileMealsPerDay.
  ///
  /// In en, this message translates to:
  /// **'Meals per day'**
  String get profileMealsPerDay;

  /// No description provided for @profileSaved.
  ///
  /// In en, this message translates to:
  /// **'Profile saved'**
  String get profileSaved;

  /// No description provided for @profileOpen.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get profileOpen;

  /// No description provided for @profileNone.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get profileNone;

  /// No description provided for @settingsNotifications.
  ///
  /// In en, this message translates to:
  /// **'Expiry reminders'**
  String get settingsNotifications;

  /// No description provided for @notifEnable.
  ///
  /// In en, this message translates to:
  /// **'Send notifications'**
  String get notifEnable;

  /// No description provided for @notifDays.
  ///
  /// In en, this message translates to:
  /// **'Warn in advance'**
  String get notifDays;

  /// No description provided for @notifDaysOpt2.
  ///
  /// In en, this message translates to:
  /// **'2 days ahead'**
  String get notifDaysOpt2;

  /// No description provided for @notifDaysOpt1.
  ///
  /// In en, this message translates to:
  /// **'1 day ahead'**
  String get notifDaysOpt1;

  /// No description provided for @notifHour.
  ///
  /// In en, this message translates to:
  /// **'Reminder time'**
  String get notifHour;

  /// No description provided for @notifHourAt.
  ///
  /// In en, this message translates to:
  /// **'At {hour}:00'**
  String notifHourAt(int hour);

  /// No description provided for @notifPermissionHint.
  ///
  /// In en, this message translates to:
  /// **'If notifications do not arrive — check the system permissions and battery optimization settings.'**
  String get notifPermissionHint;

  /// No description provided for @onbWelcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Smart Fridge\n& Chef Planner'**
  String get onbWelcomeTitle;

  /// No description provided for @onbWelcomeBody.
  ///
  /// In en, this message translates to:
  /// **'We track expiry dates and assemble a weekly menu from what is already in your fridge. Everything offline.'**
  String get onbWelcomeBody;

  /// No description provided for @onbStart.
  ///
  /// In en, this message translates to:
  /// **'Start setup'**
  String get onbStart;

  /// No description provided for @onbStep1Title.
  ///
  /// In en, this message translates to:
  /// **'How much do you eat per day?'**
  String get onbStep1Title;

  /// No description provided for @onbStep2Title.
  ///
  /// In en, this message translates to:
  /// **'Diet and allergies'**
  String get onbStep2Title;

  /// No description provided for @onbStep2Body.
  ///
  /// In en, this message translates to:
  /// **'The planner will exclude unsuitable recipes.'**
  String get onbStep2Body;

  /// No description provided for @onbStep3Title.
  ///
  /// In en, this message translates to:
  /// **'Routine and reminders'**
  String get onbStep3Title;

  /// No description provided for @onbStep3Body.
  ///
  /// In en, this message translates to:
  /// **'Notifications arrive 1–2 days before the expiry date.'**
  String get onbStep3Body;

  /// No description provided for @onbFinish.
  ///
  /// In en, this message translates to:
  /// **'Done — to the fridge!'**
  String get onbFinish;

  /// No description provided for @onbSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get onbSkip;

  /// No description provided for @onbNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get onbNext;

  /// No description provided for @dietNone.
  ///
  /// In en, this message translates to:
  /// **'No restrictions'**
  String get dietNone;

  /// No description provided for @dietVegetarian.
  ///
  /// In en, this message translates to:
  /// **'Vegetarian'**
  String get dietVegetarian;

  /// No description provided for @dietVegan.
  ///
  /// In en, this message translates to:
  /// **'Vegan'**
  String get dietVegan;

  /// No description provided for @dietLent.
  ///
  /// In en, this message translates to:
  /// **'Fasting'**
  String get dietLent;

  /// No description provided for @dietPescatarian.
  ///
  /// In en, this message translates to:
  /// **'Pescatarian'**
  String get dietPescatarian;

  /// No description provided for @dietLowCarb.
  ///
  /// In en, this message translates to:
  /// **'Low-carb'**
  String get dietLowCarb;

  /// No description provided for @dietHalal.
  ///
  /// In en, this message translates to:
  /// **'Halal (Muslim)'**
  String get dietHalal;

  /// No description provided for @dietKosher.
  ///
  /// In en, this message translates to:
  /// **'Kosher (Jewish)'**
  String get dietKosher;

  /// No description provided for @dietHindu.
  ///
  /// In en, this message translates to:
  /// **'No beef (Hindu)'**
  String get dietHindu;

  /// No description provided for @profileDietMultipleHint.
  ///
  /// In en, this message translates to:
  /// **'Select several — restrictions combine'**
  String get profileDietMultipleHint;

  /// No description provided for @planExcludedTitle.
  ///
  /// In en, this message translates to:
  /// **'Why some recipes are not in the menu'**
  String get planExcludedTitle;

  /// No description provided for @planExcludedSummary.
  ///
  /// In en, this message translates to:
  /// **'Excluded during planning: {n}'**
  String planExcludedSummary(Object n);

  /// No description provided for @shareMenuTitle.
  ///
  /// In en, this message translates to:
  /// **'Share products'**
  String get shareMenuTitle;

  /// No description provided for @shareShowQr.
  ///
  /// In en, this message translates to:
  /// **'Show QR code'**
  String get shareShowQr;

  /// No description provided for @shareShowQrHint.
  ///
  /// In en, this message translates to:
  /// **'Send the list to another phone'**
  String get shareShowQrHint;

  /// No description provided for @shareReceiveQr.
  ///
  /// In en, this message translates to:
  /// **'Receive via QR'**
  String get shareReceiveQr;

  /// No description provided for @shareReceiveQrHint.
  ///
  /// In en, this message translates to:
  /// **'Scan another person\'s codes'**
  String get shareReceiveQrHint;

  /// No description provided for @shareQrTitle.
  ///
  /// In en, this message translates to:
  /// **'Share products'**
  String get shareQrTitle;

  /// No description provided for @shareQrHint.
  ///
  /// In en, this message translates to:
  /// **'Point the other phone\'s camera at this screen. Pages advance automatically — keep the devices facing each other until the transfer completes.'**
  String get shareQrHint;

  /// No description provided for @shareQrPage.
  ///
  /// In en, this message translates to:
  /// **'Page {i} of {n}'**
  String shareQrPage(Object i, Object n);

  /// No description provided for @shareQrSingle.
  ///
  /// In en, this message translates to:
  /// **'Single code — one scan is enough'**
  String get shareQrSingle;

  /// No description provided for @shareQrAuto.
  ///
  /// In en, this message translates to:
  /// **'Auto-advance'**
  String get shareQrAuto;

  /// No description provided for @shareQrEmpty.
  ///
  /// In en, this message translates to:
  /// **'No active products to share'**
  String get shareQrEmpty;

  /// No description provided for @shareQrTooBig.
  ///
  /// In en, this message translates to:
  /// **'Too many products even for a QR series (limit is 255 pages). Remove some items and try again.'**
  String get shareQrTooBig;

  /// No description provided for @receiveQrTitle.
  ///
  /// In en, this message translates to:
  /// **'Receive products'**
  String get receiveQrTitle;

  /// No description provided for @receiveQrWaiting.
  ///
  /// In en, this message translates to:
  /// **'Point the camera at the other phone\'s QR codes. Each code counts once — duplicates are harmless.'**
  String get receiveQrWaiting;

  /// No description provided for @receiveQrProgress.
  ///
  /// In en, this message translates to:
  /// **'Received {a} of {n}'**
  String receiveQrProgress(Object a, Object n);

  /// No description provided for @receiveQrConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Add {n} products?'**
  String receiveQrConfirmTitle(Object n);

  /// No description provided for @receiveQrConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'List starts with: {names}{more, plural, =0{} other{ … and {more} more}}'**
  String receiveQrConfirmBody(num more, Object names);

  /// No description provided for @receiveQrDone.
  ///
  /// In en, this message translates to:
  /// **'Added: {added}. Duplicates skipped: {skipped}'**
  String receiveQrDone(Object added, Object skipped);

  /// No description provided for @receiveQrBroken.
  ///
  /// In en, this message translates to:
  /// **'QR code is damaged — transfer restarts'**
  String get receiveQrBroken;

  /// No description provided for @receiveQrEmpty.
  ///
  /// In en, this message translates to:
  /// **'The transfer contains no products'**
  String get receiveQrEmpty;

  /// No description provided for @allergenMilk.
  ///
  /// In en, this message translates to:
  /// **'Milk'**
  String get allergenMilk;

  /// No description provided for @allergenEggs.
  ///
  /// In en, this message translates to:
  /// **'Eggs'**
  String get allergenEggs;

  /// No description provided for @allergenFish.
  ///
  /// In en, this message translates to:
  /// **'Fish'**
  String get allergenFish;

  /// No description provided for @allergenCrustaceans.
  ///
  /// In en, this message translates to:
  /// **'Crustaceans (shrimp, crab)'**
  String get allergenCrustaceans;

  /// No description provided for @allergenMolluscs.
  ///
  /// In en, this message translates to:
  /// **'Molluscs (mussels, squid, oysters)'**
  String get allergenMolluscs;

  /// No description provided for @allergenNuts.
  ///
  /// In en, this message translates to:
  /// **'Nuts'**
  String get allergenNuts;

  /// No description provided for @allergenPeanuts.
  ///
  /// In en, this message translates to:
  /// **'Peanuts'**
  String get allergenPeanuts;

  /// No description provided for @allergenSoy.
  ///
  /// In en, this message translates to:
  /// **'Soy'**
  String get allergenSoy;

  /// No description provided for @allergenWheat.
  ///
  /// In en, this message translates to:
  /// **'Wheat / gluten'**
  String get allergenWheat;

  /// No description provided for @allergenSesame.
  ///
  /// In en, this message translates to:
  /// **'Sesame'**
  String get allergenSesame;

  /// No description provided for @catDairy.
  ///
  /// In en, this message translates to:
  /// **'Dairy'**
  String get catDairy;

  /// No description provided for @catMeat.
  ///
  /// In en, this message translates to:
  /// **'Meat'**
  String get catMeat;

  /// No description provided for @catFish.
  ///
  /// In en, this message translates to:
  /// **'Fish'**
  String get catFish;

  /// No description provided for @catVegetables.
  ///
  /// In en, this message translates to:
  /// **'Vegetables'**
  String get catVegetables;

  /// No description provided for @catFruits.
  ///
  /// In en, this message translates to:
  /// **'Fruits'**
  String get catFruits;

  /// No description provided for @catBakery.
  ///
  /// In en, this message translates to:
  /// **'Bakery'**
  String get catBakery;

  /// No description provided for @catGrains.
  ///
  /// In en, this message translates to:
  /// **'Grains'**
  String get catGrains;

  /// No description provided for @catFrozen.
  ///
  /// In en, this message translates to:
  /// **'Frozen'**
  String get catFrozen;

  /// No description provided for @catBeverages.
  ///
  /// In en, this message translates to:
  /// **'Beverages'**
  String get catBeverages;

  /// No description provided for @catSweets.
  ///
  /// In en, this message translates to:
  /// **'Sweets'**
  String get catSweets;

  /// No description provided for @catCondiments.
  ///
  /// In en, this message translates to:
  /// **'Condiments'**
  String get catCondiments;

  /// No description provided for @catOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get catOther;

  /// No description provided for @unitPcs.
  ///
  /// In en, this message translates to:
  /// **'pcs'**
  String get unitPcs;

  /// No description provided for @unitGram.
  ///
  /// In en, this message translates to:
  /// **'g'**
  String get unitGram;

  /// No description provided for @unitKilogram.
  ///
  /// In en, this message translates to:
  /// **'kg'**
  String get unitKilogram;

  /// No description provided for @unitMilliliter.
  ///
  /// In en, this message translates to:
  /// **'ml'**
  String get unitMilliliter;

  /// No description provided for @unitLiter.
  ///
  /// In en, this message translates to:
  /// **'l'**
  String get unitLiter;

  /// No description provided for @unitPack.
  ///
  /// In en, this message translates to:
  /// **'pack'**
  String get unitPack;

  /// No description provided for @slotBreakfast.
  ///
  /// In en, this message translates to:
  /// **'Breakfast'**
  String get slotBreakfast;

  /// No description provided for @slotSnack.
  ///
  /// In en, this message translates to:
  /// **'Snack'**
  String get slotSnack;

  /// No description provided for @slotLunch.
  ///
  /// In en, this message translates to:
  /// **'Lunch'**
  String get slotLunch;

  /// No description provided for @slotDinner.
  ///
  /// In en, this message translates to:
  /// **'Dinner'**
  String get slotDinner;

  /// No description provided for @notifTitle.
  ///
  /// In en, this message translates to:
  /// **'Check your fridge'**
  String get notifTitle;

  /// No description provided for @notifBody.
  ///
  /// In en, this message translates to:
  /// **'{name}: expiry {date}. {days, plural, =0{The term expires today} =1{1 day left} other{{days} days left}}'**
  String notifBody(String name, String date, int days);

  /// No description provided for @cookedButton.
  ///
  /// In en, this message translates to:
  /// **'Cooked — deduct from fridge'**
  String get cookedButton;

  /// No description provided for @cookedSheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Deduct from fridge'**
  String get cookedSheetTitle;

  /// No description provided for @cookedSheetHint.
  ///
  /// In en, this message translates to:
  /// **'Deduction is suggested automatically, soonest-expiring first. Uncheck rows or adjust pieces if you used less.'**
  String get cookedSheetHint;

  /// No description provided for @cookedApply.
  ///
  /// In en, this message translates to:
  /// **'Deduct'**
  String get cookedApply;

  /// No description provided for @cookedMissing.
  ///
  /// In en, this message translates to:
  /// **'Not in the fridge'**
  String get cookedMissing;

  /// No description provided for @cookedNothing.
  ///
  /// In en, this message translates to:
  /// **'No recipe ingredients found in the fridge — nothing to deduct.'**
  String get cookedNothing;

  /// No description provided for @cookedWillFinish.
  ///
  /// In en, this message translates to:
  /// **'will be marked as eaten'**
  String get cookedWillFinish;

  /// No description provided for @cookedRemains.
  ///
  /// In en, this message translates to:
  /// **'leaving {n}'**
  String cookedRemains(Object n);

  /// No description provided for @cookedDone.
  ///
  /// In en, this message translates to:
  /// **'Deducted from fridge: {n}'**
  String cookedDone(Object n);

  /// No description provided for @shareWhatTitle.
  ///
  /// In en, this message translates to:
  /// **'What to share?'**
  String get shareWhatTitle;

  /// No description provided for @shareWhatAll.
  ///
  /// In en, this message translates to:
  /// **'All uneaten'**
  String get shareWhatAll;

  /// No description provided for @shareWhatAllHint.
  ///
  /// In en, this message translates to:
  /// **'All active products: {n}'**
  String shareWhatAllHint(Object n);

  /// No description provided for @shareWhatPerishable.
  ///
  /// In en, this message translates to:
  /// **'Perishable (≤3 days)'**
  String get shareWhatPerishable;

  /// No description provided for @shareWhatPerishableHint.
  ///
  /// In en, this message translates to:
  /// **'What expires within 3 days: {n}'**
  String shareWhatPerishableHint(Object n);

  /// No description provided for @shareWhatManual.
  ///
  /// In en, this message translates to:
  /// **'Pick manually'**
  String get shareWhatManual;

  /// No description provided for @shareWhatManualHint.
  ///
  /// In en, this message translates to:
  /// **'Check items in the list'**
  String get shareWhatManualHint;

  /// No description provided for @sharePickTitle.
  ///
  /// In en, this message translates to:
  /// **'Select products'**
  String get sharePickTitle;

  /// No description provided for @sharePickSend.
  ///
  /// In en, this message translates to:
  /// **'Share: {n}'**
  String sharePickSend(Object n);

  /// No description provided for @sharePickAll.
  ///
  /// In en, this message translates to:
  /// **'Select all'**
  String get sharePickAll;

  /// No description provided for @sharePickNone.
  ///
  /// In en, this message translates to:
  /// **'Clear all'**
  String get sharePickNone;

  /// No description provided for @sharePickEmpty.
  ///
  /// In en, this message translates to:
  /// **'No uneaten products to share'**
  String get sharePickEmpty;

  /// No description provided for @shareQrCount.
  ///
  /// In en, this message translates to:
  /// **'Sharing products: {n}'**
  String shareQrCount(Object n);

  /// No description provided for @productSaved.
  ///
  /// In en, this message translates to:
  /// **'Added to your fridge'**
  String get productSaved;

  /// No description provided for @productUpdated.
  ///
  /// In en, this message translates to:
  /// **'Changes saved'**
  String get productUpdated;

  /// No description provided for @productSavedDuplicate.
  ///
  /// In en, this message translates to:
  /// **'A product with this barcode is already in the fridge'**
  String get productSavedDuplicate;

  /// No description provided for @allergenCelery.
  ///
  /// In en, this message translates to:
  /// **'Celery'**
  String get allergenCelery;

  /// No description provided for @allergenMustard.
  ///
  /// In en, this message translates to:
  /// **'Mustard'**
  String get allergenMustard;

  /// No description provided for @allergenSulphites.
  ///
  /// In en, this message translates to:
  /// **'Sulphites'**
  String get allergenSulphites;

  /// No description provided for @allergenLupin.
  ///
  /// In en, this message translates to:
  /// **'Lupin'**
  String get allergenLupin;

  /// No description provided for @allergenHoney.
  ///
  /// In en, this message translates to:
  /// **'Honey'**
  String get allergenHoney;

  /// No description provided for @allergenChocolate.
  ///
  /// In en, this message translates to:
  /// **'Chocolate, cocoa, coffee'**
  String get allergenChocolate;

  /// No description provided for @allergenRedProduce.
  ///
  /// In en, this message translates to:
  /// **'Red and orange produce'**
  String get allergenRedProduce;

  /// No description provided for @allergenMushrooms.
  ///
  /// In en, this message translates to:
  /// **'Mushrooms'**
  String get allergenMushrooms;

  /// No description provided for @allergenSpices.
  ///
  /// In en, this message translates to:
  /// **'Garlic, cinnamon, spices'**
  String get allergenSpices;

  /// No description provided for @allergenPoultry.
  ///
  /// In en, this message translates to:
  /// **'Poultry (chicken, turkey)'**
  String get allergenPoultry;

  /// No description provided for @allergenBeef.
  ///
  /// In en, this message translates to:
  /// **'Beef'**
  String get allergenBeef;

  /// No description provided for @allergenPork.
  ///
  /// In en, this message translates to:
  /// **'Pork'**
  String get allergenPork;

  /// No description provided for @allergenMildFruits.
  ///
  /// In en, this message translates to:
  /// **'Peaches, apricots, grapes'**
  String get allergenMildFruits;

  /// No description provided for @allergenMildCereals.
  ///
  /// In en, this message translates to:
  /// **'Rice, buckwheat, corn'**
  String get allergenMildCereals;

  /// No description provided for @allergenMildVegetables.
  ///
  /// In en, this message translates to:
  /// **'Peppers, potatoes, peas'**
  String get allergenMildVegetables;

  /// No description provided for @onbDislikesTitle.
  ///
  /// In en, this message translates to:
  /// **'What don\'t you like?'**
  String get onbDislikesTitle;

  /// No description provided for @onbDislikesBody.
  ///
  /// In en, this message translates to:
  /// **'Pick what you never buy. Dishes where it is a main ingredient won\'t be planned; a pinch for flavour is fine — and marked in the plan.'**
  String get onbDislikesBody;

  /// No description provided for @profileDislikes.
  ///
  /// In en, this message translates to:
  /// **'Disliked foods'**
  String get profileDislikes;

  /// No description provided for @profileDislikesHint.
  ///
  /// In en, this message translates to:
  /// **'Dishes where a disliked food is a main ingredient (10%+ of the dish) are excluded from the plan; a small amount is fine, marked as \"contains\". \"Always exclude\" is for foods you can\'t stand at all.'**
  String get profileDislikesHint;

  /// No description provided for @dislikeAddLabel.
  ///
  /// In en, this message translates to:
  /// **'Custom food'**
  String get dislikeAddLabel;

  /// No description provided for @dislikeAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get dislikeAdd;

  /// No description provided for @dislikeModeAlways.
  ///
  /// In en, this message translates to:
  /// **'always exclude'**
  String get dislikeModeAlways;

  /// No description provided for @dislikeModeMajor.
  ///
  /// In en, this message translates to:
  /// **'only if a main ingredient'**
  String get dislikeModeMajor;

  /// No description provided for @menuContainsDislike.
  ///
  /// In en, this message translates to:
  /// **'contains: {names}'**
  String menuContainsDislike(String names);

  /// No description provided for @dislikesEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing marked yet — add from the presets below or type your own'**
  String get dislikesEmpty;

  /// No description provided for @priceSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Store prices (experimental)'**
  String get priceSectionTitle;

  /// No description provided for @priceEnable.
  ///
  /// In en, this message translates to:
  /// **'Auto-fill prices when adding a product'**
  String get priceEnable;

  /// No description provided for @priceSourceLabel.
  ///
  /// In en, this message translates to:
  /// **'Price source'**
  String get priceSourceLabel;

  /// No description provided for @priceSourcePyat.
  ///
  /// In en, this message translates to:
  /// **'Pyaterochka — Russia'**
  String get priceSourcePyat;

  /// No description provided for @priceSourceKroger.
  ///
  /// In en, this message translates to:
  /// **'Kroger — USA'**
  String get priceSourceKroger;

  /// No description provided for @priceSourceOpenPrices.
  ///
  /// In en, this message translates to:
  /// **'Open Prices — by barcode (worldwide)'**
  String get priceSourceOpenPrices;

  /// No description provided for @priceRefresh.
  ///
  /// In en, this message translates to:
  /// **'Find price'**
  String get priceRefresh;

  /// No description provided for @priceSearching.
  ///
  /// In en, this message translates to:
  /// **'Searching for a price…'**
  String get priceSearching;

  /// No description provided for @unitKcal.
  ///
  /// In en, this message translates to:
  /// **'kcal'**
  String get unitKcal;

  /// No description provided for @unitP.
  ///
  /// In en, this message translates to:
  /// **'P'**
  String get unitP;

  /// No description provided for @unitF.
  ///
  /// In en, this message translates to:
  /// **'F'**
  String get unitF;

  /// No description provided for @unitC.
  ///
  /// In en, this message translates to:
  /// **'C'**
  String get unitC;

  /// No description provided for @perServing.
  ///
  /// In en, this message translates to:
  /// **'(per serving)'**
  String get perServing;

  /// No description provided for @planErrorGenerate.
  ///
  /// In en, this message translates to:
  /// **'Failed to generate the menu'**
  String get planErrorGenerate;

  /// No description provided for @planErrorSave.
  ///
  /// In en, this message translates to:
  /// **'Failed to save the plan'**
  String get planErrorSave;

  /// No description provided for @planErrorHistory.
  ///
  /// In en, this message translates to:
  /// **'Failed to load plan history'**
  String get planErrorHistory;

  /// No description provided for @planErrorOpen.
  ///
  /// In en, this message translates to:
  /// **'Failed to open the plan'**
  String get planErrorOpen;

  /// No description provided for @planErrorDelete.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete the plan'**
  String get planErrorDelete;

  /// No description provided for @planErrorShopping.
  ///
  /// In en, this message translates to:
  /// **'Failed to update the shopping list'**
  String get planErrorShopping;

  /// No description provided for @medicalDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'This app does not replace professional advice: a therapeutic diet must be prescribed by a doctor. The strict filter is not a substitute for reading the label.'**
  String get medicalDisclaimer;

  /// No description provided for @priceSourceUnofficial.
  ///
  /// In en, this message translates to:
  /// **'unofficial source'**
  String get priceSourceUnofficial;

  /// No description provided for @resetDeviceId.
  ///
  /// In en, this message translates to:
  /// **'Reset request identifier'**
  String get resetDeviceId;

  /// No description provided for @resetDeviceIdDone.
  ///
  /// In en, this message translates to:
  /// **'Identifier reset — a new one will be used for the next request'**
  String get resetDeviceIdDone;

  /// No description provided for @priceIndexProgress.
  ///
  /// In en, this message translates to:
  /// **'Building catalog index: {done} of {total}'**
  String priceIndexProgress(int done, int total);

  /// No description provided for @priceIndexCancel.
  ///
  /// In en, this message translates to:
  /// **'Stop indexing'**
  String get priceIndexCancel;

  /// No description provided for @priceMatched.
  ///
  /// In en, this message translates to:
  /// **'Matched: {name}'**
  String priceMatched(String name);

  /// No description provided for @priceNotFound.
  ///
  /// In en, this message translates to:
  /// **'Not found in the selected store'**
  String get priceNotFound;

  /// No description provided for @priceBarcodeNotFound.
  ///
  /// In en, this message translates to:
  /// **'No price for this barcode in Open Prices yet'**
  String get priceBarcodeNotFound;

  /// No description provided for @priceUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Source unavailable (blocked or VPN)'**
  String get priceUnavailable;

  /// No description provided for @priceNoNetwork.
  ///
  /// In en, this message translates to:
  /// **'Network unavailable — no price'**
  String get priceNoNetwork;

  /// No description provided for @priceAuthError.
  ///
  /// In en, this message translates to:
  /// **'Key rejected — check it in Settings'**
  String get priceAuthError;

  /// No description provided for @priceNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'Price source not configured — see Settings'**
  String get priceNotConfigured;

  /// No description provided for @priceBarcodeRequired.
  ///
  /// In en, this message translates to:
  /// **'Open Prices needs the product barcode'**
  String get priceBarcodeRequired;

  /// No description provided for @priceOpenPricesNote.
  ///
  /// In en, this message translates to:
  /// **'The price is filled from the open Open Prices database (Open Food Facts project) by the scanned barcode: no keys, no registration. Coverage is crowdsourced and uneven — some products have no prices yet.'**
  String get priceOpenPricesNote;

  /// No description provided for @priceSourceMercadona.
  ///
  /// In en, this message translates to:
  /// **'Mercadona — Spain'**
  String get priceSourceMercadona;

  /// No description provided for @priceSourceAldi.
  ///
  /// In en, this message translates to:
  /// **'Aldi Süd — Germany'**
  String get priceSourceAldi;

  /// No description provided for @priceSourceWegmans.
  ///
  /// In en, this message translates to:
  /// **'Wegmans — USA'**
  String get priceSourceWegmans;

  /// No description provided for @priceMercadonaNote.
  ///
  /// In en, this message translates to:
  /// **'The catalog is fetched once straight from the device on the first search (about a minute), then cached and answered instantly; it refreshes in the background every few days. Prices are warehouse prices (no store selection), name-based search — no barcodes in this catalog.'**
  String get priceMercadonaNote;

  /// No description provided for @priceAldiNote.
  ///
  /// In en, this message translates to:
  /// **'Search across the whole Aldi Süd assortment (shelf prices, no store selection), straight from the device. With VPN on, Aldi may block the request — then the price simply won\'t be filled. Search by name, no barcodes.'**
  String get priceAldiNote;

  /// No description provided for @wegmansKeyLabel.
  ///
  /// In en, this message translates to:
  /// **'Subscription key (developer.wegmans.io)'**
  String get wegmansKeyLabel;

  /// No description provided for @wegmansFindStores.
  ///
  /// In en, this message translates to:
  /// **'Find stores'**
  String get wegmansFindStores;

  /// No description provided for @wegmansSelected.
  ///
  /// In en, this message translates to:
  /// **'Selected: {name}'**
  String wegmansSelected(String name);

  /// No description provided for @wegmansPickTitle.
  ///
  /// In en, this message translates to:
  /// **'Wegmans stores'**
  String get wegmansPickTitle;

  /// No description provided for @wegmansNeedCredentials.
  ///
  /// In en, this message translates to:
  /// **'Fill in the subscription key first'**
  String get wegmansNeedCredentials;

  /// No description provided for @wegmansStoresEmpty.
  ///
  /// In en, this message translates to:
  /// **'No stores found for this key'**
  String get wegmansStoresEmpty;

  /// No description provided for @wegmansHint.
  ///
  /// In en, this message translates to:
  /// **'Create a free key at developer.wegmans.io and paste it here; it is stored only on the device. Wegmans operates ~110 stores in the northeastern USA — the price matches the selected store.'**
  String get wegmansHint;

  /// No description provided for @pyatStoreCode.
  ///
  /// In en, this message translates to:
  /// **'Store code (SAP)'**
  String get pyatStoreCode;

  /// No description provided for @pyatStoreHint.
  ///
  /// In en, this message translates to:
  /// **'The code is 4 characters, e.g. 35XY. Get it on 5ka.ru: pick your store for delivery and find the sapCode in any catalog request URL (DevTools → Network → …/stores/CODE/…). Prices will match that store.'**
  String get pyatStoreHint;

  /// No description provided for @pyatVpnNote.
  ///
  /// In en, this message translates to:
  /// **'Requests go straight from the device — no keys, no accounts. Pyaterochka blocks VPN and datacenter IPs: with VPN on, the price simply won\'t be filled — everything else keeps working.'**
  String get pyatVpnNote;

  /// No description provided for @krogerClientId.
  ///
  /// In en, this message translates to:
  /// **'Client ID (developer.kroger.com)'**
  String get krogerClientId;

  /// No description provided for @krogerClientSecret.
  ///
  /// In en, this message translates to:
  /// **'Client Secret'**
  String get krogerClientSecret;

  /// No description provided for @krogerZip.
  ///
  /// In en, this message translates to:
  /// **'Store ZIP code'**
  String get krogerZip;

  /// No description provided for @krogerFindStores.
  ///
  /// In en, this message translates to:
  /// **'Find stores by ZIP'**
  String get krogerFindStores;

  /// No description provided for @krogerSelected.
  ///
  /// In en, this message translates to:
  /// **'Selected: {name}'**
  String krogerSelected(String name);

  /// No description provided for @krogerPickTitle.
  ///
  /// In en, this message translates to:
  /// **'Stores nearby'**
  String get krogerPickTitle;

  /// No description provided for @krogerNeedCredentials.
  ///
  /// In en, this message translates to:
  /// **'Fill in Client ID, Client Secret and ZIP code'**
  String get krogerNeedCredentials;

  /// No description provided for @krogerStoresEmpty.
  ///
  /// In en, this message translates to:
  /// **'No stores found near this ZIP'**
  String get krogerStoresEmpty;

  /// No description provided for @krogerHint.
  ///
  /// In en, this message translates to:
  /// **'Create a free app at developer.kroger.com (Public tier, Products API) and paste its Client ID and Client Secret. Keys are stored only on the device and are sent only to api.kroger.com.'**
  String get krogerHint;

  /// No description provided for @productFieldPrice.
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get productFieldPrice;
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
