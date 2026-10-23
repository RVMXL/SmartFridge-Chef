/// Интеграционные тесты PlanController: генерация -> сохранение ->
/// история -> открытие -> удаление -> покупки (Шаг 2).
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:smart_fridge_chef/ai/recipe_repository.dart';
import 'package:smart_fridge_chef/ai/rule_based_planner.dart';
import 'package:smart_fridge_chef/data/database.dart';
import 'package:smart_fridge_chef/data/dao/product_dao.dart';
import 'package:smart_fridge_chef/data/dao/profile_dao.dart';
import 'package:smart_fridge_chef/data/models/product.dart';
import 'package:smart_fridge_chef/data/models/user_profile.dart';
import 'package:smart_fridge_chef/state/plan_controller.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Directory tmp;
  late String dbPath;
  late RecipeRepository repo;
  late PlanController controller;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('fridge_ctrl_test');
    dbPath = '${tmp.path}/test.db';
    repo = RecipeRepository(
      loadString: () =>
          File('assets/data/recipes.json').readAsString(),
    );
    controller = PlanController(
      planner: RuleBasedPlanner(repo),
      repo: repo,
      openDb: () => AppDatabase.open(absolutePath: dbPath),
    );
  });

  tearDown(() async {
    controller.dispose();
    await tmp.delete(recursive: true);
  });

  Product product(String name, String category, int inDays) => Product(
        name: name,
        category: ProductCategory.fromKey(category),
        expiryDate: DateTime.now().add(Duration(days: inDays)),
        addedAt: DateTime.now(),
      );

  group('генерация', () {
    test('на пустой базе (дефолтный профиль) план создаётся', () async {
      await controller.generate(seed: 1);
      expect(controller.phase, PlanPhase.ready);
      expect(controller.error, isNull);
      expect(controller.plan!.daysCount, 7);
      expect(controller.plan!.kcalTarget,
          PlanController.defaultProfile.dailyCalories);
    });

    test('с профилем из БД план учитывает калораж', () async {
      final db = await AppDatabase.open(absolutePath: dbPath);
      final now = DateTime.now();
      await ProfileDao(db).save(UserProfile(
        dailyCalories: 1600,
        mealsPerDay: 4,
        createdAt: now,
        updatedAt: now,
      ));
      await ProductDao(db).insert(product('Куриное филе', 'meat', 2));
      await db.close();

      await controller.generate(seed: 3);
      expect(controller.phase, PlanPhase.ready);
      expect(controller.plan!.kcalTarget, 1600);
      final slots =
          controller.plan!.days.first.meals.map((m) => m.slot.key);
      expect(slots, contains('snack'));
    });

    test('ошибка базы переводит контроллер в error с текстом', () async {
      final broken = PlanController(
        planner: RuleBasedPlanner(repo),
        repo: repo,
        openDb: () async {
          throw StateError('база недоступна');
        },
      );
      await broken.generate();
      expect(broken.phase, PlanPhase.error);
      expect(broken.error, isNotNull);
      broken.dispose();
    });
  });

  group('сохранение и история', () {
    test('save -> saved -> история -> открыть -> удалить', () async {
      await controller.generate(seed: 5);
      final planId = controller.plan!.id;

      expect(await controller.saveCurrent(), isTrue);
      expect(controller.phase, PlanPhase.saved);
      expect(controller.history, hasLength(1));
      expect(controller.history.first.id, planId);

      controller.plan = null;
      controller.phase = PlanPhase.idle;
      expect(await controller.openSaved(planId), isTrue);
      expect(controller.plan, isNotNull);
      expect(controller.plan!.id, planId);

      expect(await controller.deleteSaved(planId), isTrue);
      expect(controller.history, isEmpty);
      expect(controller.plan, isNull);
      expect(controller.phase, PlanPhase.idle);
    });

    test('saveCurrent без плана — false', () async {
      expect(await controller.saveCurrent(), isFalse);
    });
  });

  group('покупки', () {
    test('setShoppingChecked обновляет план и базу', () async {
      await controller.generate(seed: 8);
      await controller.saveCurrent();

      final item = controller.plan!.shoppingList.first;
      await controller.setShoppingChecked(
          ingKey: item.key, checked: true);

      expect(
        controller.plan!.shoppingList
            .firstWhere((s) => s.key == item.key)
            .checked,
        isTrue,
      );
      // Перезагрузка из БД подтверждает сохранение.
      final id = controller.plan!.id;
      controller.plan = null;
      await controller.openSaved(id);
      expect(
        controller.plan!.shoppingList
            .firstWhere((s) => s.key == item.key)
            .checked,
        isTrue,
      );
    });
  });

  group('уведомления слушателей', () {
    test('generate уведомляет минимум дважды (старт + готово)', () async {
      var notifications = 0;
      controller.addListener(() => notifications++);
      await controller.generate(seed: 11);
      expect(notifications, greaterThanOrEqualTo(2));
    });
  });
}
