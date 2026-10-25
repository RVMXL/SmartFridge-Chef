/// Тесты движка «нелюбимых продуктов» (v0.5.4):
/// порог «основа блюда», режим «всегда», группы, произвольные названия,
/// пометки tolerated в плане.
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:smart_fridge_chef/ai/dislikes.dart';
import 'package:smart_fridge_chef/data/models/recipe.dart';
import 'package:smart_fridge_chef/data/models/user_profile.dart';

/// Реальный путь загрузки: encode → decode, как из assets.
Recipe _fromJson(Map<String, Object?> j) =>
    Recipe.fromJson(jsonDecode(jsonEncode(j)) as Map<String, Object?>);

Recipe _recipe({
  required List<(String, String, int)> ingredients, // key, ru, grams
  bool pantryAll = false,
}) {
  return Recipe(
    id: 'test_recipe',
    titleRu: 'Тестовое блюдо',
    titleEn: 'Test dish',
    category: 'main',
    minutes: 30,
    servings: 2,
    kcal: 300,
    protein: 20,
    fat: 10,
    carbs: 30,
    vegetarian: true,
    vegan: false,
    glutenFree: true,
    lowCarb: false,
    hasMeat: false,
    hasFish: false,
    allergens: const [],
    family: 'test',
    secondFamily: 'test2',
    ingredients: [
      for (final (key, ru, grams) in ingredients)
        RecipeIngredient(key: key, ru: ru, en: key, grams: grams,
            pantry: pantryAll),
    ],
    stepsRu: const ['шаг'],
    stepsEn: const ['step'],
  );
}

