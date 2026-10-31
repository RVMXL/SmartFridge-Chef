/// Распределение суточного калоража по приёмам пищи (Шаг 2).
///
/// Профиль задаёт mealsPerDay (2–6) и dailyCalories; планер получает
/// целевую калорийность каждого слота. Доли подобраны по стандартной
/// диетологии: завтрак ~25–30%, обед ~35–40%, ужин ~25–30%,
/// перекусы делят остаток. Сумма долей всегда 1.0 — закреплено тестом.
///
/// v0.6.10: состав обеда и ужина настраивается в профиле
/// ([MealCourseType], [compositionTemplate]) — шаблон по умолчанию
/// ([composedCourses]) действует, пока настройка не задана.
library;

import 'dart:math';

import '../data/models/recipe.dart';

/// Один слот в распределении дня.
class MealSplit {
  const MealSplit({required this.slot, required this.order, required this.share});

  final MealSlot slot;

  /// Порядок в рамках дня (0, 1, 2...).
  final int order;

  /// Доля суточного калоража (0..1).
  final double share;
}

/// Схема распределения для mealsPerDay.
const Map<int, List<MealSplit>> _splits = {
  2: [
    MealSplit(slot: MealSlot.lunch, order: 0, share: 0.45),
    MealSplit(slot: MealSlot.dinner, order: 1, share: 0.55),
  ],
  3: [
    MealSplit(slot: MealSlot.breakfast, order: 0, share: 0.30),
    MealSplit(slot: MealSlot.lunch, order: 1, share: 0.40),
    MealSplit(slot: MealSlot.dinner, order: 2, share: 0.30),
  ],
  4: [
    MealSplit(slot: MealSlot.breakfast, order: 0, share: 0.25),
    MealSplit(slot: MealSlot.snack, order: 1, share: 0.10),
    MealSplit(slot: MealSlot.lunch, order: 2, share: 0.35),
    MealSplit(slot: MealSlot.dinner, order: 3, share: 0.30),
  ],
  5: [
    MealSplit(slot: MealSlot.breakfast, order: 0, share: 0.25),
    MealSplit(slot: MealSlot.snack, order: 1, share: 0.10),
    MealSplit(slot: MealSlot.lunch, order: 2, share: 0.35),
    MealSplit(slot: MealSlot.snack, order: 3, share: 0.08),
    MealSplit(slot: MealSlot.dinner, order: 4, share: 0.22),
  ],
  6: [
    MealSplit(slot: MealSlot.breakfast, order: 0, share: 0.20),
    MealSplit(slot: MealSlot.snack, order: 1, share: 0.08),
    MealSplit(slot: MealSlot.lunch, order: 2, share: 0.30),
    MealSplit(slot: MealSlot.snack, order: 3, share: 0.10),
    MealSplit(slot: MealSlot.dinner, order: 4, share: 0.22),
    MealSplit(slot: MealSlot.snack, order: 5, share: 0.10),
  ],
};

/// Возвращает схему слотов для [mealsPerDay]; значения вне 2–6
/// прижимаются к границам (2 и 3 — самые осмысленные минимумы).
List<MealSplit> splitsForMealsPerDay(int mealsPerDay) {
  if (mealsPerDay <= 2) return _splits[2]!;
  if (mealsPerDay >= 6) return _splits[6]!;
  return _splits[mealsPerDay]!;
}

/// Целевая калорийность слота (минимум 120 ккал — «нулевых» приёмов
/// планер не подбирает, это ломало бы выбор рецептов).
int slotTargetKcal(int dailyCalories, MealSplit split) =>
    (dailyCalories * split.share).round().clamp(120, dailyCalories);

/// Верхняя граница порций одного блюда в слоте (v0.6.8): три порции —
/// максимум разумного за один приём; лёгкие блюда добирают калораж
/// этим потолком, плотные укладываются в одну-две.
const int kMaxPlannedServings = 3;

/// Сколько порций рецепта планировать в слот, чтобы приблизиться к
/// [targetKcal] (v0.6.8): округление к ближайшему целому с потолком
/// [kMaxPlannedServings] и полом в одну порцию.
///
/// До v0.6.8 план брал всегда одну порцию — при цели 2750 ккал/день
/// суммарный калораж дня падал до трети цели (медиана завтрака базы
/// 403 ккал, перекуса 216 ккал): добор порциями устраняет системный
/// недобор. Остаток после округления (максимум полпорции) остаётся
/// штрафом в скоринге — плотные блюда выигрывают у слишком лёгких.
int plannedServingsFor({
  required int targetKcal,
  required int kcalPerServing,
}) {
  if (kcalPerServing <= 0) return 1;
  return (targetKcal / kcalPerServing).round().clamp(1, kMaxPlannedServings);
}

