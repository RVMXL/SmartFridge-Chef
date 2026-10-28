/// Единая точка доступа к локальной базе для UI-слоя.
///
/// Пока приложение маленькое, достаточно ленивого синглтона; при росте
/// (Шаги 2–3) репозитории перейдут на provider без изменения DAO.
library;

import 'dart:async';

import 'package:sqflite/sqflite.dart';

import 'dao/barcode_cache_dao.dart';
import 'dao/plan_dao.dart';
import 'dao/product_dao.dart';
import 'dao/profile_dao.dart';
import 'database.dart';

class AppDataStore {
  AppDataStore._();

  static final AppDataStore instance = AppDataStore._();

  Database? _db;

  /// DATA-3 (аудит 2026-10-28, v0.6.2): защита от гонки ленивой
  /// инициализации. Раньше `_db ??= await open()` при двух почти
  /// одновременных вызовах (старт приложения: refresh + профиль)
  /// открывал базу ДВАЖДЫ — второй open при активном первом
  /// мог упасть (SQLite busy) или дать два независимых соединения.
  Completer<Database>? _opening;

  Future<Database> database() async {
    final existing = _db;
    if (existing != null) return existing;
    final opening = _opening;
    if (opening != null) return opening.future;

    final completer = Completer<Database>();
    _opening = completer;
    try {
      final db = await AppDatabase.open();
      _db = db;
      completer.complete(db);
    } catch (e, st) {
      _opening = null; // следующая попытка повторит открытие
      completer.completeError(e, st);
    }
    return completer.future;
  }

  Future<ProductDao> productDao() async => ProductDao(await database());

  Future<ProfileDao> profileDao() async => ProfileDao(await database());

  Future<PlanDao> planDao() async => PlanDao(await database());

  Future<BarcodeCacheDao> barcodeCacheDao() async =>
      BarcodeCacheDao(await database());

  /// Закрыть базу (для тестов инфраструктуры).
  Future<void> close() async {
    final opening = _opening;
    if (opening != null) {
      try {
        await opening.future;
      } catch (_) {
        // Открытие упало — закрывать нечего.
      }
    }
    _opening = null;
    await _db?.close();
    _db = null;
  }
}
