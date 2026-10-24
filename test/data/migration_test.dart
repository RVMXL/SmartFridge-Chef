/// Тест миграций схемы: v1 -> v2 (Шаг 2) и v1/v2 -> v3 (кэш
/// штрих-кодов, Шаг 3.1). База, созданная на старой версии, после
/// обновления получает новые таблицы, а данные пользователей
/// сохраняются без потерь.
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

  test('v1 -> v3: все таблицы созданы, данные продуктов живы',
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

    // 2. Открываем текущей версией — сработает миграция 1 -> 2 -> 3.
    final db = await AppDatabase.open(absolutePath: dbPath);
    expect(await db.getVersion(), AppDatabase.dbVersion);

    // 3. Таблицы v2 и v3 существуют.
    final tables = (await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table'",
    )).map((r) => r['name'] as String).toSet();
    expect(tables, containsAll(['meal_plans', 'planned_meals',
      'shopping_items', 'barcode_cache']));

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

  test('v2 -> v3: кэш штрих-кодов добавлен, планы живы', () async {
    // База версии 2 (как у пользователя v0.3.x).
    final v2 = await databaseFactory.openDatabase(dbPath,
        options: OpenDatabaseOptions(
          version: 2,
          onCreate: (db, version) async {
            final batch = db.batch();
            AppDatabase.createV1Tables(batch);
            AppDatabase.createV2Tables(batch);
            await batch.commit(noResult: true);
          },
        ));
    await v2.insert('products', Product(
      name: 'Кефир',
      category: ProductCategory.dairy,
      expiryDate: DateTime(2026, 10, 28),
      addedAt: DateTime(2026, 10, 24),
    ).toMap());
    await v2.close();

    final db = await AppDatabase.open(absolutePath: dbPath);
    expect(await db.getVersion(), 3);

    final tables = (await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table'",
    )).map((r) => r['name'] as String).toSet();
    expect(tables, contains('barcode_cache'));

    // Планы и продукты не тронуты.
    expect(await db.query('products'), hasLength(1));
    expect(await db.query('meal_plans'), isEmpty);

    // Кэш принимает запись: первичный ключ — сам код.
    await db.insert('barcode_cache', {
      'code': '4600338011634',
      'name': 'Молоко 3,2%',
      'category_key': 'dairy',
      'source': 'openfoodfacts',
      'fetched_at': '2026-10-24T10:00:00.000Z',
    });
    await db.insert('barcode_cache', {
      'code': '4600338011634',
      'name': 'Молоко 3,2% обновлённое',
      'category_key': 'dairy',
      'source': 'openfoodfacts',
      'fetched_at': '2026-10-24T11:00:00.000Z',
    },
        conflictAlgorithm: ConflictAlgorithm.replace);
    final cached = await db.query('barcode_cache');
    expect(cached, hasLength(1));
    expect(cached.first['name'], 'Молоко 3,2% обновлённое');
    await db.close();
  });

  test('свежая база создаётся сразу с полной схемой (v1+v2+v3)',
      () async {
    final db = await AppDatabase.open(
        absolutePath: '${tmp.path}/fresh.db');
    expect(await db.getVersion(), AppDatabase.dbVersion);
    final tables = (await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table'",
    )).map((r) => r['name'] as String).toSet();
    expect(tables, containsAll(['products', 'user_profile',
      'meal_plans', 'planned_meals', 'shopping_items',
      'barcode_cache']));
    await db.close();
  });
}
