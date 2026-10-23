/// Экран профиля питания (Шаг 3): калораж, БЖУ, диета, аллергены,
/// количество приёмов пищи и регион (сезонность).
///
/// Используется и из настроек, и из онбординга (режим без AppBar-возврата
/// — тогда кнопка «Сохранить» закрывает онбординг).
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
  late Diet _diet;
  late Set<Allergen> _allergies;
  late int _mealsPerDay;
  late final TextEditingController _region;

  @override
  void initState() {
    super.initState();
    final p = widget.initial ?? PlanDefaults.profile;
    _calories = p.dailyCalories;
    _protein = p.proteinG;
    _fat = p.fatG;
    _carbs = p.carbsG;
    _diet = p.diet;
    _allergies = {...p.allergies};
    _mealsPerDay = p.mealsPerDay;
    _region = TextEditingController(text: p.regionName ?? '');
  }

  @override
  void dispose() {
    _region.dispose();
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
      diet: _diet,
      allergies: _allergies.toList(),
      mealsPerDay: _mealsPerDay,
      regionName: _region.text.trim().isEmpty ? null : _region.text.trim(),
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
                    _calories =
                        int.tryParse(v)?.clamp(800, 6000) ?? _calories;
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
            children: [
              for (final d in Diet.values)
                ChoiceChip(
                  label: Text(dietLabel(l, d)),
                  selected: _diet == d,
                  onSelected: (_) => setState(() => _diet = d),
                ),
            ],
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

          SectionHeader(l.profileRegion),
          TextField(
            controller: _region,
            decoration: InputDecoration(
              hintText: l.profileRegionHint,
              border: const OutlineInputBorder(),
            ),
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
}

/// Значения по умолчанию для нового профиля (без обращения к PlanController).
class PlanDefaults {
  static UserProfile get profile {
    final now = DateTime.now();
    return UserProfile(createdAt: now, updatedAt: now);
  }
}
