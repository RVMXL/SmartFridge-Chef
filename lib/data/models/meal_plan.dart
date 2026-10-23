/// Модели сгенерированного плана меню (Шаг 2) — выход AI-слоя
/// и содержимое таблиц `meal_plans` / `planned_meals` / `shopping_items`
/// (схема БД v2). Соответствуют JSON-контракту из docs/ARCHITECTURE.md.
library;

import 'dart:convert';

import 'recipe.dart';

/// Один приём пищи в плане. Рецепт хранится снимком (snapshot),
/// поэтому сохранённые планы не ломаются при обновлении базы рецептов.
class PlannedMeal {
  const PlannedMeal({
    required this.dayIndex,
    required this.slot,
    required this.slotOrder,
    required this.recipe,
    required this.usesExpiring,
    required this.coverage,
  });

  final int dayIndex;
  final MealSlot slot;

  /// Порядок внутри слота (при 5–6 приёмах в день бывает два перекуса).
  final int slotOrder;

  /// Снимок рецепта на момент генерации.
  final Recipe recipe;

  /// Названия продуктов из холодильника с истекающим сроком,
  /// которые закрывает этот приём («съесть раньше»).
  final List<String> usesExpiring;

  /// Доля некладовых ингредиентов, найденных в холодильнике (0..1).
  final double coverage;

  int get kcal => recipe.kcal;

  Map<String, Object?> toMap(String planId) => {
        'plan_id': planId,
        'day_index': dayIndex,
        'slot': slot.key,
        'slot_order': slotOrder,
        'recipe_id': recipe.id,
        'recipe_json': jsonEncode(recipe.toJson()),
        'kcal': recipe.kcal,
        'uses_expiring': jsonEncode(usesExpiring),
        'coverage': coverage,
      };

  static PlannedMeal fromMap(Map<String, Object?> map) => PlannedMeal(
        dayIndex: (map['day_index'] as num).toInt(),
        slot: MealSlot.fromKey(map['slot'] as String),
        slotOrder: ((map['slot_order'] as num?) ?? 0).toInt(),
        recipe: Recipe.fromJson(
            jsonDecode(map['recipe_json'] as String) as Map<String, Object?>),
        usesExpiring: ((jsonDecode(map['uses_expiring'] as String? ?? '[]')
                as List<dynamic>))
            .cast<String>(),
        coverage: ((map['coverage'] as num?) ?? 0).toDouble(),
      );

  @override
  String toString() =>
      'PlannedMeal(d${dayIndex}_${slot.key}, ${recipe.titleRu}, $kcal ккал)';
}

/// День плана: дата + слоты + итоги КБЖУ.
class PlanDay {
  const PlanDay({
    required this.dayIndex,
    required this.date,
    required this.meals,
  });

  final int dayIndex;
  final DateTime date;
  final List<PlannedMeal> meals;

  int get kcalTotal => meals.fold(0, (s, m) => s + m.kcal);
  int get proteinTotal => meals.fold(0, (s, m) => s + m.recipe.protein);
  int get fatTotal => meals.fold(0, (s, m) => s + m.recipe.fat);
  int get carbsTotal => meals.fold(0, (s, m) => s + m.recipe.carbs);

  /// Все продукты с истекающим сроком, закрытые этим днём.
  List<String> get expiringUsed =>
      meals.expand((m) => m.usesExpiring).toList();
}

/// Недостающий ингредиент (таблица `shopping_items`).
class PlanShoppingItem {
  const PlanShoppingItem({
    required this.key,
    required this.name,
    this.checked = false,
  });

  /// Канонический ключ IngredientMatcher (для будущих подсказок при вводе).
  final String key;
  final String name;
  final bool checked;

  Map<String, Object?> toMap(String planId) => {
        'plan_id': planId,
        'ing_key': key,
        'name': name,
        'checked': checked ? 1 : 0,
      };

  static PlanShoppingItem fromMap(Map<String, Object?> map) =>
      PlanShoppingItem(
        key: map['ing_key'] as String? ?? '',
        name: map['name'] as String? ?? '',
        checked: ((map['checked'] as num?) ?? 0) == 1,
      );

  @override
  String toString() => 'PlanShoppingItem($name${checked ? " ✓" : ""})';
}

/// Итоговый план на N дней — результат MealPlanner.generate.
class GeneratedPlan {
  const GeneratedPlan({
    required this.id,
    required this.createdAt,
    required this.startDate,
    required this.kcalTarget,
    required this.seed,
    required this.source,
    required this.days,
    required this.shoppingList,
    required this.warnings,
  });

  /// Идентификатор вида `p<millis>-<seed>`; генерирует планировщик.
  final String id;
  final DateTime createdAt;
  final DateTime startDate;
  final int kcalTarget;

  /// Зерно детерминированной генерации: тот же seed — тот же план.
  final int seed;

  /// Источник: `rule_based` | `local_llm` (Шаг 3+).
  final String source;
  final List<PlanDay> days;
  final List<PlanShoppingItem> shoppingList;
  final List<String> warnings;

  int get daysCount => days.length;

  /// Средний калораж дня по плану.
  int get kcalPerDay =>
      days.isEmpty ? 0 : (kcalTotal / days.length).round();

  int get kcalTotal => days.fold(0, (s, d) => s + d.kcalTotal);

  @override
  String toString() =>
      'GeneratedPlan($id, $daysCount дн., ~$kcalPerDay ккал/день, '
      'покупок: ${shoppingList.length})';
}

/// Краткая сводка сохранённого плана для списка истории.
class PlanSummary {
  const PlanSummary({
    required this.id,
    required this.createdAt,
    required this.startDate,
    required this.daysCount,
    required this.kcalTarget,
    required this.mealCount,
    required this.source,
  });

  final String id;
  final DateTime createdAt;
  final DateTime startDate;
  final int daysCount;
  final int kcalTarget;
  final int mealCount;
  final String source;

  static PlanSummary fromMap(Map<String, Object?> map) => PlanSummary(
        id: map['id'] as String,
        createdAt: DateTime.parse(map['created_at'] as String),
        startDate: _parseDate(map['start_date'] as String),
        daysCount: (map['days_count'] as num?)?.toInt() ?? 0,
        kcalTarget: (map['kcal_target'] as num?)?.toInt() ?? 0,
        mealCount: (map['meal_count'] as num?)?.toInt() ?? 0,
        source: map['source'] as String? ?? 'rule_based',
      );

  @override
  String toString() =>
      'PlanSummary($id, $daysCount дн., $mealCount приёмов)';
}

DateTime _parseDate(String s) {
  final p = s.split('-');
  return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
}
