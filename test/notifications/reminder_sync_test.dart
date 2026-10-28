/// NOTIF-6 (аудит 2026-10-28): фейковый планировщик + тесты синхронизации.
///
/// Раньше ReminderSyncService не имел ни одного теста — именно поэтому
/// NOTIF-1 (UTC-fallback) не был пойман. Здесь фейк-планировщик
/// протоколирует cancel/schedule/pending, позволяя проверить diff,
/// сериализацию (NOTIF-3) и отказ от повторных перезаписей (NOTIF-4).
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:smart_fridge_chef/data/models/product.dart';
import 'package:smart_fridge_chef/notifications/reminder_logic.dart';
import 'package:smart_fridge_chef/notifications/reminder_scheduler.dart';
import 'package:smart_fridge_chef/notifications/reminder_sync.dart';
import 'package:smart_fridge_chef/state/settings_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeReminderScheduler implements ReminderScheduler {
  final Map<int, ScheduledReminder> scheduled = {};
  final List<int> cancelLog = [];
  final List<int> scheduleLog = [];
  bool cancelledAll = false;

  /// Задержка в schedule — чтобы проверить сериализацию (NOTIF-3).
  final Duration scheduleDelay;

  FakeReminderScheduler({this.scheduleDelay = Duration.zero});

  @override
  Future<bool> requestPermissions() async => true;

  @override
  Future<void> schedule({
    required int id,
    required DateTime when,
    required String title,
    required String body,
  }) async {
    if (scheduleDelay > Duration.zero) {
      await Future<void>.delayed(scheduleDelay);
    }
    scheduled[id] = ScheduledReminder(when, title, body);
    scheduleLog.add(id);
  }

  @override
  Future<void> cancel(int id) async {
    scheduled.remove(id);
    cancelLog.add(id);
  }

  @override
  Future<void> cancelAll() async {
    scheduled.clear();
    cancelledAll = true;
  }

  @override
  Future<Set<int>> pendingIds() async => scheduled.keys.toSet();
}

class ScheduledReminder {
  ScheduledReminder(this.when, this.title, this.body);

  final DateTime when;
  final String title;
  final String body;
}

Product product(int id, String name, DateTime expiry) => Product(
      id: id,
      name: name,
      category: ProductCategory.dairy,
      expiryDate: expiry,
      addedAt: DateTime(2026, 10, 20),
    );

