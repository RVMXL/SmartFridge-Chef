/// Юнит-тесты DAO продуктов на реальной SQLite (sqflite_common_ffi, хост).
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:smart_fridge_chef/data/dao/product_dao.dart';
import 'package:smart_fridge_chef/data/database.dart';
import 'package:smart_fridge_chef/data/models/product.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Directory tmp;
  late Database db;
  late ProductDao dao;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('fridge_product_test');
    db = await AppDatabase.open(absolutePath: '${tmp.path}/test.db');
    dao = ProductDao(db);
  });

  tearDown(() async {
    await db.close();
    await tmp.delete(recursive: true);
  });

  Product product({
    String name = 'Молоко Простоквашино',
    String? barcode,
    String category = 'dairy',
    String expiry = '2026-10-26',
    double quantity = 2,
  }) =>
      Product(
        name: name,
        category: ProductCategory.fromKey(category),
        barcode: barcode,
        quantity: quantity,
        unit: ProductUnit.liter,
        expiryDate: Product.parseDate(expiry),
        addedAt: DateTime(2026, 10, 24, 12, 0),
        kcalPer100: 52,
        proteinPer100: 2.9,
        fatPer100: 2.5,
        carbsPer100: 4.7,
      );

  group('вставка и чтение', () {
    test('roundtrip сохраняет все поля', () async {
      final id = await dao.insert(product(barcode: '4607065386111'));
      final loaded = await dao.getById(id);

      expect(loaded, isNotNull);
      expect(loaded!.name, 'Молоко Простоквашино');
      expect(loaded.category, ProductCategory.dairy);
      expect(loaded.barcode, '4607065386111');
      expect(loaded.quantity, 2.0);
      expect(loaded.unit, ProductUnit.liter);
      expect(loaded.expiryDate, DateTime(2026, 10, 26));
      expect(loaded.addedAt, DateTime(2026, 10, 24, 12, 0));
      expect(loaded.kcalPer100, 52.0);
      expect(loaded.proteinPer100, 2.9);
      expect(loaded.fatPer100, 2.5);
      expect(loaded.carbsPer100, 4.7);
      expect(loaded.status, ProductStatus.active);
    });

    test('ручной продукт без штрих-кода и с минимальными полями', () async {
      final id = await dao.insert(Product(
        name: 'Лук',
        category: ProductCategory.vegetables,
        expiryDate: Product.parseDate('2026-10-28'),
        addedAt: DateTime(2026, 10, 24, 12, 0),
      ));
      final loaded = (await dao.getById(id))!;
      expect(loaded.barcode, isNull);
      expect(loaded.category, ProductCategory.vegetables);
      expect(loaded.quantity, 1.0);
      expect(loaded.unit, ProductUnit.pcs);
      expect(loaded.status, ProductStatus.active);
      expect(loaded.kcalPer100, isNull);
      expect(loaded.notes, isNull);
    });
  });

  group('штрих-коды', () {
    test('частичный уникальный индекс: дубликат кода запрещён', () async {
      await dao.insert(product(barcode: '4600000000001'));
      expect(
        () => dao.insert(
            product(name: 'Кефир', barcode: '4600000000001')),
        throwsA(isA<DatabaseException>()),
      );
    });

    test('несколько продуктов БЕЗ кода разрешены', () async {
      await dao.insert(product(name: 'Лук', barcode: null));
      await dao.insert(product(name: 'Морковь', barcode: null));
      expect((await dao.activeProducts()).length, 2);
    });

    test('getByBarcode находит по коду', () async {
      await dao.insert(product(barcode: '4607065386111'));
      final found = await dao.getByBarcode('4607065386111');
      expect(found, isNotNull);
      expect(found!.name, 'Молоко Простоквашино');
      expect(await dao.getByBarcode('0000000000000'), isNull);
    });
  });

  group('выборки холодильника', () {
    test('activeProducts сортирует по возрастанию срока', () async {
      await dao.insert(product(name: 'Сметана', expiry: '2026-10-25'));
      await dao.insert(product(name: 'Рис', barcode: null, expiry: '2027-01-01'));
      await dao.insert(product(name: 'Рыба', barcode: null, expiry: '2026-10-24'));

      final list = await dao.activeProducts();
      expect(list.map((p) => p.name).toList(),
          ['Рыба', 'Сметана', 'Рис']);
    });

    test('потреблённые и выброшенные не попадают в активные', () async {
      final eaten = await dao.insert(product());
      final bin = await dao.insert(product(name: 'Протухший салат'));
      await dao.setStatus(eaten, ProductStatus.consumed);
      await dao.setStatus(bin, ProductStatus.discarded);
      expect(await dao.activeProducts(), isEmpty);
      expect((await dao.stats()).activeCount, 0);
    });

    test('expiringWithin: сегодня..+N дней включительно', () async {
      await dao.insert(product(name: 'Просрочка', expiry: '2026-10-23'));
      await dao.insert(product(name: 'Сегодня', expiry: '2026-10-24'));
      await dao.insert(product(name: 'В пределах', expiry: '2026-10-26'));
      await dao.insert(product(name: 'За порогом', expiry: '2026-10-27'));

      final soon = await dao.expiringWithin(2, now: DateTime(2026, 10, 24));
      expect(soon.map((p) => p.name).toList(), ['Сегодня', 'В пределах']);
    });

    test('expired: только просроченные активные', () async {
      await dao.insert(product(name: 'Просрочка', expiry: '2026-10-23'));
      await dao.insert(product(name: 'Свежий', expiry: '2026-10-30'));
      final old = await dao.expired(now: DateTime(2026, 10, 24));
      expect(old.map((p) => p.name).toList(), ['Просрочка']);
    });

    test('stats раскладывает по группам свежести', () async {
      await dao.insert(product(name: 'A', expiry: '2026-10-23'));
      await dao.insert(product(name: 'B', expiry: '2026-10-24'));
      await dao.insert(product(name: 'C', expiry: '2026-10-26'));
      await dao.insert(product(name: 'D', expiry: '2026-11-15'));

      final s = await dao.stats(now: DateTime(2026, 10, 24));
      expect(s.activeCount, 4);
      expect(s.expiringCount, 2); // сегодня + ≤2 дней
      expect(s.expiredCount, 1);
    });
  });

  group('обновление и удаление', () {
    test('update меняет поля', () async {
      final id = await dao.insert(product(barcode: '4607065386111'));
      final loaded = (await dao.getById(id))!;
      await dao.update(loaded.copyWith(quantity: 3, notes: 'открыто 24.10'));
      final reloaded = (await dao.getById(id))!;
      expect(reloaded.quantity, 3.0);
      expect(reloaded.notes, 'открыто 24.10');
    });

    test('delete удаляет строку', () async {
      final id = await dao.insert(product(barcode: null, quantity: 1));
      await dao.delete(id);
      expect(await dao.getById(id), isNull);
    });
  });
}
