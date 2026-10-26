/// Общие виджеты и маппинги доменных ключей в локализованные названия.
library;

import 'package:flutter/material.dart';

import '../../core/freshness.dart';
import '../../data/models/product.dart';
import '../../data/models/recipe.dart';
import '../../data/models/user_profile.dart';
import '../../l10n/generated/app_localizations.dart';

/// Цвет свежести на схеме Material (приглушённые контейнеры).
Color freshnessColor(BuildContext context, Freshness f) {
  final scheme = Theme.of(context).colorScheme;
  return switch (f) {
    Freshness.fresh => scheme.primary,
    Freshness.expiringSoon => const Color(0xFFF9A825),
    Freshness.expired => scheme.error,
  };
}

/// Локализованное название категории.
String categoryLabel(AppLocalizations l, ProductCategory c) => switch (c) {
      ProductCategory.dairy => l.catDairy,
      ProductCategory.meat => l.catMeat,
      ProductCategory.fish => l.catFish,
      ProductCategory.vegetables => l.catVegetables,
      ProductCategory.fruits => l.catFruits,
      ProductCategory.bakery => l.catBakery,
      ProductCategory.grains => l.catGrains,
      ProductCategory.frozen => l.catFrozen,
      ProductCategory.beverages => l.catBeverages,
      ProductCategory.sweets => l.catSweets,
      ProductCategory.condiments => l.catCondiments,
      ProductCategory.other => l.catOther,
    };

/// Локализованное название единицы измерения.
String unitLabel(AppLocalizations l, ProductUnit u) => switch (u) {
      ProductUnit.pcs => l.unitPcs,
      ProductUnit.gram => l.unitGram,
      ProductUnit.kilogram => l.unitKilogram,
      ProductUnit.milliliter => l.unitMilliliter,
      ProductUnit.liter => l.unitLiter,
      ProductUnit.pack => l.unitPack,
    };

/// «Количество + единица», например «2 л».
String quantityText(AppLocalizations l, Product p) {
  final qty = p.quantity == p.quantity.roundToDouble()
      ? p.quantity.toStringAsFixed(0)
      : p.quantity.toStringAsFixed(2);
  return '$qty ${unitLabel(l, p.unit)}';
}

/// Локализованное название диеты.
String dietLabel(AppLocalizations l, Diet d) => switch (d) {
      Diet.none => l.dietNone,
      Diet.vegetarian => l.dietVegetarian,
      Diet.vegan => l.dietVegan,
      Diet.lent => l.dietLent,
      Diet.pescatarian => l.dietPescatarian,
      Diet.lowCarb => l.dietLowCarb,
      Diet.halal => l.dietHalal,
      Diet.kosher => l.dietKosher,
      Diet.hindu => l.dietHindu,
    };

/// Локализованное название аллергена.
String allergenLabel(AppLocalizations l, Allergen a) => switch (a) {
      Allergen.milk => l.allergenMilk,
      Allergen.eggs => l.allergenEggs,
      Allergen.fish => l.allergenFish,
      Allergen.shellfish => l.allergenShellfish,
      Allergen.nuts => l.allergenNuts,
      Allergen.peanuts => l.allergenPeanuts,
      Allergen.soy => l.allergenSoy,
      Allergen.wheat => l.allergenWheat,
      Allergen.sesame => l.allergenSesame,
      Allergen.celery => l.allergenCelery,
      Allergen.mustard => l.allergenMustard,
      Allergen.sulphites => l.allergenSulphites,
      Allergen.lupin => l.allergenLupin,
      Allergen.honey => l.allergenHoney,
      Allergen.chocolate => l.allergenChocolate,
      Allergen.redProduce => l.allergenRedProduce,
      Allergen.mushrooms => l.allergenMushrooms,
      Allergen.spices => l.allergenSpices,
      Allergen.poultry => l.allergenPoultry,
      Allergen.beef => l.allergenBeef,
      Allergen.pork => l.allergenPork,
      Allergen.mildFruits => l.allergenMildFruits,
      Allergen.mildCereals => l.allergenMildCereals,
      Allergen.mildVegetables => l.allergenMildVegetables,
    };

/// Локализованное название приёма пищи.
String slotLabel(AppLocalizations l, MealSlot s) => switch (s) {
      MealSlot.breakfast => l.slotBreakfast,
      MealSlot.snack => l.slotSnack,
      MealSlot.lunch => l.slotLunch,
      MealSlot.dinner => l.slotDinner,
    };

/// Иконка приёма пищи.
IconData slotIcon(MealSlot s) => switch (s) {
      MealSlot.breakfast => Icons.wb_sunny_outlined,
      MealSlot.snack => Icons.cookie_outlined,
      MealSlot.lunch => Icons.lunch_dining_outlined,
      MealSlot.dinner => Icons.dinner_dining_outlined,
    };

/// Заголовок секции настроек/экранов.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8),
      child: Text(
        text,
        style: theme.textTheme.titleSmall
            ?.copyWith(color: theme.colorScheme.primary),
      ),
    );
  }
}

/// Пустое состояние с иконкой, заголовком и описанием.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.action,
  });

  final IconData icon;
  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: theme.colorScheme.primary),
            const SizedBox(height: 12),
            Text(title,
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              body,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant),
            ),
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}
