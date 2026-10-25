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
import 'package:smart_fridge_chef/data/models/user_profile.dart';

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
    expect(await db.getVersion(), AppDatabase.dbVersion);

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

  test('v3 -> v4: единичная диета переносится в список, колонки v4 есть',
      () async {
    // База версии 3 (как у пользователя v0.4.x) с профилем-«халяль».
    final v3 = await databaseFactory.openDatabase(dbPath,
        options: OpenDatabaseOptions(
          version: 3,
          onCreate: (db, version) async {
            final batch = db.batch();
            AppDatabase.createV1Tables(batch);
            AppDatabase.createV2Tables(batch);
            AppDatabase.createV3Tables(batch);
            await batch.commit(noResult: true);
          },
        ));
    await v3.insert('user_profile', {
      'id': 1,
      'daily_calories': 2200,
      'protein_g': 160,
      'fat_g': 70,
      'carbs_g': 210,
      'diet': 'halal',
      'allergies': '[]',
      'meals_per_day': 3,
      'onboarded': 1,
      'created_at': '2026-10-01T10:00:00.000',
      'updated_at': '2026-10-24T10:00:00.000',
    });
    await v3.close();

    final db = await AppDatabase.open(absolutePath: dbPath);
    expect(await db.getVersion(), AppDatabase.dbVersion);

    // Колонки v4 существуют.
    final cols = (await db.rawQuery(
      'PRAGMA table_info(user_profile)',
    )).map((r) => r['name'] as String).toSet();
    expect(cols, contains('diets'));

    // Миграция данных: halal → ["halal"].
    final rows = await db.query('user_profile', limit: 1);
    expect(rows.first['diets'], '["halal"]');

    // Профиль читается моделью со списком диет.
    final profile = UserProfile.fromMap(rows.first);
    expect(profile.diets, [Diet.halal]);

    // Покупки принимают граммы, планы — отчёт фильтра.
    await db.insert('meal_plans', {
      'id': 'p1',
      'created_at': '2026-10-24T10:00:00.000',
      'start_date': '2026-10-26',
      'days_count': 1,
      'kcal_target': 2000,
      'seed': 1,
      'source': 'rule_based',
      'warnings': '[]',
      'filter_report': '{"counts":{"халяль: свинина":2},"examples":{}}',
    });
    await db.insert('shopping_items', {
      'plan_id': 'p1',
      'ing_key': 'rice',
      'name': 'рис',
      'checked': 0,
      'missing_grams': 300,
    });
    final shopping = await db.query('shopping_items');
    expect(shopping.first['missing_grams'], 300);
    await db.close();
  });

  test('свежая база создаётся сразу с полной схемой (v1..v4)',
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
    // Колонки v4 на месте и на свежей базе.
    final profileCols = (await db.rawQuery(
      'PRAGMA table_info(user_profile)',
    )).map((r) => r['name'] as String).toSet();
    expect(profileCols, contains('diets'));
    // Колонки v5 (v0.5.4) тоже.
    expect(profileCols, contains('dislikes'));
    final mealCols = (await db.rawQuery(
      'PRAGMA table_info(planned_meals)',
    )).map((r) => r['name'] as String).toSet();
    expect(mealCols, contains('minor_dislikes'));
    await db.close();
  });

  test('миграция v4 -> v5: колонки dislikes / minor_dislikes', () async {
    final dbPath = '${tmp.path}/v4to5.db';
    // База версии 4 с профилем.
    final v4 = await openDatabase(dbPath, version: 4);
    final b4 = v4.batch();
    AppDatabase.createV1Tables(b4);
    AppDatabase.createV2Tables(b4);
    AppDatabase.createV3Tables(b4);
    AppDatabase.createV4Columns(b4);
    await b4.commit(noResult: true);
    await v4.insert('user_profile', {
      'daily_calories': 2000,
      'protein_g': 150,
      'fat_g': 67,
      'carbs_g': 200,
      'diet': 'none',
      'allergies': '[]',
      'meals_per_day': 3,
      'onboarded': 1,
      'created_at': '2026-10-24T10:00:00.000',
      'updated_at': '2026-10-24T10:00:00.000',
      'diets': '[]',
    });
    await v4.close();

    final db = await AppDatabase.open(absolutePath: dbPath);
    expect(await db.getVersion(), AppDatabase.dbVersion);

    final profileCols = (await db.rawQuery(
      'PRAGMA table_info(user_profile)',
    )).map((r) => r['name'] as String).toSet();
    expect(profileCols, contains('dislikes'));
    final mealCols = (await db.rawQuery(
      'PRAGMA table_info(planned_meals)',
    )).map((r) => r['name'] as String).toSet();
    expect(mealCols, contains('minor_dislikes'));

    // Профиль читается, нелюбимые пусты (дефолт колонки).
    final rows = await db.query('user_profile', limit: 1);
    final profile = UserProfile.fromMap(rows.first);
    expect(profile.dislikes, isEmpty);
    expect(profile.allergies, isEmpty);
    await db.close();
  });
}
