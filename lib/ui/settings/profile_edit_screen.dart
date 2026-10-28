/// Экран профиля питания (Шаг 3): калораж, БЖУ, диета, аллергены,
/// количество приёмов пищи.
///
/// Используется и из настроек, и из онбординга (режим без AppBar-возврата
/// — тогда кнопка «Сохранить» закрывает онбординг).
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../ai/dislikes.dart';
import '../../ai/ingredient_matcher.dart';
import '../../data/models/medical_diet.dart';
import '../../data/models/user_profile.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../state/profile_controller.dart';
import '../widgets/common.dart';

class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({
    super.key,
    this.initial,
    this.embedded = false,
  });

  /// Существующий профиль (null → дефолт 2000 ккал, 3 приёма).
  final UserProfile? initial;

  /// true — открыт из онбординга: минималистичный вид, поп только по «Готово».
  final bool embedded;

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  late int _calories;
  late int _protein;
  late int _fat;
  late int _carbs;
  late Set<Diet> _diets;
  late Set<Allergen> _allergies;
  late Set<String> _medicalDiets;
  late List<DislikeRule> _dislikes;
  late int _mealsPerDay;

  @override
  void initState() {
    super.initState();
    final p = widget.initial ?? PlanDefaults.profile;
    _calories = p.dailyCalories;
    _protein = p.proteinG;
    _fat = p.fatG;
    _carbs = p.carbsG;
    _diets = {...p.diets};
    _allergies = {...p.allergies};
    _medicalDiets = {...p.medicalDiets};
    _dislikes = [...p.dislikes];
    _mealsPerDay = p.mealsPerDay;
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _recalcBju() {
    final d = UserProfile.defaultsForCalories(_calories);
    setState(() {
      _protein = d.protein;
      _fat = d.fat;
      _carbs = d.carbs;
    });
  }

  Future<void> _save() async {
    final l = AppLocalizations.of(context);
    final controller = context.read<ProfileController>();
    final base = widget.initial ?? PlanDefaults.profile;
    final ok = await controller.save(base.copyWith(
      dailyCalories: _calories,
      proteinG: _protein,
      fatG: _fat,
      carbsG: _carbs,
      diets: _diets.where((d) => d != Diet.none).toList(),
      allergies: _allergies.toList(),
      dislikes: _dislikes,
      medicalDiets: _medicalDiets.toList(),
      mealsPerDay: _mealsPerDay,
      latitude: null,
      longitude: null,
    ));
    if (!mounted) return;
    if (widget.embedded) {
      Navigator.of(context).pop(ok);
    } else if (ok) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l.profileSaved)));
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final localeTag = Localizations.localeOf(context).languageCode;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !widget.embedded,
        title: Text(l.profileTitle),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Калораж: слайдер 1200–3500 + числовое поле.
          Text(l.profileCalories, style: theme.textTheme.titleSmall),
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: _calories.clamp(1200, 3500).toDouble(),
                  min: 1200,
                  max: 3500,
                  divisions: 46,
                  label: '$_calories',
                  onChanged: (v) =>
                      setState(() => _calories = v.round()),
                ),
              ),
              SizedBox(
                width: 88,
                child: TextFormField(
                  key: ValueKey('kcal-$_calories'),
                  initialValue: '$_calories',
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  onFieldSubmitted: (v) => setState(() {
                    // UI-11 (аудит 2026-10-28, v0.6.2): диапазон поля
                    // совпадает со слайдером (1200–3500) — раньше поле
                    // принимало 800–6000, и значение за пределами слайдера
                    // молча зажималось отображением (900 выглядел как 1200).
                    _calories =
                        int.tryParse(v)?.clamp(1200, 3500) ?? _calories;
                  }),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          Text(l.profileBju, style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(child: _bjuField(l.profileProtein, _protein, (v) => _protein = v)),
              const SizedBox(width: 8),
              Expanded(child: _bjuField(l.profileFat, _fat, (v) => _fat = v)),
              const SizedBox(width: 8),
              Expanded(child: _bjuField(l.profileCarbs, _carbs, (v) => _carbs = v)),
            ],
          ),
          TextButton.icon(
            onPressed: _recalcBju,
            icon: const Icon(Icons.calculate_outlined, size: 18),
            label: Text(l.profileAutoBju),
          ),
          const SizedBox(height: 8),

          Text(l.profileDiet, style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 0,
            children: [
              for (final d in Diet.values)
                FilterChip(
                  label: Text(dietLabel(l, d)),
                  selected: _diets.contains(d),
                  onSelected: (on) => setState(() {
                    if (d == Diet.none) {
                      // «Без ограничений» сбрасывает остальные.
                      _diets.clear();
                    } else if (on) {
                      _diets.remove(Diet.none);
                      _diets.add(d);
                    } else {
                      _diets.remove(d);
                    }
                  }),
                ),
            ],
          ),
          Text(
            l.profileDietMultipleHint,
            style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant),
          ),

          SectionHeader(l.profileAllergies),
          Wrap(
            spacing: 8,
            runSpacing: 0,
            children: [
              for (final a in Allergen.values)
                FilterChip(
                  label: Text(allergenLabel(l, a)),
                  selected: _allergies.contains(a),
                  onSelected: (on) => setState(() {
                    on ? _allergies.add(a) : _allergies.remove(a);
                  }),
                ),
            ],
          ),

          // Лечебные столы по Певзнеру (v0.5.9): чипы выбора + диалог
          // со справкой «что означает каждый стол».
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: SectionHeader(l.profileMedicalDiets)),
              IconButton(
                tooltip: l.profileMedicalDietsAbout,
                icon: const Icon(Icons.help_outline, size: 20),
                onPressed: _showMedicalDietsInfo,
              ),
            ],
          ),
          Wrap(
            spacing: 8,
            runSpacing: 0,
            children: [
              for (final d in medicalDiets)
                FilterChip(
                  label: Text('№${d.number} · ${d.shortLabel(localeTag)}'),
                  selected: _medicalDiets.contains(d.key),
                  onSelected: (on) => setState(() {
                    on ? _medicalDiets.add(d.key)
                       : _medicalDiets.remove(d.key);
                  }),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            l.profileMedicalDietsHint,
            style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant),
          ),
          // LEG-4 (аудит 2026-10-28): общий дисклеймер в справке профиля —
          // «не заменяет консультацию специалиста / чтение этикетки».
          const SizedBox(height: 8),
          Text(
            l.medicalDisclaimer,
            style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic),
          ),

          SectionHeader(l.profileDislikes),
          Text(
            l.profileDislikesHint,
            style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          _DislikesEditor(
            rules: _dislikes,
            onChanged: (rules) => setState(() => _dislikes = rules),
          ),

          SectionHeader(l.profileMealsPerDay),
          SegmentedButton<int>(
            segments: [
              for (final n in [2, 3, 4, 5, 6])
                ButtonSegment(value: n, label: Text('$n')),
            ],
            selected: {_mealsPerDay.clamp(2, 6)},
            onSelectionChanged: (s) =>
                setState(() => _mealsPerDay = s.first),
          ),

          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.check),
            label: Text(widget.embedded ? l.commonDone : l.commonSave),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _bjuField(
      String label, int value, ValueChanged<int> onChanged) {
    return TextFormField(
      key: ValueKey('$label-$value'),
      initialValue: '$value',
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      onFieldSubmitted: (v) => setState(() {
        onChanged(int.tryParse(v)?.clamp(0, 500) ?? value);
      }),
    );
  }

  /// Справка о столах: полный каталог с показаниями и запретами.
  void _showMedicalDietsInfo() {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final localeTag = Localizations.localeOf(context).languageCode;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.medicalDietsDialogTitle),
        content: SizedBox(
          width: double.maxFinite,
          height: 420,
          child: ListView(
            children: [
              for (final d in medicalDiets)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(d.title(localeTag),
                          style: theme.textTheme.titleSmall),
                      const SizedBox(height: 2),
                      Text(d.indications(localeTag),
                          style: theme.textTheme.bodySmall),
                      const SizedBox(height: 2),
                      Text(
                        '${l.medicalDietsForbiddenLabel} '
                        '${d.forbiddenSummary(localeTag)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l.commonClose),
          ),
        ],
      ),
    );
  }
}

