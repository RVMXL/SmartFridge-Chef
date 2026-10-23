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
