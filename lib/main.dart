/// Умный Холодильник & Шеф-Планер — точка входа.
///
/// Offline-first приложение: трекинг сроков годности продуктов и
/// генерация меню на неделю прямо на устройстве. Без аналитики,
/// без серверов, без аккаунтов.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'ai/llm_planner.dart';
import 'ai/recipe_repository.dart';
import 'ai/rule_based_planner.dart';
import 'data/data_store.dart';
import 'l10n/generated/app_localizations.dart';
import 'notifications/reminder_scheduler.dart';
import 'notifications/reminder_sync.dart';
import 'scan/aldi_lookup.dart';
import 'scan/barcode_lookup.dart';
import 'scan/kroger_lookup.dart';
import 'scan/mercadona_lookup.dart';
import 'scan/openprices_lookup.dart';
import 'scan/pyaterochka_lookup.dart';
import 'scan/wegmans_lookup.dart';
import 'state/plan_controller.dart';
import 'state/product_controller.dart';
import 'state/profile_controller.dart';
import 'state/settings_controller.dart';
import 'ui/home_shell.dart';
import 'ui/onboarding/onboarding_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // ST-3 (аудит 2026-10-28, v0.6.2): intl-символы локалей для дат в
  // пушах — без этой инициализации DateFormat('d MMM y', 'ru') падал и
  // текст напоминаний всегда уходил в запасной ISO-вид («2026-11-05»).
  await initializeDateFormatting('ru', null);
  final settings = await SettingsController.load();

  // AI-слой (Шаг 2): встроенная база рецептов + детерминированный движок.
  // AI-8 (аудит 2026-10-28, v0.6.2): LocalLlmPlanner — живое звено цепи
  // (прозрачно делегирует движку, пока модель Gemma не подключена на Шаге 3).
  final recipeRepository = RecipeRepository();
  final planController = PlanController(
    planner: LocalLlmPlanner(
      fallback: RuleBasedPlanner(recipeRepository),
    ),
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
    // ST-2 (аудит 2026-10-28): при языке «как в системе» локаль читается
    // из системы, а не захардкожена на русский — EN-система получала
    // интерфейс на английском, а пуши на русском.
    localeTag: () => settings.language != 'system'
        ? settings.language
        : (Platform.localeName.toLowerCase().startsWith('ru')
            ? 'ru'
            : 'en'),
  );
  final profileController = ProfileController(
    openDb: AppDataStore.instance.database,
  );
  await productController.refresh();
  await profileController.load();

  // Автопоиск по штрих-коду: кэш + открытая база Open Food Facts.
  final barcodeLookup = BarcodeLookupService(
    openDb: AppDataStore.instance.database,
  );

  // Источники цен (v0.5.5–v0.5.8, эксперимент): запросы только
  // с устройства; ключи Kroger/Wegmans — свои у каждого пользователя.
  final pyaterochka = PyaterochkaService();
  final kroger = KrogerService();
  final openPrices = OpenPricesService();
  final mercadona = MercadonaService(
    openDb: AppDataStore.instance.database,
  );
  final aldi = AldiService();
  final wegmans = WegmansService();

  runApp(SmartFridgeApp(
    settings: settings,
    recipeRepository: recipeRepository,
    planController: planController,
    productController: productController,
    profileController: profileController,
    scheduler: scheduler,
    barcodeLookup: barcodeLookup,
    pyaterochka: pyaterochka,
    kroger: kroger,
    openPrices: openPrices,
    mercadona: mercadona,
    aldi: aldi,
    wegmans: wegmans,
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
    required this.barcodeLookup,
    required this.pyaterochka,
    required this.kroger,
    required this.openPrices,
    required this.mercadona,
    required this.aldi,
    required this.wegmans,
  });

  final SettingsController settings;
  final RecipeRepository recipeRepository;
  final PlanController planController;
  final ProductController productController;
  final ProfileController profileController;
  final LocalReminderScheduler scheduler;
  final BarcodeLookupService barcodeLookup;
  final PyaterochkaService pyaterochka;
  final KrogerService kroger;
  final OpenPricesService openPrices;
  final MercadonaService mercadona;
  final AldiService aldi;
  final WegmansService wegmans;

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
        Provider<BarcodeLookupService>.value(value: barcodeLookup),
        Provider<PyaterochkaService>.value(value: pyaterochka),
        Provider<KrogerService>.value(value: kroger),
        Provider<OpenPricesService>.value(value: openPrices),
        Provider<MercadonaService>.value(value: mercadona),
        Provider<AldiService>.value(value: aldi),
        Provider<WegmansService>.value(value: wegmans),
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
