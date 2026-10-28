/// Лист подтверждения списания после «Приготовил» (v0.5.1).
///
/// Показывает, что и сколько спишется из холодильника: скоропортящееся
/// первым, весовые позиции — точными граммами, штучные — по умолчанию
/// одна штука со степпером. Каждый пункт с галочкой: снять — списания
/// не будет. Обнулившиеся позиции уходят в «съедено» (история
/// сохраняется, в QR-обмен попадает только несъеденное).
///
/// Если один продукт закрывает несколько ингредиентов (два ингредиента
/// с одним ключом), списания агрегируются в одну строку по продукту:
/// пользователю видно «Помидоры −300 г», а не две строки по одному
/// продукту с одинаковым названием.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../ai/pantry_deduction.dart';
import '../../data/models/product.dart';
import '../../data/models/recipe.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../state/product_controller.dart';

/// Открывает лист подтверждения; true — списание выполнено.
Future<bool> showCookedSheet(BuildContext context, Recipe recipe) async =>
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.85,
        child: CookedSheet(recipe: recipe),
      ),
    ) ??
    false;

/// Строка таблицы списания: агрегат по одному продукту + правки
/// пользователя (галочка, количество штук).
class _Row {
  _Row({
    required this.ingredient,
    required this.product,
    required this.qty,
    required this.remaining,
    required this.editable,
  })  : checked = true,
        userQty = qty;

  final RecipeIngredient ingredient;
  final Product product;

  /// Предложенная движком сумма списания (в единицах продукта).
  final double qty;

  /// Остаток после всех предложенных списаний (считает движок).
  final double remaining;

  /// Штучная позиция: количество можно править степпером.
  final bool editable;

  bool checked;
  double userQty;

  /// Сколько списываем с учётом правок пользователя.
  double get effectiveQty => editable ? userQty : qty;

  /// Остаток с учётом правок: для граммов движок уже посчитал точную
  /// математику; для штучных остаток сдвигается на разницу правки.
  double get effectiveRemaining => editable
      ? remaining - (userQty - qty)
      : remaining;
}

class CookedSheet extends StatefulWidget {
  const CookedSheet({super.key, required this.recipe});

  final Recipe recipe;

  @override
  State<CookedSheet> createState() => _CookedSheetState();
}

class _CookedSheetState extends State<CookedSheet> {
  late final DeductionPlan _plan;
  List<_Row> _rows = const [];
  List<String> _missing = const [];
  bool _rowsBuilt = false;
  bool _applying = false;

  @override
  void initState() {
    super.initState();
    final fridge = context.read<ProductController>().products;
    _plan = DeductionPlan.build(widget.recipe, fridge);
  }

  // UI-2 (аудит 2026-10-28): Localizations.localeOf — dependOnInherited,
  // вызов в initState даёт FlutterError в debug-сборке («Приготовил»).
  // Чтение локали и построение строк — в didChangeDependencies.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_rowsBuilt) return;
    _rowsBuilt = true;
    final plan = _plan;