/// Порог целевого калоража слота, ниже которого состав не собирается
/// (v0.6.9): при маленькой цели (обед 1500 ккал/день = 600…) два-три
/// блюда базы минимальной калорийности перебирают её так же сильно, как
/// одиночное блюдо, — а возни с готовкой больше. Ниже порога слот
/// остаётся одиночным блюдом с добором порциями (v0.6.8).
const int kComposeMinSlotKcal = 550;

/// Порог целевого калоража слота, при котором в состав добавляется
/// десерт (v0.6.9, вынесено в константу в v0.6.10): к малым приёмам
/// десерт не добавляется — раздувал бы приём.
const int kDessertMinSlotKcal = 950;

/// Минимальная цель бокового курса, ради которой стоит готовить отдельное
/// блюдо (v0.6.9): курс с целью ниже этого порога пропускается, его долю
/// забирает «второе». Пример: салат на 60 ккал — это «ещё одно блюдо,
/// которое почти ничего не закрывает», а не составная часть приёма.
const int kMinCourseTargetKcal = 100;

/// Настраиваемый боковой курс составного приёма пищи (v0.6.10).
///
/// Курс — то, что пользователь включает/выключает в профиле: «первое»,
/// салат, десерт. «Второе» ([MealCourse.closing]) в настройку не
/// входит: оно всегда замыкает приём, забирает остаток цели и добирает
/// порциями — без него состав не держит калораж слота.
enum MealCourseType {
  first('first'),
  salad('salad'),
  dessert('dessert');

  const MealCourseType(this.key);

  /// Ключ хранения в профиле (JSON meal_composition).
  final String key;

  /// Категории рецептов, из которых набирается курс.
  List<String> get categories => switch (this) {
        MealCourseType.first => const ['soup'],
        MealCourseType.salad => const ['salad'],
        MealCourseType.dessert => const ['dessert'],
      };

  /// Неизвестный/повреждённый ключ → null (ключ отбрасывается),
  /// как у аллергенов: битое значение профиля не должно подменять
  /// настройку курсом по умолчанию.
  static MealCourseType? fromKey(String key) {
    for (final t in values) {
      if (t.key == key) return t;
    }
    return null;
  }
}

/// Доли боковых курсов по слотам (v0.6.10): те же значения, что
/// задавали шаблон v0.6.9. Доля «второго» вычисляется как остаток
/// единицы, поэтому сумма долей готового шаблона всегда 1.0.
const Map<MealSlot, Map<MealCourseType, ({double share, int minSlotKcal})>>
    courseParams = {
  MealSlot.lunch: {
    MealCourseType.first: (share: 0.27, minSlotKcal: 0),
    MealCourseType.salad: (share: 0.19, minSlotKcal: 0),
    MealCourseType.dessert: (share: 0.14, minSlotKcal: kDessertMinSlotKcal),
  },
  MealSlot.dinner: {
    MealCourseType.first: (share: 0.27, minSlotKcal: 0),
    MealCourseType.salad: (share: 0.30, minSlotKcal: 0),
    MealCourseType.dessert: (share: 0.14, minSlotKcal: kDessertMinSlotKcal),
  },
};

/// Наборы боковых курсов по умолчанию (v0.6.10): обед — «первое,
/// салат и десерт к большим приёмам», ужин — салат. Именно эти наборы
/// пользователь видит в профиле до первой правки.
const Map<MealSlot, Set<MealCourseType>> defaultCourseSides = {
  MealSlot.lunch: {
    MealCourseType.first,
    MealCourseType.salad,
    MealCourseType.dessert,
  },
  MealSlot.dinner: {MealCourseType.salad},
};

/// Шаблон состава слота с учётом настройки профиля (v0.6.10).
///
/// [custom] — карта «слот → включённые боковые курсы» из профиля
/// ([UserProfile.mealComposition]). Семантика:
///  • настройка null или слота в ней нет — шаблон по умолчанию
///    ([defaultCourseSides] — совпадает с [composedCourses]);
///  • пустой набор у слота — приём из одного блюда: шаблон состоит
///    только из обязательного «второго» и состав не соберётся;
///  • завтрак и перекус не настраиваются ([courseParams] без слота) —
///    возвращается null, слот живёт по одиночной схеме v0.6.8.
///
/// Порядок боковых курсов в шаблоне — порядок ПОДБОРА
/// (первое → салат → десерт, как в v0.6.9): остаток цели для «второго»
/// считается по факту уже выбранных блюд.
List<MealCourse>? compositionTemplate(
  MealSlot slot,
  Map<MealSlot, Set<MealCourseType>>? custom,
) {
  final params = courseParams[slot];
  if (params == null) return null; // завтрак и перекус — без состава
  final sides = custom == null || !custom.containsKey(slot)
      ? defaultCourseSides[slot]!
      : custom[slot] ?? const <MealCourseType>{};
  var sideShare = 0.0;
  final template = <MealCourse>[];
  for (final type in MealCourseType.values) {
    final p = params[type];
    if (p == null || !sides.contains(type)) continue;
    sideShare += p.share;
    template.add(MealCourse(
      categories: type.categories,
      share: p.share,
      optional: true,
      minSlotKcal: p.minSlotKcal,
    ));
  }
  // «Второе» замыкает приём: остаток доли (пол — 0.2 — страховка от
  // вырождения, когда боковых курсов выбрано слишком много).
  template.add(MealCourse(
    categories: const ['main', 'side'],
    share: max(1 - sideShare, 0.2),
    optional: false,
  ));
  return template;
}

