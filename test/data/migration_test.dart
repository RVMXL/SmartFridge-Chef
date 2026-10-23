/// Тест миграции схемы v1 -> v2 (Шаг 2): база, созданная на v1
/// (продукты + профиль), после обновления получает таблицы планов,
/// а данные пользователей сохраняются без потерь.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:smart_fridge_chef/data/database.dart';
import 'package:smart_fridge_chef/data/models/product.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Directory tmp;
  late String dbPath;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('fridge_migration_test');
    dbPath = '${tmp.path}/upgrade.db';
  });

  tearDown(() async {
    await tmp.delete(recursive: true);
  });

  test('v1 -> v2: таблицы планов созданы, данные продуктов живы',
      () async {
    // 1. Строим базу версии 1 вручную (как у пользователя после Шага 1).
    final v1 = await databaseFactory.openDatabase(dbPath,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, version) async {
            final batch = db.batch();
            AppDatabase.createV1Tables(batch);
            await batch.commit(noResult: true);
          },
        ));
    await v1.insert('products', Product(
      name: 'Молоко',
      category: ProductCategory.dairy,
      expiryDate: DateTime(2026, 10, 26),
      addedAt: DateTime(2026, 10, 24),
    ).toMap());
    await v1.close();

    // 2. Открываем текущей версией — сработает миграция 1 -> 2.
    final db = await AppDatabase.open(absolutePath: dbPath);
    expect(await db.getVersion(), AppDatabase.dbVersion);

    // 3. Таблицы v2 существуют.
    final tables = (await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table'",
    )).map((r) => r['name'] as String).toSet();
    expect(tables, containsAll(['meal_plans', 'planned_meals',
      'shopping_items']));

    // 4. Данные v1 не потеряны.
    final products = await db.query('products');
    expect(products, hasLength(1));
    expect(products.first['name'], 'Молоко');

    // 5. Внешние ключи работают: вставка приёма с несуществующим
    //    plan_id запрещена (PRAGMA foreign_keys = ON).
    expect(
      () => db.insert('planned_meals', {
        'plan_id': 'no-such-plan',
        'day_index': 0,
        'slot': 'lunch',
        'slot_order': 0,
        'recipe_id': 'r0001',
        'recipe_json': '{}',
        'kcal': 400.0,
        'uses_expiring': '[]',
        'coverage': 0.0,
      }),
      throwsA(isA<DatabaseException>()),
    );
    await db.close();
  });

  test('свежая база создаётся сразу с полной схемой v2', () async {
    final db = await AppDatabase.open(
        absolutePath: '${tmp.path}/fresh.db');
    expect(await db.getVersion(), 2);
    final tables = (await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table'",
    )).map((r) => r['name'] as String).toSet();
    expect(tables, containsAll(['products', 'user_profile',
      'meal_plans', 'planned_meals', 'shopping_items']));
    await db.close();
  });
}