    // Агрегация по продукту: один продукт — одна строка. Остаток — из
    // последней цели по продукту (движок уже учёл накопление спроса);
    // штучность — если хоть одна цель правимая.
    final acc = <int, ({RecipeIngredient ing, Product p, double qty, double rem, bool editable})>{};
    final missing = <String>[];
    final localeTag = Localizations.localeOf(context).languageCode;
    for (final row in plan.rows) {
      if (row.targets.isEmpty) {
        missing.add(localeTag.startsWith('ru')
            ? row.ingredient.ru
            : row.ingredient.en);
        continue;
      }
      for (final t in row.targets) {
        final key = t.product.id ?? t.product.hashCode;
        final prev = acc[key];
        acc[key] = prev == null
            ? (
                ing: row.ingredient,
                p: t.product,
                qty: t.qty,
                rem: t.remaining,
                editable: t.editable,
              )
            : (
                ing: prev.ing,
                p: prev.p,
                qty: prev.qty + t.qty,
                rem: t.remaining,
                editable: prev.editable || t.editable,
              );
      }
    }
    _rows = [
      for (final e in acc.values)
        _Row(
          ingredient: e.ing,
          product: e.p,
          qty: e.qty,
          remaining: e.rem,
          editable: e.editable,
        ),
    ];
    _missing = missing;
  }

  int get _checkedCount =>
      _rows.where((r) => r.checked && r.effectiveQty > 0).length;

  Future<void> _apply() async {
    setState(() => _applying = true);
    final controller = context.read<ProductController>();
    final l = AppLocalizations.of(context);
    final applied = await controller.applyCookedDeductions([
      for (final r in _rows)
        if (r.checked && r.effectiveQty > 0)
          (productId: r.product.id!, qty: r.effectiveQty),
    ]);
    if (!mounted) return;
    Navigator.of(context).pop(true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l.cookedDone(applied))),
    );
  }

  String _unitShort(ProductUnit u) {
    final ru = Localizations.localeOf(context).languageCode.startsWith('ru');
    return switch (u) {
      ProductUnit.gram => ru ? 'г' : 'g',
      ProductUnit.kilogram => ru ? 'кг' : 'kg',
      ProductUnit.milliliter => ru ? 'мл' : 'ml',
      ProductUnit.liter => ru ? 'л' : 'l',
      ProductUnit.pcs => ru ? 'шт' : 'pcs',
      ProductUnit.pack => ru ? 'упак' : 'pack',
    };
  }

  String _qtyLabel(Product p, double qty) {
    switch (p.unit) {
      case ProductUnit.gram:
      case ProductUnit.milliliter:
        return '−${qty.round()} ${_unitShort(p.unit)}';
      case ProductUnit.kilogram:
      case ProductUnit.liter:
        return '−${qty.toStringAsFixed(qty < 10 ? 2 : 1)} ${_unitShort(p.unit)}';
      case ProductUnit.pcs:
      case ProductUnit.pack:
        return '−${_fmtQty(qty)} ${_unitShort(p.unit)}';
    }
  }

  String _remainsLabel(Product p, double remaining) {
    switch (p.unit) {
      case ProductUnit.gram:
      case ProductUnit.milliliter:
        return '${remaining.round()} ${_unitShort(p.unit)}';
      case ProductUnit.kilogram:
      case ProductUnit.liter:
        return '${remaining.toStringAsFixed(remaining < 10 ? 2 : 1)} ${_unitShort(p.unit)}';
      case ProductUnit.pcs:
      case ProductUnit.pack:
        return '${_fmtQty(remaining)} ${_unitShort(p.unit)}';
    }
  }

  static String _fmtQty(double qty) =>
      qty == qty.roundToDouble() ? '${qty.round()}' : qty.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          Text(l.cookedSheetTitle, style: theme.textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            l.cookedSheetHint,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          if (_rows.isEmpty)
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    l.cookedNothing,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ),
            )
          else
            Expanded(
              child: ListView(
                children: [
                  for (final r in _rows) _targetTile(l, theme, r),
                  if (_missing.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
                      child: Text(l.cookedMissing,
                          style: theme.textTheme.titleSmall),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 8, bottom: 8),
                      child: Text(
                        _missing.join(', '),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          if (_rows.isNotEmpty)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8, top: 4),
                child: FilledButton(
                  onPressed: _checkedCount > 0 && !_applying ? _apply : null,
                  child: _applying
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text('${l.cookedApply} ($_checkedCount)'),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _targetTile(AppLocalizations l, ThemeData theme, _Row r) {
    final p = r.product;
    final willFinish =
        r.checked && r.effectiveQty > 0 && r.effectiveRemaining <= 0.0001;
    final subtitle = willFinish
        ? '${_qtyLabel(p, r.effectiveQty)} · ${l.cookedWillFinish}'
        : '${_qtyLabel(p, r.effectiveQty)} · '
            '${l.cookedRemains(_remainsLabel(p, r.effectiveRemaining))}';
    return CheckboxListTile(
      value: r.checked,
      onChanged: (v) => setState(() => r.checked = v ?? false),
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      title: Text(p.name),
      isThreeLine: false,
      subtitle: Text(subtitle, style: theme.textTheme.bodySmall),
      secondary: r.editable
          ? _Stepper(
              qty: r.userQty,
              max: p.quantity,
              onChanged: (v) => setState(() => r.userQty = v),
            )
          : null,
    );
  }
}

/// Степпер штук: 0..количество на позиции.
class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.qty,
    required this.max,
    required this.onChanged,
  });

  final double qty;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          visualDensity: VisualDensity.compact,
          onPressed: qty > 0 ? () => onChanged(qty - 1) : null,
          icon: const Icon(Icons.remove_circle_outline),
        ),
        Text('${qty.round()}'),
        IconButton(
          visualDensity: VisualDensity.compact,
          onPressed: qty < max ? () => onChanged(qty + 1) : null,
          icon: const Icon(Icons.add_circle_outline),
        ),
      ],
    );
  }
}
