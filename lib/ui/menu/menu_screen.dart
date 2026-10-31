/// Экран «Мое меню» (Шаг 3): кнопка Суперпланера, недельная сетка,
/// детали блюда и история сохранённых планов.
///
/// Данные — `Consumer<PlanController>` (Шаг 2): генерация детерминированная,
/// офлайн; снимки рецептов самодостаточны для отображения.
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../ai/equipment.dart';
import '../../core/household_measures.dart';
import '../../data/models/meal_plan.dart';
import '../../data/models/recipe.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../state/plan_controller.dart';
import '../../state/profile_controller.dart';
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

  /// ST-1 (аудит 2026-10-28): ошибки планера локализуются через ARB —
  /// EN-пользователь больше не получает русские хардкоды контроллера.
  String _planErrorMessage(AppLocalizations l, PlanError? e) => switch (e) {
        PlanError.generate => l.planErrorGenerate,
        PlanError.save => l.planErrorSave,
        PlanError.history => l.planErrorHistory,
        PlanError.open => l.planErrorOpen,
        PlanError.delete => l.planErrorDelete,
        PlanError.shopping => l.planErrorShopping,
        null => '',
      };

  void _snack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _generate({bool fresh = false}) async {
    final controller = context.read<PlanController>();
    await controller.generate(seed: fresh ? null : 0);
    if (!mounted) return;
    final l = AppLocalizations.of(context);
    if (controller.phase == PlanPhase.error) {
      _snack(_planErrorMessage(l, controller.error));
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
            body: _planErrorMessage(l, plan.error),
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

  /// Расхождения по технике для блюда (v0.6.4): считаются на runtime
  /// из текущего профиля — пометки всегда соответствуют настройке,
  /// в план ничего дополнительно не пишется. Профиль без явного списка
  /// (до v0.6.4) — расхождений нет.
  List<EquipmentGap> _equipmentGaps(BuildContext context, Recipe recipe) {
    final profile = context.watch<ProfileController>().profile;
    if (profile == null) return const [];
    return KitchenEquipmentEngine.gaps(
      needed: KitchenEquipmentEngine.requiredForSteps(
          KitchenEquipmentEngine.stepsTextOf(recipe.stepsRu)),
      servings: recipe.servings,
      owned: profile.equipment?.toSet(),
    );
  }

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
          '${day.kcalTotal} ${l.unitKcal} · '
          '${l.unitP}/${l.unitF}/${l.unitC} ${day.proteinTotal}/${day.fatTotal}/${day.carbsTotal}',
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
          // v0.6.9: блюда составного приёма (первое, второе, салат…)
          // идут подряд с одним slot_order — группируем их под общим
          // заголовком слота; одиночные приёмы выглядят как раньше.
          for (final group in _mealGroups(day.meals))
            if (group.length == 1)
              _mealTile(context, l, group.single, showSlot: true)
            else ...[
              ListTile(
                dense: true,
                leading: Icon(slotIcon(group.first.slot),
                    color: theme.colorScheme.primary),
                title: Text(slotLabel(l, group.first.slot),
                    style: theme.textTheme.titleSmall),
                subtitle: Text(
                  '${group.fold<int>(0, (s, m) => s + m.kcal)} '
                  '${l.unitKcal}',
                  style: theme.textTheme.bodySmall,
                ),
              ),
              for (final meal in group)
                _mealTile(context, l, meal, showSlot: false),
            ],
        ],
      ),
    );
  }

  /// Подряд идущие блюда одного слота (v0.6.9): составной приём читается
  /// одним блоком, порядок записей (подача) сохраняется.
  List<List<PlannedMeal>> _mealGroups(List<PlannedMeal> meals) {
    final groups = <List<PlannedMeal>>[];
    for (final meal in meals) {
      if (groups.isNotEmpty && groups.last.last.slot == meal.slot) {
        groups.last.add(meal);
      } else {
        groups.add([meal]);
      }
    }
    return groups;
  }

  /// Строка блюда плана (v0.6.9): в составе приёма подпись слота несёт
  /// заголовок блока, поэтому у блюда она опускается ([showSlot]).
  Widget _mealTile(
    BuildContext context,
    AppLocalizations l,
    PlannedMeal meal, {
    required bool showSlot,
  }) {
    final theme = Theme.of(context);
    final localeTag = Localizations.localeOf(context).languageCode;
    // Пометка замены техники (v0.6.4): только заместимые расхождения —
    // блокирующее не попадает в план.
    final equipmentNote = _equipmentGaps(context, meal.recipe)
        .where((g) => g.substitutable)
        .map((g) =>
            '${equipmentLabel(l, g.equipment)} → '
            '${equipmentSubstShort(l, g.equipment)}')
        .toList();
    return ListTile(
      leading: showSlot
          ? Icon(slotIcon(meal.slot), color: theme.colorScheme.primary)
          : const SizedBox(width: 24),
      title: Text(meal.recipe.title(localeTag)),
      subtitle: Text(
        '${showSlot ? '${slotLabel(l, meal.slot)} · ' : ''}'
        '${meal.kcal} ${l.unitKcal}'
        // Порции (v0.6.8): план добирает калораж порциями — честно
        // показываем «×2 порции», калорийность уже с ними.
        '${meal.servings > 1 ? ' · ${l.menuPlannedServings(meal.servings)}' : ''}'
        '${meal.usesExpiring.isEmpty ? '' : ' · ★ ${meal.usesExpiring.length}'}'
        '${equipmentNote.isEmpty ? '' : ' · ${l.menuEquipmentNote(equipmentNote.join(', '))}'}',
        style: theme.textTheme.bodySmall,
      ),
      // Нелюбимое в малом количестве (v0.5.4): честная пометка
      // «содержит: лук» под приёмом пищи.
      trailing: meal.minorDislikes.isEmpty
          ? const Icon(Icons.chevron_right)
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    l.menuContainsDislike(
                        meal.minorDislikes.take(2).join(', ')),
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.tertiary),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
      onTap: () => _showRecipe(context, meal),
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
        child: RecipeSheet(
          recipe: meal.recipe,
          localeTag: localeTag,
          // Порции плана (v0.6.8): КБЖУ, ингредиенты и «Приготовил»
          // масштабируются к запланированному числу порций.
          plannedServings: meal.servings,
        ),
      ),
    );
  }
}

