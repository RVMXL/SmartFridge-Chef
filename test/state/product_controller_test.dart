/// Тесты ProductController (Шаг 3): CRUD, дубликаты штрих-кодов,
/// поиск/сортировка и синхронизация напоминаний после мутаций.
///
/// SQLite — настоящая (sqflite_common_ffi, хост); напоминания — фейковый
/// планировщик, настройки — SharedPreferences с мок-значениями.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:smart_fridge_chef/data/database.dart';
import 'package:smart_fridge_chef/data/models/product.dart';
import 'package:smart_fridge_chef/notifications/reminder_scheduler.dart';
import 'package:smart_fridge_chef/notifications/reminder_sync.dart';
import 'package:smart_fridge_chef/state/product_controller.dart';
import 'package:smart_fridge_chef/state/settings_controller.dart';

/// Пассивный планировщик: запоминает вызовы, ничего не шлёт.
class FakeScheduler implements ReminderScheduler {
  final Map<int, DateTime> scheduled = {};
  final Set<int> cancelled = {};
  bool allCancelled = false;
  bool permissionAsked = false;

  @override
  Future<bool> requestPermissions() async {
    permissionAsked = true;
    return true;
  }

  @override
  Future<void> schedule({
    required int id,
    required DateTime when,
    required String title,
    required String body,
  }) async {
    scheduled[id] = when;
    cancelled.remove(id);
    allCancelled = false;
  }

  @override
  Future<void> cancel(int id) async {
    scheduled.remove(id);
    cancelled.add(id);
  }

  @override
  Future<void> cancelAll() async {
    scheduled.clear();
    allCancelled = true;
  }

  @override
  Future<Set<int>> pendingIds() async => scheduled.keys.toSet();
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    SharedPreferences.setMockInitialValues({});
  });

  late Directory tmp;
  late Database db;
  late FakeScheduler scheduler;
  late ReminderSyncService sync;
  late ProductController controller;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('fridge_ctrl_test');
    db = await AppDatabase.open(absolutePath: '${tmp.path}/test.db');
    scheduler = FakeScheduler();
    final prefs = await SharedPreferences.getInstance();
    sync = ReminderSyncService(
      scheduler: scheduler,
      settings: SettingsController(prefs),
    );
    controller = ProductController(
      openDb: () async => db,
      reminderSync: sync,
      localeTag: () => 'ru',
    );
  });

  tearDown(() async {
    await db.close();
    await tmp.delete(recursive: true);
  });

  Product product(
    String name, {
    String? barcode,
    String expiry = '2026-11-01',
    ProductCategory category = ProductCategory.dairy,
  }) =>
      Product(
        name: name,
        category: category,
        barcode: barcode,
        expiryDate: Product.parseDate(expiry),
        addedAt: DateTime(2026, 10, 24),
      );

  test('add → refresh: список и статистика обновляются', () async {
    final result = await controller.add(product('Молоко'));
    expect(result, AddResult.ok);
    expect(controller.products, hasLength(1));
    expect(controller.stats?.activeCount, 1);
  });

  test('второй продукт с тем же штрих-кодом отклоняется (индекс Шага 1)',
      () async {
    expect(await controller.add(product('Молоко', barcode: '4600000000001')),
        AddResult.ok);
    expect(await controller.add(product('Молоко ещё', barcode: '4600000000001')),
        AddResult.duplicateBarcode);
    expect(controller.products, hasLength(1));
  });

  test('findByBarcode находит сохранённый продукт', () async {
    await controller.add(product('Сыр', barcode: '4600000000002'));
    final found = await controller.findByBarcode('4600000000002');
    expect(found, isNotNull);
    expect(found!.name, 'Сыр');
    expect(await controller.findByBarcode('00000'), isNull);
  });

  test('update и delete проходят через контроллер', () async {
    await controller.add(product('Молоко'));
    final p = controller.products.single;
    await controller.update(p.copyWith(name: 'Молоко 3,2%'));
    expect(controller.products.single.name, 'Молоко 3,2%');

    await controller.delete(p.id!);
    expect(controller.products, isEmpty);
  });

  test('setStatus consumed убирает из активных, статистика меняется', () async {
    await controller.add(product('Молоко'));
    final id = controller.products.single.id!;
    await controller.setStatus(id, ProductStatus.consumed);
    expect(controller.products, isEmpty);
    expect(controller.stats?.activeCount, 0);
  });

  test('addAll из чека: позиции с занятым кодом не валят партию', () async {
    await controller.add(product('Кефир', barcode: '4600000000003'));
    final saved = await controller.addAll([
      product('Сыр', barcode: '4600000000004'),
      product('Дубль кефира', barcode: '4600000000003'),
      product('Хлеб'),
    ]);
    expect(saved, 2);
    expect(controller.products, hasLength(3));
  });

  test('поиск по названию регистронезависим', () async {
    await controller.add(product('Молоко Простоквашино'));
    await controller.add(product('Хлеб Бородинский'));
    controller.setQuery('просток');
    expect(controller.visible, hasLength(1));
    expect(controller.visible.single.name, 'Молоко Простоквашино');
    controller.setQuery('');
    expect(controller.visible, hasLength(2));
  });

  test('сортировка: по имени и по категории', () async {
    await controller.add(product('Яблоки',
        category: ProductCategory.fruits, expiry: '2026-11-10'));
    await controller.add(product('Молоко',
        category: ProductCategory.dairy, expiry: '2026-11-05'));
    await controller.add(product('Ананас',
        category: ProductCategory.fruits, expiry: '2026-11-01'));

    controller.setSort(FridgeSort.name);
    expect(
      controller.visible.map((p) => p.name).toList(),
      ['Ананас', 'Молоко', 'Яблоки'],
    );

    controller.setSort(FridgeSort.category);
    expect(
      controller.visible.map((p) => p.category.key).toList(),
      ['dairy', 'fruits', 'fruits'],
    );
    // Внутри категории — по сроку.
    expect(controller.visible[1].name, 'Ананас');
  });

  group('синхронизация напоминаний', () {
    // Далёкий срок, чтобы тест не зависел от текущей даты на хосте.
    test('после add планируются пуши за 2 и за 1 день (по умолчанию)', () async {
      await controller.add(product('Молоко', expiry: '2027-06-01'));
      expect(scheduler.scheduled, hasLength(2));
      final days = scheduler.scheduled.keys
          .map((id) => id % 10) // напоминаниеId = productId*10 + daysBefore
          .toSet();
      expect(days, {1, 2});
    });

    test('после delete лишние пуши отменяются', () async {
      await controller.add(product('Молоко', expiry: '2027-06-01'));
      expect(scheduler.scheduled, hasLength(2));
      final id = controller.products.single.id!;
      await controller.delete(id);
      expect(scheduler.scheduled, isEmpty);
    });

    test('выключенные уведомления → cancelAll', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('pref_notif_enabled', false);
      await controller.add(product('Молоко', expiry: '2027-06-01'));
      expect(scheduler.allCancelled, isTrue);
      expect(scheduler.scheduled, isEmpty);
    });

    test('изменённый час будильника учитывается при планировании', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('pref_notif_hour', 21);
      await controller.add(product('Молоко', expiry: '2027-06-01'));
      expect(scheduler.scheduled.values.every((d) => d.hour == 21), isTrue);
    });
  });
}
