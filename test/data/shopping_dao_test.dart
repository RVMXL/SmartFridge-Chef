/// Тесты списка покупок (Шаг 3): отметки «куплено» и очистка отмеченных
/// поверх сохранённого плана (схема v2).
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:smart_fridge_chef/data/dao/plan_dao.dart';
import 'package:smart_fridge_chef/data/database.dart';
import 'package:smart_fridge_chef/data/models/meal_plan.dart';
import 'package:smart_fridge_chef/data/models/recipe.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Directory tmp;
  late Database db;
  late PlanDao dao;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('fridge_shopping_test');
    db = await AppDatabase.open(absolutePath: '${tmp.path}/test.db');
    dao = PlanDao(db);
  });

  tearDown(() async {
    await db.close();
    await tmp.delete(recursive: true);
  });

  GeneratedPlan plan() {
    final recipe = const Recipe(
      id: 'r1',
      titleRu: 'Омлет',
      titleEn: 'Omelette',
      category: 'breakfast',
      minutes: 10,
      servings: 2,
      kcal: 200,
      protein: 12,
      fat: 14,
      carbs: 3,
      vegetarian: true,
      vegan: false,
      glutenFree: true,
      lowCarb: true,
      hasMeat: false,
      hasFish: false,
      allergens: [],
      family: 'eggs',
      secondFamily: 'milk',
      ingredients: [],
      stepsRu: ['Взбить', 'Жарить'],
      stepsEn: ['Whisk', 'Fry'],
    );
    return GeneratedPlan(
      id: 'p-test',
      createdAt: DateTime(2026, 10, 24),
      startDate: DateTime(2026, 10, 24),
      kcalTarget: 2000,
      seed: 1,
      source: 'rule_based',
      days: [
        PlanDay(
          dayIndex: 0,
          date: DateTime(2026, 10, 24),
          meals: [
            PlannedMeal(
              dayIndex: 0,
              slot: MealSlot.breakfast,
              slotOrder: 0,
              recipe: recipe,
              usesExpiring: const [],
              coverage: 0.5,
            ),
          ],
        ),
      ],
      shoppingList: const [
        PlanShoppingItem(key: 'milk', name: 'Молоко'),
        PlanShoppingItem(key: 'bread', name: 'Хлеб'),
        PlanShoppingItem(key: 'cheese', name: 'Сыр'),
      ],
      warnings: const [],
    );
  }

  test('сохранённый план отдаёт список покупок с чекбоксами', () async {
    await dao.savePlan(plan());
    final loaded = await dao.getPlan('p-test');
    expect(loaded!.shoppingList, hasLength(3));
    expect(loaded.shoppingList.every((i) => !i.checked), isTrue);
  });

  test('отметка «куплено» сохраняется и перечитывается', () async {
    await dao.savePlan(plan());
    await dao.setShoppingChecked(
        planId: 'p-test', ingKey: 'milk', checked: true);
    final loaded = await dao.getPlan('p-test');
    final milk = loaded!.shoppingList.firstWhere((i) => i.key == 'milk');
    expect(milk.checked, isTrue);
    expect(
      loaded.shoppingList.where((i) => i.checked),
      hasLength(1),
    );
  });

  test('deleteCheckedShopping убирает только купленные позиции', () async {
    await dao.savePlan(plan());
    await dao.setShoppingChecked(
        planId: 'p-test', ingKey: 'milk', checked: true);
    await dao.setShoppingChecked(
        planId: 'p-test', ingKey: 'bread', checked: true);

    final removed = await dao.deleteCheckedShopping('p-test');
    expect(removed, 2);

    final loaded = await dao.getPlan('p-test');
    expect(
      loaded!.shoppingList.map((i) => i.key),
      ['cheese'],
    );
  });

  test('clearCheckedShopping на плане без отметок — ничего не удаляет',
      () async {
    await dao.savePlan(plan());
    expect(await dao.deleteCheckedShopping('p-test'), 0);
    expect((await dao.getPlan('p-test'))!.shoppingList, hasLength(3));
  });
}
