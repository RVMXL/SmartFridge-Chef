/// Тесты PlanDao на реальной SQLite (sqflite_common_ffi, хост):
/// roundtrip плана со снимками рецептов, каскадное удаление,
/// история и чекбоксы покупок (схема v2, Шаг 2).
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:smart_fridge_chef/data/dao/plan_dao.dart';
import 'package:smart_fridge_chef/data/database.dart';
import 'package:smart_fridge_chef/data/models/meal_plan.dart';
import 'package:smart_fridge_chef/data/models/recipe.dart';
import 'package:smart_fridge_chef/data/models/user_profile.dart'
    show Allergen;

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Directory tmp;
  late Database db;
  late PlanDao dao;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('fridge_plan_test');
    db = await AppDatabase.open(absolutePath: '${tmp.path}/test.db');
    dao = PlanDao(db);
  });

  tearDown(() async {
    await db.close();
    await tmp.delete(recursive: true);
  });

  Recipe recipe(String id, {int kcal = 400, String category = 'main'}) =>
      Recipe(
        id: id,
        titleRu: 'Тестовое блюдо $id',
        titleEn: 'Test dish $id',
        category: category,
        minutes: 25,
        servings: 2,
        kcal: kcal,
        protein: 25,
        fat: 12,
        carbs: 40,
        vegetarian: true,
        vegan: false,
        glutenFree: true,
        lowCarb: false,
        hasMeat: false,
        hasFish: false,
        allergens: const [Allergen.milk],
        family: 'test_family',
        secondFamily: 'test_side',
        ingredients: const [
          RecipeIngredient(
              key: 'milk', ru: 'молоко', en: 'milk', grams: 200,
              pantry: false),
          RecipeIngredient(
              key: 'salt', ru: 'соль', en: 'salt', grams: 2,
              pantry: true),
        ],
        stepsRu: const ['Шаг один.', 'Шаг два.'],
        stepsEn: const ['Step one.', 'Step two.'],
      );

  GeneratedPlan plan({
    String id = 'p100-1',
    int days = 2,
    DateTime? createdAt,
  }) {
    final meals = <PlannedMeal>[
      PlannedMeal(
        dayIndex: 0,
        slot: MealSlot.breakfast,
        slotOrder: 0,
        recipe: recipe('r0001', category: 'breakfast'),
        usesExpiring: const ['Молоко'],
        coverage: 0.5,
      ),
      PlannedMeal(
        dayIndex: 0,
        slot: MealSlot.lunch,
        slotOrder: 1,
        recipe: recipe('r0002', kcal: 520),
        usesExpiring: const [],
        coverage: 0.0,
      ),
      PlannedMeal(
        dayIndex: 1,
        slot: MealSlot.dinner,
        slotOrder: 2,
        recipe: recipe('r0003', kcal: 610),
        usesExpiring: const [],
        coverage: 1.0,
      ),
    ];
    // Слот dinner нужен в обоих днях для симметрии — упрощаем:
    // второй день получает копии, чтобы meal_count был предсказуем.
    final daysList = <PlanDay>[
      PlanDay(
        dayIndex: 0,
        date: DateTime(2026, 10, 26),
        meals: meals.where((m) => m.dayIndex == 0).toList(),
      ),
      PlanDay(
        dayIndex: 1,
        date: DateTime(2026, 10, 27),
        meals: meals.where((m) => m.dayIndex == 1).toList(),
      ),
    ];
    return GeneratedPlan(
      id: id,
      createdAt: createdAt ?? DateTime(2026, 10, 24, 18, 30),
      startDate: DateTime(2026, 10, 26),
      kcalTarget: 2000,
      seed: 1,
      source: 'rule_based',
      days: daysList.take(days).toList(),
      shoppingList: const [
        PlanShoppingItem(key: 'milk', name: 'молоко'),
        PlanShoppingItem(key: 'buckwheat', name: 'гречка'),
      ],
      warnings: const ['День 1: 2050 ккал при цели 2000 — отклонение 3%.'],
    );
  }

  group('сохранение и чтение', () {
    test('roundtrip v0.5.0: отчёт фильтра и граммы покупок', () async {
      final plan = GeneratedPlan(
        id: 'p_v50_report',
        createdAt: DateTime(2026, 10, 24, 19, 0),
        startDate: DateTime(2026, 10, 26),
        kcalTarget: 2100,
        seed: 9,
        source: 'rule_based',
        days: const [],
        shoppingList: const [
          PlanShoppingItem(
              key: 'rice', name: 'рис', missingGrams: 320),
          PlanShoppingItem(key: 'salt', name: 'соль'), // без оценки
        ],
        warnings: const [],
        excludedCounts: const {
          'халяль: свинина': 20,
          'кошер: мясо с молочным': 37,
        },
        excludedExamples: const {
          'халяль: свинина': ['Жареная свинина', 'Свиные отбивные'],
        },
      );
      await dao.savePlan(plan);
      final loaded = await dao.getPlan('p_v50_report');

      expect(loaded, isNotNull);
      expect(loaded!.excludedCounts, plan.excludedCounts);
      expect(loaded.excludedExamples, plan.excludedExamples);
      expect(loaded.hasExclusions, isTrue);
      expect(loaded.shoppingList.first.missingGrams, 320);
      expect(loaded.shoppingList.last.missingGrams, isNull);
    });

    test('план без исключений не пишет отчёт и читается пустым',
        () async {
      final plan = GeneratedPlan(
        id: 'p_v50_clean',
        createdAt: DateTime(2026, 10, 24, 19, 0),
        startDate: DateTime(2026, 10, 26),
        kcalTarget: 2000,
        seed: 1,
        source: 'rule_based',
        days: const [],
        shoppingList: const [],
        warnings: const [],
      );
      await dao.savePlan(plan);
      final loaded = await dao.getPlan('p_v50_clean');
      expect(loaded!.hasExclusions, isFalse);
    });

    test('roundtrip: план восстанавливается со снимками рецептов',
        () async {
      final original = plan();
      await dao.savePlan(original);
      final loaded = (await dao.getPlan(original.id))!;

      expect(loaded.id, original.id);
      expect(loaded.createdAt, original.createdAt);
      expect(loaded.startDate, DateTime(2026, 10, 26));
      expect(loaded.kcalTarget, 2000);
      expect(loaded.seed, 1);
      expect(loaded.source, 'rule_based');
      expect(loaded.warnings, original.warnings);
      expect(loaded.shoppingList.length, 2);
      expect(loaded.shoppingList.first.name, 'молоко');
      expect(loaded.shoppingList.first.checked, isFalse);

      final meals = loaded.days.expand((d) => d.meals).toList();
      expect(meals.length, 3);
      final first = meals.first;
      expect(first.slot, MealSlot.breakfast);
      expect(first.recipe.id, 'r0001');
      expect(first.recipe.titleRu, 'Тестовое блюдо r0001');
      expect(first.recipe.kcal, 400);
      expect(first.recipe.allergens, [Allergen.milk]);
      expect(first.recipe.ingredients.length, 2);
      expect(first.usesExpiring, ['Молоко']);
      expect(first.coverage, 0.5);
      // Снимок самодостаточен: рецепт читается даже без базы рецептов.
      expect(first.recipe.stepsRu, ['Шаг один.', 'Шаг два.']);
    });

    test('порядок приёмов: по дню и slot_order', () async {
      await dao.savePlan(plan());
      final loaded = (await dao.getPlan('p100-1'))!;
      final day0 = loaded.days.first.meals;
      expect(day0.map((m) => m.slot.key).toList(),
          ['breakfast', 'lunch']);
    });

    test('повторное сохранение с тем же id заменяет план', () async {
      await dao.savePlan(plan());
      final updated = GeneratedPlan(
        id: 'p100-1',
        createdAt: DateTime(2026, 10, 24, 19, 0),
        startDate: DateTime(2026, 10, 26),
        kcalTarget: 1800,
        seed: 2,
        source: 'rule_based',
        days: [
          PlanDay(
            dayIndex: 0,
            date: DateTime(2026, 10, 26),
            meals: [
              PlannedMeal(
                dayIndex: 0,
                slot: MealSlot.lunch,
                slotOrder: 0,
                recipe: recipe('r0009', kcal: 350),
                usesExpiring: const [],
                coverage: 0,
              ),
            ],
          ),
        ],
        shoppingList: const [],
        warnings: const [],
      );
      await dao.savePlan(updated);

      final loaded = (await dao.getPlan('p100-1'))!;
      expect(loaded.seed, 2);
      expect(loaded.days.expand((d) => d.meals).length, 1,
          reason: 'старые приёмы не должны остаться');
    });
  });

  group('история и удаление', () {
    test('listPlans: новые сверху, meal_count считается', () async {
      await dao.savePlan(plan(
        id: 'p1',
        createdAt: DateTime(2026, 10, 24, 10, 0),
      ));
      await dao.savePlan(plan(
        id: 'p2',
        createdAt: DateTime(2026, 10, 24, 20, 0),
      ));

      final list = await dao.listPlans();
      expect(list.length, 2);
      expect(list.first.id, 'p2');
      expect(list.first.mealCount, 3);
      expect(list.last.id, 'p1');
    });

    test('deletePlan каскадно удаляет приёмы и покупки', () async {
      await dao.savePlan(plan(id: 'p3'));
      expect(await dao.countPlans(), 1);

      await dao.deletePlan('p3');

      expect(await dao.countPlans(), 0);
      expect(await dao.getPlan('p3'), isNull);
      final meals = await db.query('planned_meals');
      final shopping = await db.query('shopping_items');
      expect(meals, isEmpty);
      expect(shopping, isEmpty);
    });

    test('getPlan несуществующего id — null', () async {
      expect(await dao.getPlan('nope'), isNull);
    });
  });

  group('покупки', () {
    test('setShoppingChecked переключает чекбокс', () async {
      await dao.savePlan(plan(id: 'p4'));

      await dao.setShoppingChecked(
          planId: 'p4', ingKey: 'milk', checked: true);
      final loaded = (await dao.getPlan('p4'))!;
      expect(loaded.shoppingList.firstWhere((s) => s.key == 'milk').checked,
          isTrue);
      expect(loaded.shoppingList.firstWhere((s) => s.key == 'buckwheat')
          .checked, isFalse);
    });
  });
}
