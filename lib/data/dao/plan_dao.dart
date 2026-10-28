/// DAO сохранённых планов меню (таблицы `meal_plans`, `planned_meals`,
/// `shopping_items` — схема v2, Шаг 2).
///
/// Сохранение — одна транзакция (заголовок + приёмы + покупки);
/// удаление каскадное через FOREIGN KEY. Рецепты читаются из
/// JSON-снимков, поэтому план не зависит от версии базы рецептов.
library;

import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../models/meal_plan.dart';

class PlanDao {
  PlanDao(this.db);

  final Database db;

  /// Сохраняет план целиком. При конфликте id план заменяется
  /// (повторная генерация с тем же seed перезаписывает черновик).
  Future<void> savePlan(GeneratedPlan plan) async {
    await db.transaction((txn) async {
      await txn.delete('planned_meals',
          where: 'plan_id = ?', whereArgs: [plan.id]);
      await txn.delete('shopping_items',
          where: 'plan_id = ?', whereArgs: [plan.id]);
      await txn.insert(
        'meal_plans',
        {
          'id': plan.id,
          'created_at': plan.createdAt.toIso8601String(),
          'start_date': _formatDate(plan.startDate),
          'days_count': plan.daysCount,
          'kcal_target': plan.kcalTarget,
          'seed': plan.seed,
          'source': plan.source,
          'warnings': jsonEncode(plan.warnings),
          'filter_report': plan.hasExclusions
              ? jsonEncode({
                  'counts': plan.excludedCounts,
                  'examples': plan.excludedExamples,
                })
              : null,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      // DATA-2 (аудит 2026-10-28): batch вместо построчных await insert —
      // тот же паттерн, что при создании схемы: 21–42 приёма и позиции
      // покупок уезжают одним батчем внутри транзакции.
      final batch = txn.batch();
      for (final day in plan.days) {
        for (final meal in day.meals) {
          batch.insert('planned_meals', meal.toMap(plan.id));
        }
      }
      for (final item in plan.shoppingList) {
        batch.insert('shopping_items', item.toMap(plan.id));
      }
      await batch.commit(noResult: true);
    });
  }

  /// План по id (со снимками рецептов) или null.
  Future<GeneratedPlan?> getPlan(String id) async {
    final header = await db.query('meal_plans',
        where: 'id = ?', whereArgs: [id], limit: 1);
    if (header.isEmpty) return null;
    final h = header.first;

    final mealRows = await db.query(
      'planned_meals',
      where: 'plan_id = ?',
      whereArgs: [id],
      orderBy: 'day_index, slot_order, id',
    );
    final mealsByDay = <int, List<PlannedMeal>>{};
    for (final row in mealRows) {
      final meal = PlannedMeal.fromMap(row);
      mealsByDay.putIfAbsent(meal.dayIndex, () => []).add(meal);
    }
    final daysCount = (h['days_count'] as num?)?.toInt() ?? 0;
    final startDate = _parseDate(h['start_date'] as String);
    final days = List<PlanDay>.generate(
      daysCount,
      (i) => PlanDay(
        dayIndex: i,
        date: DateTime(startDate.year, startDate.month, startDate.day + i),
        meals: mealsByDay[i] ?? const [],
      ),
    );

    final shoppingRows = await db.query(
      'shopping_items',
      where: 'plan_id = ?',
      whereArgs: [id],
      orderBy: 'id',
    );

    // Диагностика «почему исключено» (v0.5.0): у старых планов колонка
    // пуста — карты остаются пустыми, карточка не показывается.
    Map<String, int> excludedCounts = const {};
    Map<String, List<String>> excludedExamples = const {};
    final rawReport = h['filter_report'] as String?;
    if (rawReport != null && rawReport.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawReport) as Map<String, Object?>;
        excludedCounts =
            ((decoded['counts'] as Map<String, Object?>?) ?? const {})
                .map((k, v) => MapEntry(k, (v as num).toInt()));
        excludedExamples =
            ((decoded['examples'] as Map<String, Object?>?) ?? const {})
                .map((k, v) => MapEntry(
                    k, (v as List<dynamic>).cast<String>().toList()));
      } catch (_) {
        // Битый отчёт не должен ломать открытие плана.
      }
    }

    return GeneratedPlan(
      id: h['id'] as String,
      createdAt: DateTime.parse(h['created_at'] as String),
      startDate: startDate,
      kcalTarget: (h['kcal_target'] as num?)?.toInt() ?? 0,
      seed: (h['seed'] as num?)?.toInt() ?? 0,
      source: h['source'] as String? ?? 'rule_based',
      days: days,
      shoppingList: shoppingRows.map(PlanShoppingItem.fromMap).toList(),
      warnings: ((jsonDecode(h['warnings'] as String? ?? '[]')
              as List<dynamic>))
          .cast<String>(),
      excludedCounts: excludedCounts,
      excludedExamples: excludedExamples,
    );
  }

  /// Список сохранённых планов (новые сверху) — для истории меню.
  Future<List<PlanSummary>> listPlans({int limit = 30}) async {
    final rows = await db.rawQuery('''
      SELECT mp.*, COUNT(pm.id) AS meal_count
      FROM meal_plans mp
      LEFT JOIN planned_meals pm ON pm.plan_id = mp.id
      GROUP BY mp.id
      ORDER BY mp.created_at DESC
      LIMIT ?
    ''', [limit]);
    return rows.map(PlanSummary.fromMap).toList();
  }

  /// Удаляет план (приёмы и покупки — каскадом).
  Future<int> deletePlan(String id) =>
      db.delete('meal_plans', where: 'id = ?', whereArgs: [id]);

  /// Отметка «куплено» для позиции списка покупок.
  Future<int> setShoppingChecked({
    required String planId,
    required String ingKey,
    required bool checked,
  }) =>
      db.update(
        'shopping_items',
        {'checked': checked ? 1 : 0},
        where: 'plan_id = ? AND ing_key = ?',
        whereArgs: [planId, ingKey],
      );

  /// Удаляет купленные (отмеченные) позиции из списка покупок плана.
  Future<int> deleteCheckedShopping(String planId) => db.delete(
        'shopping_items',
        where: 'plan_id = ? AND checked = 1',
        whereArgs: [planId],
      );

  /// Количество сохранённых планов (тесты/статистика).
  Future<int> countPlans() async {
    final rows = await db.rawQuery('SELECT COUNT(*) AS c FROM meal_plans');
    return (rows.first['c'] as num?)?.toInt() ?? 0;
  }

  // ------------------------------------------------------------ утилиты

  static String _formatDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static DateTime _parseDate(String s) {
    final p = s.split('-');
    return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
  }
}
