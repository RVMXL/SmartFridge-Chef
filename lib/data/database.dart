/// Открытие и миграции локальной базы SQLite (Шаги 1–2 ТЗ).
///
/// Offline-first: база целиком живёт в приватной папке приложения,
/// наружу не передаётся ничего. Схема и политика миграций описаны
/// в docs/DATABASE.md.
///
/// v1 — `products`, `user_profile` (Шаг 1).
/// v2 — `meal_plans`, `planned_meals`, `shopping_items` (Шаг 2):
/// планы меню хранятся снимками рецептов, поэтому не ломаются
/// при обновлении встроенной базы.
library;

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  AppDatabase._();

  static const String dbName = 'smart_fridge.db';
  static const int dbVersion = 2;

  /// Открывает базу.
  ///
  /// [absolutePath] — для юнит-тестов (sqflite_common_ffi на хосте);
  /// null → стандартная папка баз приложения.
  static Future<Database> open({String? absolutePath}) async {
    final path =
        absolutePath ?? p.join(await getDatabasesPath(), dbName);
    return openDatabase(
      path,
      version: dbVersion,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON;'),
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// Полная схема (v1 + v2) для новой базы.
  static Future<void> _onCreate(Database db, int version) async {
    final batch = db.batch();
    createV1Tables(batch);
    createV2Tables(batch);
    await batch.commit(noResult: true);
  }

  /// Политика миграций: последовательное накатывание со старой версии.
  static Future<void> _onUpgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    switch (oldVersion) {
      case 1:
        // v1 -> v2: таблицы планов меню (Шаг 2). Данные продуктов и
        // профиля не трогаются — миграция только добавляет таблицы.
        final batch = db.batch();
        createV2Tables(batch);
        await batch.commit(noResult: true);
        break;
      default:
        assert(newVersion == dbVersion, 'Неизвестная версия: $newVersion');
    }
  }

  // ------------------------------------------------------------- схема v1

  /// Таблицы версии 1: продукты и профиль (Шаг 1, не менять по полям —
  /// ключи стабильны в базах пользователей).
  static void createV1Tables(Batch batch) {
    batch.execute('''
      CREATE TABLE products (
        id            INTEGER PRIMARY KEY AUTOINCREMENT,
        name          TEXT    NOT NULL,
        category_key  TEXT    NOT NULL,
        barcode       TEXT,
        quantity      REAL    NOT NULL DEFAULT 1.0,
        unit_key      TEXT    NOT NULL DEFAULT 'pcs',
        expiry_date   TEXT    NOT NULL,
        added_at      TEXT    NOT NULL,
        kcal_per_100  REAL,
        protein_per_100 REAL,
        fat_per_100   REAL,
        carbs_per_100 REAL,
        notes         TEXT,
        status        TEXT    NOT NULL DEFAULT 'active'
      )
    ''');
    // Частичный уникальный индекс: один и тот же штрих-код не добавится
    // дважды, но ручные продукты без кода не ограничены.
    batch.execute(
      'CREATE UNIQUE INDEX idx_products_barcode ON products(barcode) '
      'WHERE barcode IS NOT NULL',
    );
    batch.execute(
      'CREATE INDEX idx_products_status_expiry ON products(status, expiry_date)',
    );
    batch.execute(
      'CREATE INDEX idx_products_category ON products(category_key)',
    );
    batch.execute('''
      CREATE TABLE user_profile (
        id             INTEGER PRIMARY KEY CHECK (id = 1),
        daily_calories INTEGER NOT NULL DEFAULT 2000,
        protein_g      INTEGER NOT NULL DEFAULT 150,
        fat_g          INTEGER NOT NULL DEFAULT 67,
        carbs_g        INTEGER NOT NULL DEFAULT 200,
        diet           TEXT    NOT NULL DEFAULT 'none',
        allergies      TEXT    NOT NULL DEFAULT '[]',
        meals_per_day  INTEGER NOT NULL DEFAULT 3,
        region_name    TEXT,
        latitude       REAL,
        longitude      REAL,
        onboarded      INTEGER NOT NULL DEFAULT 0,
        created_at     TEXT    NOT NULL,
        updated_at     TEXT    NOT NULL
      )
    ''');
  }

  // ------------------------------------------------------------- схема v2

  /// Таблицы версии 2: сохранённые планы меню (Шаг 2).
  ///
  /// Рецепты хранятся JSON-снимками в planned_meals.recipe_json:
  /// план самодостаточен и переживает обновления базы рецептов.
  static void createV2Tables(Batch batch) {
    batch.execute('''
      CREATE TABLE meal_plans (
        id          TEXT    PRIMARY KEY,
        created_at  TEXT    NOT NULL,
        start_date  TEXT    NOT NULL,
        days_count  INTEGER NOT NULL,
        kcal_target INTEGER NOT NULL,
        seed        INTEGER NOT NULL,
        source      TEXT    NOT NULL DEFAULT 'rule_based',
        warnings    TEXT    NOT NULL DEFAULT '[]'
      )
    ''');
    batch.execute('''
      CREATE TABLE planned_meals (
        id            INTEGER PRIMARY KEY AUTOINCREMENT,
        plan_id       TEXT    NOT NULL REFERENCES meal_plans(id)
                              ON DELETE CASCADE,
        day_index     INTEGER NOT NULL,
        slot          TEXT    NOT NULL,
        slot_order    INTEGER NOT NULL DEFAULT 0,
        recipe_id     TEXT    NOT NULL,
        recipe_json   TEXT    NOT NULL,
        kcal          REAL    NOT NULL,
        uses_expiring TEXT    NOT NULL DEFAULT '[]',
        coverage      REAL    NOT NULL DEFAULT 0
      )
    ''');
    // Чтение плана: все приёмы дня по порядку слотов.
    batch.execute(
      'CREATE INDEX idx_planned_meals_plan '
      'ON planned_meals(plan_id, day_index, slot_order)',
    );
    batch.execute('''
      CREATE TABLE shopping_items (
        id       INTEGER PRIMARY KEY AUTOINCREMENT,
        plan_id  TEXT    NOT NULL REFERENCES meal_plans(id)
                         ON DELETE CASCADE,
        ing_key  TEXT    NOT NULL,
        name     TEXT    NOT NULL,
        checked  INTEGER NOT NULL DEFAULT 0
      )
    ''');
    batch.execute(
      'CREATE INDEX idx_shopping_items_plan '
      'ON shopping_items(plan_id, checked)',
    );
  }
}