void main() {
  group('DislikeEngine: доля в блюде', () {
    test('лук — приправа (5% массы): блюдо разрешено, но с пометкой', () {
      // Луковый« акцент»: 100 г из 2000 г = 5% — вкус, не основа.
      final r = _recipe(ingredients: [
        ('potato', 'Картофель', 900),
        ('chicken_breast', 'Куриное филе', 800),
        ('onion', 'Лук', 100),
        ('water', 'Вода', 200),
      ]);
      final res = DislikeEngine.evaluate(r, const [
        DislikeRule(key: 'onion'),
      ]);
      expect(res.isAllowed, isTrue);
      expect(res.toleratedMarks, ['Лук']);
    });

    test('лук — основа (50%): блюдо исключается', () {
      final r = _recipe(ingredients: [
        ('onion', 'Лук', 1000),
        ('butter', 'Сливочное масло', 100),
        ('water', 'Вода', 900),
      ]);
      final res = DislikeEngine.evaluate(r, const [
        DislikeRule(key: 'onion'),
      ]);
      expect(res.isAllowed, isFalse);
      expect(res.exclusionReason, 'не любите: Лук — основа блюда');
      expect(res.toleratedMarks, isEmpty);
    });

    test('порог majorShare = 10% соблюдается на границе', () {
      // 200/2000 = ровно 10% — уже «основа».
      final r = _recipe(ingredients: [
        ('onion', 'Лук', 200),
        ('water', 'Вода', 1800),
      ]);
      final res = DislikeEngine.evaluate(r, const [
        DislikeRule(key: 'onion'),
      ]);
      expect(res.isAllowed, isFalse);
    });

    test('двойное вхождение ключа суммируется', () {
      final r = _recipe(ingredients: [
        ('onion', 'Лук', 150),
        ('onion', 'Лук', 150),
        ('water', 'Вода', 1700),
      ]);
      final res = DislikeEngine.evaluate(r, const [
        DislikeRule(key: 'onion'),
      ]);
      expect(res.isAllowed, isFalse); // 300/2000 = 15% >= 10%
    });
  });

  group('DislikeEngine: режимы', () {
    test('«исключать всегда» ловит даже 2% массы', () {
      final r = _recipe(ingredients: [
        ('potato', 'Картофель', 1900),
        ('onion', 'Лук', 100),
      ]);
      final res = DislikeEngine.evaluate(r, const [
        DislikeRule(key: 'onion', always: true),
      ]);
      expect(res.isAllowed, isFalse);
      expect(res.exclusionReason, 'не любите: Лук');
    });

    test('без правил рецепт разрешён без пометок', () {
      final r = _recipe(ingredients: [
        ('onion', 'Лук', 500),
        ('water', 'Вода', 500),
      ]);
      final res = DislikeEngine.evaluate(r, const []);
      expect(res.isAllowed, isTrue);
      expect(res.toleratedMarks, isEmpty);
    });

    test('продукта нет в рецепте — правило не срабатывает', () {
      final r = _recipe(ingredients: [
        ('potato', 'Картофель', 1000),
      ]);
      final res = DislikeEngine.evaluate(r, const [
        DislikeRule(key: 'onion'),
        DislikeRule(key: 'garlic', always: true),
      ]);
      expect(res.isAllowed, isTrue);
      expect(res.toleratedMarks, isEmpty);
    });
  });

  group('DislikeEngine: группы и произвольные названия', () {
    test('группа fish_any ловит всю рыбу, но не морепродукты', () {
      final salmon = _recipe(ingredients: [
        ('salmon', 'Сёмга', 300),
        ('water', 'Вода', 1700),
      ]);
      final shrimp = _recipe(ingredients: [
        ('shrimp', 'Креветки', 300),
        ('water', 'Вода', 1700),
      ]);
      final rules = const [DislikeRule(key: 'fish_any')];
      expect(DislikeEngine.evaluate(salmon, rules).isAllowed, isFalse);
      final resShrimp = DislikeEngine.evaluate(shrimp, rules);
      expect(resShrimp.isAllowed, isTrue);
      expect(resShrimp.toleratedMarks, isEmpty); // креветка — не рыба
    });

    test('произвольное название «чеснок» матчится по имени ингредиента', () {
      final r = _recipe(ingredients: [
        ('potato', 'Картофель', 1900),
        ('garlic', 'Чеснок', 100),
      ]);
      final res = DislikeEngine.evaluate(
        r,
        const [DislikeRule(key: 'чеснок')],
      );
      // 100/2000 = 5% < 10% — «вкус», блюдо разрешено с пометкой.
      expect(res.isAllowed, isTrue);
      expect(res.toleratedMarks, ['Чеснок']);
    });

    test('короткое произвольное название — только точное имя', () {
      // «рис» (3 символа) не должен ловить «рисовый уксус».
      final r = _recipe(ingredients: [
        ('vinegar', 'Рисовый уксус', 100),
        ('water', 'Вода', 1900),
      ]);
      final res = DislikeEngine.evaluate(
        r,
        const [DislikeRule(key: 'рис')],
      );
      expect(res.isAllowed, isTrue);
      expect(res.toleratedMarks, isEmpty);
    });

    test('длинный стем ловит падежи: «зелень» → ингредиент «Зелень»', () {
      final r = _recipe(ingredients: [
        ('potato', 'Картофель', 1900),
        ('greens', 'Зелень', 100),
      ]);
      final res = DislikeEngine.evaluate(
        r,
        const [DislikeRule(key: 'зелень', always: true)],
      );
      expect(res.isAllowed, isFalse);
    });
  });

  group('Вывод новых аллергенов из ключей (v0.5.4)', () {
    test('сельдерей и горчица в составе → аллергены', () {
      final json = {
        'id': 'r1',
        'title': {'ru': 'Салат', 'en': 'Salad'},
        'category': 'salad',
        'minutes': 15,
        'servings': 2,
        'nutrition': {'kcal': 100, 'protein': 5, 'fat': 5, 'carbs': 5},
        'flags': {},
        'allergens': <String>[],
        'family': 'celery',
        'second_family': 'mustard',
        'ingredients': [
          {'key': 'celery', 'ru': 'Сельдерей', 'en': 'Celery',
            'grams': 100, 'pantry': false},
          {'key': 'mustard', 'ru': 'Горчица', 'en': 'Mustard',
            'grams': 10, 'pantry': true},
        ],
        'steps': {'ru': <String>['a'], 'en': <String>['b']},
      };
      final r = _fromJson(json);
      expect(r.allergens, contains(Allergen.celery));
      expect(r.allergens, contains(Allergen.mustard));
    });

    test('уксус → сульфиты; базовый список JSON не теряется', () {
      final json = {
        'id': 'r2',
        'title': {'ru': 'Маринад', 'en': 'Marinade'},
        'category': 'main',
        'minutes': 20,
        'servings': 2,
        'nutrition': {'kcal': 200, 'protein': 10, 'fat': 10, 'carbs': 10},
        'flags': {},
        'allergens': <String>['milk'],
        'family': 'x',
        'second_family': 'y',
        'ingredients': [
          {'key': 'vinegar', 'ru': 'Уксус', 'en': 'Vinegar',
            'grams': 30, 'pantry': true},
          {'key': 'milk', 'ru': 'Молоко', 'en': 'Milk',
            'grams': 200, 'pantry': false},
        ],
        'steps': {'ru': <String>['a'], 'en': <String>['b']},
      };
      final r = _fromJson(json);
      expect(r.allergens, contains(Allergen.milk));
      expect(r.allergens, contains(Allergen.sulphites));
    });
  });

  group('Профиль: хранение правил', () {
    test('copyWith + toMap/fromMap сохраняют dislikes', () {
      final now = DateTime.now();
      final p = UserProfile(
        createdAt: now,
        updatedAt: now,
        allergies: const [Allergen.celery, Allergen.sulphites],
        dislikes: const [
          DislikeRule(key: 'onion'),
          DislikeRule(key: 'cilantro', always: true),
        ],
      );
      final restored = UserProfile.fromMap(p.toMap());
      expect(restored.allergies, [Allergen.celery, Allergen.sulphites]);
      expect(restored.dislikes.length, 2);
      expect(restored.dislikes[0].key, 'onion');
      expect(restored.dislikes[0].always, isFalse);
      expect(restored.dislikes[1].key, 'cilantro');
      expect(restored.dislikes[1].always, isTrue);
    });

    test('профиль без колонки dislikes (старая база) → пустой список', () {
      final now = DateTime.now();
      final map = UserProfile(createdAt: now, updatedAt: now).toMap()
        ..remove('dislikes');
      final restored = UserProfile.fromMap(map);
      expect(restored.dislikes, isEmpty);
    });
  });
}
