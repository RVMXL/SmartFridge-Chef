/// Детерминированный планировщик меню по встроенной базе рецептов (Шаг 2).
///
/// Алгоритм на каждый слот дня:
///  1. Жёсткие фильтры: аллергии (исключают рецепт целиком), диета,
///     максимальное время готовки.
///  2. Категория рецепта должна подходить слоту (завтрак — завтраки,
///     обед — супы/основные/салаты, ужин — основные/салаты, перекус —
///     перекусы/десерты).
///  3. Скоринг (см. [_score]): покрытие холодильника, бонус за продукты
///     с истекающим сроком (порог синхронизирован с core/freshness),
///     попадание в целевую калорийность слота, анти-повторы (тот же
///     рецепт и та же «семья» блюда штрафуются по нарастающей).
///  4. Выбор максимума; зерно [Random] делает план воспроизводимым:
///     тот же seed и данные — тот же план, новый seed — новая неделя.
///
/// Подробности приоритетов — docs/ARCHITECTURE.md (AI-слой).
library;

import 'dart:math';

import '../data/models/meal_plan.dart';
import '../data/models/recipe.dart';
import '../data/models/user_profile.dart';
import 'calorie_target.dart';
import 'ingredient_matcher.dart';
import 'planner.dart';
import 'recipe_repository.dart';

/// Веса скоринга — вынесены наверх для прозрачной настройки и тестов.
abstract final class ScoreWeights {
  /// Максимальный вклад покрытия холодильника (coverage 1.0 → +50).
  static const double coverage = 50;

  /// Бонус за каждый срочный продукт (<= 2 дней), суммарно не выше [cap].
  static const double expiringUrgent = 14;
  static const double expiringSoon = 7;
  static const double expiringCap = 28;

  /// Штраф за отклонение калорийности слота от цели (45 * |d|/target).
  static const double kcalPenalty = 45;

  /// Штраф за повтор того же рецепта в неделе (за каждый предыдущий раз).
  static const double sameRecipePenalty = 90;

  /// Штраф за повтор «семьи» блюда (главного ингредиента).
  static const double sameFamilyPenalty = 15;
  static const double sameFamilyCap = 60;

  /// Мягкий штраф за повтор второго ингредиента (гарнир/основа) —
  /// против «5 ужинов с картофельным пюре».
  static const double sameSidePenalty = 10;
  static const double sameSideCap = 30;

  /// Бонус приоритетной категории слота / штраф супа на ужин.
  static const double categoryBonus = 6;
  static const double soupForDinnerPenalty = 12;

  /// Бонус/штраф при диете low_carb.
  static const double lowCarbBonus = 15;
  static const double lowCarbPenalty = 8;

  /// Диапазон случайного джиттера [0, jitter).
  static const int jitter = 7;
}

class RuleBasedPlanner implements MealPlanner {
  RuleBasedPlanner(this._repo, {this._matcher = const IngredientMatcher()});

  final RecipeRepository _repo;
  final IngredientMatcher _matcher;

  @override
  String get id => 'rule_based';

  @override
  String get label => 'Движок рецептов (офлайн, из коробки)';