/// Редактор «нелюбимых продуктов» (v0.5.4): выбранные правила с
/// переключением режима («всегда / только основа блюда») и удалением,
/// пресеты для быстрого добавления и поле для своего продукта.
class _DislikesEditor extends StatefulWidget {
  const _DislikesEditor({required this.rules, required this.onChanged});

  final List<DislikeRule> rules;
  final ValueChanged<List<DislikeRule>> onChanged;

  @override
  State<_DislikesEditor> createState() => _DislikesEditorState();
}

class _DislikesEditorState extends State<_DislikesEditor> {
  final _customCtrl = TextEditingController();

  @override
  void dispose() {
    _customCtrl.dispose();
    super.dispose();
  }

  void _apply(List<DislikeRule> rules) => widget.onChanged(rules);

  void _addPreset(DislikePreset preset) {
    if (widget.rules.any((r) => r.key == preset.key)) return;
    _apply([...widget.rules, DislikeRule(key: preset.key)]);
  }

  void _addCustom() {
    final name = _customCtrl.text.trim();
    if (name.isEmpty) return;
    // Дубликат своего пункта не добавляем (по нормализованному имени).
    if (widget.rules.any(
      (r) => IngredientMatcher.normalize(r.key) ==
          IngredientMatcher.normalize(name),
    )) {
      _customCtrl.clear();
      return;
    }
    _apply([...widget.rules, DislikeRule(key: name)]);
    _customCtrl.clear();
    setState(() {});
  }

