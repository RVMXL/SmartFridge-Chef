/// Экран настроек (Шаг 3): оформление, язык, профиль питания,
/// напоминания о сроках и справка.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../notifications/reminder_scheduler.dart';
import '../../state/profile_controller.dart';
import '../../state/product_controller.dart';
import '../../state/settings_controller.dart';
import '../widgets/common.dart';
import 'profile_edit_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final settings = context.watch<SettingsController>();
    final profile = context.watch<ProfileController>();
    final products = context.watch<ProductController>();
    // Контроллеры для асинхронных колбэков — захватываем заранее.
    final scheduler = context.read<ReminderScheduler>();

    return Scaffold(
      appBar: AppBar(title: Text(l.settingsTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ---------------- Профиль питания
          SectionHeader(l.settingsProfile),
          Card(
            child: ListTile(
              leading: const Icon(Icons.person_outline),
              title: Text(
                profile.profile == null
                    ? l.profileNone
                    : '${profile.profile!.dailyCalories} '
                        '${Localizations.localeOf(context).languageCode.startsWith('ru') ? 'ккал/день' : 'kcal/day'}',
              ),
              subtitle: Text(
                profile.profile == null
                    ? l.onbStart
                    : dietLabel(l, profile.profile!.diet),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                await Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) =>
                      ProfileEditScreen(initial: profile.profile),
                ));
                // Профиль мог измениться — напоминалки не зависят,
                // но меню пересоберётся при следующей генерации.
              },
            ),
          ),

          // ---------------- Напоминания о сроках
          SectionHeader(l.settingsNotifications),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    secondary: const Icon(Icons.notifications_outlined),
                    title: Text(l.notifEnable),
                    value: settings.notificationsEnabled,
                    onChanged: (on) async {
                      await settings.setNotificationsEnabled(on);
                      if (on) {
                        await scheduler.requestPermissions();
                      }
                      // Полная пересинхронизация: вкл/выкл меняет всё.
                      await products.refresh();
                    },
                  ),
                  if (settings.notificationsEnabled) ...[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(l.notifDays,
                            style: theme.textTheme.bodyMedium),
                      ),
                    ),
                    Wrap(
                      spacing: 8,
                      children: [
                        FilterChip(
                          label: Text(l.notifDaysOpt2),
                          selected: settings.notificationDaysBefore
                              .contains(2),
                          onSelected: (on) => _toggleDay(context, 2, on),
                        ),
                        FilterChip(
                          label: Text(l.notifDaysOpt1),
                          selected: settings.notificationDaysBefore
                              .contains(1),
                          onSelected: (on) => _toggleDay(context, 1, on),
                        ),
                      ],
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.schedule),
                      title: Text(l.notifHour),
                      subtitle: Text(
                          l.notifHourAt(settings.notificationHour)),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _pickHour(context),
                    ),
                  ],
                  Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        l.notifPermissionHint,
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ---------------- Оформление
          SectionHeader(l.settingsAppearance),
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
            onSelectionChanged: (s) => settings.setThemeMode(s.first),
          ),
          const SizedBox(height: 16),
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
            onSelectionChanged: (s) => settings.setLanguage(s.first),
          ),

          // ---------------- О приложении
          SectionHeader(l.settingsAbout),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.stageCurrent, style: theme.textTheme.bodyMedium),
                  const Divider(height: 24),
                  Text(
                    '${l.settingsVersion}: $kAppVersion',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l.settingsOffline,
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleDay(
      BuildContext context, int day, bool on) async {
    final settings = context.read<SettingsController>();
    final products = context.read<ProductController>();
    final days = {...settings.notificationDaysBefore};
    if (on) {
      days.add(day);
    } else {
      days.remove(day);
    }
    if (days.isEmpty) return; // должен остаться хотя бы один вариант
    await settings.setNotificationDaysBefore(days.toList());
    await products.refresh();
  }

  Future<void> _pickHour(BuildContext context) async {
    final l = AppLocalizations.of(context);
    final settings = context.read<SettingsController>();
    final products = context.read<ProductController>();
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: settings.notificationHour, minute: 0),
      helpText: l.notifHour,
    );
    if (picked == null) return;
    await settings.setNotificationHour(picked.hour);
    await products.refresh();
  }
}
