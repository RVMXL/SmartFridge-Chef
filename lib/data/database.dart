/// Открытие и миграции локальной базы SQLite (Шаг 1 ТЗ).
///
/// Offline-first: база целиком живёт в приватной папке приложения,
/// наружу не передаётся ничего. Схема и политика миграций описаны
/// в docs/DATABASE.md.
library;

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  AppDatabase._();

  static const String dbName = 'smart_fridge.db';
  static const int dbVersion = 1;

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

  /// Схема версии 1: `products` и `user_profile` — ровно Шаг 1 ТЗ.
  /// Таблицы плана меню/рецептов/покупок добавятся миграцией v2 (Шаги 2–3),
  /// чтобы каждая стадия разработки соответствовала честной версии схемы.
  static Future<void> _onCreate(Database db, int version) async {
    final batch = db.batch();
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
    // Главный запрос холодильника: активные по возрастанию срока.
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
    await batch.commit(noResult: true);
  }

  /// Политика миграций: каждая версия схемы — отдельный шаг в switch,
  /// последовательное накатывание со старой версии до текущей.
  static Future<void> _onUpgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    // Пример будущей миграции v2 (Шаг 2): таблицы recipes/meal_plan.
    // switch (oldVersion) {
    //   case 1:
    //     await db.execute('CREATE TABLE recipes (...)');
    //     // fallthrough
    // }
    assert(newVersion == dbVersion, 'Неизвестная версия схемы: $newVersion');
  }
}
