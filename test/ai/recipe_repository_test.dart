/// Валидация встроенной базы рецептов: целостность recipes.json
/// как данных (Шаг 2). Тест читает реальный актив из репозитория —
/// генератор scripts/gen_recipes.py обязан сохранять эти инварианты.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:smart_fridge_chef/ai/recipe_repository.dart';
import 'package:smart_fridge_chef/data/models/recipe.dart';
import 'package:smart_fridge_chef/data/models/user_profile.dart';

const Set<String> _categories = {
  'breakfast', 'soup', 'main', 'salad', 'side', 'snack', 'dessert',
};

void main() {
  late RecipeRepository repo;
  late List<Recipe> recipes;

  setUpAll(() async {
    repo = RecipeRepository(
      loadString: () =>
          File('assets/data/recipes.json').readAsString(),
    );
    recipes = await repo.loadAll();
  });

  test('база достаточно велика (500+) и имеет ожидаемую схему', () {
    expect(recipes.length, greaterThanOrEqualTo(kMinExpectedRecipes));
  });

  test('id и названия уникальны', () {
    final ids = recipes.map((r) => r.id).toSet();
    final titles = recipes.map((r) => r.titleRu).toSet();
    expect(ids.length, recipes.length, reason: 'дубликаты id');
    expect(titles.length, recipes.length, reason: 'дубликаты названий');
  });

  test('все поля в разумных границах', () {
    for (final r in recipes) {
      expect(r.category, isIn(_categories),
          reason: '${r.id}: категория ${r.category}');
      expect(r.minutes, inInclusiveRange(1, 120),
          reason: '${r.id}: время ${r.minutes}');
      expect(r.servings, greaterThanOrEqualTo(1));
      expect(r.kcal, inInclusiveRange(80, 950),
          reason: '${r.id}: калорий ${r.kcal}');
      expect(r.protein, inInclusiveRange(0, 90));
      expect(r.fat, inInclusiveRange(0, 95));
      expect(r.carbs, inInclusiveRange(0, 130));
      expect(r.ingredients, isNotEmpty, reason: r.id);
      expect(r.stepsRu.length, greaterThanOrEqualTo(2), reason: r.id);
      expect(r.stepsEn.length, greaterThanOrEqualTo(2), reason: r.id);
      expect(r.titleEn, isNotEmpty, reason: r.id);
      expect(r.family, isNotEmpty, reason: r.id);
    }
  });

  test('аллергены — только ключи enum Allergen', () {
    final allowed = Allergen.values.map((a) => a.key).toSet();
    for (final r in recipes) {
      for (final a in r.allergens) {
        expect(allowed, contains(a.key),
            reason: '${r.id}: неизвестный аллерген ${a.key}');
      }
    }
  });

  test(
      'безопасность: ингредиент-аллерген обязан давать рецепту свою метку',
      () {
    // Инвариант той же карты, что в scripts/fix_recipe_allergens.py:
    // генератор недопоставил метки (например, манка без «wheat» ловилась
    // жёстким фильтром аллергий только частично). Тест не даёт регрессии.
    // v0.5.7: карта дополнена деривациями расширенного списка аллергенов
    // (мёд, шоколад, грибы, красные плоды, пряности, птица, говядина,
    // свинина, крупы/овощи умеренной аллергенности, овсянка → глютен,
    // соевый соус/тофу → соя).
    // Значения — множества: один ингредиент может требовать нескольких
    // меток (соевый соус — это и соя, и пшеница).
    const requiredByKey = <String, Set<String>>{
      'flour': {'wheat'}, 'bread': {'wheat'}, 'bread_rye': {'wheat'},
      'pasta': {'wheat'}, 'semolina': {'wheat'},
      'bulgur_cooked': {'wheat'},
      'couscous_cooked': {'wheat'}, 'pearl_barley': {'wheat'},
      'barley_cooked': {'wheat'}, 'soy_sauce': {'wheat', 'soy'},
      'oat_flakes': {'wheat'},
      'mayo': {'eggs'}, 'egg': {'eggs'},
      'milk': {'milk'}, 'kefir': {'milk'}, 'yogurt': {'milk'},
      'sour_cream': {'milk'}, 'cottage_cheese': {'milk'},
      'cheese': {'milk'},
      'butter': {'milk'}, 'cream': {'milk'},
      'salmon': {'fish'}, 'cod': {'fish'}, 'pollock': {'fish'},
      'herring': {'fish'}, 'tuna_can': {'fish'}, 'minced_fish': {'fish'},
      'shrimp': {'shellfish'}, 'squid': {'shellfish'},
      'walnut': {'nuts'}, 'almond': {'nuts'},
      'peanut_butter': {'peanuts'},
      'tofu': {'soy'},
      'honey': {'honey'}, 'chocolate': {'chocolate'},
      'mushroom': {'mushrooms'},
      'orange': {'red_produce'}, 'lemon': {'red_produce'},
      'cherry': {'red_produce'}, 'berries': {'red_produce'},
      'tomato': {'red_produce'}, 'tomato_paste': {'red_produce'},
      'carrot': {'red_produce'}, 'beetroot': {'red_produce'},
      'pumpkin': {'red_produce'},
      'garlic': {'spices'}, 'cinnamon': {'spices'}, 'pepper': {'spices'},
      'spices': {'spices'}, 'herbs_dried': {'spices'},
      'bay_leaf': {'spices'},
      'chicken_breast': {'poultry'}, 'chicken_thigh': {'poultry'},
      'turkey': {'poultry'}, 'minced_chicken': {'poultry'},
      'minced_turkey': {'poultry'}, 'chicken_liver': {'poultry'},
      'beef': {'beef'}, 'minced_beef': {'beef'}, 'pork': {'pork'},
      'raisins': {'mild_fruits'},
      'rice': {'mild_cereals'}, 'buckwheat': {'mild_cereals'},
      'corn': {'mild_cereals'},
      'bell_pepper': {'mild_vegetables'}, 'potato': {'mild_vegetables'},
      'green_peas': {'mild_vegetables'},
      'split_peas': {'mild_vegetables'},
    };
    final problems = <String>[];
    for (final r in recipes) {
      for (final ing in r.ingredients) {
        final required = requiredByKey[ing.key];
        if (required == null) continue;
        final have = r.allergens.map((a) => a.key).toSet();
        for (final need in required) {
          if (!have.contains(need)) {
            problems.add('${r.id}: ключ ${ing.key} требует "$need"');
          }
        }
      }
    }
    expect(problems, isEmpty, reason: problems.join('; '));
  });

  test('расширенные аллергены v0.5.7 реально покрыты базой', () {
    // Каждый новый пункт должен что-то исключать: иначе чип в профиле
    // вводит в заблуждение. Исключения — «на будущее» (как люпин):
    // кунжута и люпина в составе рецептов нет.
    const covered = <String, int>{
      'honey': 1, 'chocolate': 1, 'mushrooms': 1, 'red_produce': 10,
      'spices': 10, 'poultry': 10, 'beef': 1, 'pork': 1,
      'mild_fruits': 1, 'mild_cereals': 10, 'mild_vegetables': 10,
    };
    final counts = <String, int>{};
    for (final r in recipes) {
      for (final a in r.allergens) {
        counts[a.key] = (counts[a.key] ?? 0) + 1;
      }
    }
    for (final entry in covered.entries) {
      expect(counts[entry.key] ?? 0, greaterThanOrEqualTo(entry.value),
          reason: 'аллерген ${entry.key} почти не покрыт базой');
    }
    // Крупы/овощи/красные плоды/пряности/птица — самые массовые группы:
    // проверяем нижнюю границу, чтобы деривация не «истончилась».
    expect(counts['poultry'], greaterThanOrEqualTo(50),
        reason: 'птица должна закрывать все куриные/индюшиные рецепты');
    expect(counts['mild_vegetables'], greaterThanOrEqualTo(100),
        reason: 'картофель в четверти базы');
  });

  test('безопасность: религиозные флаги согласованы с составом', () {
    // Инвариант той же карты, что в scripts/enrich_recipe_diet_flags.py
    // (v0.4.3): рецепт с ключом «свинина/алкоголь/говядина/моллюски/
    // молочное» обязан нести соответствующий флаг — иначе фильтры
    // халяля/кошера/индуизма пропустят запрещённое блюдо.
    const requiredFlag = <String, String>{
      'pork': 'has_pork', 'bacon': 'has_pork', 'lard': 'has_pork',
      'ham': 'has_pork', 'salami': 'has_pork', 'prosciutto': 'has_pork',
      'gelatin': 'has_pork',
      'wine': 'has_alcohol', 'white_wine': 'has_alcohol',
      'red_wine': 'has_alcohol', 'beer': 'has_alcohol',
      'cognac': 'has_alcohol', 'rum': 'has_alcohol',
      'vodka': 'has_alcohol', 'brandy': 'has_alcohol',
      'beef': 'has_beef', 'minced_beef': 'has_beef', 'veal': 'has_beef',
      'shrimp': 'has_shellfish', 'squid': 'has_shellfish',
      'crab': 'has_shellfish', 'mussels': 'has_shellfish',
      'oysters': 'has_shellfish', 'octopus': 'has_shellfish',
      'lobster': 'has_shellfish', 'scallops': 'has_shellfish',
      'milk': 'has_dairy', 'kefir': 'has_dairy', 'cream': 'has_dairy',
      'sour_cream': 'has_dairy', 'butter': 'has_dairy',
      'cheese': 'has_dairy', 'cottage_cheese': 'has_dairy',
      'yogurt': 'has_dairy', 'condensed_milk': 'has_dairy',
    };
    bool? flagOf(Recipe r, String name) => switch (name) {
          'has_pork' => r.hasPork,
          'has_alcohol' => r.hasAlcohol,
          'has_beef' => r.hasBeef,
          'has_shellfish' => r.hasShellfish,
          'has_dairy' => r.hasDairy,
          _ => null,
        };
    final problems = <String>[];
    for (final r in recipes) {
      for (final ing in r.ingredients) {
        final required = requiredFlag[ing.key];
        if (required == null) continue;
        if (flagOf(r, required) != true) {
          problems.add('${r.id}: ключ ${ing.key} требует флага "$required"');
        }
      }
      // Перекрёстные согласованности флагов между собой и с аллергенами.
      if (r.hasPork && !r.hasMeat) {
        problems.add('${r.id}: has_pork без has_meat');
      }
      if (r.hasBeef && !r.hasMeat) {
        problems.add('${r.id}: has_beef без has_meat');
      }
      if (r.hasDairy && !r.allergens.contains(Allergen.milk)) {
        problems.add('${r.id}: has_dairy без аллергена milk');
      }
      if (r.hasShellfish && !r.allergens.contains(Allergen.shellfish)) {
        problems.add('${r.id}: has_shellfish без аллергена shellfish');
      }
    }
    expect(problems, isEmpty, reason: problems.join('; '));
  });

  test('веганские флаги согласованы с составом (без мяса/рыбы)', () {
    for (final r in recipes) {
      if (r.vegan) {
        expect(r.hasMeat, isFalse, reason: r.id);
        expect(r.hasFish, isFalse, reason: r.id);
        expect(r.vegetarian, isTrue, reason: r.id);
      }
      if (r.vegetarian) {
        expect(r.hasMeat, isFalse, reason: r.id);
        expect(r.hasFish, isFalse, reason: r.id);
      }
    }
  });

  test('в базе есть рецепты для каждого слота планирования', () {
    final categories = recipes.map((r) => r.category).toSet();
    expect(categories, containsAll(['breakfast', 'soup', 'main', 'snack']));
  });

  test('веганских рецептов достаточно для недели веганского меню', () {
    // На 7 дней x 3 приёма нужно 21 блюдо + запас на разнообразие.
    expect(recipes.where((r) => r.vegan).length, greaterThanOrEqualTo(21),
        reason: 'веганских рецептов мало');
    expect(recipes.where((r) => r.vegetarian).length,
        greaterThanOrEqualTo(40));
  });

  test('JSON-снимок рецепта восстанавливается без потерь', () async {
    final source = jsonDecode(
            await File('assets/data/recipes.json').readAsString())
        as Map<String, Object?>;
    final sample =
        (source['recipes'] as List<dynamic>).first as Map<String, Object?>;
    final recipe = Recipe.fromJson(sample);
    final restored = Recipe.fromJson(
        jsonDecode(jsonEncode(recipe.toJson())) as Map<String, Object?>);

    expect(restored.id, recipe.id);
    expect(restored.titleRu, recipe.titleRu);
    expect(restored.kcal, recipe.kcal);
    expect(restored.allergens.length, recipe.allergens.length);
    expect(restored.ingredients.length, recipe.ingredients.length);
    expect(restored.stepsRu, recipe.stepsRu);
  });
}