  @override
  Future<GeneratedPlan> generate(PlanRequest request) async {
    final all = await _repo.loadAll();
    final fridge = _matcher.indexProducts(request.products,
        now: request.startDate);
    final pool = _hardFiltered(all, request);
    final splits = splitsForMealsPerDay(request.profile.mealsPerDay);
    final rnd = Random(request.seed);

    final usedRecipes = <String, int>{};
    final usedFamilies = <String, int>{};
    final usedSides = <String, int>{};
    final coveredKeys = <String>{};
    final days = <PlanDay>[];
    final skippedSlots = <String>[];

    for (var d = 0; d < request.days; d++) {
      final date = DateTime(
        request.startDate.year,
        request.startDate.month,
        request.startDate.day + d,
      );
      final meals = <PlannedMeal>[];
      for (final split in splits) {
        final target = slotTargetKcal(request.profile.dailyCalories, split);
        final recipe = _pickRecipe(
          pool: pool,
          slot: split.slot,
          targetKcal: target,
          fridge: fridge,
          usedRecipes: usedRecipes,
          usedFamilies: usedFamilies,
          usedSides: usedSides,
          diet: request.profile.diet,
          rnd: rnd,
        );
        if (recipe == null) {
          skippedSlots.add('день ${d + 1}, ${split.slot.key}');
          continue;
        }
        final match = _matcher.matchRecipe(recipe, fridge);
        coveredKeys.addAll(match.matchedKeys);
        meals.add(PlannedMeal(
          dayIndex: d,
          slot: split.slot,
          slotOrder: split.order,
          recipe: recipe,
          usesExpiring: match.expiringNames,
          coverage: match.coverage,
        ));
        usedRecipes[recipe.id] = (usedRecipes[recipe.id] ?? 0) + 1;
        if (recipe.family.isNotEmpty) {
          usedFamilies[recipe.family] =
              (usedFamilies[recipe.family] ?? 0) + 1;
        }
        if (recipe.secondFamily.isNotEmpty) {
          usedSides[recipe.secondFamily] =
              (usedSides[recipe.secondFamily] ?? 0) + 1;
        }
      }
      days.add(PlanDay(dayIndex: d, date: date, meals: meals));
    }

    final warnings = _buildWarnings(
      fridge: fridge,
      coveredKeys: coveredKeys,
      skippedSlots: skippedSlots,
      days: days,
      dailyTarget: request.profile.dailyCalories,
    );

    return GeneratedPlan(
      id: _planId(request),
      createdAt: DateTime.now(),
      startDate: DateTime(
        request.startDate.year,
        request.startDate.month,
        request.startDate.day,
      ),
      kcalTarget: request.profile.dailyCalories,
      seed: request.seed,
      source: id,
      days: days,
      shoppingList: _shoppingList(pool: pool, days: days, fridge: fridge),
      warnings: warnings,
    );
  }

  /// Стабильный id: неделя старта + seed (одинаковый запрос → одинаковый id).
  static String _planId(PlanRequest request) =>
      'p${request.startDate.millisecondsSinceEpoch ~/ 86400000}-'
      '${request.seed}';

  // ------------------------------------------------------------ фильтры

  /// Жёсткая фильтрация: аллергии и диета — безопасность, не скоринг.
  List<Recipe> _hardFiltered(List<Recipe> all, PlanRequest request) {
    final allergens = request.profile.allergies.toSet();
    final diet = request.profile.diet;
    return all.where((r) {
      if (r.allergens.any(allergens.contains)) return false;
      switch (diet) {
        case Diet.none:
          break;
        case Diet.vegetarian:
          if (r.hasMeat || r.hasFish) return false;
          break;
        case Diet.vegan:
        case Diet.lent:
          if (!r.vegan) return false;
          break;
        case Diet.pescatarian:
          if (r.hasMeat) return false;
          break;
        case Diet.lowCarb:
          break; // низкоуглеводность — мягкий бонус в скоринге
      }
      if (request.maxCookMinutes > 0 && r.minutes > request.maxCookMinutes) {
        return false;
      }
      return true;
    }).toList();
  }

  // ------------------------------------------------------------ скоринг

  Recipe? _pickRecipe({
    required List<Recipe> pool,
    required MealSlot slot,
    required int targetKcal,
    required Map<String, FridgeKey> fridge,
    required Map<String, int> usedRecipes,
    required Map<String, int> usedFamilies,
    required Map<String, int> usedSides,
    required Diet diet,
    required Random rnd,
  }) {
    final allowedCategories = slotCategories[slot]!;
    var candidates = pool
        .where((r) => allowedCategories.contains(r.category))
        .toList();
    if (candidates.isEmpty) {
      // Фолбэк: слот без подходящих категорий (редкие профили) —
      // берём из всего отфильтрованного пула по калорийности.
      candidates = pool;
    }
    if (candidates.isEmpty) return null;

    Recipe best = candidates.first;
    var bestScore = double.negativeInfinity;
    for (final r in candidates) {
      final s = _score(
        recipe: r,
        targetKcal: targetKcal,
        slot: slot,
        fridge: fridge,
        usedRecipes: usedRecipes,
        usedFamilies: usedFamilies,
        usedSides: usedSides,
        diet: diet,
        rnd: rnd,
      );
      if (s > bestScore) {
        bestScore = s;
        best = r;
      }
    }
    return best;
  }

