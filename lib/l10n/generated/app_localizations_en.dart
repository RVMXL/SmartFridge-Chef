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
  String get receiptOcrNote =>
      'On-device OCR: Russian (Tesseract) and Latin (ML Kit) — the engine is chosen automatically from the receipt content. Review items before adding.';

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
  String get profileMedicalDiets => 'Medical diets (Pevzner tables)';

  @override
  String get profileMedicalDietsHint =>
      'The menu will exclude meals with restricted foods. A table is prescribed by a doctor — confirm your choice with them';

  @override
  String get profileMedicalDietsAbout => 'What the tables mean';

  @override
  String get medicalDietsDialogTitle => 'Pevzner dietary tables';

  @override
  String get medicalDietsForbiddenLabel => 'Excludes:';

  @override
  String get medicalDietsNoRestrictions => 'No restrictions in the recipe base';

  @override
  String get medicalDietsDialogFooter =>
      'Descriptions are for reference only and do not replace your doctor\'s instructions';

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
  String get allergenCrustaceans => 'Crustaceans (shrimp, crab)';

  @override
  String get allergenMolluscs => 'Molluscs (mussels, squid, oysters)';

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

  @override
  String get allergenCelery => 'Celery';

  @override
  String get allergenMustard => 'Mustard';

  @override
  String get allergenSulphites => 'Sulphites';

  @override
  String get allergenLupin => 'Lupin';

  @override
  String get allergenHoney => 'Honey';

  @override
  String get allergenChocolate => 'Chocolate, cocoa, coffee';

  @override
  String get allergenRedProduce => 'Red and orange produce';

  @override
  String get allergenMushrooms => 'Mushrooms';

  @override
  String get allergenSpices => 'Garlic, cinnamon, spices';

  @override
  String get allergenPoultry => 'Poultry (chicken, turkey)';

  @override
  String get allergenBeef => 'Beef';

  @override
  String get allergenPork => 'Pork';

  @override
  String get allergenMildFruits => 'Peaches, apricots, grapes';

  @override
  String get allergenMildCereals => 'Rice, buckwheat, corn';

  @override
  String get allergenMildVegetables => 'Peppers, potatoes, peas';

  @override
  String get onbDislikesTitle => 'What don\'t you like?';

  @override
  String get onbDislikesBody =>
      'Pick what you never buy. Dishes where it is a main ingredient won\'t be planned; a pinch for flavour is fine — and marked in the plan.';

  @override
  String get profileDislikes => 'Disliked foods';

  @override
  String get profileDislikesHint =>
      'Dishes where a disliked food is a main ingredient (10%+ of the dish) are excluded from the plan; a small amount is fine, marked as \"contains\". \"Always exclude\" is for foods you can\'t stand at all.';

  @override
  String get dislikeAddLabel => 'Custom food';

  @override
  String get dislikeAdd => 'Add';

  @override
  String get dislikeModeAlways => 'always exclude';

  @override
  String get dislikeModeMajor => 'only if a main ingredient';

  @override
  String menuContainsDislike(String names) {
    return 'contains: $names';
  }

  @override
  String get dislikesEmpty =>
      'Nothing marked yet — add from the presets below or type your own';

  @override
  String get priceSectionTitle => 'Store prices (experimental)';

  @override
  String get priceEnable => 'Auto-fill prices when adding a product';

  @override
  String get priceSourceLabel => 'Price source';

  @override
  String get priceSourcePyat => 'Pyaterochka — Russia';

  @override
  String get priceSourceKroger => 'Kroger — USA';

  @override
  String get priceSourceOpenPrices => 'Open Prices — by barcode (worldwide)';

  @override
  String get priceRefresh => 'Find price';

  @override
  String get priceSearching => 'Searching for a price…';

  @override
  String get unitKcal => 'kcal';

  @override
  String get unitP => 'P';

  @override
  String get unitF => 'F';

  @override
  String get unitC => 'C';

  @override
  String get perServing => '(per serving)';

  @override
  String get planErrorGenerate => 'Failed to generate the menu';

  @override
  String get planErrorSave => 'Failed to save the plan';

  @override
  String get planErrorHistory => 'Failed to load plan history';

  @override
  String get planErrorOpen => 'Failed to open the plan';

  @override
  String get planErrorDelete => 'Failed to delete the plan';

  @override
  String get planErrorShopping => 'Failed to update the shopping list';

  @override
  String get medicalDisclaimer =>
      'This app does not replace professional advice: a therapeutic diet must be prescribed by a doctor. The strict filter is not a substitute for reading the label.';

  @override
  String get priceSourceUnofficial => 'unofficial source';

  @override
  String get resetDeviceId => 'Reset request identifier';

  @override
  String get resetDeviceIdDone =>
      'Identifier reset — a new one will be used for the next request';

  @override
  String priceIndexProgress(int done, int total) {
    return 'Building catalog index: $done of $total';
  }

  @override
  String get priceIndexCancel => 'Stop indexing';

  @override
  String priceMatched(String name) {
    return 'Matched: $name';
  }

  @override
  String get priceNotFound => 'Not found in the selected store';

  @override
  String get priceBarcodeNotFound =>
      'No price for this barcode in Open Prices yet';

  @override
  String get priceUnavailable => 'Source unavailable (blocked or VPN)';

  @override
  String get priceNoNetwork => 'Network unavailable — no price';

  @override
  String get priceAuthError => 'Key rejected — check it in Settings';

  @override
  String get priceNotConfigured => 'Price source not configured — see Settings';

  @override
  String get priceBarcodeRequired => 'Open Prices needs the product barcode';

  @override
  String get priceOpenPricesNote =>
      'The price is filled from the open Open Prices database (Open Food Facts project) by the scanned barcode: no keys, no registration. Coverage is crowdsourced and uneven — some products have no prices yet.';

  @override
  String get priceSourceMercadona => 'Mercadona — Spain';

  @override
  String get priceSourceAldi => 'Aldi Süd — Germany';

  @override
  String get priceSourceWegmans => 'Wegmans — USA';

  @override
  String get priceMercadonaNote =>
      'The catalog is fetched once straight from the device on the first search (about a minute), then cached and answered instantly; it refreshes in the background every few days. Prices are warehouse prices (no store selection), name-based search — no barcodes in this catalog.';

  @override
  String get priceAldiNote =>
      'Search across the whole Aldi Süd assortment (shelf prices, no store selection), straight from the device. With VPN on, Aldi may block the request — then the price simply won\'t be filled. Search by name, no barcodes.';

  @override
  String get wegmansKeyLabel => 'Subscription key (developer.wegmans.io)';

  @override
  String get wegmansFindStores => 'Find stores';

  @override
  String wegmansSelected(String name) {
    return 'Selected: $name';
  }

  @override
  String get wegmansPickTitle => 'Wegmans stores';

  @override
  String get wegmansNeedCredentials => 'Fill in the subscription key first';

  @override
  String get wegmansStoresEmpty => 'No stores found for this key';

  @override
  String get wegmansHint =>
      'Create a free key at developer.wegmans.io and paste it here; it is stored only on the device. Wegmans operates ~110 stores in the northeastern USA — the price matches the selected store.';

  @override
  String get pyatStoreCode => 'Store code (SAP)';

  @override
  String get pyatStoreHint =>
      'The code is 4 characters, e.g. 35XY. Get it on 5ka.ru: pick your store for delivery and find the sapCode in any catalog request URL (DevTools → Network → …/stores/CODE/…). Prices will match that store.';

  @override
  String get pyatVpnNote =>
      'Requests go straight from the device — no keys, no accounts. Pyaterochka blocks VPN and datacenter IPs: with VPN on, the price simply won\'t be filled — everything else keeps working.';

  @override
  String get krogerClientId => 'Client ID (developer.kroger.com)';

  @override
  String get krogerClientSecret => 'Client Secret';

  @override
  String get krogerZip => 'Store ZIP code';

  @override
  String get krogerFindStores => 'Find stores by ZIP';

  @override
  String krogerSelected(String name) {
    return 'Selected: $name';
  }

  @override
  String get krogerPickTitle => 'Stores nearby';

  @override
  String get krogerNeedCredentials =>
      'Fill in Client ID, Client Secret and ZIP code';

  @override
  String get krogerStoresEmpty => 'No stores found near this ZIP';

  @override
  String get krogerHint =>
      'Create a free app at developer.kroger.com (Public tier, Products API) and paste its Client ID and Client Secret. Keys are stored only on the device and are sent only to api.kroger.com.';

  @override
  String get productFieldPrice => 'Price';

  @override
  String get notifLastDayNote =>
      'At least one days option must remain — otherwise reminders would lose their point.';

  @override
  String get dataSectionTitle => 'Data';

  @override
  String get exportDataTitle => 'Export data';

  @override
  String get exportDataSubtitle => 'Backup: products, plans, profile, settings';

  @override
  String get exportHint =>
      'The system share sheet will open — save the file somewhere safe. Store secrets are never included in the backup.';

  @override
  String get importDataTitle => 'Import data';

  @override
  String get importDataSubtitle => 'Restore from a backup file';

  @override
  String get importConfirmTitle => 'Replace all data?';

  @override
  String get importConfirmBody =>
      'Your current products, meal plans, profile and settings will be replaced with the file contents. This cannot be undone.';

  @override
  String get importConfirmAction => 'Replace';

  @override
  String get exportSuccess => 'Backup ready — send the file to a safe place';

  @override
  String get exportFailed => 'Failed to create the backup';

  @override
  String importSuccess(int products, int plans) {
    return 'Data restored: $products products, $plans plans';
  }

  @override
  String get importFailed => 'Import failed — the file is corrupted';

  @override
  String get importNotBackup => 'This is not a SmartFridge backup file';

  @override
  String get importNewerVersion =>
      'The file was created by a newer app version. Update SmartFridge and try again.';
}
