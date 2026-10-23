/// Умный Холодильник & Шеф-Планер — точка входа.
///
/// Offline-first приложение: трекинг сроков годности продуктов и
/// генерация меню на неделю прямо на устройстве. Без аналитики,
/// без серверов, без аккаунтов.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'l10n/generated/app_localizations.dart';
import 'state/settings_controller.dart';
import 'ui/home_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = await SettingsController.load();
  runApp(SmartFridgeApp(settings: settings));
}

class SmartFridgeApp extends StatelessWidget {
  const SmartFridgeApp({super.key, required this.settings});

  final SettingsController settings;

  /// Семенной цвет обеих тем — зелёный «свежести» (#2E7D32).
  static const Color seedColor = Color(0xFF2E7D32);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: settings,
      child: Consumer<SettingsController>(
        builder: (context, s, _) => MaterialApp(
          onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            colorSchemeSeed: seedColor,
            brightness: Brightness.light,
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            colorSchemeSeed: seedColor,
            brightness: Brightness.dark,
            useMaterial3: true,
          ),
          themeMode: s.themeMode,
          locale: s.locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const HomeShell(),
        ),
      ),
    );
  }
}
