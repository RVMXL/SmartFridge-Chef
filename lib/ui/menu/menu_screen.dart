/// Экран «Мое меню» (Шаг 3): кнопка Суперпланера, недельная сетка,
/// детали блюда и история сохранённых планов.
///
/// Данные — `Consumer<PlanController>` (Шаг 2): генерация детерминированная,
/// офлайн; снимки рецептов самодостаточны для отображения.
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../data/models/meal_plan.dart';
import '../../data/models/recipe.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../state/plan_controller.dart';
import '../widgets/common.dart';
import 'cooked_sheet.dart';
import 'shopping_screen.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<PlanController>().loadHistory();
    });
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _generate({bool fresh = false}) async {
    final controller = context.read<PlanController>();
    await controller.generate(seed: fresh ? null : 0);
    if (!mounted) return;
    final l = AppLocalizations.of(context);
    if (controller.phase == PlanPhase.error) {
      _snack('${l.menuPlanError}: ${controller.error ?? ''}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final plan = context.watch<PlanController>();

    return Scaffold(
      appBar: AppBar(
        title: Text(l.plannerTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: l.menuHistory,
            onPressed: plan.history.isEmpty ? null : _showHistory,
          ),
        ],
      ),
      body: switch (plan.phase) {
        PlanPhase.generating => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(l.menuGenerating),
              ],
            ),
          ),
        PlanPhase.error => EmptyState(
            icon: Icons.error_outline,
            title: l.menuPlanError,
            body: plan.error ?? '',
            action: FilledButton(
              onPressed: () => _generate(fresh: true),
              child: Text(l.menuGenerateShort),
            ),
          ),
        PlanPhase.idle => EmptyState(
            icon: Icons.restaurant_menu,
            title: l.menuEmptyTitle,
            body: l.menuEmptyBody,
            action: FilledButton.icon(
              onPressed: () => _generate(),
              icon: const Icon(Icons.auto_awesome),
              label: Text(l.menuGenerateShort),
            ),
          ),
        PlanPhase.ready || PlanPhase.saved => _PlanView(plan: plan.plan!),
      },
    );
  }

  Future<void> _showHistory() async {
    final controller = context.read<PlanController>();
    final l = AppLocalizations.of(context);
    final localeTag = Localizations.localeOf(context).languageCode;
    final fmt = DateFormat.yMMMd(localeTag);
    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (sheetCtx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(l.menuHistory, style: Theme.of(context).textTheme.titleMedium),
            ),
            if (controller.history.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(l.menuHistoryEmpty),
              ),
            for (final s in controller.history)
              ListTile(
                leading: const Icon(Icons.calendar_month_outlined),
                title: Text(fmt.format(s.startDate)),
                subtitle: Text(l.menuKcalPerDay(s.kcalTarget)),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    await controller.deleteSaved(s.id);
                    if (sheetCtx.mounted) Navigator.of(sheetCtx).pop();
                  },
                ),
                onTap: () async {
                  await controller.openSaved(s.id);
                  if (sheetCtx.mounted) Navigator.of(sheetCtx).pop();
                },
              ),
          ],
        ),
      ),
    );
  }
}

/// Содержимое собранного плана: сводка + 7 дней.
class _PlanView extends StatelessWidget {
  const _PlanView({required this.plan});

  final GeneratedPlan plan;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final controller = context.watch<PlanController>();
    final localeTag = Localizations.localeOf(context).languageCode;
    final fmt = DateFormat.yMMMd(localeTag);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l.menuWeekOf(fmt.format(plan.startDate)),
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                    Chip(
                      label: Text(
                        controller.phase == PlanPhase.saved
                            ? l.menuSavedBadge
                            : l.menuDraftBadge,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${l.menuKcalPerDay(plan.kcalPerDay)} · '
                  '${l.menuTarget(plan.kcalTarget)}',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (controller.phase == PlanPhase.ready)
                      FilledButton.icon(
                        onPressed: () async {
                          final ok =
                              await context.read<PlanController>().saveCurrent();
                          if (context.mounted && ok) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content:
                                      Text(AppLocalizations.of(context).menuSaved)),
                            );
                          }
                        },
                        icon: const Icon(Icons.save_outlined),
                        label: Text(l.menuSavePlan),
                      ),
                    OutlinedButton.icon(
                      onPressed: () =>
                          context.read<PlanController>().generate(seed: null),
                      icon: const Icon(Icons.refresh),
                      label: Text(l.menuRegenerate),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const ShoppingScreen()),
                      ),
                      icon: const Icon(Icons.shopping_cart_outlined),
                      label: Text(l.menuShopping),
                    ),
                  ],
                ),
                if (plan.warnings.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  for (final w in plan.warnings)
                    Text(
                      w,
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant),
                    ),
                ],
                if (plan.hasExclusions) ...[
                  const SizedBox(height: 8),
                  _ExclusionsCard(plan: plan),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        for (final day in plan.days)
          _DayCard(day: day, localeTag: localeTag),
      ],
    );
  }
}

/// Карточка «почему некоторые рецепты не в меню» (v0.5.0):
/// причина → сколько исключено + до трёх примеров. По умолчанию
/// свёрнута — для тех, кому интересно, почему пул сузился.
class _ExclusionsCard extends StatelessWidget {
  const _ExclusionsCard({required this.plan});

