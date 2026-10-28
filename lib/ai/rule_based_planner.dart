/// Детерминированный планировщик меню по встроенной базе рецептов (Шаг 2).
///
/// Алгоритм на каждый слот дня:
///  1. Жёсткие фильтры: аллергии (исключают рецепт целиком), диета,
///     лечебные столы по Певзнеру (v0.5.9 — наравне с аллергиями:
///     это назначение врача, а не предпочтение), максимальное время
///     готовки.
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

import 'package:flutter/foundation.dart' show visibleForTesting;

import '../data/models/meal_plan.dart';
import '../data/models/medical_diet.dart';
import '../data/models/product.dart';
import '../data/models/recipe.dart';
import '../data/models/user_profile.dart';
import 'calorie_target.dart';
import 'dislikes.dart';
import 'equipment.dart';
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

  /// Мягкий штраф за замещаемое отсутствие техники (v0.6.4): блюдо под
  /// имеющуюся технику выигрывает при прочих равных, но блюдо с лучшим
  /// покрытием холодильника всё равно может победить. Меньше
  /// [sameFamilyPenalty], чтобы разнообразие недели страдало сильнее,
  /// чем отсутствие духовки (все духовочные блюда базы — малые).
  static const double missingEquipment = 12;

  /// Диапазон случайного джиттера [0, jitter).
  static const int jitter = 7;
}

/// Результат жёсткой фильтрации с диагностикой (v0.5.0).
class FilterDiagnostics {
  const FilterDiagnostics({
    required this.allowed,
    required this.excludedCounts,
    required this.excludedExamples,
  });

  /// Рецепты, прошедшие все фильтры (пул для скоринга).
  final List<Recipe> allowed;

  /// Причина → сколько рецептов исключено (причина — первая сработавшая).
  final Map<String, int> excludedCounts;

  /// Причина → до трёх примеров названий исключённых рецептов.
  final Map<String, List<String>> excludedExamples;
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
    final diagnostics = hardFilteredDetailed(all, request);
    final pool = diagnostics.allowed;
    final splits = splitsForMealsPerDay(request.profile.mealsPerDay);

