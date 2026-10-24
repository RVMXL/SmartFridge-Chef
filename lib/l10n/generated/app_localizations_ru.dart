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
  String get stageCurrent =>
      'Готово: автопоиск штрих-кодов, офлайн-планер, сканер, пуши о сроках (v0.4.0)';

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

  @override
  String get commonCancel => 'Отмена';

  @override
  String get commonSave => 'Сохранить';

  @override
  String get commonDelete => 'Удалить';

  @override
  String get commonAdd => 'Добавить';

  @override
  String get commonDone => 'Готово';

  @override
  String get commonClose => 'Закрыть';

  @override
  String get commonError => 'Ошибка';

  @override
  String get searchHint => 'Поиск по названию';

  @override
  String get sortTooltip => 'Сортировка';

  @override
  String get sortExpiry => 'По сроку годности';

  @override
  String get sortName => 'По названию';

  @override
  String get sortCategory => 'По категории';

  @override
  String get emptySearchTitle => 'Ничего не найдено';

  @override
  String get emptySearchBody =>
      'Попробуйте другой запрос — в холодильнике такого нет.';

  @override
  String get fridgeAddTooltip => 'Добавить продукты';

  @override
  String get fridgeEmptyTitle => 'Холодильник пуст';

  @override
  String get fridgeEmptyBody =>
      'Добавьте первый продукт: сканируйте штрих-код, сфотографируйте чек или введите вручную.';

  @override
  String get fridgeAddBarcode => 'Сканировать штрих-код';

  @override
  String get fridgeAddReceipt => 'Фото чека (OCR)';

  @override
  String get fridgeAddManual => 'Ввести вручную';

  @override
  String get fridgeLegend => 'Цвета свежести';

  @override
  String get swipeHint =>
      'Смахните карточку, чтобы отметить съеденным или выбросить.';

  @override
  String daysLeft(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'осталось $days дня',
      many: 'осталось $days дней',
      few: 'осталось $days дня',
      one: 'остался 1 день',
      zero: 'истекает сегодня',
    );
    return '$_temp0';
  }

  @override
  String expiryOn(String date) {
    return 'Срок до $date';
  }

  @override
  String get actionAte => 'Съел';

  @override
  String get actionDiscard => 'Выбросить';

  @override
  String get actionDeleted => 'Удалено';

  @override
  String get snackbarUndo => 'Вернуть';

  @override
  String get confirmDeleteTitle => 'Удалить продукт?';

  @override
  String confirmDeleteBody(String name) {
    return '«$name» исчезнет из холодильника без следа в истории.';
  }

  @override
  String get duplicateTitle => 'Уже в холодильнике';

  @override
  String duplicateBody(String name, String date) {
    return '«$name» уже лежит на полке (до $date). Добавить ещё один — увеличим количество.';
  }

  @override
  String get duplicateAddOne => 'Добавить +1';

  @override
  String get duplicateOpen => 'Изменить';

  @override
  String get productNew => 'Новый продукт';

  @override
  String get productEditTitle => 'Редактировать продукт';

  @override
  String get productFieldName => 'Название';

  @override
  String get productNameHint => 'Например, Молоко 3,2%';

  @override
  String get productFieldCategory => 'Категория';

  @override
  String get productFieldQuantity => 'Количество';

  @override
  String get productFieldExpiry => 'Срок годности';

  @override
  String get productExpiryPick => 'Выбрать дату';

  @override
  String get productQuickPlus2 => '+2 дня';

  @override
  String get productQuickPlus7 => '+7 дней';

  @override
  String productDefaultShelf(int days) {
    return 'Типовой срок: $days дн.';
  }

  @override
  String get productFieldBarcode => 'Штрих-код';

  @override
  String get productBarcodeEmpty => 'Не задан';

  @override
  String get productFieldNotes => 'Заметка';

  @override
  String get productNameRequired => 'Введите название';

  @override
  String get productSaveError => 'Не удалось сохранить продукт';

  @override
  String get scanTitle => 'Сканер штрих-кода';

  @override
  String get scanHint => 'Наведите камеру на штрих-код товара';

  @override
  String get scanManualEntry => 'Ввести код вручную';

  @override
  String get scanManualHint => 'Штрих-код';

  @override
  String get scanInvalidCode => 'Код не распознан';

  @override
  String get scanCameraError =>
      'Камера недоступна. Проверьте разрешение или введите код вручную.';

  @override
  String get scanLookupWaiting => 'Ищем в открытой базе продуктов…';

  @override
  String get scanLookupMiss => 'Не найдено в открытой базе — заполните вручную';

  @override
  String get receiptTitle => 'Продукты из чека';

  @override
  String get receiptPickCamera => 'Сфотографировать чек';

  @override
  String get receiptPickGallery => 'Выбрать фото из галереи';

  @override
  String get receiptRecognizing => 'Распознаём текст…';

  @override
  String receiptFound(int count) {
    return 'Найдено позиций: $count';
  }

  @override
  String get receiptNotFound =>
      'Не удалось распознать товары. Попробуйте фото чётче или добавьте продукты вручную.';

  @override
  String get receiptEditHint =>
      'Проверьте названия — OCR может ошибаться. Снимите выделение с лишних строк.';

  @override
  String receiptAddSelected(int count) {
    return 'Добавить выбранные ($count)';
  }

  @override
  String receiptAdded(int count) {
    return 'Добавлено позиций: $count';
  }

  @override
  String get menuGenerate => 'Суперпланер: меню на неделю';

  @override
  String get menuGenerateShort => 'Сгенерировать меню';

  @override
  String get menuGenerating => 'Собираем меню…';

  @override
  String get menuRegenerate => 'Другой вариант';

  @override
  String get menuSavePlan => 'Сохранить план';

  @override
  String get menuSaved => 'План сохранён';

  @override
  String get menuShopping => 'Список покупок';

  @override
  String get menuHistory => 'История планов';

  @override
  String menuKcalPerDay(int kcal) {
    return '~$kcal ккал/день';
  }

  @override
  String menuTarget(int kcal) {
    return 'Цель: $kcal ккал';
  }

  @override
  String menuUsesExpiring(String items) {
    return 'Съесть раньше: $items';
  }

  @override
  String get menuEmptyTitle => 'Меню ещё не собрано';

  @override
  String get menuEmptyBody =>
      'Суперпланер смотрит в ваш холодильник, учитывает калораж, диету, аллергены и сезонность — и собирает меню на 7 дней прямо на устройстве.';

  @override
  String get menuPlanError => 'Не удалось собрать меню';

  @override
  String get menuDraftBadge => 'Черновик';

  @override
  String get menuSavedBadge => 'Сохранён';

  @override
  String get menuHistoryEmpty => 'Пока нет сохранённых планов';

  @override
  String get menuDeletePlan => 'Удалить план';

  @override
  String menuCookMinutes(int minutes) {
    return '$minutes мин';
  }

  @override
  String menuServings(int count) {
    return '$count порц.';
  }

  @override
  String get menuIngredients => 'Ингредиенты';

  @override
  String get menuSteps => 'Приготовление';

  @override
  String menuWeekOf(String date) {
    return 'Неделя с $date';
  }

  @override
  String get shoppingTitle => 'Список покупок';

  @override
  String get shoppingFromPlan => 'Из плана «меню на неделю»';

  @override
  String get shoppingEmpty =>
      'Всё нужное уже в холодильнике — докупать нечего.';

  @override
  String shoppingChecked(int done, int total) {
    return 'Куплено: $done из $total';
  }

  @override
  String get shoppingClearChecked => 'Убрать купленные';

  @override
  String get shoppingNoPlan =>
      'Сначала соберите меню — список недостающего появится здесь.';

  @override
  String get settingsProfile => 'Профиль питания';

  @override
  String get profileTitle => 'Профиль питания';

  @override
  String get profileCalories => 'Суточный калораж, ккал';

  @override
  String get profileBju => 'БЖУ, г/день';

  @override
  String get profileProtein => 'Белки';

  @override
  String get profileFat => 'Жиры';

  @override
  String get profileCarbs => 'Углеводы';

  @override
  String get profileAutoBju => 'Пересчитать 30/30/40';

  @override
  String get profileDiet => 'Диета';

  @override
  String get profileAllergies => 'Аллергии и непереносимости';

  @override
  String get profileMealsPerDay => 'Приёмов пищи в день';

  @override
  String get profileSaved => 'Профиль сохранён';

  @override
  String get profileOpen => 'Изменить';

  @override
  String get profileNone => 'Не указан';

  @override
  String get settingsNotifications => 'Напоминания о сроках';

  @override
  String get notifEnable => 'Присылать пуши';

  @override
  String get notifDays => 'Предупреждать заранее';

  @override
  String get notifDaysOpt2 => 'за 2 дня';

  @override
  String get notifDaysOpt1 => 'за 1 день';

  @override
  String get notifHour => 'Время напоминания';

  @override
  String notifHourAt(int hour) {
    return 'В $hour:00';
  }

  @override
  String get notifPermissionHint =>
      'Если пуши не приходят — проверьте разрешения системы и запрет оптимизации батареи.';

  @override
  String get onbWelcomeTitle => 'Умный Холодильник\n& Шеф-Планер';

  @override
  String get onbWelcomeBody =>
      'Следим за сроками годности и собираем меню на неделю из того, что уже лежит в холодильнике. Всё офлайн.';

  @override
  String get onbStart => 'Начать настройку';

  @override
  String get onbStep1Title => 'Сколько вы едите в день?';

  @override
  String get onbStep2Title => 'Диета и аллергии';

  @override
  String get onbStep2Body => 'Планер исключит неподходящие рецепты.';

  @override
  String get onbStep3Title => 'Режим и напоминания';

  @override
  String get onbStep3Body =>
      'Пуши приходят за 1–2 дня до конца срока годности.';

  @override
  String get onbFinish => 'Готово — в холодильник!';

  @override
  String get onbSkip => 'Пропустить';

  @override
  String get onbNext => 'Дальше';

  @override
  String get dietNone => 'Без ограничений';

  @override
  String get dietVegetarian => 'Вегетарианская';

  @override
  String get dietVegan => 'Веганская';

  @override
  String get dietLent => 'Пост';

  @override
  String get dietPescatarian => 'Пескетарианская';

  @override
  String get dietLowCarb => 'Низкоуглеводная';

  @override
  String get allergenMilk => 'Молоко';

  @override
  String get allergenEggs => 'Яйца';

  @override
  String get allergenFish => 'Рыба';

  @override
  String get allergenShellfish => 'Моллюски';

  @override
  String get allergenNuts => 'Орехи';

  @override
  String get allergenPeanuts => 'Арахис';

  @override
  String get allergenSoy => 'Соя';

  @override
  String get allergenWheat => 'Пшеница / глютен';

  @override
  String get allergenSesame => 'Кунжут';

  @override
  String get catDairy => 'Молочные';

  @override
  String get catMeat => 'Мясо';

  @override
  String get catFish => 'Рыба';

  @override
  String get catVegetables => 'Овощи';

  @override
  String get catFruits => 'Фрукты';

  @override
  String get catBakery => 'Выпечка';

  @override
  String get catGrains => 'Крупы';

  @override
  String get catFrozen => 'Заморозка';

  @override
  String get catBeverages => 'Напитки';

  @override
  String get catSweets => 'Сладкое';

  @override
  String get catCondiments => 'Соусы';

  @override
  String get catOther => 'Другое';

  @override
  String get unitPcs => 'шт';

  @override
  String get unitGram => 'г';

  @override
  String get unitKilogram => 'кг';

  @override
  String get unitMilliliter => 'мл';

  @override
  String get unitLiter => 'л';

  @override
  String get unitPack => 'упак';

  @override
  String get slotBreakfast => 'Завтрак';

  @override
  String get slotSnack => 'Перекус';

  @override
  String get slotLunch => 'Обед';

  @override
  String get slotDinner => 'Ужин';

  @override
  String get notifTitle => 'Проверьте холодильник';

  @override
  String notifBody(String name, String date, int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Осталось $days дня',
      many: 'Осталось $days дней',
      few: 'Осталось $days дня',
      one: 'Остался 1 день',
      zero: 'Срок истекает сегодня',
    );
    return '$name: срок годности до $date. $_temp0';
  }
}
