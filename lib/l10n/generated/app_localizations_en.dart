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
  String get fridgePlaceholderTitle => 'Screen — Step 3';

  @override
  String get fridgePlaceholderBody =>
      'The product list with freshness color coding will appear in Step 3. The data layer (Step 1) already works — below is the real state of the local SQLite database.';

  @override
  String get fridgeEmpty =>
      'The fridge is empty. Products will be added by barcode scanning or quick manual input.';

  @override
  String get statActive => 'In the fridge';

  @override
  String statExpiring(int days) {
    return 'Expiring (≤ $days d.)';
  }

  @override
  String get statExpired => 'Expired';

  @override
  String get plannerTitle => 'My Menu';

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
  String get stageCurrent =>
      'Done: barcode auto-lookup, offline planner, scanner, expiry notifications (v0.4.0)';

  @override
  String get settingsOffline =>
      'Offline-first: all data stays on the device. No analytics, servers or accounts.';

  @override
  String get dbOpenError => 'Failed to open the local database';

  @override
  String get retry => 'Retry';

  @override
  String get freshnessFresh => 'Fresh';

  @override
  String get freshnessExpiring => 'Expiring';

  @override
  String get freshnessExpired => 'Expired';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonSave => 'Save';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonAdd => 'Add';

  @override
  String get commonDone => 'Done';

  @override
  String get commonClose => 'Close';

  @override
  String get commonError => 'Error';

  @override
  String get searchHint => 'Search by name';

  @override
  String get sortTooltip => 'Sort';

  @override
  String get sortExpiry => 'By expiry date';

  @override
  String get sortName => 'By name';

  @override
  String get sortCategory => 'By category';

  @override
  String get emptySearchTitle => 'Nothing found';

  @override
  String get emptySearchBody =>
      'Try a different query — the fridge list is empty.';

  @override
  String get fridgeAddTooltip => 'Add products';

  @override
  String get fridgeEmptyTitle => 'The fridge is empty';

  @override
  String get fridgeEmptyBody =>
      'Add your first product: scan a barcode, photograph a receipt or type it manually.';

  @override
  String get fridgeAddBarcode => 'Scan barcode';

  @override
  String get fridgeAddReceipt => 'Receipt photo (OCR)';

  @override
  String get fridgeAddManual => 'Enter manually';

  @override
  String get fridgeLegend => 'Freshness legend';

  @override
  String get swipeHint => 'Swipe a card to mark it as eaten or discarded.';

  @override
  String daysLeft(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days left',
      one: '1 day left',
      zero: 'expires today',
    );
    return '$_temp0';
  }

  @override
  String expiryOn(String date) {
    return 'Expiry: $date';
  }

  @override
  String get actionAte => 'Ate it';

  @override
  String get actionDiscard => 'Discard';

  @override
  String get actionDeleted => 'Deleted';

  @override
  String get snackbarUndo => 'Undo';

  @override
  String get confirmDeleteTitle => 'Delete product?';

  @override
  String confirmDeleteBody(String name) {
    return '“$name” will disappear from the fridge without a trace in the history.';
  }

  @override
  String get duplicateTitle => 'Already in the fridge';

  @override
  String duplicateBody(String name, String date) {
    return '“$name” is already on the shelf (until $date). Add another one — we will increase the quantity.';
  }

  @override
  String get duplicateAddOne => 'Add +1';

  @override
  String get duplicateOpen => 'Edit';

  @override
  String get productNew => 'New product';

  @override
  String get productEditTitle => 'Edit product';

  @override
  String get productFieldName => 'Name';

  @override
  String get productNameHint => 'For example, Milk 3.2%';

  @override
  String get productFieldCategory => 'Category';

  @override
  String get productFieldQuantity => 'Quantity';

  @override
  String get productFieldExpiry => 'Expiry date';

  @override
  String get productExpiryPick => 'Pick a date';

  @override
  String get productQuickPlus2 => '+2 days';

  @override
  String get productQuickPlus7 => '+7 days';

  @override
  String productDefaultShelf(int days) {
    return 'Typical shelf life: $days days';
  }

  @override
  String get productFieldBarcode => 'Barcode';

  @override
  String get productBarcodeEmpty => 'Not set';

  @override
  String get productFieldNotes => 'Note';

  @override
  String get productNameRequired => 'Enter a name';

  @override
  String get productSaveError => 'Failed to save the product';

  @override
  String get scanTitle => 'Barcode scanner';

  @override
  String get scanHint => 'Point the camera at the product barcode';

  @override
  String get scanManualEntry => 'Enter the code manually';

  @override
  String get scanManualHint => 'Barcode';

  @override
  String get scanInvalidCode => 'The code was not recognized';

  @override
  String get scanCameraError =>
      'Camera unavailable. Check the permission or enter the code manually.';

  @override
  String get scanLookupWaiting => 'Searching the open product database…';

  @override
  String get scanLookupMiss =>
      'Not found in the open database — fill in manually';

  @override
  String get receiptTitle => 'Products from the receipt';

  @override
  String get receiptPickCamera => 'Photograph the receipt';

  @override
  String get receiptPickGallery => 'Pick a photo from the gallery';

  @override
  String get receiptRecognizing => 'Recognizing text…';

  @override
  String receiptFound(int count) {
    return 'Items found: $count';
  }

  @override
  String get receiptNotFound =>
      'Could not recognize any items. Try a sharper photo or add products manually.';

  @override
  String get receiptEditHint =>
      'Check the names — OCR can be wrong. Uncheck the lines you do not need.';

  @override
  String receiptAddSelected(int count) {
    return 'Add selected ($count)';
  }

  @override
  String receiptAdded(int count) {
    return 'Items added: $count';
  }

  @override
  String get menuGenerate => 'Superplanner: weekly menu';

  @override
  String get menuGenerateShort => 'Generate menu';

  @override
  String get menuGenerating => 'Assembling the menu…';

  @override
  String get menuRegenerate => 'Another option';

  @override
  String get menuSavePlan => 'Save plan';

  @override
  String get menuSaved => 'Plan saved';

  @override
  String get menuShopping => 'Shopping list';

  @override
  String get menuHistory => 'Plan history';

  @override
  String menuKcalPerDay(int kcal) {
    return '~$kcal kcal/day';
  }

  @override
  String menuTarget(int kcal) {
    return 'Target: $kcal kcal';
  }

  @override
  String menuUsesExpiring(String items) {
    return 'Eat first: $items';
  }

  @override
  String get menuEmptyTitle => 'The menu is not assembled yet';

  @override
  String get menuEmptyBody =>
      'The Superplanner looks into your fridge, takes calories, diet, allergies and seasonality into account — and assembles a 7-day menu right on the device.';

  @override
  String get menuPlanError => 'Failed to assemble the menu';

  @override
  String get menuDraftBadge => 'Draft';

  @override
  String get menuSavedBadge => 'Saved';

  @override
  String get menuHistoryEmpty => 'No saved plans yet';

  @override
  String get menuDeletePlan => 'Delete plan';

  @override
  String menuCookMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String menuServings(int count) {
    return '$count servings';
  }

  @override
  String get menuIngredients => 'Ingredients';

  @override
  String get menuSteps => 'Cooking';

  @override
  String menuWeekOf(String date) {
    return 'Week of $date';
  }

  @override
  String get shoppingTitle => 'Shopping list';

  @override
  String get shoppingFromPlan => 'From the weekly menu plan';

  @override
  String get shoppingEmpty =>
      'Everything you need is already in the fridge — nothing to buy.';

  @override
  String shoppingChecked(int done, int total) {
    return 'Bought: $done of $total';
  }

  @override
  String get shoppingClearChecked => 'Remove bought';

  @override
  String get shoppingNoPlan =>
      'Assemble the menu first — the missing-ingredients list will appear here.';

  @override
  String get settingsProfile => 'Nutrition profile';

  @override
  String get profileTitle => 'Nutrition profile';

  @override
  String get profileCalories => 'Daily calories, kcal';

  @override
  String get profileBju => 'Macros, g/day';

  @override
  String get profileProtein => 'Protein';

  @override
  String get profileFat => 'Fat';

  @override
  String get profileCarbs => 'Carbs';

  @override
  String get profileAutoBju => 'Recalculate 30/30/40';

  @override
  String get profileDiet => 'Diet';

  @override
  String get profileAllergies => 'Allergies and intolerances';

  @override
  String get profileMealsPerDay => 'Meals per day';

  @override
  String get profileSaved => 'Profile saved';

  @override
  String get profileOpen => 'Change';

  @override
  String get profileNone => 'Not set';

  @override
  String get settingsNotifications => 'Expiry reminders';

  @override
  String get notifEnable => 'Send notifications';

  @override
  String get notifDays => 'Warn in advance';

  @override
  String get notifDaysOpt2 => '2 days ahead';

  @override
  String get notifDaysOpt1 => '1 day ahead';

  @override
  String get notifHour => 'Reminder time';

  @override
  String notifHourAt(int hour) {
    return 'At $hour:00';
  }

  @override
  String get notifPermissionHint =>
      'If notifications do not arrive — check the system permissions and battery optimization settings.';

  @override
  String get onbWelcomeTitle => 'Smart Fridge\n& Chef Planner';

  @override
  String get onbWelcomeBody =>
      'We track expiry dates and assemble a weekly menu from what is already in your fridge. Everything offline.';

  @override
  String get onbStart => 'Start setup';

  @override
  String get onbStep1Title => 'How much do you eat per day?';

  @override
  String get onbStep2Title => 'Diet and allergies';

  @override
  String get onbStep2Body => 'The planner will exclude unsuitable recipes.';

  @override
  String get onbStep3Title => 'Routine and reminders';

  @override
  String get onbStep3Body =>
      'Notifications arrive 1–2 days before the expiry date.';

  @override
  String get onbFinish => 'Done — to the fridge!';

  @override
  String get onbSkip => 'Skip';

  @override
  String get onbNext => 'Next';

  @override
  String get dietNone => 'No restrictions';

  @override
  String get dietVegetarian => 'Vegetarian';

  @override
  String get dietVegan => 'Vegan';

  @override
  String get dietLent => 'Fasting';

  @override
  String get dietPescatarian => 'Pescatarian';

  @override
  String get dietLowCarb => 'Low-carb';

  @override
  String get dietHalal => 'Halal (Muslim)';

  @override
  String get dietKosher => 'Kosher (Jewish)';

  @override
  String get dietHindu => 'No beef (Hindu)';

  @override
  String get profileDietMultipleHint => 'Select several — restrictions combine';

  @override
  String get planExcludedTitle => 'Why some recipes are not in the menu';

  @override
  String planExcludedSummary(Object n) {
    return 'Excluded during planning: $n';
  }

  @override
  String get shareMenuTitle => 'Share products';

  @override
  String get shareShowQr => 'Show QR code';

  @override
  String get shareShowQrHint => 'Send the list to another phone';

  @override
  String get shareReceiveQr => 'Receive via QR';

  @override
  String get shareReceiveQrHint => 'Scan another person\'s codes';

  @override
  String get shareQrTitle => 'Share products';

  @override
  String get shareQrHint =>
      'Point the other phone\'s camera at this screen. Pages advance automatically — keep the devices facing each other until the transfer completes.';

  @override
  String shareQrPage(Object i, Object n) {
    return 'Page $i of $n';
  }

  @override
  String get shareQrSingle => 'Single code — one scan is enough';

  @override
  String get shareQrAuto => 'Auto-advance';

  @override
  String get shareQrEmpty => 'No active products to share';

  @override
  String get shareQrTooBig =>
      'Too many products even for a QR series (limit is 255 pages). Remove some items and try again.';

  @override
  String get receiveQrTitle => 'Receive products';

  @override
  String get receiveQrWaiting =>
      'Point the camera at the other phone\'s QR codes. Each code counts once — duplicates are harmless.';

  @override
  String receiveQrProgress(Object a, Object n) {
    return 'Received $a of $n';
  }

  @override
  String receiveQrConfirmTitle(Object n) {
    return 'Add $n products?';
  }

  @override
  String receiveQrConfirmBody(num more, Object names) {
    String _temp0 = intl.Intl.pluralLogic(
      more,
      locale: localeName,
      other: ' … and $more more',
      zero: '',
    );
    return 'List starts with: $names$_temp0';
  }

  @override
  String receiveQrDone(Object added, Object skipped) {
    return 'Added: $added. Duplicates skipped: $skipped';
  }

  @override
  String get receiveQrBroken => 'QR code is damaged — transfer restarts';

  @override
  String get receiveQrEmpty => 'The transfer contains no products';

  @override
  String get allergenMilk => 'Milk';

  @override
  String get allergenEggs => 'Eggs';

  @override
  String get allergenFish => 'Fish';

  @override
  String get allergenShellfish => 'Shellfish';

  @override
  String get allergenNuts => 'Nuts';

  @override
  String get allergenPeanuts => 'Peanuts';

  @override
  String get allergenSoy => 'Soy';

  @override
  String get allergenWheat => 'Wheat / gluten';

  @override
  String get allergenSesame => 'Sesame';

  @override
  String get catDairy => 'Dairy';

  @override
  String get catMeat => 'Meat';

  @override
  String get catFish => 'Fish';

  @override
  String get catVegetables => 'Vegetables';

  @override
  String get catFruits => 'Fruits';

  @override
  String get catBakery => 'Bakery';

  @override
  String get catGrains => 'Grains';

  @override
  String get catFrozen => 'Frozen';

  @override
  String get catBeverages => 'Beverages';

  @override
  String get catSweets => 'Sweets';

  @override
  String get catCondiments => 'Condiments';

  @override
  String get catOther => 'Other';

  @override
  String get unitPcs => 'pcs';

  @override
  String get unitGram => 'g';

  @override
  String get unitKilogram => 'kg';

  @override
  String get unitMilliliter => 'ml';

  @override
  String get unitLiter => 'l';

  @override
  String get unitPack => 'pack';

  @override
  String get slotBreakfast => 'Breakfast';

  @override
  String get slotSnack => 'Snack';

  @override
  String get slotLunch => 'Lunch';

  @override
  String get slotDinner => 'Dinner';

  @override
  String get notifTitle => 'Check your fridge';

  @override
  String notifBody(String name, String date, int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days left',
      one: '1 day left',
      zero: 'The term expires today',
    );
    return '$name: expiry $date. $_temp0';
  }

  @override
  String get cookedButton => 'Cooked — deduct from fridge';

  @override
  String get cookedSheetTitle => 'Deduct from fridge';

  @override
  String get cookedSheetHint =>
      'Deduction is suggested automatically, soonest-expiring first. Uncheck rows or adjust pieces if you used less.';

  @override
  String get cookedApply => 'Deduct';

  @override
  String get cookedMissing => 'Not in the fridge';

  @override
  String get cookedNothing =>
      'No recipe ingredients found in the fridge — nothing to deduct.';

  @override
  String get cookedWillFinish => 'will be marked as eaten';

  @override
  String cookedRemains(Object n) {
    return 'leaving $n';
  }

  @override
  String cookedDone(Object n) {
    return 'Deducted from fridge: $n';
  }

  @override
  String get shareWhatTitle => 'What to share?';

  @override
  String get shareWhatAll => 'All uneaten';

  @override
  String shareWhatAllHint(Object n) {
    return 'All active products: $n';
  }

  @override
  String get shareWhatPerishable => 'Perishable (≤3 days)';

  @override
  String shareWhatPerishableHint(Object n) {
    return 'What expires within 3 days: $n';
  }

  @override
  String get shareWhatManual => 'Pick manually';

  @override
  String get shareWhatManualHint => 'Check items in the list';

  @override
  String get sharePickTitle => 'Select products';

  @override
  String sharePickSend(Object n) {
    return 'Share: $n';
  }

  @override
  String get sharePickAll => 'Select all';

  @override
  String get sharePickNone => 'Clear all';

  @override
  String get sharePickEmpty => 'No uneaten products to share';

  @override
  String shareQrCount(Object n) {
    return 'Sharing products: $n';
  }

  @override
  String get productSaved => 'Added to your fridge';

  @override
  String get productUpdated => 'Changes saved';

  @override
  String get productSavedDuplicate =>
      'A product with this barcode is already in the fridge';
}
