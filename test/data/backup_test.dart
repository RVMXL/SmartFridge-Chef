/// Тесты резервного копирования (v0.6.3, экспорт/импорт).
///
/// Покрывают: round-trip «экспорт → текст файла → импорт в чистую базу»
/// со всеми таблицами и колонками схемы v9; replace-all вместо слияния;
/// отказные сценарии (чужой файл, более новый формат, битые строки) —
/// с проверкой, что текущие данные НЕ тронуты при неудачном импорте.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:smart_fridge_chef/data/backup_service.dart';
import 'package:smart_fridge_chef/data/database.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Directory tmp;
  late Database db;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('fridge_backup_test');
    db = await AppDatabase.open(absolutePath: '${tmp.path}/test.db');
  });

  tearDown(() async {
    await db.close();
    await tmp.delete(recursive: true);
  });

  BackupService serviceFor(Database target) => BackupService(() async => target);

  /// Полный засев: по строке в каждую таблицу, с ценой/валютой (v6/v9),
  /// диетами/дизлайками/лечебными столами (v4/v5/v7), отчётом фильтра.
  Future<void> seedFull(Database target) async {
    await target.insert('products', {
      'name': 'Молоко Простоквашино',
      'category_key': 'dairy',
      'barcode': '4607065386111',
      'quantity': 1.5,
      'unit_key': 'l',
      'expiry_date': '2026-11-05',
      'added_at': '2026-10-29T10:00:00.000',
      'kcal_per_100': 52.0,
      'protein_per_100': 2.9,
      'fat_per_100': 2.5,
      'carbs_per_100': 4.7,
      'notes': 'проверка бэкапа',
      'status': 'active',
      'price': 89.9,
      'price_updated_at': '2026-10-29T10:00:00.000',
      'price_source': 'pyaterochka',
      'currency': 'RUB',
    });
    await target.insert('user_profile', {
      'id': 1,
      'daily_calories': 2100,
      'protein_g': 140,
      'fat_g': 70,
      'carbs_g': 220,
      'diet': 'none',
      'allergies': '["lactose"]',
      'meals_per_day': 4,
      'region_name': 'Москва',
      'latitude': 55.75,
      'longitude': 37.62,
      'onboarded': 1,
      'created_at': '2026-10-01T08:00:00.000',
      'updated_at': '2026-10-29T08:00:00.000',
      'diets': '["vegetarian"]',
      'dislikes': '[{"name":"лук","always":true}]',
      'medical_diets': '["table5"]',
    });
    await target.insert('meal_plans', {
      'id': 'plan-1',
      'created_at': '2026-10-28T18:00:00.000',
      'start_date': '2026-10-29',
      'days_count': 7,
      'kcal_target': 2100,
      'seed': 42,
      'source': 'rule_based',
      'warnings': '["мало рецептов"]',
      'filter_report': '{"counts":{"allergy":2},"examples":[]}',
    });
    await target.insert('planned_meals', {
      'plan_id': 'plan-1',
      'day_index': 0,
      'slot': 'breakfast',
      'slot_order': 0,
      'recipe_id': 'r-oat-1',
      'recipe_json': '{"id":"r-oat-1","title":"Овсянка"}',
      'kcal': 350.0,
      'uses_expiring': '["Молоко Простоквашино"]',
      'coverage': 0.8,
      'minor_dislikes': '[]',
    });
    await target.insert('shopping_items', {
      'plan_id': 'plan-1',
      'ing_key': 'oats',
      'name': 'Овсяные хлопья',
      'checked': 1,
      'missing_grams': 500,
    });
    await target.insert('barcode_cache', {
      'code': '4600682074657',
      'name': 'Кефир Домик в деревне',
      'category_key': 'dairy',
      'source': 'openfoodfacts',
      'fetched_at': '2026-10-28T12:00:00.000',
    });
  }

  group('экспорт', () {
    test('конверт содержит все таблицы и служебные поля', () async {
      await seedFull(db);
      final bundle = await serviceFor(db).buildBundle(
        appVersion: '0.6.3',
        now: DateTime.utc(2026, 10, 29, 12, 0),
      );

      expect(bundle['app'], BackupService.appMarker);
      expect(bundle['kind'], 'backup');
      expect(bundle['formatVersion'], BackupService.formatVersion);
      expect(bundle['appVersion'], '0.6.3');
      expect(bundle['schemaVersion'], AppDatabase.dbVersion);
      expect(bundle['exportedAt'], '2026-10-29T12:00:00.000Z');
      final data = bundle['data'] as Map;
      expect(data.keys, containsAll([
        'products',
        'user_profile',
        'meal_plans',
        'planned_meals',
        'shopping_items',
        'barcode_cache',
      ]));
      // mercadona_index — перезагружаемый каталог, в бэкап не входит.
      expect(data.keys, isNot(contains('mercadona_index')));
      expect((data['products'] as List).length, 1);
    });

    test('имя файла содержит дату и время', () {
      expect(
        BackupService.suggestFileName(DateTime(2026, 10, 29, 9, 5)),
        'smart_fridge_backup_20261029_0905.json',
      );
    });

    test('encodeBundle даёт валидный разбираемый JSON', () async {
      final bundle = await serviceFor(db).buildBundle(appVersion: '0.6.3');
      final text = serviceFor(db).encodeBundle(bundle);
      final parsed = jsonDecode(text);
      expect(parsed, isA<Map<String, dynamic>>());
      expect((parsed as Map)['formatVersion'], BackupService.formatVersion);
    });
  });

  group('round-trip', () {
    test('экспорт → текст файла → импорт в чистую базу сохраняет всё',
        () async {
      await seedFull(db);
      final original = serviceFor(db);
      final bundle = await original.buildBundle(
        appVersion: '0.6.3',
        settings: {'pref_theme_mode': 'dark', 'pref_notif_hour': 7},
      );
      // Через текст файла — как в реальном сценарии (share → файл → пикер).
      final text = original.encodeBundle(bundle);
      final parsed = jsonDecode(text) as Map<String, Object?>;

      // Чистая база-приёмник.
      final tmp2 =
          await Directory.systemTemp.createTemp('fridge_backup_target');
      final db2 = await AppDatabase.open(absolutePath: '${tmp2.path}/t.db');
      try {
        final result = await serviceFor(db2).importBundle(parsed);
        expect(result.products, 1);
        expect(result.plans, 1);
        expect(result.total, 6);

        for (final table in const [
          'products',
          'user_profile',
          'meal_plans',
          'planned_meals',
          'shopping_items',
          'barcode_cache',
        ]) {
          final expected = await db.query(table, orderBy: 'rowid');
          final actual = await db2.query(table, orderBy: 'rowid');
          expect(actual, expected, reason: 'таблица $table не совпала');
        }
        // Идентификаторы сохранены (ссылки planned_meals → meal_plans).
        final meals = await db2.query('planned_meals');
        expect(meals.single['plan_id'], 'plan-1');
        // AUTOINCREMENT-счётчик скорректирован после вставки явных id:
        // следующий продукт получит id=2, а не коллизию.
        final nextId = await db2.insert('products', {
          'name': 'Новый после импорта',
          'category_key': 'vegetables',
          'expiry_date': '2026-11-10',
          'added_at': '2026-10-29T11:00:00.000',
        });
        expect(nextId, greaterThan(1));
      } finally {
        await db2.close();
        await tmp2.delete(recursive: true);
      }
    });

    test('импорт заменяет существующие данные (replace-all, без слияния)',
        () async {
      // В базе-приёмнике есть «свой» продукт и пустой кэш.
      await db.insert('products', {
        'name': 'Старый продукт до импорта',
        'category_key': 'fruits',
        'expiry_date': '2026-11-01',
        'added_at': '2026-10-20T09:00:00.000',
      });
      await db.insert('barcode_cache', {
        'code': '1',
        'name': 'Старый кэш',
        'fetched_at': '2026-10-20T09:00:00.000',
      });

      final source =
          await AppDatabase.open(absolutePath: '${tmp.path}/source.db');
      try {
        await seedFull(source);
        final bundle = await serviceFor(source).buildBundle(
          appVersion: '0.6.3',
        );
        await serviceFor(db).importBundle(bundle);
      } finally {
        await source.close();
      }

      expect(await db.query('products'), hasLength(1));
      expect((await db.query('products')).single['name'],
          'Молоко Простоквашино');
      expect(await db.query('barcode_cache'), hasLength(1));
      expect((await db.query('barcode_cache')).single['code'],
          '4600682074657');
      expect(await db.query('meal_plans'), hasLength(1));
    });

    test('пустая база даёт пустой конверт, импорт пустого — нули', () async {
      final bundle = await serviceFor(db).buildBundle(appVersion: '0.6.3');
      final data = bundle['data'] as Map;
      for (final table in data.keys) {
        expect(data[table], isEmpty, reason: 'таблица $table должна быть пуста');
      }

      final target =
          await AppDatabase.open(absolutePath: '${tmp.path}/empty.db');
      try {
        final result =
            await serviceFor(target).importBundle(jsonDecode(jsonEncode(bundle)));
        expect(result.total, 0);
        // Профиль не появился — onboarding останется честным.
        expect(await target.query('user_profile'), isEmpty);
      } finally {
        await target.close();
      }
    });
  });

  group('отказные сценарии — данные не трогаются', () {
    Future<int> seededProductCount() async {
      await seedFull(db);
      final rows = await db.query('products');
      return rows.length;
    }

    test('чужой файл → notBackup', () async {
      final before = await seededProductCount();
      final service = serviceFor(db);

      expect(
        () => service.importBundle({'hello': 'world'}),
        throwsA(isA<BackupException>()
            .having((e) => e.kind, 'kind', BackupError.notBackup)),
      );
      // Данные на месте.
      expect((await db.query('products')).length, before);
    });

    test('data — массив вместо объекта → notBackup', () async {
      final before = await seededProductCount();
      expect(
        () => serviceFor(db).importBundle(const {
          'app': BackupService.appMarker,
          'kind': 'backup',
          'formatVersion': 1,
          'data': [1, 2, 3],
        }),
        throwsA(isA<BackupException>()),
      );
      expect((await db.query('products')).length, before);
    });

    test('более новый формат → newerVersion', () async {
      final before = await seededProductCount();
      final bundle = await serviceFor(db).buildBundle(appVersion: '0.6.3');
      bundle['formatVersion'] = BackupService.formatVersion + 1;

      expect(
        () => serviceFor(db).importBundle(bundle),
        throwsA(isA<BackupException>()
            .having((e) => e.kind, 'kind', BackupError.newerVersion)),
      );
      expect((await db.query('products')).length, before);
    });

    test('строка без обязательных колонок → corrupted', () async {
      final before = await seededProductCount();
      final bundle = await serviceFor(db).buildBundle(appVersion: '0.6.3');
      (bundle['data'] as Map)['products'] = [
        {'name': 'полубитая строка'},
      ];

      expect(
        () => serviceFor(db).importBundle(bundle),
        throwsA(isA<BackupException>()
            .having((e) => e.kind, 'kind', BackupError.corrupted)),
      );
      // Валидация до стирания: исходная строка молока на месте.
      final after = await db.query('products');
      expect(after.length, before);
      expect(after.single['name'], 'Молоко Простоквашино');
    });

    test('NULL в обязательной колонке → corrupted', () async {
      final before = await seededProductCount();
      final bundle = await serviceFor(db).buildBundle(appVersion: '0.6.3');
      (bundle['data'] as Map)['shopping_items'] = [
        {'plan_id': 'plan-1', 'ing_key': null, 'name': 'Овсянка'},
      ];
      expect(
        () => serviceFor(db).importBundle(bundle),
        throwsA(isA<BackupException>()
            .having((e) => e.kind, 'kind', BackupError.corrupted)),
      );
      expect((await db.query('shopping_items')).length, before);
    });
  });
}
