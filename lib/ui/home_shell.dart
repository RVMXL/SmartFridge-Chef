/// Оболочка приложения: нижняя навигация «Холодильник / Меню / Настройки».
///
/// На Шаге 1 экраны холодильника и планера — честные заглушки с реальной
/// статистикой из локальной базы; их наполнение — Шаги 2–3 по подтверждению.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants.dart';
import '../data/dao/product_dao.dart';
import '../data/data_store.dart';
import '../l10n/generated/app_localizations.dart';
import '../state/settings_controller.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      body: switch (_tab) {
        0 => const _FridgeTab(),
        1 => const _PlannerTab(),
        _ => const _SettingsTab(),
      },
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.kitchen_outlined),
            selectedIcon: const Icon(Icons.kitchen),
            label: l.tabFridge,
          ),
          NavigationDestination(
            icon: const Icon(Icons.restaurant_menu_outlined),
            selectedIcon: const Icon(Icons.restaurant_menu),
            label: l.tabPlanner,
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings),
            label: l.tabSettings,
          ),
        ],
      ),
    );
  }
}

/// Холодильник: статистика живёт в SQLite, экран появится на Шаге 3.
class _FridgeTab extends StatefulWidget {
  const _FridgeTab();

  @override
  State<_FridgeTab> createState() => _FridgeTabState();
}

class _FridgeTabState extends State<_FridgeTab> {
  late Future<FridgeStats> _stats = _load();

  Future<FridgeStats> _load() async {
    final dao = await AppDataStore.instance.productDao();
    return dao.stats();
  }

  void _retry() => setState(() => _stats = _load());

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.fridgeTitle)),
      body: FutureBuilder<FridgeStats>(
        future: _stats,
        builder: (context, snap) {
          if (snap.hasError) {
            return _CenterHint(
              icon: Icons.error_outline,
              title: l.dbOpenError,
              body: '${snap.error}',
              action: TextButton(onPressed: _retry, child: Text(l.retry)),
            );
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final stats = snap.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                l.fridgePlaceholderTitle,
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                l.fridgePlaceholderBody,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              if (stats.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Icon(Icons.shopping_basket_outlined),
                        const SizedBox(width: 12),
                        Expanded(child: Text(l.fridgeEmpty)),
                      ],
                    ),
                  ),
                )
              else ...[
                _StatCard(
                  icon: Icons.kitchen,
                  color: theme.colorScheme.primary,
                  label: l.statActive,
                  value: stats.activeCount,
                ),
                _StatCard(
                  icon: Icons.schedule,
                  color: theme.colorScheme.tertiary,
                  label: l.statExpiring(kExpiringSoonDays),
                  value: stats.expiringCount,
                ),
                _StatCard(
                  icon: Icons.warning_amber_rounded,
                  color: theme.colorScheme.error,
                  label: l.statExpired,
                  value: stats.expiredCount,
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color color;
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 12),
            Expanded(child: Text(label)),
            Text(
              '$value',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(color: color, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

/// Планер меню: заглушка до подтверждения Шага 1.
class _PlannerTab extends StatelessWidget {
  const _PlannerTab();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.plannerTitle)),
      body: _CenterHint(
        icon: Icons.restaurant_menu_outlined,
        title: l.plannerPlaceholderTitle,
        body: l.plannerPlaceholderBody,
      ),
    );
  }
}

/// Настройки: тема, язык и служебная информация.
class _SettingsTab extends StatelessWidget {
  const _SettingsTab();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final settings = context.watch<SettingsController>();
    return Scaffold(
      appBar: AppBar(title: Text(l.settingsTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(l.settingsAppearance,
              style: theme.textTheme.titleSmall
                  ?.copyWith(color: theme.colorScheme.primary)),
          const SizedBox(height: 8),
          SegmentedButton<ThemeMode>(
            segments: [
              ButtonSegment(
                  value: ThemeMode.system,
                  icon: const Icon(Icons.brightness_auto_outlined),
                  label: Text(l.themeSystem)),
              ButtonSegment(
                  value: ThemeMode.light,
                  icon: const Icon(Icons.light_mode_outlined),
                  label: Text(l.themeLight)),
              ButtonSegment(
                  value: ThemeMode.dark,
                  icon: const Icon(Icons.dark_mode_outlined),
                  label: Text(l.themeDark)),
            ],
            selected: {settings.themeMode},
            onSelectionChanged: (s) =>
                settings.setThemeMode(s.first),
          ),
          const SizedBox(height: 24),
          Text(l.settingsLanguage,
              style: theme.textTheme.titleSmall
                  ?.copyWith(color: theme.colorScheme.primary)),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: [
              ButtonSegment(value: 'system', label: Text(l.langSystem)),
              ButtonSegment(value: 'ru', label: Text(l.langRussian)),
              ButtonSegment(value: 'en', label: Text(l.langEnglish)),
            ],
            selected: {settings.language},
            onSelectionChanged: (s) =>
                settings.setLanguage(s.first),
          ),
          const SizedBox(height: 24),
          Text(l.settingsAbout,
              style: theme.textTheme.titleSmall
                  ?.copyWith(color: theme.colorScheme.primary)),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                          child: Text(l.settingsStage,
                              style: theme.textTheme.bodyMedium)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(l.stageCurrent,
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant)),
                  const Divider(height: 24),
                  Text(
                    '${l.settingsVersion}: $kAppVersion',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l.settingsOffline,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CenterHint extends StatelessWidget {
  const _CenterHint({
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
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              body,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant),
            ),
            if (action != null) ...[const SizedBox(height: 8), action!],
          ],
        ),
      ),
    );
  }
}
