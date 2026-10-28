/// TEST-2 (аудит 2026-10-28): BarcodeCacheDao — прямые тесты DAO
/// на реальной SQLite. Раньше DAO трогался только косвенно (через
/// barcode_lookup и миграции): upsert с ConflictAlgorithm.replace
/// и чтение не были закреплены тестом напрямую.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:smart_fridge_chef/data/database.dart';
import 'package:smart_fridge_chef/data/dao/barcode_cache_dao.dart';
import 'package:smart_fridge_chef/data/models/product.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Directory tmp;
  late String dbPath;
  late BarcodeCacheDao dao;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('fridge_barcode_dao_test');
    dbPath = '${tmp.path}/cache.db';
    final db = await AppDatabase.open(absolutePath: dbPath);
    dao = BarcodeCacheDao(db);
  });

  tearDown(() async {
    await tmp.delete(recursive: true);
  });

  test('get по несуществующему коду — null', () async {
    expect(await dao.get('4600000000000'), isNull);
  });

  test('put + get: имя и категория читаются обратно', () async {
    await dao.put('4600000000001', 'Молоко', ProductCategory.dairy);
    final hit = await dao.get('4600000000001');
    expect(hit, isNotNull);
    expect(hit!.name, 'Молоко');
    expect(hit.category, ProductCategory.dairy);
  });

  test('put с category=null: категория не подставляется', () async {
    await dao.put('4600000000002', 'Что-то редкое', null);
    final hit = await dao.get('4600000000002');
    expect(hit, isNotNull);
    expect(hit!.name, 'Что-то редкое');
    expect(hit.category, isNull);
  });

  test('upsert: повторный put по тому же коду перезаписывает', () async {
    await dao.put('4600000000003', 'Старое имя', ProductCategory.dairy);
    await dao.put('4600000000003', 'Новое имя', ProductCategory.bakery);
    final hit = await dao.get('4600000000003');
    expect(hit!.name, 'Новое имя');
    expect(hit.category, ProductCategory.bakery);
    // Строка в таблице ровно одна (replace, а не дубль).
    final db = await databaseFactory.openDatabase(dbPath);
    final rows = await db.query('barcode_cache',
        where: 'code = ?', whereArgs: ['4600000000003']);
    expect(rows, hasLength(1));
    await db.close();
  });

  test('разные коды живут независимо', () async {
    await dao.put('4600000000004', 'Кефир', ProductCategory.dairy);
    await dao.put('4600000000005', 'Хлеб', ProductCategory.bakery);
    expect((await dao.get('4600000000004'))!.name, 'Кефир');
    expect((await dao.get('4600000000005'))!.name, 'Хлеб');
  });
}