void main() {
  late FakeReminderScheduler fake;
  late ReminderSyncService sync;
  final start = DateTime(2026, 10, 26, 10, 0);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    fake = FakeReminderScheduler();
    sync = ReminderSyncService(
      scheduler: fake,
      settings: SettingsController(prefs),
    );
  });

  test('первый sync планирует напоминания по продуктам', () async {
    final products = [
      product(1, 'Молоко', start.add(const Duration(days: 3))),
    ];
    await sync.sync(products: products, now: start, localeTag: 'ru');
    expect(fake.scheduled, isNotEmpty);
    expect(fake.scheduleLog, isNotEmpty);
  });

  test('NOTIF-4: повторный sync без изменений не перезаписывает', () async {
    final products = [
      product(1, 'Молоко', start.add(const Duration(days: 3))),
      product(2, 'Хлеб', start.add(const Duration(days: 2))),
    ];
    await sync.sync(products: products, now: start, localeTag: 'ru');
    final afterFirst = List<int>.of(fake.scheduleLog);

    await sync.sync(products: products, now: start, localeTag: 'ru');
    // Ни одного нового zonedSchedule — содержимое не менялось.
    expect(fake.scheduleLog, afterFirst,
        reason: 'идемпотентный sync не должен дёргать планировщик');
  });

  test('NOTIF-4: правка даты продукта перезаписывает только его', () async {
    final products = [
      product(1, 'Молоко', start.add(const Duration(days: 3))),
      product(2, 'Хлеб', start.add(const Duration(days: 2))),
    ];
    await sync.sync(products: products, now: start, localeTag: 'ru');

    // Передвинули срок только молока.
    final moved = [
      product(1, 'Молоко', start.add(const Duration(days: 5))),
      product(2, 'Хлеб', start.add(const Duration(days: 2))),
    ];
    fake.scheduleLog.clear();
    await sync.sync(products: moved, now: start, localeTag: 'ru');
    // Молоко (id 11/12) перезапланировано, хлеб (21/22) — нет.
    final touched = fake.scheduleLog.toSet();
    expect(touched, isNotEmpty);
    expect(touched.difference({reminderId(1, 1), reminderId(1, 2)}), isEmpty,
        reason: 'хлеб не менялся — не перезаписывается');
  });

  test('удалённый продукт отменяется, изменённый перезаписывается', () async {
    final products = [
      product(1, 'Молоко', start.add(const Duration(days: 3))),
      product(2, 'Кефир', start.add(const Duration(days: 4))),
    ];
    await sync.sync(products: products, now: start, localeTag: 'ru');
    expect(fake.scheduled.keys.toSet(),
        {reminderId(1, 1), reminderId(1, 2), reminderId(2, 1), reminderId(2, 2)});

    // Кефир съели — его пуши отменены, молоко осталось.
    await sync.sync(products: [products.first], now: start, localeTag: 'ru');
    expect(fake.scheduled.keys.toSet(),
        {reminderId(1, 1), reminderId(1, 2)});
    expect(fake.cancelLog.toSet(), {reminderId(2, 1), reminderId(2, 2)});
  });

  test('выключенные уведомления — cancelAll', () async {
    await fake.schedule(id: 1, when: start, title: 't', body: 'b');
    await sync.settings.setNotificationsEnabled(false);
    await sync.sync(
      products: [product(1, 'Молоко', start.add(const Duration(days: 3)))],
      now: start,
      localeTag: 'ru',
    );
    expect(fake.cancelledAll, isTrue);
    expect(fake.scheduled, isEmpty);
  });

  test('NOTIF-3: параллельные sync сериализуются (не пересекаются)',
      () async {
    final slow = FakeReminderScheduler(scheduleDelay: const Duration(milliseconds: 20));
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final slowSync = ReminderSyncService(
      scheduler: slow,
      settings: SettingsController(prefs),
    );

    final products1 = [
      product(1, 'Молоко', start.add(const Duration(days: 3))),
    ];
    // Вторая мутация удаляет продукт — при пересечении она могла бы
    // отменить свежезапланированный id первой.
    const products2 = <Product>[];

    final f1 = slowSync.sync(products: products1, now: start, localeTag: 'ru');
    final f2 = slowSync.sync(products: products2, now: start, localeTag: 'ru');
    await f1;
    await f2;

    // Финальное состояние = результат ПОСЛЕДНЕЙ синхронизации: всё чисто.
    expect(slow.scheduled, isEmpty, reason: 'последний sync без продуктов');
    expect(slow.cancelLog, isNotEmpty);
  });

  test('исключение одной sync не роняет очередь (NOTIF-3)', () async {
    // Сломанный планировщик на первом вызове, живой — на втором.
    final flaky = FakeReminderScheduler();
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final svc = ReminderSyncService(
      scheduler: _FailingOnce(fake: flaky, failFirstSchedule: true),
      settings: SettingsController(prefs),
    );
    final products = [
      product(1, 'Молоко', start.add(const Duration(days: 3))),
    ];
    // Первая падает — но очередь должна выжить.
    await svc.sync(products: products, now: start, localeTag: 'ru')
        .catchError((Object _) {});
    await svc.sync(products: products, now: start, localeTag: 'ru');
    expect(flaky.scheduled, isNotEmpty,
        reason: 'вторая sync должна была выполниться после падения первой');
  });
}

class _FailingOnce implements ReminderScheduler {
  _FailingOnce({required this.fake, required this.failFirstSchedule});

  final FakeReminderScheduler fake;
  final bool failFirstSchedule;
  int calls = 0;

  @override
  Future<bool> requestPermissions() => fake.requestPermissions();

  @override
  Future<void> schedule({
    required int id,
    required DateTime when,
    required String title,
    required String body,
  }) async {
    calls++;
    if (calls == 1 && failFirstSchedule) {
      throw StateError('эмуляция сбоя планировщика');
    }
    return fake.schedule(id: id, when: when, title: title, body: body);
  }

  @override
  Future<void> cancel(int id) => fake.cancel(id);

  @override
  Future<void> cancelAll() => fake.cancelAll();

  @override
  Future<Set<int>> pendingIds() => fake.pendingIds();
}
