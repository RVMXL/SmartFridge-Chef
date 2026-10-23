/// Тесты IngredientMatcher: нормализация, словарь синонимов,
/// индекс холодильника и сопоставление рецептов (Шаг 2).
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:smart_fridge_chef/ai/ingredient_matcher.dart';
import 'package:smart_fridge_chef/data/models/product.dart';
import 'package:smart_fridge_chef/data/models/recipe.dart';

void main() {
  const matcher = IngredientMatcher();

  group('normalize', () {
    test('нижний регистр, ё→е, пунктуация схлопывается', () {
      expect(IngredientMatcher.normalize('Ёлки-Палки'), 'елки палки');
      expect(IngredientMatcher.normalize('  Молоко   3,2% '),
          'молоко 3 2');
      expect(IngredientMatcher.normalize('КабачОК'), 'кабачок');
    });

    test('пустая и бессмысленная строка', () {
      expect(IngredientMatcher.normalize(''), isEmpty);
      expect(IngredientMatcher.normalize('!!!'), isEmpty);
    });
  });

  group('matchProduct: словарь синонимов', () {
    final cases = <String, String>{
      'Куриное филе': 'chicken_breast',
      'Куриная грудка': 'chicken_breast',
      'Курица': 'chicken_breast',
      'куриные бёдра': 'chicken_thigh',
      'Окорочка': 'chicken_thigh',
      'Фарш индейки': 'minced_turkey',
      'Говядина': 'beef',
      'Фарш': 'minced_beef',
      'Куриный фарш': 'minced_chicken',
      'Лосось': 'salmon',
      'Сёмга': 'salmon',
      'Креветки': 'shrimp',
      'Яйца': 'egg',
      'Молоко 3,2%': 'milk',
      'Сметана 20%': 'sour_cream',
      'Творог 5%': 'cottage_cheese',
      'Сыр российский': 'cheese',
      'Картошка': 'potato',
      'Помидоры': 'tomato',
      'Томаты в собственном соку': 'tomato',
      'Огурчики': 'cucumber',
      'Болгарский перец': 'bell_pepper',
      'Кабачок': 'zucchini',
      'Шампиньоны': 'mushroom',
      'Гречка': 'buckwheat',
      'Рис': 'rice',
      'Макароны': 'pasta',
      'Спагетти': 'pasta',
      'Овсяные хлопья': 'oat_flakes',
      'Геркулес': 'oat_flakes',
      'Банан': 'banana',
      'Яблоки Гала': 'apple',
      'Мёд': 'honey',
      'Хлеб': 'bread',
      'Молоко': 'milk',
      'молоко': 'milk',
      'Milk': 'milk',
      'Chicken': 'chicken_breast',
      'Rice 500g': 'rice',
    };
    for (final entry in cases.entries) {
      test('"${entry.key}" -> ${entry.value}', () {
        expect(matcher.matchProduct(entry.key), entry.value,
            reason: 'нормализовано: '
                '"${IngredientMatcher.normalize(entry.key)}"');
      });
    }

    test('неизвестный продукт не матчится', () {
      expect(matcher.matchProduct('Трюфель экзотический'), isNull);
      expect(matcher.matchProduct(''), isNull);
    });
  });

  group('indexProducts', () {
    test('активные проецируются на ключи, неактивные пропускаются', () {
      final fridge = matcher.indexProducts([
        product('Молоко', expiryInDays: 1),
        product('Куриное филе', expiryInDays: 2),
        product('Лук', expiryInDays: 10),
      ], now: DateTime(2026, 10, 24));
      expect(fridge.containsKey('milk'), isTrue);
      expect(fridge.containsKey('chicken_breast'), isTrue);
      expect(fridge.containsKey('onion'), isTrue);
    });

    test('неопознанное имя попадает в raw-ключ', () {
      final fridge = matcher.indexProducts([
        product('Трюфель экзотический', expiryInDays: 0),
      ], now: DateTime(2026, 10, 24));
      expect(fridge.keys.first, startsWith('raw:'));
    });

    test('потреблённые продукты не попадают в индекс', () {
      final p = product('Молоко', expiryInDays: 1)
          .copyWith(status: ProductStatus.consumed);
      final fridge = matcher.indexProducts([p],
          now: DateTime(2026, 10, 24));
      expect(fridge, isEmpty);
    });

    test('дни до истечения считаются по календарному дню', () {
      final fridge = matcher.indexProducts([
        product('A Молоко', expiryInDays: 0),
        product('B Творог', expiryInDays: 2),
        product('C Сыр', expiryInDays: 3),
        product('D Кефир', expiryInDays: 5),
      ], now: DateTime(2026, 10, 24));
      expect(fridge['milk']!.isUrgent, isTrue);
      expect(fridge['cottage_cheese']!.isUrgent, isTrue);
      expect(fridge['cheese']!.isUrgent, isFalse);
      expect(fridge['cheese']!.isSoon, isTrue);
      expect(fridge['kefir']!.isSoon, isTrue);
    });
  });

  group('matchRecipe', () {
    test('покрытие и срочные продукты', () {
      final fridge = matcher.indexProducts([
        product('Молоко', expiryInDays: 1),
        product('Овсяные хлопья', expiryInDays: 300),
        product('Банан', expiryInDays: 4),
      ], now: DateTime(2026, 10, 24));

      // Овсянка на молоке с бананом и мёдом: кладовые игнорируются.
      final oatmeal = recipeWithIngredients([
        ('oat_flakes', false),
        ('milk', false),
        ('banana', false),
        ('honey', false),
        ('salt', true),
      ]);
      final match = matcher.matchRecipe(oatmeal, fridge);

      expect(match.matchedKeys,
          containsAll(['oat_flakes', 'milk', 'banana']));
      // 3 из 4 некладовых ингредиентов (мёда в холодильнике нет).
      expect(match.coverage, closeTo(0.75, 0.001));
      // Срочное (<= 2 дней) только молоко.
      expect(match.expiringNames, ['Молоко']);
    });

    test('полностью пустой холодильник — покрытие 0', () {
      final soup = recipeWithIngredients([
        ('potato', false),
        ('carrot', false),
      ]);
      final match = matcher.matchRecipe(soup, const {});
      expect(match.coverage, 0);
      expect(match.matchedKeys, isEmpty);
    });
  });
}

// ------------------------------------------------------------- помощники

Product product(String name, {required int expiryInDays}) => Product(
      name: name,
      category: ProductCategory.other,
      expiryDate: DateTime(2026, 10, 24).add(Duration(days: expiryInDays)),
      addedAt: DateTime(2026, 10, 24),
    );

Recipe recipeWithIngredients(List<(String, bool)> ings) => Recipe(
      id: 'test_r1',
      titleRu: 'Тест',
      titleEn: 'Test',
      category: 'main',
      minutes: 30,
      servings: 2,
      kcal: 400,
      protein: 20,
      fat: 10,
      carbs: 40,
      vegetarian: true,
      vegan: false,
      glutenFree: true,
      lowCarb: false,
      hasMeat: false,
      hasFish: false,
      allergens: const [],
      family: 'test',
      secondFamily: 'test_side',
      ingredients: ings
          .map((e) => RecipeIngredient(
                key: e.$1,
                ru: e.$1,
                en: e.$1,
                grams: 100,
                pantry: e.$2,
              ))
          .toList(),
      stepsRu: const ['шаг 1', 'шаг 2'],
      stepsEn: const ['step 1', 'step 2'],
    );
