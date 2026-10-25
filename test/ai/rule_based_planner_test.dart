/// Интеграционные тесты RuleBasedPlanner на реальной базе рецептов:
/// безопасность (аллергии/диета), приоритет сроков, разнообразие,
/// детерминизм, список покупок и предупреждения (Шаг 2).
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:smart_fridge_chef/ai/planner.dart';
import 'package:smart_fridge_chef/ai/recipe_repository.dart';
import 'package:smart_fridge_chef/ai/rule_based_planner.dart';
import 'package:smart_fridge_chef/data/models/product.dart';
import 'package:smart_fridge_chef/data/models/user_profile.dart';

void main() {
  late RecipeRepository repo;
  late RuleBasedPlanner planner;

  setUpAll(() async {
    repo = RecipeRepository(
      loadString: () =>
          File('assets/data/recipes.json').readAsString(),
    );
    planner = RuleBasedPlanner(repo);
  });

  UserProfile profile({
    int calories = 2000,
    List<Diet> diets = const [],
    List<Allergen> allergies = const [],
    int mealsPerDay = 3,
  }) =>
      UserProfile(
        dailyCalories: calories,
        diets: diets,
        allergies: allergies,
        mealsPerDay: mealsPerDay,
        createdAt: DateTime(2026, 10, 24),
        updatedAt: DateTime(2026, 10, 24),
      );

  PlanRequest request({
    UserProfile? prof,
    List<Product> products = const [],
    int days = 7,
    int seed = 1,
    int mealsPerDay = 3,
    List<Diet> diets = const [],
    List<Allergen> allergies = const [],
    int maxCookMinutes = 0,
  }) =>
      PlanRequest(
        products: products,
        profile: prof ??
            profile(
              diets: diets,
              allergies: allergies,
              mealsPerDay: mealsPerDay,
            ),
        startDate: DateTime(2026, 10, 26), // понедельник
        days: days,
        seed: seed,
        maxCookMinutes: maxCookMinutes,
      );

  Product product(String name, String category, int inDays) => Product(
        name: name,
        category: ProductCategory.fromKey(category),
        expiryDate: DateTime(2026, 10, 26).add(Duration(days: inDays)),
        addedAt: DateTime(2026, 10, 24),
      );

  group('структура плана', () {
    test('7 дней x 3 приёма, даты последовательные', () async {
      final plan = await planner.generate(request());

      expect(plan.daysCount, 7);
      for (final day in plan.days) {
        expect(day.meals.length, 3);
        expect(day.meals.map((m) => m.slot.key).toSet(),
            {'breakfast', 'lunch', 'dinner'});
      }
      expect(plan.days.first.date, DateTime(2026, 10, 26));
      expect(plan.days.last.date, DateTime(2026, 11, 1));
    });

    test('завтрак — только из категории завтраков', () async {
      final plan = await planner.generate(request());
      final breakfasts =
          plan.days.map((d) => d.meals.first).toList();
      expect(
        breakfasts.every((m) => m.recipe.category == 'breakfast'),
        isTrue,
      );
    });

    test('mealsPerDay = 2: обед и ужин без завтрака', () async {
      final plan = await planner.generate(request(mealsPerDay: 2));
      for (final day in plan.days) {
        expect(day.meals.map((m) => m.slot.key).toSet(),
            {'lunch', 'dinner'});
      }
    });

    test('mealsPerDay = 4: есть перекус', () async {
      final plan = await planner.generate(request(mealsPerDay: 4));
      final slots = plan.days.first.meals.map((m) => m.slot.key).toSet();
      expect(slots, contains('snack'));
      expect(slots, contains('breakfast'));
    });
  });

  group('безопасность', () {
    test('аллергия на молоко и яйца исключает их полностью', () async {
      final plan = await planner.generate(
        request(allergies: [Allergen.milk, Allergen.eggs]),
      );
      final allMeals = plan.days.expand((d) => d.meals);
      for (final meal in allMeals) {
        expect(meal.recipe.allergens, isNot(contains(Allergen.milk)),
            reason: meal.recipe.titleRu);
        expect(meal.recipe.allergens, isNot(contains(Allergen.eggs)),
            reason: meal.recipe.titleRu);
      }
    });

    test('веганский профиль: только веганские рецепты', () async {
      final plan = await planner.generate(request(diets: [Diet.vegan]));
      final allMeals = plan.days.expand((d) => d.meals);
      expect(allMeals, isNotEmpty);
      for (final meal in allMeals) {
        expect(meal.recipe.vegan, isTrue, reason: meal.recipe.titleRu);
      }
    });

    test('пескетарианство: мясо исключено, рыба разрешена', () async {
      final plan = await planner.generate(
          request(diets: [Diet.pescatarian], seed: 3));
      final allMeals = plan.days.expand((d) => d.meals);
      for (final meal in allMeals) {
        expect(meal.recipe.hasMeat, isFalse,
            reason: meal.recipe.titleRu);
      }
    });

    test('ограничение времени готовки соблюдается', () async {
      final plan = await planner.generate(request(maxCookMinutes: 20));
      final allMeals = plan.days.expand((d) => d.meals);
      for (final meal in allMeals) {
        expect(meal.recipe.minutes, lessThanOrEqualTo(20),
            reason: meal.recipe.titleRu);
      }
    });
  });

  group('религиозные диеты', () {
    test('халяль: свинина и алкоголь исключены, креветки разрешены',
        () async {
      final pool = await repo.loadAll();
      final allowed =
          planner.hardFiltered(pool, request(diets: [Diet.halal]));
      final allowedIds = allowed.map((r) => r.id).toSet();
      for (final r in pool) {
        if (r.hasPork || r.hasAlcohol) {
          expect(allowedIds.contains(r.id), isFalse, reason: r.titleRu);
        }
      }
      // Ключевое отличие от кошера: морепродукты остаются в пуле.
      expect(
        allowed.where((r) => r.hasShellfish),
        isNotEmpty,
        reason: 'халяль разрешает морепродукты — пул не должен их терять',
      );
    });

    test('кошер: свинина, алкоголь, моллюски и мясо+молочное исключены',
        () async {
      final pool = await repo.loadAll();
      final allowed =
          planner.hardFiltered(pool, request(diets: [Diet.kosher]));
      expect(allowed.length, lessThan(pool.length),
          reason: 'кошерный пул обязан сузиться');
      for (final r in allowed) {
        expect(r.hasPork, isFalse, reason: r.titleRu);
        expect(r.hasAlcohol, isFalse, reason: r.titleRu);
        expect(r.hasShellfish, isFalse, reason: r.titleRu);
        if (r.hasMeat) {
          expect(r.hasDairy, isFalse,
              reason: '${r.titleRu}: мясо + молочное в одном блюде');
        }
      }
    });

    test('кошер: рыба с молочным остаётся в пуле (парве)', () async {
      final pool = await repo.loadAll();
      final fishDairy = pool
          .where((r) =>
              r.hasFish && r.hasDairy && !r.hasMeat && !r.hasShellfish)
          .toList();
      expect(fishDairy, isNotEmpty,
          reason: 'в базе есть рыбные блюда с молочным — они не «мясо»');
      final allowed = planner
          .hardFiltered(pool, request(diets: [Diet.kosher]))
          .map((r) => r.id)
          .toSet();
      for (final r in fishDairy) {
        expect(allowed.contains(r.id), isTrue,
            reason: '${r.titleRu} — рыба парве, кошеру не мешает');
      }
    });

    test('индуизм: говядина исключена, свинина не трогается', () async {
      final pool = await repo.loadAll();
      final allowed =
          planner.hardFiltered(pool, request(diets: [Diet.hindu]));
      final allowedIds = allowed.map((r) => r.id).toSet();
      for (final r in pool) {
        if (r.hasBeef) {
          expect(allowedIds.contains(r.id), isFalse, reason: r.titleRu);
        }
      }
      expect(
        allowed.where((r) => r.hasPork),
        isNotEmpty,
        reason: 'индуизм запрещает только говядину',
      );
    });

    test('все религиозные диеты оставляют достаточный пул для недели',
        () async {
      final pool = await repo.loadAll();
      // неделя 7д x 3 приёма = 21 уникальное блюдо; пул обязан
      // многократно перекрывать потребность
      expect(
        planner.hardFiltered(pool, request(diets: [Diet.halal])).length,
        greaterThan(100),
      );
      expect(
        planner.hardFiltered(pool, request(diets: [Diet.kosher])).length,
        greaterThan(100),
      );
      expect(
        planner.hardFiltered(pool, request(diets: [Diet.hindu])).length,
        greaterThan(100),
      );
    });

    test('планы на религиозных диетах уважают фильтры', () async {
      for (final diet in [Diet.halal, Diet.kosher, Diet.hindu]) {
        final plan =
            await planner.generate(request(diets: [diet], seed: 8));
        final allMeals = plan.days.expand((d) => d.meals);
        expect(allMeals, isNotEmpty, reason: diet.key);
        for (final meal in allMeals) {
          if (diet == Diet.halal || diet == Diet.kosher) {
            expect(meal.recipe.hasPork, isFalse,
                reason: '${diet.key}: ${meal.recipe.titleRu}');
            expect(meal.recipe.hasAlcohol, isFalse,
                reason: '${diet.key}: ${meal.recipe.titleRu}');
          }
          if (diet == Diet.kosher) {
            expect(meal.recipe.hasShellfish, isFalse,
                reason: meal.recipe.titleRu);
            if (meal.recipe.hasMeat) {
              expect(meal.recipe.hasDairy, isFalse,
                  reason: meal.recipe.titleRu);
            }
          }
          if (diet == Diet.hindu) {
            expect(meal.recipe.hasBeef, isFalse,
                reason: meal.recipe.titleRu);
          }
        }
      }
    });
  });

  group('приоритет сроков', () {
    test('срочная рыба используется в первые дни плана', () async {
      // В холодильнике только истекающая рыба + чуть крупы.
      final fridge = [
        product('Минтай', 'fish', 1), // истекает завтра
        product('Рис', 'grains', 200),
      ];
      final plan = await planner.generate(
        request(products: fridge, seed: 2),
      );

      final early = plan.days.take(3).expand((d) => d.meals);
      final usedFishEarly = early.any(
        (m) => m.usesExpiring.contains('Минтай'),
      );
      expect(usedFishEarly, isTrue,
          reason: 'срочный продукт должен попасть в первые 3 дня');
    });

    test('usesExpiring заполняется только для продуктов <= 2 дней',
        () async {
      final fridge = [
        product('Молоко', 'dairy', 1), // срочное
        product('Гречка', 'grains', 100), // свежая
      ];
      final plan = await planner.generate(request(products: fridge));
      final allExpiring =
          plan.days.expand((d) => d.meals).expand((m) => m.usesExpiring);
      expect(allExpiring, contains('Молоко'));
      expect(allExpiring, isNot(contains('Гречка')));
    });
  });

  group('разнообразие', () {
    test('на пустом холодильнике ни один рецепт не повторяется за неделю',
        () async {
      final plan = await planner.generate(request(seed: 5));
      final ids = plan.days
          .expand((d) => d.meals)
          .map((m) => m.recipe.id)
          .toList();
      expect(ids.toSet().length, ids.length,
          reason: 'повторы: ${ids.where((id) => ids.where((x) => x == id).length > 1).toSet()}');
    });

    test('разные seed дают разные планы', () async {
      final a = await planner.generate(request(seed: 10));
      final b = await planner.generate(request(seed: 11));
      final titlesA = a.days.expand((d) => d.meals)
          .map((m) => m.recipe.id).join(',');
      final titlesB = b.days.expand((d) => d.meals)
          .map((m) => m.recipe.id).join(',');
      expect(titlesA, isNot(titlesB));
    });

    test('одинаковый seed — полностью детерминированный план', () async {
      final a = await planner.generate(request(seed: 42));
      final b = await planner.generate(request(seed: 42));
      final idsA = a.days.expand((d) => d.meals)
          .map((m) => m.recipe.id).toList();
      final idsB = b.days.expand((d) => d.meals)
          .map((m) => m.recipe.id).toList();
      expect(idsA, idsB);
      expect(a.id, b.id);
    });
  });

  group('список покупок и предупреждения', () {
    test('кладовые продукты не попадают в покупки; недостающее — попадает',
        () async {
      final plan = await planner.generate(request(seed: 7));
      final names = plan.shoppingList.map((s) => s.name).toSet();

      expect(names, isNot(contains('соль')));
      expect(names, isNot(contains('растительное масло')));
      expect(plan.shoppingList, isNotEmpty,
          reason: 'на пустом холодильнике покупки обязаны быть');
    });

    test('полный холодильник сокращает список покупок', () async {
      final emptyFridge =
          await planner.generate(request(seed: 7));
      // Кладём в холодильник всё, что требует первый план.
      final covered = <Product>[];
      var day = 0;
      for (final meal in emptyFridge.days.expand((d) => d.meals)) {
        for (final ing in meal.recipe.cookingIngredients) {
          covered.add(product(
            ing.ru,
            'other',
            10 + (day++),
          ));
        }
      }
      final fullFridge = await planner.generate(
        request(products: covered, seed: 7),
      );
      expect(fullFridge.shoppingList.length,
          lessThan(emptyFridge.shoppingList.length));
    });

    test('срочный неопознанный продукт даёт предупреждение', () async {
      final fridge = [
        product('Трюфель экзотический', 'other', 0),
      ];
      final plan = await planner.generate(request(products: fridge));
      expect(
        plan.warnings.any((w) => w.contains('Трюфель экзотический')),
        isTrue,
        reason: plan.warnings.join(' | '),
      );
    });
  });

  group('детали', () {
    test('coverage попадает в [0..1], usesExpiring — имена продуктов',
        () async {
      final plan = await planner.generate(request(seed: 9));
      for (final meal in plan.days.expand((d) => d.meals)) {
        expect(meal.coverage, inInclusiveRange(0, 1));
      }
    });

    test('source и seed фиксируются в плане', () async {
      final plan = await planner.generate(request(seed: 15));
      expect(plan.source, 'rule_based');
      expect(plan.seed, 15);
      expect(plan.kcalTarget, 2000);
    });

    test('план на 3 дня корректен (горизонт настраивается)', () async {
      final plan = await planner.generate(request(days: 3, seed: 21));
      expect(plan.daysCount, 3);
      expect(plan.days.last.date, DateTime(2026, 10, 28));
    });
  });

  group('несколько диет одновременно (v0.5.0)', () {
    test('халяль + веган: применяются оба ограничения', () async {
      final plan = await planner.generate(
          request(diets: [Diet.halal, Diet.vegan], seed: 11));
      final allMeals = plan.days.expand((d) => d.meals);
      expect(allMeals, isNotEmpty);
      for (final meal in allMeals) {
        expect(meal.recipe.vegan, isTrue, reason: meal.recipe.titleRu);
        expect(meal.recipe.hasPork, isFalse, reason: meal.recipe.titleRu);
        expect(meal.recipe.hasAlcohol, isFalse,
            reason: meal.recipe.titleRu);
      }
    });

    test('кошер + индуизм: и свинина/моллюски, и говядина исключены',
        () async {
      final pool = await repo.loadAll();
      final allowed = planner
          .hardFiltered(pool, request(diets: [Diet.kosher, Diet.hindu]));
      for (final r in allowed) {
        expect(r.hasBeef, isFalse, reason: r.titleRu);
        expect(r.hasPork, isFalse, reason: r.titleRu);
        expect(r.hasShellfish, isFalse, reason: r.titleRu);
        if (r.hasMeat) expect(r.hasDairy, isFalse, reason: r.titleRu);
      }
      // Составное правило отсекает больше, чем каждая диета отдельно.
      final onlyKosher =
          planner.hardFiltered(pool, request(diets: [Diet.kosher]));
      final onlyHindu =
          planner.hardFiltered(pool, request(diets: [Diet.hindu]));
      expect(allowed.length, lessThan(onlyKosher.length));
      expect(allowed.length, lessThan(onlyHindu.length));
    });
  });

  group('диагностика «почему исключено» (v0.5.0)', () {
    test('без диет и аллергий исключений нет', () async {
      final plan = await planner.generate(request(seed: 12));
      expect(plan.hasExclusions, isFalse);
    });

    test('халяль: счётчик свинины = 20, примеры приложены', () async {
      final pool = await repo.loadAll();
      final diag = planner
          .hardFilteredDetailed(pool, request(diets: [Diet.halal]));
      expect(diag.excludedCounts['халяль: свинина'], 20);
      expect(diag.excludedExamples['халяль: свинина'], isNotEmpty);
      expect(diag.excludedExamples['халяль: свинина']!.length,
          lessThanOrEqualTo(3));
      // Сумма исключённых + пул = вся база (причина у рецепта одна).
      final excluded =
          diag.excludedCounts.values.fold<int>(0, (a, b) => a + b);
      expect(diag.allowed.length + excluded, pool.length);
    });

    test('кошер: причины свинина/моллюски/мясо+молочное все присутствуют',
        () async {
      final pool = await repo.loadAll();
      final diag = planner
          .hardFilteredDetailed(pool, request(diets: [Diet.kosher]));
      expect(
        diag.excludedCounts.keys.toSet(),
        containsAll(<String>[
          'кошер: свинина',
          'кошер: морепродукты без чешуи',
          'кошер: мясо с молочным',
        ]),
      );
      final excluded =
          diag.excludedCounts.values.fold<int>(0, (a, b) => a + b);
      expect(diag.allowed.length + excluded, pool.length);
    });

    test('аллергия приоритетнее диеты (первая сработавшая причина)',
        () async {
      final pool = await repo.loadAll();
      final diag = planner.hardFilteredDetailed(
        pool,
        request(diets: [Diet.vegan], allergies: [Allergen.milk]),
      );
      // Не-веганский рецепт с молоком: причина — аллергия, не диета.
      final dairyNonVegan = pool
          .where((r) => r.allergens.contains(Allergen.milk) && !r.vegan)
          .toList();
      expect(dairyNonVegan, isNotEmpty);
      final reason = diag.excludedExamples.entries
          .firstWhere((e) => e.value.contains(dairyNonVegan.first.titleRu))
          .key;
      expect(reason, startsWith('аллергия:'));
    });

    test('ограничение времени готовки попадает в отчёт', () async {
      final pool = await repo.loadAll();
      final diag = planner.hardFilteredDetailed(
          pool, request(maxCookMinutes: 20));
      expect(diag.excludedCounts.containsKey('готовка дольше 20 мин'),
          isTrue, reason: diag.excludedCounts.keys.join(', '));
    });
  });

  group('граммы в списке покупок (v0.5.0)', () {
    Product gramProduct(String name, double grams) => Product(
          name: name,
          category: ProductCategory.other,
          quantity: grams,
          unit: ProductUnit.gram,
          expiryDate: DateTime(2026, 11, 10),
          addedAt: DateTime(2026, 10, 24),
        );

    test('на пустом холодильнике каждая позиция несёт оценку в граммах',
        () async {
      final plan = await planner.generate(request(seed: 13));
      expect(plan.shoppingList, isNotEmpty);
      for (final item in plan.shoppingList) {
        expect(item.missingGrams, isNotNull,
            reason: '${item.key}: ${item.name}');
        expect(item.missingGrams!, greaterThan(0));
      }
    });

    test('не хватает по массе — в покупке недостача, хватает — позиции нет',
        () async {
      final draft = await planner.generate(request(seed: 7));
      expect(draft.shoppingList.length,
          greaterThan(draft.shoppingList.where((i) => i.missingGrams == null).length));
      // Закупаем ровно недостающее в граммах.
      final covered = <Product>[
        for (final item in draft.shoppingList)
          gramProduct(item.name, item.missingGrams!.toDouble()),
      ];
      final full = await planner
          .generate(request(products: covered, seed: 7));
      // Каждая оставшаяся позиция — тоже с граммовой оценкой.
      for (final item in full.shoppingList) {
        expect(item.missingGrams, isNotNull,
            reason: '${item.key}: ${item.name}');
      }
    });
  });
}
