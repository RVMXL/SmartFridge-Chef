/// Умный Холодильник & Шеф-Планер — точка входа.
///
/// Offline-first приложение: трекинг сроков годности продуктов и
/// генерация меню на неделю прямо на устройстве. Без аналитики,
/// без серверов, без аккаунтов.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'ai/recipe_repository.dart';
import 'ai/rule_based_planner.dart';
import 'data/data_store.dart';
import 'l10n/generated/app_localizations.dart';
import 'state/plan_controller.dart';
import 'state/settings_controller.dart';
import 'ui/home_shell.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = await SettingsController.load();

  // AI-слой (Шаг 2): встроенная база рецептов + детерминированный движок.
  // Шаг 3 подключит экран планера через Consumer<PlanController>.
  final recipeRepository = RecipeRepository();
  final planController = PlanController(
    planner: RuleBasedPlanner(recipeRepository),
    repo: recipeRepository,
    openDb: AppDataStore.instance.database,
  );

  runApp(SmartFridgeApp(
    settings: settings,
    recipeRepository: recipeRepository,
    planController: planController,
  ));
}

class SmartFridgeApp extends StatelessWidget {
  const SmartFridgeApp({
    super.key,
    required this.settings,
    required this.recipeRepository,
    required this.planController,
  });

  final SettingsController settings;
  final RecipeRepository recipeRepository;
  final PlanController planController;

  /// Семенной цвет обеих тем — зелёный «свежести» (#2E7D32).
  static const Color seedColor = Color(0xFF2E7D32);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settings),
        Provider<RecipeRepository>.value(value: recipeRepository),
        ChangeNotifierProvider.value(value: planController),
      ],
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