/// Один курс составного приёма пищи (v0.6.9): «первое», «второе»,
/// салат, десерт.
///
/// Курс — это фильтр пула по категориям + доля цели слота. Боковые курсы
/// готовятся ровно в ОДНУ порцию (никаких «×2 салата» — разнообразие
/// вместо раздувания порций), замыкающий курс («второе») забирает
/// остаток цели и может добрать порциями (v0.6.8).
class MealCourse {
  const MealCourse({
    required this.categories,
    required this.share,
    this.optional = true,
    this.minSlotKcal = 0,
  });

  /// Категории рецептов, из которых набирается курс.
  final List<String> categories;

  /// Доля цели слота (оценочная: факт курса вычитается из остатка).
  final double share;

  /// Необязательный курс (пул пуст или цель мала — пропускается).
  /// В каждом шаблоне ровно один ОБЯЗАТЕЛЬНЫЙ курс — «второе»:
  /// он замыкает приём, забирает весь остаток калоража и не даёт
  /// составу развалиться.
  final bool optional;

  /// Курс участвует только при цели слота ≥ этого порога (0 — всегда).
  /// Десерт добавляется только к большим приёмам: при цели обеда 800
  /// ккал (2000 ккал/день) он раздувал бы приём, при 1100 (2750) —
  /// уместен ([kDessertMinSlotKcal]).
  final int minSlotKcal;

  /// Замыкающий курс («второе»): единственный обязательный — забирает
  /// весь остаток цели после факта боковых блюд и добирает порциями.
  bool get closing => !optional;
}

/// Шаблоны составных приёмов по слотам (v0.6.9) — ЭТАЛОН настроек по
/// умолчанию (v0.6.10): профильный состав строит [compositionTemplate],
/// тест закрепляет совпадение двух построений.
///
/// Обед — классическое «первое, второе, салат», при большом калораже
/// плюс десерт. Ужин — «второе + салат» (суп на ужин не поощрялся и
/// раньше — soupForDinnerPenalty). Завтрак и перекус шаблона не имеют:
/// одиночное блюдо с добором порциями там естественно (каша ×2), а
/// «завтрак из двух блюд» пулом базы не поддержан.
///
/// Порядок в списке — порядок ПОДБОРА (боковые курсы раньше «второго»,
/// чтобы остаток цели считался по факту уже выбранных блюд); порядок
/// ПОДАЧИ считает [courseServingRank].
const Map<MealSlot, List<MealCourse>> composedCourses = {
  MealSlot.lunch: [
    MealCourse(categories: ['soup'], share: 0.27),
    MealCourse(categories: ['salad'], share: 0.19),
    MealCourse(categories: ['dessert'], share: 0.14, minSlotKcal: kDessertMinSlotKcal),
    MealCourse(
        categories: ['main', 'side'], share: 0.40, optional: false),
  ],
  MealSlot.dinner: [
    MealCourse(categories: ['salad'], share: 0.30),
    MealCourse(
        categories: ['main', 'side'], share: 0.70, optional: false),
  ],
};

/// Порядок подачи блюд в составном приёме: первое → второе → салат →
/// десерт (v0.6.9). Категории вне списка идут в конце.
int courseServingRank(String category) => switch (category) {
      'soup' => 0,
      'main' || 'side' => 1,
      'salad' => 2,
      'dessert' => 3,
      _ => 4,
    };

/// Категории рецептов, подходящие слоту (жёсткое ограничение),
/// и приоритетные категории (мягкий бонус скоринга).
/// AI-2 (аудит 2026-10-28): гарниры (side) включены в обед/ужин —
/// раньше 10 side-рецептов были недостижимы ни в одном слоте.
const Map<MealSlot, List<String>> slotCategories = {
  MealSlot.breakfast: ['breakfast'],
  MealSlot.lunch: ['soup', 'main', 'salad', 'side'],
  MealSlot.dinner: ['main', 'salad', 'soup', 'side'],
  MealSlot.snack: ['snack', 'dessert'],
};

const Map<MealSlot, List<String>> preferredCategories = {
  MealSlot.breakfast: ['breakfast'],
  MealSlot.lunch: ['soup', 'main'],
  MealSlot.dinner: ['main', 'salad'],
  MealSlot.snack: ['snack', 'dessert'],
};
