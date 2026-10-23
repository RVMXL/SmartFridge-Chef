/// DAO продуктов: запросы холодильника (Шаг 1 ТЗ).
library;

import 'package:sqflite/sqflite.dart';

import '../../core/constants.dart';
import '../../core/freshness.dart';
import '../models/product.dart';

/// Сводка состояния холодильника для карточек-статистик.
class FridgeStats {
  const FridgeStats({
    required this.activeCount,
    required this.expiringCount,
    required this.expiredCount,
  });

  final int activeCount;
  final int expiringCount;
  final int expiredCount;

  bool get isEmpty => activeCount == 0;
}

class ProductDao {
  const ProductDao(this._db);

  final Database _db;

  static const String _table = 'products';

  /// Добавляет продукт, возвращает id.
  Future<int> insert(Product product) {
    assert(product.isValid, 'Имя продукта не может быть пустым');
    return _db.insert(_table, product.toMap(),
        conflictAlgorithm: ConflictAlgorithm.abort);
  }

  /// Обновляет продукт по id.
  Future<int> update(Product product) {
    assert(product.id != null, 'Обновлять можно только сохранённый продукт');
    return _db.update(_table, product.toMap(),
        where: 'id = ?', whereArgs: [product.id]);
  }

  /// Меняет статус (съел / выбросил) — продукт остаётся в истории.
  Future<int> setStatus(int id, ProductStatus status) => _db.update(
        _table,
        {'status': status.key},
        where: 'id = ?',
        whereArgs: [id],
      );

  /// Жёсткое удаление (например, по свайпу до подтверждения).
  Future<int> delete(int id) =>
      _db.delete(_table, where: 'id = ?', whereArgs: [id]);

  Future<Product?> getById(int id) async {
    final rows = await _db.query(_table, where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : Product.fromMap(rows.first);
  }

  /// Поиск по штрих-коду: «уже лежит в холодильнике?» (Шаг 3, сканер).
  Future<Product?> getByBarcode(String barcode) async {
    final rows = await _db.query(_table,
        where: 'barcode = ?', whereArgs: [barcode], limit: 1);
    return rows.isEmpty ? null : Product.fromMap(rows.first);
  }

  /// Активные продукты: сначала те, что портятся быстрее (ТЗ: главный экран).
  Future<List<Product>> activeProducts({int? limit}) => _db
      .query(_table,
          where: 'status = ?',
          whereArgs: [ProductStatus.active.key],
          orderBy: 'expiry_date ASC, name COLLATE NOCASE ASC',
          limit: limit)
      .then((rows) => rows.map(Product.fromMap).toList());

  /// Продукты, срок которых истекает в пределах [days] дней от [now] включительно.
  Future<List<Product>> expiringWithin(
    int days, {
    DateTime? now,
  }) async {
    final today = dateOnly(now ?? DateTime.now());
    final until = today.add(Duration(days: days));
    return _db
        .query(
          _table,
          where: "status = ? AND expiry_date >= ? AND expiry_date <= ?",
          whereArgs: [
            ProductStatus.active.key,
            Product.formatDate(today),
            Product.formatDate(until),
          ],
          orderBy: 'expiry_date ASC',
        )
        .then((rows) => rows.map(Product.fromMap).toList());
  }

  /// Уже просроченные активные продукты.
  Future<List<Product>> expired({DateTime? now}) async {
    final today = dateOnly(now ?? DateTime.now());
    return _db
        .query(
          _table,
          where: 'status = ? AND expiry_date < ?',
          whereArgs: [ProductStatus.active.key, Product.formatDate(today)],
          orderBy: 'expiry_date ASC',
        )
        .then((rows) => rows.map(Product.fromMap).toList());
  }

  /// Статистика для карточек экрана «Мой холодильник».
  Future<FridgeStats> stats({DateTime? now}) async {
    final all = await activeProducts();
    var expiring = 0;
    var expiredCount = 0;
    for (final p in all) {
      switch (freshnessFor(p.expiryDate,
          now: now, soonDays: kExpiringSoonDays)) {
        case Freshness.expiringSoon:
          expiring++;
        case Freshness.expired:
          expiredCount++;
        case Freshness.fresh:
          break;
      }
    }
    return FridgeStats(
      activeCount: all.length,
      expiringCount: expiring,
      expiredCount: expiredCount,
    );
  }
}
