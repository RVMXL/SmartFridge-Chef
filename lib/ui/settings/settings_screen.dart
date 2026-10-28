/// Экран настроек (Шаг 3): оформление, язык, профиль питания,
/// напоминания о сроках и справка.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants.dart';
import '../../data/models/user_profile.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../notifications/reminder_scheduler.dart';
import '../../scan/kroger_lookup.dart';
import '../../scan/pyaterochka_lookup.dart';
import '../../scan/wegmans_lookup.dart';
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
                    : profile.profile!.diets.isEmpty
                        ? dietLabel(l, Diet.none)
                        : profile.profile!.diets
                            .map((d) => dietLabel(l, d))
                            .join(', '),
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

          // ---------------- Цены магазинов (эксперимент, v0.5.5–v0.5.6)
          SectionHeader(l.priceSectionTitle),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    secondary: const Icon(Icons.sell_outlined),
                    title: Text(l.priceEnable),
                    value: settings.priceLookupEnabled,
                    onChanged: (on) => settings.setPriceLookupEnabled(on),
                  ),
                  if (settings.priceLookupEnabled) ...[
                    DropdownButtonFormField<String>(
                      initialValue: settings.priceSourceKind,
                      decoration:
                          InputDecoration(labelText: l.priceSourceLabel),
                      items: [
                        DropdownMenuItem(
                          value: 'pyaterochka',
                          // LEG-5/LEG-6 (аудит 2026-10-28): честная
                          // маркировка неофициальных источников.
                          child: Text('${l.priceSourcePyat} · ${l.priceSourceUnofficial}'),
                        ),
                        DropdownMenuItem(
                          value: 'kroger',
                          child: Text(l.priceSourceKroger),
                        ),
                        DropdownMenuItem(
                          value: 'open_prices',
                          child: Text(l.priceSourceOpenPrices),
                        ),
                        DropdownMenuItem(
                          value: 'mercadona',
                          // LEG-5/LEG-6 (аудит 2026-10-28): честная
                          // маркировка неофициальных источников.
                          child: Text('${l.priceSourceMercadona} · ${l.priceSourceUnofficial}'),
                        ),
                        DropdownMenuItem(
                          value: 'aldi',
                          // LEG-5/LEG-6 (аудит 2026-10-28): честная
                          // маркировка неофициальных источников.
                          child: Text('${l.priceSourceAldi} · ${l.priceSourceUnofficial}'),
                        ),
                        DropdownMenuItem(
                          value: 'wegmans',
                          child: Text(l.priceSourceWegmans),
                        ),
                      ],
                      onChanged: (kind) {
                        if (kind != null) settings.setPriceSourceKind(kind);
                      },
                    ),
                    if (settings.priceSourceKind == 'pyaterochka')
                      _buildPyaterochkaConfig(context, l, theme, settings),
                    if (settings.priceSourceKind == 'kroger')
                      _buildKrogerConfig(context, l, theme, settings),
                    if (settings.priceSourceKind == 'open_prices')
                      Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 8),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(l.priceOpenPricesNote,
                              style: theme.textTheme.bodySmall?.copyWith(
                                  color:
                                      theme.colorScheme.onSurfaceVariant)),
                        ),
                      ),
                    if (settings.priceSourceKind == 'mercadona')
                      _buildNoteOnly(
                          l.priceMercadonaNote, theme),
                    if (settings.priceSourceKind == 'aldi')
                      _buildNoteOnly(l.priceAldiNote, theme),
                    if (settings.priceSourceKind == 'wegmans')
                      _buildWegmansConfig(context, l, theme, settings),
                  ],
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

  /// Конфиг Пятёрочки: SAP-код магазина + подсказки (без изменений с 0.5.5).
  Widget _buildPyaterochkaConfig(BuildContext context, AppLocalizations l,
      ThemeData theme, SettingsController settings) {
    return Column(
      children: [
        TextFormField(
          initialValue: settings.pyaterochkaStoreCode,
          decoration: InputDecoration(
            labelText: l.pyatStoreCode,
            hintText: '35XY',
          ),
          onChanged: settings.setPyaterochkaStoreCode,
        ),
        // SEC-4 (аудит 2026-10-28): опция сброса анонимного идентификатора
        // — X5 теряет связность истории запросов устройства.
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () async {
              await context.read<PyaterochkaService>().resetDeviceId();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l.resetDeviceIdDone)),
                );
              }
            },
            child: Text(l.resetDeviceId),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(l.pyatStoreHint,
                style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(l.pyatVpnNote,
                style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant)),
          ),
        ),
      ],
    );
  }

  /// Заметка без настроек (Open Prices, Mercadona, Aldi).
  Widget _buildNoteOnly(String note, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(note,
            style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant)),
      ),
    );
  }

  /// Конфиг Wegmans: subscription key пользователя и выбор магазина.
  Widget _buildWegmansConfig(BuildContext context, AppLocalizations l,
      ThemeData theme, SettingsController settings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          initialValue: settings.wegmansKey,
          decoration:
              InputDecoration(labelText: l.wegmansKeyLabel),
          // SEC-3 (аудит 2026-10-28, v0.6.2): ключ — секрет, ввод
          // маскируется (как у Kroger secret).
          obscureText: true,
          onChanged: settings.setWegmansKey,
        ),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: OutlinedButton.icon(
            icon: const Icon(Icons.storefront_outlined),
            label: Text(l.wegmansFindStores),
            onPressed: () => _pickWegmansStore(context),
          ),
        ),
        if (settings.wegmansStoreNumber.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              l.wegmansSelected(
                  settings.wegmansStoreLabel.isEmpty
                      ? settings.wegmansStoreNumber
                      : settings.wegmansStoreLabel),
              style: theme.textTheme.bodySmall,
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(l.wegmansHint,
                style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant)),
          ),
        ),
      ],
    );
  }

  /// Диалог выбора магазина Wegmans по subscription key: FutureBuilder
  /// над Stores API; тап сохраняет номер + человекочитаемый label.
  Future<void> _pickWegmansStore(BuildContext context) async {
    final l = AppLocalizations.of(context);
    final settings = context.read<SettingsController>();
    final wegmans = context.read<WegmansService>();

    if (settings.wegmansKey.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.wegmansNeedCredentials)),
      );
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l.wegmansPickTitle),
        content: SizedBox(
          width: double.maxFinite,
          child: FutureBuilder<List<WegmansStore>>(
            future: wegmans.stores(
              subscriptionKey: settings.wegmansKey,
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError) {
                final reason = snapshot.error is PriceUnavailable
                    ? (snapshot.error as PriceUnavailable).reason
                    : PriceFailReason.network;
                return Text(
                  switch (reason) {
                    PriceFailReason.auth => l.priceAuthError,
                    PriceFailReason.blocked => l.priceUnavailable,
                    PriceFailReason.network => l.priceNoNetwork,
                    // NET-5: неожиданная ошибка — не «нет сети» (v0.6.2).
                    PriceFailReason.unknown => l.priceUnavailable,
                  },
                );
              }
              final stores = snapshot.data ?? const <WegmansStore>[];
              if (stores.isEmpty) {
                return Text(l.wegmansStoresEmpty);
              }
              return ListView.builder(
                shrinkWrap: true,
                itemCount: stores.length,
                itemBuilder: (context, i) {
                  final store = stores[i];
                  return ListTile(
                    dense: true,
                    title: Text(
                        '${store.name} (#${store.storeNumber})'),
                    subtitle: Text(store.shortAddress),
                    onTap: () {
                      settings.setWegmansStore(
                        store.storeNumber,
                        '${store.name} (#${store.storeNumber})'
                        '${store.shortAddress.isEmpty ? '' : ', ${store.shortAddress}'}',
                      );
                      Navigator.of(dialogContext).pop();
                    },
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
        ],
      ),
    );
  }

  /// Конфиг Kroger: ключи пользователя, ZIP и выбор магазина.
  Widget _buildKrogerConfig(BuildContext context, AppLocalizations l,
      ThemeData theme, SettingsController settings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          initialValue: settings.krogerClientId,
          decoration: InputDecoration(labelText: l.krogerClientId),
          onChanged: settings.setKrogerClientId,
        ),
        TextFormField(
          initialValue: settings.krogerClientSecret,
          obscureText: true,
          decoration: InputDecoration(labelText: l.krogerClientSecret),
          onChanged: settings.setKrogerClientSecret,
        ),
        TextFormField(
          initialValue: settings.krogerZip,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: l.krogerZip, hintText: '45202'),
          onChanged: settings.setKrogerZip,
        ),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: OutlinedButton.icon(
            icon: const Icon(Icons.storefront_outlined),
            label: Text(l.krogerFindStores),
            onPressed: () => _pickKrogerLocation(context),
          ),
        ),
        if (settings.krogerLocationId.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              l.krogerSelected(
                  settings.krogerLocationLabel.isEmpty
                      ? settings.krogerLocationId
                      : settings.krogerLocationLabel),
              style: theme.textTheme.bodySmall,
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(l.krogerHint,
                style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant)),
          ),
        ),
      ],
    );
  }

  /// Диалог выбора магазина Kroger по ZIP: FutureBuilder над Locations API;
  /// тап по магазину сохраняет locationId + человекочитаемый label.
  Future<void> _pickKrogerLocation(BuildContext context) async {
    final l = AppLocalizations.of(context);
    final settings = context.read<SettingsController>();
    final kroger = context.read<KrogerService>();

    if (settings.krogerClientId.trim().isEmpty ||
        settings.krogerClientSecret.trim().isEmpty ||
        settings.krogerZip.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.krogerNeedCredentials)),
      );
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l.krogerPickTitle),
        content: SizedBox(
          width: double.maxFinite,
          child: FutureBuilder<List<KrogerLocation>>(
            future: kroger.locations(
              clientId: settings.krogerClientId,
              clientSecret: settings.krogerClientSecret,
              zipCode: settings.krogerZip,
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError) {
                final reason = snapshot.error is PriceUnavailable
                    ? (snapshot.error as PriceUnavailable).reason
                    : PriceFailReason.network;
                return Text(
                  switch (reason) {
                    PriceFailReason.auth => l.priceAuthError,
                    PriceFailReason.blocked => l.priceUnavailable,
                    PriceFailReason.network => l.priceNoNetwork,
                    // NET-5: неожиданная ошибка — не «нет сети» (v0.6.2).
                    PriceFailReason.unknown => l.priceUnavailable,
                  },
                );
              }
              final stores = snapshot.data ?? const <KrogerLocation>[];
              if (stores.isEmpty) {
                return Text(l.krogerStoresEmpty);
              }
              return ListView.builder(
                shrinkWrap: true,
                itemCount: stores.length,
                itemBuilder: (context, i) {
                  final store = stores[i];
                  return ListTile(
                    dense: true,
                    title: Text(store.name),
                    subtitle: Text(
                      '${store.chain.isEmpty ? 'Kroger' : store.chain}'
                      '${store.shortAddress.isEmpty ? '' : ' · ${store.shortAddress}'}',
                    ),
                    onTap: () {
                      settings.setKrogerLocationId(
                        store.locationId,
                        '${store.chain.isEmpty ? 'Kroger' : store.chain}'
                        ' — ${store.name}'
                        '${store.shortAddress.isEmpty ? '' : ', ${store.shortAddress}'}',
                      );
                      Navigator.of(dialogContext).pop();
                    },
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleDay(
      BuildContext context, int day, bool on) async {
    final l = AppLocalizations.of(context);
    final settings = context.read<SettingsController>();
    final products = context.read<ProductController>();
    final days = {...settings.notificationDaysBefore};
    if (on) {
      days.add(day);
    } else {
      days.remove(day);
    }
    if (days.isEmpty) {
      // UI-13 (аудит 2026-10-28, v0.6.2): отказ больше не молчаливый —
      // объясняем, почему последний чип нельзя снять.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.notifLastDayNote)),
      );
      return;
    }
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
