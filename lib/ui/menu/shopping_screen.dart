/// Экран «Список покупок» (Шаг 3): недостающие ингредиенты текущего
/// плана меню с чекбоксами «куплено» и очисткой отмеченных.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../state/plan_controller.dart';
import '../widgets/common.dart';

class ShoppingScreen extends StatelessWidget {
  const ShoppingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final controller = context.watch<PlanController>();
    final plan = controller.plan;

    return Scaffold(
      appBar: AppBar(
        title: Text(l.shoppingTitle),
        actions: [
          if (plan != null && plan.shoppingList.any((i) => i.checked))
            IconButton(
              icon: const Icon(Icons.clear_all),
              tooltip: l.shoppingClearChecked,
              onPressed: () => controller.clearCheckedShopping(),
            ),
        ],
      ),
      body: plan == null || plan.shoppingList.isEmpty
          ? EmptyState(
              icon: Icons.shopping_cart_outlined,
              title: l.shoppingTitle,
              body: plan == null ? l.shoppingNoPlan : l.shoppingEmpty,
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Text(
                    l.shoppingFromPlan,
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                  child: Text(
                    l.shoppingChecked(
                      plan.shoppingList.where((i) => i.checked).length,
                      plan.shoppingList.length,
                    ),
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
                    children: [
                      for (final item in plan.shoppingList)
                        CheckboxListTile(
                          value: item.checked,
                          onChanged: (on) =>
                              controller.setShoppingChecked(
                            ingKey: item.key,
                            checked: on ?? false,
                          ),
                          title: Text(
                            item.missingGrams == null
                                ? item.name
                                // UI-10: единица — из ARB, не хардкод «г».
                                : '${item.name} · ≈${item.missingGrams} ${l.unitGram}',
                            style: item.checked
                                ? TextStyle(
                                    decoration: TextDecoration.lineThrough,
                                    color: theme
                                        .colorScheme.onSurfaceVariant,
                                  )
                                : null,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
