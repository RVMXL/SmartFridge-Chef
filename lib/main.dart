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
import 'notifications/reminder_scheduler.dart';
import 'notifications/reminder_sync.dart';
import 'state/plan_controller.dart';
import 'state/product_controller.dart';
import 'state/profile_controller.dart';
import 'state/settings_controller.dart';
import 'ui/home_shell.dart';
import 'ui/onboarding/onboarding_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = await SettingsController.load();

  // AI-слой (Шаг 2): встроенная база рецептов + детерминированный движок.
  final recipeRepository = RecipeRepository();
  final planController = PlanController(
    planner: RuleBasedPlanner(recipeRepository),
    repo: recipeRepository,
    openDb: AppDataStore.instance.database,
  );

  // Шаг 3: локальные пуши о сроках годности.
  final scheduler = LocalReminderScheduler();
  await scheduler.init(
    channelName: 'Сроки годности / Expiry warnings',
    channelDescription: 'Напоминания о продуктах, срок которых истекает',
  );
  final reminderSync = ReminderSyncService(
    scheduler: scheduler,
    settings: settings,
  );

  // Состояние холодильника и профиля.
  final productController = ProductController(
    openDb: AppDataStore.instance.database,
    reminderSync: reminderSync,
    localeTag: () =>
        settings.language == 'system' ? 'ru' : settings.language,
  );
  final profileController = ProfileController(
    openDb: AppDataStore.instance.database,
  );
  await productController.refresh();
  await profileController.load();

  runApp(SmartFridgeApp(
    settings: settings,
    recipeRepository: recipeRepository,
    planController: planController,
    productController: productController,
    profileController: profileController,
    scheduler: scheduler,
  ));
}

class SmartFridgeApp extends StatelessWidget {
  const SmartFridgeApp({
    super.key,
    required this.settings,
    required this.recipeRepository,
    required this.planController,
    required this.productController,
    required this.profileController,
    required this.scheduler,
  });

  final SettingsController settings;
  final RecipeRepository recipeRepository;
  final PlanController planController;
  final ProductController productController;
  final ProfileController profileController;
  final LocalReminderScheduler scheduler;

  /// Семенной цвет обеих тем — зелёный «свежести» (#2E7D32).
  static const Color seedColor = Color(0xFF2E7D32);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settings),
        Provider<RecipeRepository>.value(value: recipeRepository),
        ChangeNotifierProvider.value(value: planController),
        ChangeNotifierProvider.value(value: productController),
        ChangeNotifierProvider.value(value: profileController),
        Provider<ReminderScheduler>.value(value: scheduler),
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
          home: Consumer<ProfileController>(
            builder: (context, profile, _) =>
                profile.needsOnboarding
                    ? const OnboardingScreen()
                    : const HomeShell(),
          ),
        ),
      ),
    );
  }
}