  /// Подпись правила: пресет → его название, иначе — сам ключ
  /// (пользовательский ввод).
  static String _ruleLabel(DislikeRule rule, String localeTag) {
    for (final p in DislikeEngine.presets) {
      if (p.key == rule.key) return p.label(localeTag);
    }
    return rule.key;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final localeTag = Localizations.localeOf(context).languageCode;
    final unusedPresets = DislikeEngine.presets
        .where((p) => !widget.rules.any((r) => r.key == p.key))
        .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.rules.isEmpty)
          Text(
            l.dislikesEmpty,
            style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant),
          ),
        for (final rule in widget.rules)
          Card(
            margin: const EdgeInsets.symmetric(vertical: 3),
            child: ListTile(
              dense: true,
              title: Text(_ruleLabel(rule, localeTag)),
              subtitle: Text(
                rule.always ? l.dislikeModeAlways : l.dislikeModeMajor,
                style: theme.textTheme.bodySmall,
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Режим: «всегда» ⇄ «основа блюда».
                  IconButton(
                    tooltip: rule.always
                        ? l.dislikeModeMajor
                        : l.dislikeModeAlways,
                    icon: Icon(rule.always
                        ? Icons.block
                        : Icons.restaurant_menu),
                    onPressed: () => _apply([
                      for (final r in widget.rules)
                        if (identical(r, rule))
                          r.copyWith(always: !r.always)
                        else
                          r,
                    ]),
                  ),
                  IconButton(
                    tooltip: l.commonDelete,
                    icon: const Icon(Icons.close),
                    onPressed: () => _apply([
                      for (final r in widget.rules)
                        if (!identical(r, rule)) r,
                    ]),
                  ),
                ],
              ),
            ),
          ),
        if (unusedPresets.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 0,
            children: [
              for (final p in unusedPresets)
                ActionChip(
                  label: Text(p.label(localeTag)),
                  tooltip: l.dislikeModeMajor,
                  onPressed: () => setState(() => _addPreset(p)),
                ),
            ],
          ),
        ],
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _customCtrl,
                decoration: InputDecoration(
                  labelText: l.dislikeAddLabel,
                  isDense: true,
                ),
                onSubmitted: (_) => _addCustom(),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.tonal(
              onPressed: _addCustom,
              child: Text(l.dislikeAdd),
            ),
          ],
        ),
      ],
    );
  }
}

/// Значения по умолчанию для нового профиля (без обращения к PlanController).
class PlanDefaults {
  static UserProfile get profile {
    final now = DateTime.now();
    return UserProfile(createdAt: now, updatedAt: now);
  }
}
