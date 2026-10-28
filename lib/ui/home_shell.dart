/// Оболочка приложения: нижняя навигация «Холодильник / Меню / Настройки».
///
/// Шаг 3: все три вкладки — рабочие экраны (холодильник со сканером,
/// Суперпланер, настройки профиля и напоминаний).
library;

import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import 'fridge/fridge_screen.dart';
import 'menu/menu_screen.dart';
import 'settings/settings_screen.dart';

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
      // UI-3 (аудит 2026-10-28): IndexedStack вместо switch — вкладки не
      // пересоздаются при переключении: сохраняются скролл, режим поиска и
      // состояние виджетов; не дёргаются FridgeScreen.initState→refresh()
      // (БД + полный resync пушей) и MenuScreen→loadHistory() на каждый вход.
      body: IndexedStack(
        index: _tab,
        children: const [
          FridgeScreen(),
          MenuScreen(),
          SettingsScreen(),
        ],
      ),
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
