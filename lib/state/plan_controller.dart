/// Контроллер генерации и хранения планов меню (Шаг 2).
///
/// Собирает PlanRequest из холодильника и профиля, вызывает активный
/// MealPlanner (RuleBasedPlanner по умолчанию, LocalLlmPlanner при
/// готовой модели) и ведёт историю сохранённых планов через PlanDao.
/// UI (Шаг 3) подписывается через provider/Consumer.
library;

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart' show Database;

import '../ai/planner.dart';
import '../ai/recipe_repository.dart';
import '../data/dao/plan_dao.dart';
import '../data/dao/product_dao.dart';
import '../data/dao/profile_dao.dart';
import '../data/models/meal_plan.dart';
import '../data/models/user_profile.dart';

/// Жизненный цикл генерации для экрана планера.
enum PlanPhase {
  /// Плана ещё нет, генерация не запускалась.
  idle,

  /// Чтение холодильника/профиля и генерация.
  generating,

  /// План готов (черновик, ещё не сохранён).
  ready,

  /// План готов и сохранён в базу.
  saved,

  /// Ошибка (текст в [PlanController.error]).
  error,
}

class PlanController extends ChangeNotifier {
  PlanController({
    required this._planner,
    required this._repo,
    required this._openDb,
  });

  final MealPlanner _planner;

  /// Репозиторий рецептов — для UI Шага 3 (детали блюда, счётчики).
  final RecipeRepository _repo;
  final Future<Database> Function() _openDb;

  PlanPhase phase = PlanPhase.idle;
  GeneratedPlan? plan;
  List<PlanSummary> history = const [];
  String? error;

  /// Доступ к репозиторию рецептов для UI Шага 3.
  // ignore: unused_element
  RecipeRepository get repository => _repo;

  /// Последний использованный seed (для «перегенерировать»).
  int _lastSeed = 0;

  /// Генерирует план на [days] дней от сегодня.
  ///
  /// [freshSeed] — новая неделя при повторной генерации; тот же seed
  /// возвращает тот же план (детерминизм движка).
  Future<void> generate({
    int? seed,
    int days = 7,
    int maxCookMinutes = 0,
  }) async {
    _lastSeed = seed ?? (_lastSeed + 1);
    phase = PlanPhase.generating;
    error = null;
    notifyListeners();
    try {
      final db = await _openDb();
      final products =
          await ProductDao(db).activeProducts();
      final profile = await ProfileDao(db).getProfile() ?? defaultProfile;
      final request = PlanRequest(
        products: products,
        profile: profile,
        startDate: _dateOnly(DateTime.now()),
        days: days,
        seed: _lastSeed,
        maxCookMinutes: maxCookMinutes,
      );
      plan = await _planner.generate(request);
      phase = PlanPhase.ready;
    } catch (e) {
      error = 'Не удалось сгенерировать меню: $e';
      phase = PlanPhase.error;
    }
    notifyListeners();
  }

  /// Сохраняет текущий черновик плана в базу.
  Future<bool> saveCurrent() async {
    final current = plan;
    if (current == null) return false;
    try {
      final dao = PlanDao(await _openDb());
      await dao.savePlan(current);
      phase = PlanPhase.saved;
      await loadHistory();
      return true;
    } catch (e) {
      error = 'Не удалось сохранить план: $e';
      notifyListeners();
      return false;
    }
  }

  /// История сохранённых планов (новые сверху).
  Future<void> loadHistory() async {
    try {
      final dao = PlanDao(await _openDb());
      history = await dao.listPlans();
      notifyListeners();
    } catch (e) {
      error = 'Не удалось загрузить историю: $e';
      notifyListeners();
    }
  }

  /// Открывает сохранённый план (например, из истории).
  Future<bool> openSaved(String id) async {
    try {
      final dao = PlanDao(await _openDb());
      final loaded = await dao.getPlan(id);
      if (loaded == null) return false;
      plan = loaded;
      phase = PlanPhase.saved;
      notifyListeners();
      return true;
    } catch (e) {
      error = 'Не удалось открыть план: $e';
      notifyListeners();
      return false;
    }
  }

  /// Удаляет сохранённый план.
  Future<bool> deleteSaved(String id) async {
    try {
      final dao = PlanDao(await _openDb());
      await dao.deletePlan(id);
      if (plan?.id == id) {
        plan = null;
        phase = PlanPhase.idle;
      }
      await loadHistory();
      return true;
    } catch (e) {
      error = 'Не удалось удалить план: $e';
      notifyListeners();
      return false;
    }
  }

  /// Отметка «куплено» в списке покупок текущего плана.
  Future<void> setShoppingChecked({
    required String ingKey,
    required bool checked,
  }) async {
    final current = plan;
    if (current == null) return;
    try {
      final dao = PlanDao(await _openDb());
      await dao.setShoppingChecked(
        planId: current.id,
        ingKey: ingKey,
        checked: checked,
      );
      final updated = await dao.getPlan(current.id);
      if (updated != null) {
        plan = updated;
        notifyListeners();
      }
    } catch (e) {
      error = 'Не удалось обновить список покупок: $e';
      notifyListeners();
    }
  }

  /// Дефолтный профиль, если онбординг ещё не проходили.
  /// TODO(Шаг 3): экран онбординга запишет настоящий профиль,
  /// и планер станет персональным.
  static UserProfile get defaultProfile {
    final now = DateTime.now();
    return UserProfile(createdAt: now, updatedAt: now);
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
}
