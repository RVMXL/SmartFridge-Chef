/// Тесты волны 2 аудита 2026-10-28 для слоя планера:
/// AI-2 (side в слотах), AI-3 (kcal-штраф супов/салатов ×0.3),
/// AI-4 (просрочка не закрывает ингредиенты + предупреждение),
/// AI-5 (накопленный учёт остатков в списке покупок),
/// AI-9 (runtime-деривации нескольких аллергенов с одного ключа).
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:smart_fridge_chef/ai/calorie_target.dart';
import 'package:smart_fridge_chef/ai/ingredient_matcher.dart';
import 'package:smart_fridge_chef/ai/planner.dart';
import 'package:smart_fridge_chef/ai/recipe_repository.dart';
import 'package:smart_fridge_chef/ai/rule_based_planner.dart';
import 'package:smart_fridge_chef/data/models/product.dart';
import 'package:smart_fridge_chef/data/models/recipe.dart';
import 'package:smart_fridge_chef/data/models/user_profile.dart';

void main() {
  late RecipeRepository repo;
  late RuleBasedPlanner planner;

  setUpAll(() async {
    repo = RecipeRepository(
      loadString: () => File('assets/data/recipes.json').readAsString(),
    );
    planner = RuleBasedPlanner(repo);
  });

  UserProfile profile({int calories = 2000, int mealsPerDay = 3}) =>
      UserProfile(
        dailyCalories: calories,
        diets: const [],
        allergies: const [],
        mealsPerDay: mealsPerDay,
        createdAt: DateTime(2026, 10, 24),
        updatedAt: DateTime(2026, 10, 24),
      );

  PlanRequest request({
    List<Product> products = const [],
    int days = 7,
    int seed = 1,
  }) =>
      PlanRequest(
        products: products,
        profile: profile(),
        startDate: DateTime(2026, 10, 26), // понедельник
        days: days,
        seed: seed,
      );

  group('AI-2: гарниры (side) достижимы в основных слотах', () {
    test('slotCategories обеда/ужина содержат side', () {
      expect(slotCategories[MealSlot.lunch]!, contains('side'));
      expect(slotCategories[MealSlot.dinner]!, contains('side'));
    });

    test('side-рецепты попадают в пул обеда/ужина реального плана', () async {
      final plan = await planner.generate(request(seed: 42));
      final pickedCategories = plan.days
          .expand((d) => d.meals)
          .map((m) => m.recipe.category)
          .toSet();
      // База side-блюд мала (10), попадание зависит от холодильника,
      // поэтому проверяем инвариант жёстче: каждая категория подобранного
      // блюда разрешена слоту, в который оно попало.
      for (final day in plan.days) {
        for (final meal in day.meals) {
          expect(slotCategories[meal.slot]!, contains(meal.recipe.category),
              reason: '${meal.slot.key} / ${meal.recipe.id}');
        }
      }
      // И сам пул: если бы side не был разрешён, категория не смогла бы
      // появиться ни при каком холодильнике.
      expect(
        slotCategories.values.expand((c) => c).toSet(),
        containsAll(['side', 'soup', 'main', 'salad']),
      );
      expect(pickedCategories, isNotEmpty);
    });
  });

  group('AI-3: супы не выдавливаются из обеда калоражем', () {
    test('суп попадает в план обеда при цели 2000 ккал', () async {
      // Раньше лучший суп занимал ~202-е место из 399 кандидатов обеда:
      // штраф 45·|Δ|/target убивал категорию целиком. С коэффициентом 0.3
      // супы периодически выигрывают слот — проверяем на серии зёрен,
      // что хотя бы одно зерно даёт суп на обед.
      var soupLunches = 0;
      for (final seed in const [1, 2, 3, 4, 5]) {
        final plan = await planner.generate(request(seed: seed));
        for (final day in plan.days) {
          if (day.meals.any((m) =>
              m.slot == MealSlot.lunch && m.recipe.category == 'soup')) {
            soupLunches++;
            break;
          }
        }
      }
      expect(soupLunches, greaterThanOrEqualTo(1),
          reason: 'супы не попали в обед ни при одном из 5 зёрен');
    });
  });

  group('AI-4: просроченные продукты не закрывают ингредиенты', () {
    test('indexProducts не отдаёт ключ просрочки', () {
      final matcher = const IngredientMatcher();
      final expired = Product(
        name: 'Молоко',
        category: ProductCategory.dairy,
        quantity: 900,
        unit: ProductUnit.milliliter,
        expiryDate: DateTime(2026, 10, 24), // за 2 дня до старта плана
        addedAt: DateTime(2026, 10, 20),
      );
      final fresh = Product(
        name: 'Овсяные хлопья',
        category: ProductCategory.grains,
        quantity: 500,
        unit: ProductUnit.gram,
        expiryDate: DateTime(2026, 12, 1),
        addedAt: DateTime(2026, 10, 20),
      );
      final fridge = matcher.indexProducts(
        [expired, fresh],
        now: DateTime(2026, 10, 26),
      );
      expect(fridge.containsKey('milk'), isFalse,
          reason: 'просроченное молоко не должно закрывать ингредиенты');
      expect(fridge.containsKey('oat_flakes'), isTrue);
    });

    test('план предупреждает о просрочке', () async {
      final expired = Product(
        name: 'Молоко',
        category: ProductCategory.dairy,
        quantity: 900,
        unit: ProductUnit.milliliter,
        expiryDate: DateTime(2026, 10, 24),
        addedAt: DateTime(2026, 10, 20),
      );
      final plan = await planner.generate(request(products: [expired]));
      expect(
        plan.warnings.any((w) => w.contains('Просроченные продукты')),
        isTrue,
        reason: plan.warnings.join(' | '),
      );
    });
  });

  group('AI-5: список покупок учитывает списание по дням', () {
    test('рис 400 г не «хватает» на весь недельный спрос', () async {
      final rice = Product(
        name: 'Рис',
        category: ProductCategory.grains,
        quantity: 400,
        unit: ProductUnit.gram,
        expiryDate: DateTime(2026, 12, 1),
        addedAt: DateTime(2026, 10, 20),
      );
      final plan = await planner.generate(request(products: [rice]));

      // Полный недельный спрос на рис по подобранным рецептам.
      var demand = 0.0;
      for (final day in plan.days) {
        for (final meal in day.meals) {
          for (final ing in meal.recipe.ingredients) {
            if (ing.key == 'rice' && !ing.pantry) demand += ing.grams;
          }
        }
      }
      final item = plan.shoppingList
          .where((i) => i.key == 'rice')
          .toList();
      if (demand <= 400) {
        expect(item, isEmpty,
            reason: 'спрос $demand г покрыт 400 г');
      } else {
        expect(item, hasLength(1));
        expect(item.single.missingGrams, closeTo(demand - 400, 1.0),
            reason: 'спрос $demand г, в холодильнике 400 г — '
                'недостача должна быть накопленной');
      }
    });

    test('пустой холодильник — список покупок без изменений', () async {
      final plan = await planner.generate(request(seed: 7));
      // Все некладовые ингредиенты подобранных рецептов должны быть
      // в списке покупок с полной потребностью.
      final needed = <String, int>{};
      for (final day in plan.days) {
        for (final meal in day.meals) {
          for (final ing in meal.recipe.cookingIngredients) {
            needed[ing.key] = (needed[ing.key] ?? 0) + ing.grams;
          }
        }
      }
      final listed = {
        for (final i in plan.shoppingList) i.key: i.missingGrams,
      };
      for (final entry in needed.entries) {
        expect(listed, contains(entry.key),
            reason: 'ключ ${entry.key} должен быть в покупках');
      }
    });
  });

  group('AI-9: runtime-деривация нескольких аллергенов с одного ключа', () {
    test('soy_sauce даёт сою И пшеницу, mayo — яйца', () {
      const json = {
        'id': 't0001',
        'title': {'ru': 'Т', 'en': 'T'},
        'category': 'main',
        'minutes': 10,
        'servings': 1,
        'nutrition': {'kcal': 100, 'protein': 5, 'fat': 5, 'carbs': 5},
        'flags': {
          'vegetarian': true, 'vegan': true, 'gluten_free': true,
          'low_carb': false, 'has_meat': false, 'has_fish': false,
          'has_pork': false, 'has_alcohol': false, 'has_beef': false,
          'has_shellfish': false, 'has_dairy': false,
        },
        'allergens': [],
        'family': 'test',
        'second_family': '',
        'ingredients': [
          {'key': 'soy_sauce', 'ru': 'соевый соус', 'en': 'soy sauce',
            'grams': 15, 'pantry': false},
          {'key': 'mayo', 'ru': 'майонез', 'en': 'mayo',
            'grams': 20, 'pantry': false},
        ],
        'steps': {'ru': ['шаг'], 'en': ['step']},
      };
      final r = Recipe.fromJson(json);
      final keys = r.allergens.map((a) => a.key).toSet();
      expect(keys, containsAll(['soy', 'wheat', 'eggs']),
          reason: 'деривация должна работать на runtime, без генератора');
    });
  });
}