/// Детали блюда: КБЖУ, ингредиенты, пошаговое приготовление.
///
/// [plannedServings] (v0.6.8) — запланированное число порций, когда лист
/// открыт из плана меню: чипы, КБЖУ и ингредиенты масштабируются к нему
/// (план добирает калораж порциями). null — рецепт «как написан».
/// Ингредиенты показываются бытовой мерой + граммами
/// (core/household_measures.dart): «2 чайные ложки / 12 г».
class RecipeSheet extends StatelessWidget {
  const RecipeSheet({
    super.key,
    required this.recipe,
    required this.localeTag,
    this.plannedServings,
  });

  final Recipe recipe;
  final String localeTag;

  /// Запланированное число порций (из плана меню) или null.
  final int? plannedServings;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);

    // Масштаб к запланированным порциям. КБЖУ задано НА ПОРЦИЮ —
    // умножается на число запланированных порций; ингредиенты заданы
    // НА ВЕСЬ РЕЦЕПТ — умножаются на plannedServings / recipe.servings
    // (v0.6.8; вне плана — как написано).
    final int planned = plannedServings ?? 1;
    final double ingScale = plannedServings == null
        ? 1.0
        : plannedServings! / recipe.servings;
    int scaled(int perServing) => perServing * planned;

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
                    '${scaled(recipe.kcal)} ${l.unitKcal}'),
              ),
              Chip(
                avatar: const Icon(Icons.schedule, size: 16),
                label: Text(l.menuCookMinutes(recipe.minutes)),
              ),
              Chip(
                avatar: const Icon(Icons.restaurant_outlined, size: 16),
                label: Text(l.menuServings(plannedServings ?? recipe.servings)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${l.unitP}/${l.unitF}/${l.unitC} '
            '${scaled(recipe.protein)}/${scaled(recipe.fat)}/${scaled(recipe.carbs)}'
            '${plannedServings == null ? ' ${l.perServing}' : ''}',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          _EquipmentNoteCard(recipe: recipe, localeTag: localeTag),
          const SizedBox(height: 16),
          Text(l.menuIngredients, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final ing in recipe.ingredients)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                  Flexible(
                    child: Text(
                      // Бытовая мера + граммы (v0.6.8): «2 чайные ложки /
                      // 12 г»; без меры в таблице — только граммы.
                      formatHouseholdAmount(
                        key: ing.key,
                        grams: (ing.grams * ingScale).ceil(),
                        localeTag: localeTag,
                        gramUnit: l.unitGram,
                      ),
                      style: theme.textTheme.bodySmall,
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              l.recipeHouseholdNote,
              style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic),
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
          // С plannedServings (v0.6.8) списание масштабируется к
          // запланированным порциям.
          FilledButton.icon(
            onPressed: () async {
              final ok = await showCookedSheet(
                context,
                recipe,
                plannedServings: plannedServings,
              );
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

/// Карточка «техники нет — чем заменить» (v0.6.4) в деталях рецепта.
///
/// Считается на runtime из текущего профиля: заменяемые расхождения
/// показывают подсказку замены, блокируемые (духовка + большое блюдо) —
/// честное «без духовки не приготовить» (актуально для старых планов,
/// сгенерированных до смены набора техники).
class _EquipmentNoteCard extends StatelessWidget {
  const _EquipmentNoteCard({required this.recipe, required this.localeTag});

  final Recipe recipe;
  final String localeTag;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final profile = context.watch<ProfileController>().profile;
    if (profile == null) return const SizedBox.shrink();
    final gaps = KitchenEquipmentEngine.gaps(
      needed: KitchenEquipmentEngine.requiredForSteps(
          KitchenEquipmentEngine.stepsTextOf(recipe.stepsRu)),
      servings: recipe.servings,
      owned: profile.equipment?.toSet(),
    );
    if (gaps.isEmpty) return const SizedBox.shrink();

    final blocking = gaps.where((g) => !g.substitutable).toList();
    final substitutable = gaps.where((g) => g.substitutable).toList();

    String substitutionOf(EquipmentGap g) => localeTag.startsWith('ru')
        ? g.substitutionRu
        : g.substitutionEn;

    final String message;
    if (blocking.isNotEmpty) {
      // Блокируемое — всегда духовка (единственная нерезервируемая
      // техника), сообщение в ARB сформулировано под неё.
      message = [
        if (blocking.isNotEmpty) l.recipeEquipmentBlocking(recipe.servings),
        for (final g in substitutable)
          l.recipeEquipmentMissing(
              equipmentLabel(l, g.equipment), substitutionOf(g)),
      ].join(' ');
    } else {
      message = l.recipeEquipmentMissing(
        substitutable
            .map((g) => equipmentLabel(l, g.equipment))
            .join(', '),
        substitutable.map(substitutionOf).join(' / '),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Card(
        margin: EdgeInsets.zero,
        child: ListTile(
          leading: Icon(
            blocking.isEmpty
                ? Icons.swap_horiz_outlined
                : Icons.report_problem_outlined,
            color: blocking.isEmpty
                ? theme.colorScheme.tertiary
                : theme.colorScheme.error,
          ),
          title: Text(
            message,
            style: theme.textTheme.bodySmall,
          ),
          dense: true,
        ),
      ),
    );
  }
}
