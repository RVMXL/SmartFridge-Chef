/// Единая точка доступа к локальной базе для UI-слоя.
///
/// Пока приложение маленькое, достаточно ленивого синглтона; при росте
/// (Шаги 2–3) репозитории перейдут на provider без изменения DAO.
library;

import 'package:sqflite/sqflite.dart';

import 'dao/product_dao.dart';
import 'dao/profile_dao.dart';
import 'database.dart';

class AppDataStore {
  AppDataStore._();

  static final AppDataStore instance = AppDataStore._();

  Database? _db;

  Future<Database> database() async {
    _db ??= await AppDatabase.open();
    return _db!;
  }

  Future<ProductDao> productDao() async => ProductDao(await database());

  Future<ProfileDao> profileDao() async => ProfileDao(await database());

  /// Закрыть базу (для тестов инфраструктуры).
  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