  final GeneratedPlan plan;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final reasons = plan.excludedCounts.keys.toList()..sort();
    return ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 16),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      leading: const Icon(Icons.rule_outlined),
      title: Text(l.planExcludedTitle, style: theme.textTheme.titleSmall),
      subtitle: Text(
        l.planExcludedSummary(
            plan.excludedCounts.values.fold<int>(0, (a, b) => a + b)),
        style: theme.textTheme.bodySmall,
      ),
      children: [
        for (final reason in reasons) _reasonRow(context, reason),
      ],
    );
  }

  Widget _reasonRow(BuildContext context, String reason) {
    final theme = Theme.of(context);
    final examples = plan.excludedExamples[reason];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$reason — ${plan.excludedCounts[reason]}',
              style: theme.textTheme.bodyMedium,
            ),
            if (examples != null && examples.isNotEmpty)
              Text(
                examples.join(', '),
                style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant),
              ),
          ],
        ),
      ),
    );
  }
}

/// Карточка дня недели: раскрывается до списка приёмов пищи.
class _DayCard extends StatelessWidget {
  const _DayCard({required this.day, required this.localeTag});

  final PlanDay day;
  final String localeTag;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final fmt = DateFormat.MMMMEEEEd(localeTag);
    final expiring = day.expiringUsed;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
        title: Text(fmt.format(day.date)),
        subtitle: Text(
          '${day.kcalTotal} ${localeTag.startsWith('ru') ? 'ккал' : 'kcal'} · '
          'Б/P ${day.proteinTotal} · Ж/F ${day.fatTotal} · У/C ${day.carbsTotal}',
          style: theme.textTheme.bodySmall,
        ),
        children: [
          if (expiring.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Chip(
                  avatar: Icon(Icons.schedule,
                      size: 16, color: theme.colorScheme.tertiary),
                  label: Text(
                    l.menuUsesExpiring(
                        expiring.toSet().take(3).join(', ')),
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ),
            ),
          for (final meal in day.meals)
            ListTile(
              leading: Icon(slotIcon(meal.slot),
                  color: theme.colorScheme.primary),
              title: Text(meal.recipe.title(localeTag)),
              subtitle: Text(
                '${slotLabel(l, meal.slot)} · ${meal.kcal} ${localeTag.startsWith('ru') ? 'ккал' : 'kcal'}'
                '${meal.usesExpiring.isEmpty ? '' : ' · ★ ${meal.usesExpiring.length}'}',
                style: theme.textTheme.bodySmall,
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showRecipe(context, meal),
            ),
        ],
      ),
    );
  }

  void _showRecipe(BuildContext context, PlannedMeal meal) {
    final localeTag = Localizations.localeOf(context).languageCode;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.85,
        child: RecipeSheet(recipe: meal.recipe, localeTag: localeTag),
      ),
    );
  }
}

/// Детали блюда: КБЖУ, ингредиенты, пошаговое приготовление.
class RecipeSheet extends StatelessWidget {
  const RecipeSheet({super.key, required this.recipe, required this.localeTag});

  final Recipe recipe;
  final String localeTag;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView(
        children: [
          Text(recipe.title(localeTag), style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              Chip(
                avatar: const Icon(Icons.local_fire_department_outlined,
                    size: 16),
                label: Text(
                    '${recipe.kcal} ${localeTag.startsWith('ru') ? 'ккал' : 'kcal'}'),
              ),
              Chip(
                avatar: const Icon(Icons.schedule, size: 16),
                label: Text(l.menuCookMinutes(recipe.minutes)),
              ),
              Chip(
                avatar: const Icon(Icons.restaurant_outlined, size: 16),
                label: Text(l.menuServings(recipe.servings)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Б/P ${recipe.protein} · Ж/F ${recipe.fat} · У/C ${recipe.carbs} ${localeTag.startsWith('ru') ? '(на порцию)' : '(per serving)'}',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          Text(l.menuIngredients, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final ing in recipe.ingredients)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Icon(
                    ing.pantry ? Icons.egg_alt : Icons.egg_outlined,
                    size: 16,
                    color: ing.pantry
                        ? theme.colorScheme.onSurfaceVariant
                        : theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                        localeTag.startsWith('ru') ? ing.ru : ing.en),
                  ),
                  Text('${ing.grams} ${localeTag.startsWith('ru') ? 'г' : 'g'}',
                      style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          const SizedBox(height: 16),
          Text(l.menuSteps, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          for (var i = 0; i < recipe.steps(localeTag).length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 10,
                    child: Text('${i + 1}',
                        style: theme.textTheme.labelSmall),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(recipe.steps(localeTag)[i])),
                ],
              ),
            ),
          const SizedBox(height: 16),
          // «Приготовил» (v0.5.1): подтверждаемое списание ингредиентов
          // из холодильника — скоропортящееся первым, штуки правятся.
          FilledButton.icon(
            onPressed: () async {
              final ok = await showCookedSheet(context, recipe);
              if (ok == true && context.mounted) {
                Navigator.of(context).pop(); // закрыть и лист рецепта
              }
            },
            icon: const Icon(Icons.soup_kitchen_outlined),
            label: Text(l.cookedButton),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