    final usedRecipes = <String, int>{};
    final usedFamilies = <String, int>{};
    final usedSides = <String, int>{};
    final coveredKeys = <String>{};
    final days = <PlanDay>[];
    final skippedSlots = <String>[];
    // AI-5 (аудит 2026-10-28): накопленный учёт остатков по дням.
    // Граммы холодильника не «бесконечны» на всю неделю: подобранное
    // блюдо списывает свои ингредиенты, и следующие дни видят остаток
    // (null — счётная позиция, не убывает). Ключ есть для каждого
    // ключа холодильника — отличаем «счётная» от «нет в холодильнике».
    final stock = <String, double?>{
      for (final e in fridge.entries) e.key: e.value.grams,
    };
    // Дефицит, накопленный в моменты подбора: то, чего не хватило
    // именно тогда, когда блюдо выбиралось. Список покупок строится из
    // него — двойной вычет (списание + повторный пересчёт спроса)
    // невозможен.
    final deficits = <String, double>{};

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
          stock: stock,
          usedRecipes: usedRecipes,
          usedFamilies: usedFamilies,
          usedSides: usedSides,
          diets: request.profile.diets,
          ownedEquipment: request.profile.equipment?.toSet(),
          seed: request.seed,
        );
        if (recipe == null) {
          skippedSlots.add('день ${d + 1}, ${split.slot.key}');
          continue;
        }
        final match = _matcher.matchRecipe(recipe, fridge, remaining: stock);
        coveredKeys.addAll(match.matchedKeys);
        // Нелюбимое в малом количестве (приправа) — допустимо, но план
        // честно помечает «содержит: лук» (v0.5.4).
        final tolerated =
            DislikeEngine.evaluate(recipe, request.profile.dislikes)
                .toleratedMarks;
        meals.add(PlannedMeal(
          dayIndex: d,
          slot: split.slot,
          slotOrder: split.order,
          recipe: recipe,
          usesExpiring: match.expiringNames,
          coverage: match.coverage,
          minorDislikes: tolerated,
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
        // AI-5: списание подобранного блюда — потребность ингредиентов
        // уменьшает остаток; нехватка в момент подбора копится в дефицит
        // (он попадёт в список покупок, без двойного вычета).
        for (final ing in recipe.ingredients) {
          if (ing.pantry) continue;
          final cur = stock[ing.key];
          if (cur == null) continue; // счётная позиция
          if (cur >= ing.grams) {
            stock[ing.key] = cur - ing.grams;
          } else {
            deficits[ing.key] =
                (deficits[ing.key] ?? 0) + (ing.grams - cur);
            stock[ing.key] = 0.0;
          }
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
      slotPools: _slotPools(diagnostics.allowed),
      expiredNames: request.products
          .where((p) => p.status == ProductStatus.active)
          .where((p) => p.expiryDate
              .isBefore(DateTime(request.startDate.year,
                  request.startDate.month, request.startDate.day)))
          .map((p) => p.name)
          .toList(),
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
      shoppingList: _shoppingList(
        pool: pool,
        days: days,
        fridge: fridge,
        deficits: deficits,
      ),
      warnings: warnings,
      excludedCounts: diagnostics.excludedCounts,
      excludedExamples: diagnostics.excludedExamples,
    );
  }

  /// Пулы кандидатов по слотам после жёстких фильтров (для предупреждений).
  Map<MealSlot, int> _slotPools(List<Recipe> allowed) {
    final byCategory = <String, int>{};
    for (final r in allowed) {
      byCategory[r.category] = (byCategory[r.category] ?? 0) + 1;
    }
    return {
      for (final entry in slotCategories.entries)
        entry.key: entry.value
            .map((c) => byCategory[c] ?? 0)
            .reduce((a, b) => a + b),
    };
  }

  /// «1 рецепт / 2 рецепта / 5 рецептов» для предупреждений.
  static String _recipesWord(int n) {
    final mod10 = n % 10, mod100 = n % 100;
    if (mod10 == 1 && mod100 != 11) return 'рецепт';
    if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) {
      return 'рецепта';
    }
    return 'рецептов';
  }

  /// Стабильный id: неделя старта + seed (одинаковый запрос → одинаковый id).
  static String _planId(PlanRequest request) =>
      'p${request.startDate.millisecondsSinceEpoch ~/ 86400000}-'
      '${request.seed}';

  // ------------------------------------------------------------ фильтры

  /// Жёсткая фильтрация: аллергии и диеты — безопасность, не скоринг.
  /// Публичный (не private): прозрачность безопасных фильтров и прямые
  /// юнит-тесты религиозных диет на реальном пуле рецептов.
  List<Recipe> hardFiltered(List<Recipe> all, PlanRequest request) =>
      hardFilteredDetailed(all, request).allowed;

  /// Та же фильтрация с отчётом «почему исключено» (v0.5.0).
  /// Причина у рецепта — первая сработавшая: аллергии → диеты в порядке
  /// выбора → лечебные столы (v0.5.9) → нелюбимые (v0.5.4) → время готовки.
  FilterDiagnostics hardFilteredDetailed(
    List<Recipe> all,
    PlanRequest request,
  ) {
    final allergens = request.profile.allergies.toSet();
    final diets = request.profile.diets;
    final medicalTables = request.profile.medicalDiets;
    final dislikes = request.profile.dislikes;
    final maxMinutes = request.maxCookMinutes;
    // Техника (v0.6.4): null — «неизвестно/всё есть» (профили до
    // v0.6.4), фильтрации нет; явный список — проверяем каждую технику.
    final ownedEquipment = request.profile.equipment?.toSet();
    final allowed = <Recipe>[];
    final counts = <String, int>{};
    final examples = <String, List<String>>{};
    void exclude(String reason, Recipe r) {
      counts[reason] = (counts[reason] ?? 0) + 1;
      final list = examples.putIfAbsent(reason, () => []);
      if (list.length < 3) list.add(r.titleRu);
    }

    for (final r in all) {
      var reason = allergenExclusionReason(r, allergens);
      if (reason == null) {
        for (final d in diets) {
          reason = dietExclusionReason(r, d);
          if (reason != null) break;
        }
      }
      // Лечебные столы — безопасность наравне с аллергиями (v0.5.9).
      reason ??= MedicalDiet.exclusionReason(r, medicalTables);
      reason ??= DislikeEngine.evaluate(r, dislikes).exclusionReason;
      // Техника (v0.6.4): нерезервируемое расхождение — духовка для
      // большого блюда (>= kOvenBigServings порций) — жёсткий фильтр.
      // Замещаемые расхождения НЕ исключают: блюдо предлагается со
      // штрафом в скоринге и пометкой замены (UI считает сам).
      if (reason == null && ownedEquipment != null) {
        final equipmentGaps = KitchenEquipmentEngine.gaps(
          needed: KitchenEquipmentEngine.requiredForSteps(
              KitchenEquipmentEngine.stepsTextOf(r.stepsRu)),
          servings: r.servings,
          owned: ownedEquipment,
        );
        if (KitchenEquipmentEngine.hasBlocking(equipmentGaps)) {
          final blocked = equipmentGaps
              .firstWhere((g) => !g.substitutable)
              .equipment;
          reason = 'нет техники: ${blocked.ruLabel} — блюдо большое, '
              'замене не подлежит';
        }
      }
      if (reason == null && maxMinutes > 0 && r.minutes > maxMinutes) {
        reason = 'готовка дольше $maxMinutes мин';
      }
      if (reason == null) {
        allowed.add(r);
      } else {
        exclude(reason, r);
      }
    }
    return FilterDiagnostics(
      allowed: allowed,
      excludedCounts: counts,
      excludedExamples: examples,
    );
  }

  /// Человеческая причина исключения рецепта аллергиями (или null).
  static String? allergenExclusionReason(
    Recipe r,
    Set<Allergen> allergies,
  ) {
    for (final a in allergies) {
      if (r.allergens.contains(a)) {
        return 'аллергия: ${_allergenRu[a] ?? a.key}';
      }
    }
    return null;
  }

  static const Map<Allergen, String> _allergenRu = {
    Allergen.milk: 'молоко',
    Allergen.eggs: 'яйца',
    Allergen.fish: 'рыба',
    Allergen.crustaceans: 'ракообразные',
    Allergen.molluscs: 'моллюски',
    Allergen.nuts: 'орехи',
    Allergen.peanuts: 'арахис',
    Allergen.soy: 'соя',
    Allergen.wheat: 'пшеница (глютен)',
    Allergen.sesame: 'кунжут',
    Allergen.honey: 'мёд',
    Allergen.chocolate: 'шоколад, какао',
    Allergen.redProduce: 'красные и оранжевые плоды',
    Allergen.mushrooms: 'грибы',
    Allergen.spices: 'чеснок и пряности',
    Allergen.poultry: 'курица и птица',
    Allergen.beef: 'говядина',
    Allergen.pork: 'свинина',
    Allergen.mildFruits: 'персики, абрикосы, виноград',
    Allergen.mildCereals: 'рис, гречка, кукуруза',
    Allergen.mildVegetables: 'перец, картофель, горох',
  };

  /// Человеческая причина исключения рецепта диетой (или null).
  /// Используется и фильтром, и диагностикой — правила в одном месте.
  static String? dietExclusionReason(Recipe r, Diet d) {
    switch (d) {
      case Diet.none:
        return null;
      case Diet.vegetarian:
        if (r.hasMeat || r.hasFish) return 'вегетарианская: мясо или рыба';
        return null;
      case Diet.vegan:
        if (!r.vegan) return 'веганская: не веганский рецепт';
        return null;
      case Diet.lent:
        if (!r.vegan) return 'пост: не постный рецепт';
        return null;
      case Diet.pescatarian:
        if (r.hasMeat) return 'пескетарианская: мясо';
        return null;
      case Diet.lowCarb:
        return null; // низкоуглеводность — мягкий бонус в скоринге
      case Diet.halal:
        if (r.hasPork) return 'халяль: свинина';
        if (r.hasAlcohol) return 'халяль: алкоголь';
        return null;
      case Diet.kosher:
        if (r.hasPork) return 'кошер: свинина';
        if (r.hasAlcohol) return 'кошер: алкоголь';
        if (r.hasShellfish) return 'кошер: морепродукты без чешуи';
        if (r.hasMeat && r.hasDairy) {
          return 'кошер: мясо с молочным';
        }
        return null;
      case Diet.hindu:
        if (r.hasBeef) return 'индуизм: говядина';
        return null;
    }
  }

  // ------------------------------------------------------------ скоринг

  Recipe? _pickRecipe({
    required List<Recipe> pool,
    required MealSlot slot,
    required int targetKcal,
    required Map<String, FridgeKey> fridge,
    required Map<String, double?> stock,
    required Map<String, int> usedRecipes,
    required Map<String, int> usedFamilies,
    required Map<String, int> usedSides,
    required List<Diet> diets,
    required Set<KitchenEquipment>? ownedEquipment,
    required int seed,
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
        stock: stock,
        usedRecipes: usedRecipes,
        usedFamilies: usedFamilies,
        usedSides: usedSides,
        diets: diets,
        ownedEquipment: ownedEquipment,
        seed: seed,
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
    required Map<String, double?> stock,
    required Map<String, int> usedRecipes,
    required Map<String, int> usedFamilies,
    required Map<String, int> usedSides,
    required List<Diet> diets,
    required Set<KitchenEquipment>? ownedEquipment,
    required int seed,
  }) {
    final match = _matcher.matchRecipe(recipe, fridge, remaining: stock);
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
    var kcalPenalty = ScoreWeights.kcalPenalty *
        (recipe.kcal - targetKcal).abs() /
        max(targetKcal, 1);
    // AI-3 (аудит 2026-10-28): «суп на обед» декларирован в
    // preferredCategories, но штраф 45·|Δ|/target ронял средний суп
    // (236 ккал при цели 800) на ~200-е место из 399 — супы/салаты
    // системно меньше main-порции, поэтому для них в основных слотах
    // штраф умножается на 0.3. Иначе заявленный приоритет не работает.
    if ((slot == MealSlot.lunch || slot == MealSlot.dinner) &&
        (recipe.category == 'soup' || recipe.category == 'salad')) {
      kcalPenalty *= 0.3;
    }
    s -= kcalPenalty;

    // Диета low_carb — мягкое предпочтение (среди прочих выбранных диет).
    if (diets.contains(Diet.lowCarb)) {
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

    // Техника (v0.6.4): замещаемое отсутствие — мягкий штраф, чтобы
    // блюда под имеющуюся технику выигрывали при прочих равных. Жёсткий
    // фильтр уже сработал в hardFilteredDetailed — здесь остаются только
    // заместимые расхождения, но страховка не помешает: блокирующее
    // расхождение (если когда-нибудь дойдёт сюда) штрафуется так же.
    if (ownedEquipment != null) {
      final equipmentGaps = KitchenEquipmentEngine.gaps(
        needed: KitchenEquipmentEngine.requiredForSteps(
            KitchenEquipmentEngine.stepsTextOf(recipe.stepsRu)),
        servings: recipe.servings,
        owned: ownedEquipment,
      );
      s -= ScoreWeights.missingEquipment * equipmentGaps.length;
    }

    // AI-6 (аудит 2026-10-28, v0.6.2): джиттер детерминирован парой
    // «блюдо × слот × зерно» (FNV-1a), а не порядком обхода кандидатов —
    // раньше rnd.nextInt() сдвигал генератор на каждом кандидате, и
    // джиттер блюда менялся от того, сколько и каких кандидатов шло
    // перед ним (добавление рецепта в пул сдвигало выбор других).
    s += slotJitter(recipe.id, seed, slot);
    return s;
  }

  /// Стабильный джиттер [0, jitter): FNV-1a по «id|слот|зерно».
  @visibleForTesting
  static int slotJitter(String recipeId, int seed, MealSlot slot) {
    var h = 0x811c9dc5;
    final s = '$recipeId|${slot.index}|${seed & 0x7fffffff}';
    for (final code in s.codeUnits) {
      h ^= code;
      h = (h * 0x01000193) & 0x7fffffff;
    }
    return h % ScoreWeights.jitter;
  }

  // --------------------------------------------------- покупки и варнинги

  /// Недостающие ингредиенты: некладовые ингредиенты выбранных рецептов,
  /// которых в холодильнике нет или не хватало ПО СОСТОЯНИЮ НА МОМЕНТ
  /// подбора (AI-5, аудит 2026-10-28: раньше граммы считались достаточными
  /// для всех блюд недели одновременно — 400 г риса «хватало» на три
  /// блюда по 300 г, и подсказка «докупить ≈N г» занижала недостачу;
  /// дефицит копится в [deficits] во время генерации плана — двойного
  /// вычета нет). Для счётных позиций (масса неизвестна) подсказка
  /// в граммах не даётся.
  List<PlanShoppingItem> _shoppingList({
    required List<Recipe> pool,
    required List<PlanDay> days,
    required Map<String, FridgeKey> fridge,
    required Map<String, double> deficits,
  }) {
    final pickedIds = days
        .expand((d) => d.meals)
        .map((m) => m.recipe.id)
        .toSet();
    final picked = pool.where((r) => pickedIds.contains(r.id));
    final neededBy = <String, int>{};
    final nameBy = <String, String>{};
    for (final r in picked) {
      for (final ing in r.cookingIngredients) {
        neededBy[ing.key] = (neededBy[ing.key] ?? 0) + ing.grams;
        nameBy.putIfAbsent(ing.key, () => ing.ru);
      }
    }
    final items = <PlanShoppingItem>[];
    final keys = neededBy.keys.toList()..sort();
    for (final k in keys) {
      final fk = fridge[k];
      if (fk == null) {
        // Ключа нет в холодильнике вовсе — полная потребность.
        items.add(PlanShoppingItem(
          key: k,
          name: nameBy[k]!,
          missingGrams: neededBy[k]!,
        ));
        continue;
      }
      final deficit = deficits[k] ?? 0.0;
      if (deficit <= 0) continue; // хватило (или счётная позиция)
      final missing = deficit.ceil();
      items.add(PlanShoppingItem(
        key: k,
        name: nameBy[k]!,
        missingGrams: missing > 0 ? missing : null,
      ));
    }
    return items;
  }

  List<String> _buildWarnings({
    required Map<String, FridgeKey> fridge,
    required Set<String> coveredKeys,
    required List<String> skippedSlots,
    required List<PlanDay> days,
    required int dailyTarget,
    required Map<MealSlot, int> slotPools,
    required List<String> expiredNames,
  }) {
    final warnings = <String>[];

    // AI-4 (аудит 2026-10-28): просроченные продукты не участвуют в
    // подборе — пользователь должен знать, что именно выпало из плана.
    if (expiredNames.isNotEmpty) {
      final shown = expiredNames.take(5).join(', ');
      final more = expiredNames.length > 5
          ? ' и ещё ${expiredNames.length - 5}'
          : '';
      warnings.add(
        'Просроченные продукты не участвуют в подборе меню: $shown$more. '
        'Замените или удалите их.',
      );
    }

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

    // AI-1 (аудит 2026-10-28): вырожденные слоты после жёстких фильтров.
    // Недельный план использует каждый слот ~7 раз — при пуле меньше
    // семи блюд план неминуемо повторяется, и пользователь должен
    // видеть причину (столы №4/12/13/14 и молочно-яичные завтраки
    // давали вырожденность незаметно для пользователя).
    const slotNames = {
      MealSlot.breakfast: 'завтрак',
      MealSlot.lunch: 'обед',
      MealSlot.dinner: 'ужин',
      MealSlot.snack: 'перекус',
    };
    slotPools.forEach((slot, poolSize) {
      if (poolSize < 7) {
        warnings.add(
          'В слоте «${slotNames[slot]}» после фильтров осталось $poolSize '
          '${_recipesWord(poolSize)} — меню будет повторяться. '
          'Ослабьте фильтры (аллергии/диеты/столы) в профиле.',
        );
      }
    });

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
