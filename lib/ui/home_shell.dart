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
      body: switch (_tab) {
        0 => const FridgeScreen(),
        1 => const MenuScreen(),
        _ => const SettingsScreen(),
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
