/// DAO кэша штрих-кодов: локальные результаты автопоиска (Шаг 3.1).
///
/// Найденный в открытой базе товар сохраняется на устройстве, поэтому
/// повторное сканирование работает без сети. Отрицательные результаты
/// не кэшируются — открытая база постоянно пополняется.
library;

import 'package:sqflite/sqflite.dart';

import '../../data/models/product.dart';

/// Результат из кэша: имя и категория (если удалось определить).
class CachedBarcode {
  const CachedBarcode({
    required this.name,
    required this.category,
  });

  final String name;
  final ProductCategory? category;
}

class BarcodeCacheDao {
  const BarcodeCacheDao(this._db);

  final Database _db;

  static const String _table = 'barcode_cache';

  /// Результат по коду или null, если код ещё не искали/не нашли.
  Future<CachedBarcode?> get(String code) async {
    final rows = await _db.query(_table,
        where: 'code = ?', whereArgs: [code], limit: 1);
    if (rows.isEmpty) return null;
    final row = rows.first;
    final categoryKey = row['category_key'] as String?;
    return CachedBarcode(
      name: row['name'] as String,
      category: categoryKey == null
          ? null
          : ProductCategory.fromKey(categoryKey),
    );
  }

  /// Сохраняет результат (перезаписывает прежний по тому же коду).
  Future<void> put(
    String code,
    String name,
    ProductCategory? category,
  ) {
    return _db.insert(
      _table,
      {
        'code': code,
        'name': name,
        'category_key': category?.key,
        'source': 'openfoodfacts',
        'fetched_at': DateTime.now().toUtc().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
