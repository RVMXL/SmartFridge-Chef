/// Распределение суточного калоража по приёмам пищи (Шаг 2).
///
/// Профиль задаёт mealsPerDay (2–6) и dailyCalories; планер получает
/// целевую калорийность каждого слота. Доли подобраны по стандартной
/// диетологии: завтрак ~25–30%, обед ~35–40%, ужин ~25–30%,
/// перекусы делят остаток. Сумма долей всегда 1.0 — закреплено тестом.
library;

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

/// Минимальная цель бокового курса, ради которой стоит готовить отдельное
/// блюдо (v0.6.9): курс с целью ниже этого порога пропускается, его долю
/// забирает «второе». Пример: салат на 60 ккал — это «ещё одно блюдо,
/// которое почти ничего не закрывает», а не составная часть приёма.
const int kMinCourseTargetKcal = 100;

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
  /// уместен.
  final int minSlotKcal;
}

/// Шаблоны составных приёмов по слотам (v0.6.9).
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
    MealCourse(categories: ['dessert'], share: 0.14, minSlotKcal: 950),
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
