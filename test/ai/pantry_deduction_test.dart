/// Тесты движка списания «Приготовил» (v0.5.1): точные граммы для
/// весовых позиций, FIFO по сроку, штуки по умолчанию, накопление
/// спроса по одинаковым ключам, кладовые мимо, интеграция с реальной
/// базой рецептов.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:smart_fridge_chef/ai/pantry_deduction.dart';
import 'package:smart_fridge_chef/ai/recipe_repository.dart';
import 'package:smart_fridge_chef/data/models/product.dart';
import 'package:smart_fridge_chef/data/models/recipe.dart';

Recipe recipe(List<RecipeIngredient> ings) => Recipe(
      id: 'test_r',
      titleRu: 'Тест',
      titleEn: 'Test',
      category: 'main',
      minutes: 10,
      servings: 1,
      kcal: 100,
      protein: 1,
      fat: 1,
      carbs: 1,
      vegetarian: false,
      vegan: false,
      glutenFree: false,
      lowCarb: false,
      hasMeat: false,
      hasFish: false,
      allergens: const [],
      family: 'test',
      secondFamily: 'test2',
      ingredients: ings,
      stepsRu: const [],
      stepsEn: const [],
    );

RecipeIngredient ing(String key, int grams, {bool pantry = false}) =>
    RecipeIngredient(
      key: key,
      ru: key,
      en: key,
      grams: grams,
      pantry: pantry,
    );

Product prod(
  String name,
  double qty,
  ProductUnit unit, {
  int inDays = 5,
  ProductStatus status = ProductStatus.active,
}) =>
    Product(
      name: name,
      category: ProductCategory.other,
      quantity: qty,
      unit: unit,
      expiryDate: DateTime(2026, 11, 1).add(Duration(days: inDays)),
      addedAt: DateTime(2026, 10, 24),
      status: status,
    );

