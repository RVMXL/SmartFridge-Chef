/// Онбординг (Шаг 3, ТЗ: «Пользователь один раз настраивает свои параметры»).
///
/// 5 экранов PageView: приветствие → калораж → диета/аллергии →
/// нелюбимые продукты (v0.5.4) → приёмы пищи и напоминания. На финале
/// сохраняется профиль (onboarded = 1) и запрашиваются права на пуши.
/// «Пропустить» — сохраняет профиль по умолчанию; донастроить можно
/// в «Настройках».
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../ai/dislikes.dart';
import '../../data/models/user_profile.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../notifications/reminder_scheduler.dart';
import '../../state/profile_controller.dart';
import '../settings/profile_edit_screen.dart';
import '../widgets/common.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  // Черновик профиля, собирается по шагам.
  int _calories = 2000;
  final Set<Diet> _diets = {};
  final Set<Allergen> _allergies = {};
  final Set<String> _dislikes = {};
  int _mealsPerDay = 3;
  bool _wantNotifications = true;

  static const _pages = 5;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    if (_page < _pages - 1) {
      await _controller.nextPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
      return;
    }
    await _finish(wantNotifications: _wantNotifications);
  }

  /// Финал (кнопка или «Пропустить»): сохранить профиль и (по желанию)
  /// запросить права на пуши.
  Future<void> _finish({required bool wantNotifications}) async {
    final l = AppLocalizations.of(context);
    final profileCtrl = context.read<ProfileController>();
    final base = PlanDefaults.profile;
    final ok = await profileCtrl.completeOnboarding(base.copyWith(
      dailyCalories: _calories,
      diets: _diets.where((d) => d != Diet.none).toList(),
      allergies: _allergies.toList(),
      // В онбординге — быстрый выбор: все нелюбимые в мягком режиме
      // «только если основа блюда»; тонкая настройка — в профиле.
      dislikes: _dislikes
          .map((key) => DislikeRule(key: key, always: false))
          .toList(),
      mealsPerDay: _mealsPerDay,
    ));
    if (ok && wantNotifications && mounted) {
      try {
        await context.read<ReminderScheduler>().requestPermissions();
      } catch (_) {
        // Права не выданы — напоминания донастроятся в «Настройках».
      }
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? l.onbFinish : l.commonError),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (i) => setState(() => _page = i),
                children: [
                  _Welcome(),
                  _Step(
                    title: l.onbStep1Title,
                    onNext: _next,
                    child: _CaloriesStep(
                      calories: _calories,
                      mealsPerDay: _mealsPerDay,
                      onCalories: (v) => setState(() => _calories = v),
                      onMeals: (v) => setState(() => _mealsPerDay = v),
                    ),
                  ),
                  _Step(
                    title: l.onbStep2Title,
                    subtitle: l.onbStep2Body,
                    footnote: l.medicalDisclaimer,
                    onNext: _next,
                    child: _DietStep(
                      diets: _diets,
                      allergies: _allergies,
                      onDiet: (d, on) => setState(() {
                        if (d == Diet.none) {
                          _diets.clear();
                        } else if (on) {
                          _diets.remove(Diet.none);
                          _diets.add(d);
                        } else {
                          _diets.remove(d);
                        }
                      }),
                      onAllergen: (a, on) => setState(() {
                        on ? _allergies.add(a) : _allergies.remove(a);
                      }),
                    ),
                  ),
                  _Step(
                    title: l.onbDislikesTitle,
                    subtitle: l.onbDislikesBody,
                    onNext: _next,
                    child: _DislikesStep(
                      selected: _dislikes,
                      onToggle: (key) => setState(() {
                        _dislikes.contains(key)
                            ? _dislikes.remove(key)
                            : _dislikes.add(key);
                      }),
                    ),
                  ),
                  _Step(
                    title: l.onbStep3Title,
                    subtitle: l.onbStep3Body,
                    onNext: _next,
                    child: _NotifyStep(
                      enabled: _wantNotifications,
                      onEnabled: (v) =>
                          setState(() => _wantNotifications = v),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: _next,
                      child: Text(
                        _page == 0
                            ? l.onbStart
                            : (_page == _pages - 1
                                ? l.onbFinish
                                : l.onbNext),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () => _finish(wantNotifications: false),
              child: Text(
                l.onbSkip,
                style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class _Welcome extends StatelessWidget {
  const _Welcome();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.kitchen, size: 96),
          const SizedBox(height: 24),
          Text(
            l.onbWelcomeTitle,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          Text(
            l.onbWelcomeBody,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// Каркас шага с заголовком и контентом (кнопка «Дальше» одна внизу экрана).
class _Step extends StatelessWidget {
  const _Step({
    required this.title,
    required this.child,
    required this.onNext,
    this.subtitle,
    this.footnote,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final VoidCallback onNext;

  /// LEG-4 (аудит 2026-10-28): общий дисклеймер — «не заменяет
  /// консультацию специалиста / чтение этикетки». Обязателен на шаге
  /// аллергий/диет/столов.
  final String? footnote;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: theme.textTheme.headlineSmall),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(
              subtitle!,
              style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
          const SizedBox(height: 24),
          child,
          if (footnote != null) ...[
            const SizedBox(height: 24),
            Text(
              footnote!,
              style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}

class _CaloriesStep extends StatelessWidget {
  const _CaloriesStep({
    required this.calories,
    required this.mealsPerDay,
    required this.onCalories,
    required this.onMeals,
  });

  final int calories;
  final int mealsPerDay;
  final ValueChanged<int> onCalories;
  final ValueChanged<int> onMeals;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('$calories',
            style: theme.textTheme.displaySmall
                ?.copyWith(color: theme.colorScheme.primary)),
        Slider(
          value: calories.clamp(1200, 3500).toDouble(),
          min: 1200,
          max: 3500,
          divisions: 46,
          label: '$calories',
          onChanged: (v) => onCalories(v.round()),
        ),
        Text(l.profileCalories,
            style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 24),
        Text(l.profileMealsPerDay, style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        SegmentedButton<int>(
          segments: [
            for (final n in [2, 3, 4, 5, 6]) ButtonSegment(value: n, label: Text('$n')),
          ],
          selected: {mealsPerDay.clamp(2, 6)},
          onSelectionChanged: (s) => onMeals(s.first),
        ),
      ],
    );
  }
}

class _DietStep extends StatelessWidget {
  const _DietStep({
    required this.diets,
    required this.allergies,
    required this.onDiet,
    required this.onAllergen,
  });

  final Set<Diet> diets;
  final Set<Allergen> allergies;
  final void Function(Diet, bool) onDiet;
  final void Function(Allergen, bool) onAllergen;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 0,
          children: [
            for (final d in Diet.values)
              FilterChip(
                label: Text(dietLabel(l, d)),
                selected: diets.contains(d),
                onSelected: (on) => onDiet(d, on),
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
                selected: allergies.contains(a),
                onSelected: (on) => onAllergen(a, on),
              ),
          ],
        ),
      ],
    );
  }
}

class _NotifyStep extends StatelessWidget {
  const _NotifyStep({required this.enabled, required this.onEnabled});

  final bool enabled;
  final ValueChanged<bool> onEnabled;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Card(
      child: SwitchListTile(
        secondary: const Icon(Icons.notifications_active_outlined),
        title: Text(l.notifEnable),
        subtitle: Text(l.onbStep3Body),
        value: enabled,
        onChanged: onEnabled,
      ),
    );
  }
}

/// Шаг «Что вы не любите?» (v0.5.4): пресеты нелюбимых продуктов.
/// Режим на этом шаге не спрашиваем — по умолчанию «только если основа
/// блюда», меняется в настройках профиля.
class _DislikesStep extends StatelessWidget {
  const _DislikesStep({required this.selected, required this.onToggle});

  final Set<String> selected;
  final void Function(String) onToggle;

  @override
  Widget build(BuildContext context) {
    final localeTag = Localizations.localeOf(context).languageCode;
    return Wrap(
      spacing: 8,
      runSpacing: 0,
      children: [
        for (final preset in DislikeEngine.presets)
          FilterChip(
            label: Text(preset.label(localeTag)),
            selected: selected.contains(preset.key),
            onSelected: (_) => onToggle(preset.key),
          ),
      ],
    );
  }
}