  double _score({
    required Recipe recipe,
    required int targetKcal,
    required MealSlot slot,
    required Map<String, FridgeKey> fridge,
    required Map<String, int> usedRecipes,
    required Map<String, int> usedFamilies,
    required Map<String, int> usedSides,
    required Diet diet,
    required Random rnd,
  }) {
    final match = _matcher.matchRecipe(recipe, fridge);
    var s = match.coverage * ScoreWeights.coverage;

    // Приоритет сроков (№2 после безопасности): срочные продукты
    // получают наибольший бонус, «скоро истекает» — средний.
    var expiring = 0.0;
    for (final key in match.matchedKeys) {
      final days = fridge[key]!.daysLeft;
      if (days <= 2) {
        expiring += ScoreWeights.expiringUrgent;
      } else if (days <= 5) {
        expiring += ScoreWeights.expiringSoon;
      }
    }
    s += min(expiring, ScoreWeights.expiringCap);

    // Калораж слота (№3): чем ближе к цели, тем лучше.
    s -= ScoreWeights.kcalPenalty *
        (recipe.kcal - targetKcal).abs() /
        max(targetKcal, 1);

    // Диета low_carb — мягкое предпочтение.
    if (diet == Diet.lowCarb) {
      s += recipe.lowCarb
          ? ScoreWeights.lowCarbBonus
          : -ScoreWeights.lowCarbPenalty;
    }

    // Разнообразие (№5): штрафы за повторы блюда, семьи и гарнира.
    s -= ScoreWeights.sameRecipePenalty * (usedRecipes[recipe.id] ?? 0);
    s -= min(
      ScoreWeights.sameFamilyCap,
      ScoreWeights.sameFamilyPenalty * (usedFamilies[recipe.family] ?? 0),
    );
    s -= min(
      ScoreWeights.sameSideCap,
      ScoreWeights.sameSidePenalty * (usedSides[recipe.secondFamily] ?? 0),
    );

    // Приоритетные категории слота; суп на ужин не поощряем.
    if (preferredCategories[slot]!.contains(recipe.category)) {
      s += ScoreWeights.categoryBonus;
    }
    if (slot == MealSlot.dinner && recipe.category == 'soup') {
      s -= ScoreWeights.soupForDinnerPenalty;
    }

    s += rnd.nextInt(ScoreWeights.jitter);
    return s;
  }

  // --------------------------------------------------- покупки и варнинги

  /// Недостающие ингредиенты: некладовые ингредиенты выбранных рецептов,
  /// которых нет в холодильнике (дедупликация по ключу).
  List<PlanShoppingItem> _shoppingList({
    required List<Recipe> pool,
    required List<PlanDay> days,
    required Map<String, FridgeKey> fridge,
  }) {
    final pickedIds = days
        .expand((d) => d.meals)
        .map((m) => m.recipe.id)
        .toSet();
    final picked = pool.where((r) => pickedIds.contains(r.id));
    final byKey = <String, String>{};
    for (final r in picked) {
      for (final ing in r.cookingIngredients) {
        if (fridge.containsKey(ing.key)) continue;
        byKey.putIfAbsent(ing.key, () => ing.ru);
      }
    }
    final keys = byKey.keys.toList()..sort();
    return keys.map((k) => PlanShoppingItem(key: k, name: byKey[k]!)).toList();
  }

  List<String> _buildWarnings({
    required Map<String, FridgeKey> fridge,
    required Set<String> coveredKeys,
    required List<String> skippedSlots,
    required List<PlanDay> days,
    required int dailyTarget,
  }) {
    final warnings = <String>[];

    // Срочные продукты, не закрытые планом.
    final urgentUnused = fridge.values
        .where((f) => f.isUrgent && !coveredKeys.contains(f.key))
        .toList();
    for (final f in urgentUnused) {
      warnings.add(
        '«${f.productName}» истекает ${f.daysLeft <= 0 ? "сегодня" : "через ${f.daysLeft} дн."} '
        '— не вошло в план, используйте вне меню или добавьте в рецепт.',
      );
    }

    if (skippedSlots.isNotEmpty) {
      warnings.add(
        'Не удалось подобрать блюдо для: ${skippedSlots.join("; ")}. '
        'Проверьте профиль (диета/аллергии) или время готовки.',
      );
    }

    // Отклонение дня от цели более чем на 15%.
    for (final d in days) {
      if (d.meals.isEmpty) continue;
      final deviation = (d.kcalTotal - dailyTarget).abs() / dailyTarget;
      if (deviation > 0.15) {
        warnings.add(
          'День ${d.dayIndex + 1}: ${d.kcalTotal} ккал при цели '
          '$dailyTarget — отклонение ${(deviation * 100).round()}%.',
        );
      }
    }
    return warnings;
  }
}