void main() {
  group('весовые позиции', () {
    test('точные граммы: списывается ровно столько, сколько нужно', () {
      final plan = DeductionPlan.build(
        recipe([ing('chicken_breast', 300)]),
        [prod('Куриное филе', 500, ProductUnit.gram)],
      );
      final t = plan.rows.single.targets;
      expect(t, hasLength(1));
      expect(t.single.qty, 300);
      expect(t.single.remaining, 200);
      expect(t.single.editable, isFalse);
    });

    test('запаса меньше нужды: списывается всё, что есть (остаток 0)', () {
      final plan = DeductionPlan.build(
        recipe([ing('rice', 300)]),
        [prod('Рис', 100, ProductUnit.gram)],
      );
      final t = plan.rows.single.targets;
      expect(t.single.qty, 100);
      expect(t.single.remaining, 0);
    });

    test('кг → г: 1 кг творога, нужно 200 г — списываем 0.2', () {
      final plan = DeductionPlan.build(
        recipe([ing('cottage_cheese', 200)]),
        [prod('Творог', 1, ProductUnit.kilogram)],
      );
      final t = plan.rows.single.targets.single;
      expect(t.qty, closeTo(0.2, 1e-9));
      expect(t.remaining, closeTo(0.8, 1e-9));
    });

    test('мл ≈ г: 200 мл сливок, нужно 150 г — списываем 150 мл', () {
      final plan = DeductionPlan.build(
        recipe([ing('cream', 150)]),
        [prod('Сливки', 200, ProductUnit.milliliter)],
      );
      expect(plan.rows.single.targets.single.qty, 150);
    });

    test('л → мл: 1 л молока, нужно 300 — списываем 0.3 л', () {
      final plan = DeductionPlan.build(
        recipe([ing('milk', 300)]),
        [prod('Молоко', 1, ProductUnit.liter)],
      );
      expect(plan.rows.single.targets.single.qty, closeTo(0.3, 1e-9));
    });
  });

  group('FIFO и распределение', () {
    test('FIFO по сроку: скоропортящееся списывается первым, до нуля', () {
      final plan = DeductionPlan.build(
        recipe([ing('chicken_breast', 500)]),
        [
          prod('Куриная грудка', 1000, ProductUnit.gram, inDays: 10),
          prod('Куриное филе', 300, ProductUnit.gram, inDays: 1),
        ],
      );
      final t = plan.rows.single.targets;
      expect(t, hasLength(2));
      // Первая позиция — та, что истекает через 1 день.
      expect(t[0].product.name, 'Куриное филе');
      expect(t[0].qty, 300);
      expect(t[0].remaining, 0); // ушло целиком → «съедено»
      expect(t[1].product.name, 'Куриная грудка');
      expect(t[1].qty, 200);
    });

    test('два ингредиента с одним ключом копят спрос на один запас', () {
      final plan = DeductionPlan.build(
        recipe([ing('tomato', 200), ing('tomato', 150)]),
        [prod('Помидоры', 300, ProductUnit.gram)],
      );
      expect(plan.rows, hasLength(2));
      expect(plan.rows[0].targets.single.qty, 200);
      // На второй осталось только 100 — списывается всё, что есть.
      expect(plan.rows[1].targets.single.qty, 100);
      expect(plan.rows[1].targets.single.remaining, 0);
    });

    test('несъедобные состояния (consumed/discarded) не участвуют', () {
      final plan = DeductionPlan.build(
        recipe([ing('potato', 200)]),
        [
          prod('Картофель', 500, ProductUnit.gram,
              status: ProductStatus.consumed),
          prod('Картошка', 400, ProductUnit.gram,
              status: ProductStatus.discarded),
        ],
      );
      expect(plan.rows.single.targets, isEmpty);
      expect(plan.anythingToDeduct, isFalse);
    });
  });

  group('счётные позиции', () {
    test('штука по умолчанию: 1 шт с самой скоропортящейся позиции', () {
      final plan = DeductionPlan.build(
        recipe([ing('egg', 180)]),
        [
          prod('Яйца С1', 10, ProductUnit.pcs, inDays: 7),
          prod('Яйца С0', 10, ProductUnit.pcs, inDays: 2),
        ],
      );
      final t = plan.rows.single.targets;
      expect(t, hasLength(1)); // только одна позиция, не обе
      expect(t.single.product.name, 'Яйца С0'); // быстрее портится
      expect(t.single.qty, 1);
      expect(t.single.editable, isTrue); // пользователь правит степпером
    });

    test('упаковка: тоже 1, editable', () {
      final plan = DeductionPlan.build(
        recipe([ing('pasta', 200)]),
        [prod('Макароны', 2, ProductUnit.pack)],
      );
      final t = plan.rows.single.targets.single;
      expect(t.qty, 1);
      expect(t.editable, isTrue);
    });
  });

  group('кладовые и промахи', () {
    test('кладовые ингредиенты не списываются (соль, специи)', () {
      final plan = DeductionPlan.build(
        recipe([ing('salt', 5, pantry: true), ing('chicken_breast', 300)]),
        [prod('Соль', 500, ProductUnit.gram)],
      );
      // Единственная строка — курица, и она без целей.
      expect(plan.rows, hasLength(1));
      expect(plan.rows.single.ingredient.key, 'chicken_breast');
      expect(plan.rows.single.targets, isEmpty);
    });

    test('ингредиента нет в холодильнике — пустые цели, не ошибка', () {
      final plan = DeductionPlan.build(
        recipe([ing('salmon', 300)]),
        [prod('Куриное филе', 500, ProductUnit.gram)],
      );
      expect(plan.rows.single.targets, isEmpty);
      expect(plan.anythingToDeduct, isFalse);
      expect(plan.targetCount, 0);
    });
  });

  group('интеграция с реальной базой', () {
    late RecipeRepository repo;

    setUpAll(() async {
      repo = RecipeRepository(
        loadString: () => File('assets/data/recipes.json').readAsString(),
      );
    });

    test('рецепты: холодильник с запасом закрывает все некладовые цели',
        () async {
      final recipes = await repo.loadAll();
      expect(recipes, isNotEmpty);
      var checked = 0;
      for (final r in recipes.take(60)) {
        // Холодильник: каждый некладовый ингредиент — позиция с запасом.
        final fridge = <Product>[
          for (final i in r.cookingIngredients)
            prod(
              // Название = ru-имя ингредиента: матчер обязан его узнать.
              i.ru,
              2,
              ProductUnit.kilogram,
              inDays: 3,
            ),
        ];
        final plan = DeductionPlan.build(r, fridge);
        expect(plan.rows, hasLength(r.cookingIngredients.length),
            reason: '${r.id}: строк меньше, чем некладовых ингредиентов');
        for (final row in plan.rows) {
          expect(row.matched, isTrue,
              reason: '${r.id}: ключ ${row.ingredient.key} не распознан '
                  'по имени «${row.ingredient.ru}»');
          final totalGrams =
              row.targets.fold<double>(0, (s, t) => s + t.grams);
          // 2 кг запаса покрывают любой ингредиент базы целиком.
          expect(totalGrams, row.ingredient.grams.toDouble(),
              reason: '${r.id}: ${row.ingredient.key} списано '
                  '$totalGrams г вместо ${row.ingredient.grams} г');
        }
        checked++;
      }
      expect(checked, 60);
    });
  });
}
