/// Тесты AppDataStore (DATA-3, v0.6.2): ленивое открытие БД под
/// Future-замком — параллельные вызовы database() дают ровно одно
/// соединение (раньше `_db ??= await open()` открывал базу дважды).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:smart_fridge_chef/data/data_store.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('DATA-3: 50 параллельных database() — один экземпляр', () async {
    final store = AppDataStore.instance;
    await store.close(); // изолированный старт

    final results = await Future.wait(
      [for (var i = 0; i < 50; i++) store.database()],
    );

    expect(results.toSet().length, 1,
        reason: 'все параллельные вызовы ждут одно и то же открытие');
    await store.close();
  });

  test('DATA-3: после ошибки открытия следующая попытка повторяется',
      () async {
    final store = AppDataStore.instance;
    await store.close();
    // Повторное открытие после close() работает — и не зависает на
    // Completer предыдущего цикла.
    final db = await store.database();
    expect(db.isOpen, isTrue);
    await store.close();
  });
}
