/// Контроллер профиля питания (Шаг 3): онбординг и экран настроек.
///
/// Профиль один (id = 1) и живёт в SQLite; здесь только загрузка,
/// сохранение и флаг онбординга. Суперпланер читает профиль напрямую
/// из базы при генерации — через этого контроллера обновлять ничего
/// не нужно.
library;

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart' show Database;

import '../data/dao/profile_dao.dart';
import '../data/models/user_profile.dart';

class ProfileController extends ChangeNotifier {
  ProfileController({required this._openDb});

  final Future<Database> Function() _openDb;

  UserProfile? profile;
  bool loading = false;
  String? error;

  /// Онбординг ещё не проходили (профиля нет или не помечен).
  bool get needsOnboarding => profile == null || !profile!.onboarded;

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      profile = await ProfileDao(await _openDb()).getProfile();
    } catch (e) {
      error = e.toString();
    }
    loading = false;
    notifyListeners();
  }

  /// Сохраняет профиль (создание или обновление, updatedAt = сейчас).
  Future<bool> save(UserProfile updated) async {
    try {
      final dao = ProfileDao(await _openDb());
      final now = DateTime.now();
      final existing = profile;
      await dao.save(updated.copyWith(
        updatedAt: now,
        createdAt: existing?.createdAt ?? now,
      ));
      profile = updated.copyWith(
        updatedAt: now,
        createdAt: existing?.createdAt ?? now,
      );
      notifyListeners();
      return true;
    } catch (e) {
      error = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Завершает онбординг, сохраняя профиль с флагом onboarded.
  Future<bool> completeOnboarding(UserProfile base) async {
    final ok = await save(base.copyWith(onboarded: true));
    return ok;
  }
}
