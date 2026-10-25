/// Движок списания продуктов после «Приготовил» (v0.5.1).
///
/// Ответ на вопрос «как определяется съеденный продукт»: приложение
/// предлагает списание АВТОМАТИЧЕСКИ, но через подтверждение — экран
/// показывает, что и сколько спишется, каждый пункт можно снять с
/// галочки или поправить количество. Так работают оба режима сразу:
/// авто по умолчанию, ручной контроль рядом.
///
/// Правила списания:
///  1. Матчинг ингредиента → продукты холодильника через словарь
///     IngredientMatcher (тот же, что в планере — согласованность).
///  2. FIFO по сроку: первым списывается то, что портится быстрее.
///  3. Весовые позиции (г/кг/мл/л): точные граммы рецепта,
///     1 мл ≈ 1 г (то же допущение, что и в матчере).
///  4. Счётные позиции (штуки/упаковки): 1 штука с самой скоропортящейся
///     позиции — масса штуки неизвестна, точную цифру пользователь
///     правит степпером на экране подтверждения.
///  5. Кладовые ингредиенты (соль, специи) не списываются вовсе —
///     они и в планере не участвуют в покрытии.
///
/// Класс чистый (без Flutter и БД) — легко тестируется.
library;

import '../data/models/product.dart';
import '../data/models/recipe.dart';
import 'ingredient_matcher.dart';

/// Списание с конкретной позиции холодильника.
class DeductionTarget {
  const DeductionTarget({
    required this.product,
    required this.qty,
    required this.remaining,
  });

  /// Позиция холодильника (текущее состояние).
  final Product product;

  /// Сколько списать, В ЕДИНИЦАХ ПРОДУКТА (г для gram, шт для pcs...).
  final double qty;

  /// Остаток на позиции после списания. Считает ДВИЖОК, а не вычитанием
  /// из product.quantity: один продукт может закрывать несколько
  /// ингредиентов (два ингредиента с одним ключом) — тогда простое
  /// вычитание показало бы неверный остаток.
  final double remaining;

  /// Можно ли править количество на экране (штуки — да, граммы — нет:
  /// там детерминированная математика).
  bool get editable =>
      product.unit == ProductUnit.pcs || product.unit == ProductUnit.pack;

  /// <= 0 значит «съедено целиком».
  bool get zeroes => remaining <= 0.0001;

  /// Списание в граммах (для отображения «−300 г»).
  double get grams {
    switch (product.unit) {
      case ProductUnit.gram:
      case ProductUnit.milliliter:
        return qty;
      case ProductUnit.kilogram:
      case ProductUnit.liter:
        return qty * 1000;
      case ProductUnit.pcs:
      case ProductUnit.pack:
        return 0;
    }
  }
}

/// Списание по одному ингредиенту рецепта.
class IngredientDeduction {
  const IngredientDeduction({required this.ingredient, required this.targets});

  /// Ингредиент рецепта (некладовый).
  final RecipeIngredient ingredient;

  /// Позиции к списанию в порядке FIFO; пусто — ингредиента нет.
  final List<DeductionTarget> targets;

  bool get matched => targets.isNotEmpty;
}

/// Готовый план списания для экрана подтверждения.
class DeductionPlan {
  const DeductionPlan({required this.rows});

  /// По каждому некладовому ингредиенту рецепта.
  final List<IngredientDeduction> rows;

  /// Есть ли хоть что-то к списанию.
  bool get anythingToDeduct => rows.any((r) => r.matched);

  /// Число затронутых позиций холодильника (для итогового снека).
  int get targetCount =>
      rows.fold(0, (s, r) => s + r.targets.length);

  /// Считает план списания для рецепта по текущему холодильнику.
  ///
  /// [fridge] — все продукты; активные фильтруются внутри. Несколько
  /// ингредиентов с одним ключом списывают один и тот же запас
  /// последовательно (demand копится). Повторный вызов с теми же
  /// данными даёт тот же план — детерминизм для тестов.
  static DeductionPlan build(
    Recipe recipe,
    List<Product> fridge, {
    IngredientMatcher matcher = const IngredientMatcher(),
  }) {
    // Остатки в единицах продукта — снижаются по мере списания.
    final remaining = <Product, double>{
      for (final p in fridge)
        if (p.status == ProductStatus.active) p: p.quantity,
    };
    final rows = <IngredientDeduction>[];

    for (final ing in recipe.ingredients) {
      if (ing.pantry) continue;
      // Кандидаты: активные продукты с нужным ключом, FIFO по сроку.
      final candidates =
          fridge.where((p) => p.status == ProductStatus.active).where(
                (p) => matcher.matchProduct(p.name) == ing.key,
              ).toList()
            ..sort((a, b) => a.expiryDate.compareTo(b.expiryDate));

      var demandLeft = ing.grams.toDouble();
      final targets = <DeductionTarget>[];

      for (final p in candidates) {
        final left = remaining[p] ?? p.quantity;
        if (left <= 0) continue;

        final double qty;
        switch (p.unit) {
          case ProductUnit.gram:
          case ProductUnit.milliliter:
            qty = demandLeft < left ? demandLeft : left;
          case ProductUnit.kilogram:
          case ProductUnit.liter:
            final leftGrams = left * 1000;
            qty = (demandLeft < leftGrams ? demandLeft : leftGrams) / 1000;
          case ProductUnit.pcs:
          case ProductUnit.pack:
            // Масса штуки неизвестна: ровно одна с самой скоропортящейся
            // позиции; сколько реально ушло — правит пользователь.
            qty = left < 1 ? left : 1;
        }
        if (qty <= 0) continue;

        targets.add(DeductionTarget(
          product: p,
          qty: qty,
          remaining: left - qty,
        ));
        remaining[p] = left - qty;
        demandLeft -= targets.last.grams;
        if (demandLeft <= 0) break;
        if (targets.last.editable) break; // штучное — по одной позиции
      }
      rows.add(IngredientDeduction(ingredient: ing, targets: targets));
    }
    return DeductionPlan(rows: rows);
  }
}
