/// Контроллер холодильника (Шаг 3): список активных продуктов,
/// CRUD с пересчётом статистики и синхронизацией напоминаний.
///
/// Единственный источник истины — SQLite через ProductDao; UI подписывается
/// через provider. После каждой мутации запускается sync пуши-планировщика,
/// чтобы напоминания не отставали от реального содержимого холодильника.
library;

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart' show Database;

import '../data/dao/product_dao.dart';
import '../data/models/product.dart';
import '../notifications/reminder_sync.dart';

/// Режим сортировки списка холодильника.
enum FridgeSort { expiry, name, category }

/// Результат добавления продукта.
enum AddResult { ok, duplicateBarcode, error }

class ProductController extends ChangeNotifier {
  ProductController({
    required this._openDb,
    this._reminderSync,
    this._localeTag,
  });

  final Future<Database> Function() _openDb;
  final ReminderSyncService? _reminderSync;
  final String Function()? _localeTag;

  /// Активные продукты (упорядочены по сроку, как в DAO).
  List<Product> products = const [];
  FridgeStats? stats;
  bool loading = false;
  String? error;

  String _query = '';
  FridgeSort _sort = FridgeSort.expiry;

  /// Поисковый запрос (регистронезависимое вхождение в название).
  String get query => _query;

  FridgeSort get sort => _sort;

  void setQuery(String value) {
    _query = value;
    notifyListeners();
  }

  void setSort(FridgeSort value) {
    _sort = value;
    notifyListeners();
  }

  /// Список после поиска и сортировки выбранного режима.
  List<Product> get visible {
    Iterable<Product> list = products;
    final q = _query.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((p) => p.name.toLowerCase().contains(q));
    }
    final sorted = switch (_sort) {
      FridgeSort.expiry => list.toList()
        ..sort((a, b) => a.expiryDate.compareTo(b.expiryDate)),
      FridgeSort.name => list.toList()
        ..sort((a, b) =>
            a.name.toLowerCase().compareTo(b.name.toLowerCase())),
      FridgeSort.category => list.toList()
        ..sort((a, b) {
          final byCat = a.category.key.compareTo(b.category.key);
          return byCat != 0
              ? byCat
              : a.expiryDate.compareTo(b.expiryDate);
        }),
    };
    return sorted;
  }

  /// Перезагружает список и статистику, затем синхронизирует напоминания.
  Future<void> refresh() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final dao = ProductDao(await _openDb());
      products = await dao.activeProducts();
      stats = await dao.stats();
    } catch (e) {
      error = e.toString();
    }
    loading = false;
    notifyListeners();
    await _syncReminders();
  }

  /// Добавляет продукт. При занятом штрих-коде возвращает
  /// [AddResult.duplicateBarcode] и не пишет в базу
  /// (частично-уникальный индекс из Шага 1).
  Future<AddResult> add(Product product) async {
    try {
      final dao = ProductDao(await _openDb());
      final barcode = product.barcode?.trim();
      if (barcode != null && barcode.isNotEmpty) {
        final existing = await dao.getByBarcode(barcode);
        if (existing != null) return AddResult.duplicateBarcode;
      }
      await dao.insert(product);
      await refresh();
      return AddResult.ok;
    } catch (e) {
      error = e.toString();
      notifyListeners();
      return AddResult.error;
    }
  }

  /// Массовое добавление из чека (OCR): частично успешное добавление
  /// допустимо, итог — число записанных позиций.
  Future<int> addAll(List<Product> items) async {
    var saved = 0;
    try {
      final dao = ProductDao(await _openDb());
      for (final item in items) {
        try {
          await dao.insert(item);
          saved++;
        } catch (_) {
          // Позиция с занятым штрих-кодом не валит весь чек.
        }
      }
      await refresh();
    } catch (e) {
      error = e.toString();
      notifyListeners();
    }
    return saved;
  }

  Future<bool> update(Product product) async {
    try {
      final dao = ProductDao(await _openDb());
      await dao.update(product);
      await refresh();
      return true;
    } catch (e) {
      error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Съел / выбросил — продукт остаётся в истории со статусом.
  Future<bool> setStatus(int id, ProductStatus status) async {
    try {
      final dao = ProductDao(await _openDb());
      await dao.setStatus(id, status);
      await refresh();
      return true;
    } catch (e) {
      error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Жёсткое удаление (без истории).
  Future<bool> delete(int id) async {
    try {
      final dao = ProductDao(await _openDb());
      await dao.delete(id);
      await refresh();
      return true;
    } catch (e) {
      error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Ищет продукт по штрих-коду (экран сканера: «уже в холодильнике?»).
  Future<Product?> findByBarcode(String barcode) async {
    final dao = ProductDao(await _openDb());
    return dao.getByBarcode(barcode.trim());
  }

  /// Пуш-планер догоняет изменения. Ошибки глушатся: напоминания —
  /// фон, не повод ронять UI-поток.
  Future<void> _syncReminders() async {
    final sync = _reminderSync;
    if (sync == null) return;
    try {
      await sync.sync(
        products: products,
        localeTag: _localeTag?.call() ?? 'ru',
      );
    } catch (e) {
      debugPrint('ReminderSync: $e');
    }
  }
}
