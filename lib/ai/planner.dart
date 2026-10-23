/// Контракт AI-слоя: запрос на генерацию и интерфейс провайдера (Шаг 2).
///
/// Провайдеры (реализуют [MealPlanner]):
///  - RuleBasedPlanner — детерминированный движок по встроенной базе,
///    работает всегда, офлайн, миллисекунды (по умолчанию и фолбэк);
///  - LocalLlmPlanner — обёртка над on-device LLM (Gemma через MediaPipe),
///    при недоступности модели прозрачно делегирует RuleBasedPlanner.
///
/// Точка расширения (Шаг 3+, без изменения контракта):
///  - PlatformAiPlanner — Android AICore / Apple Foundation Models;
///  - RemoteRecipeSource — открытые API рецептов (TheMealDB) как
///    дополнительный источник базы.
library;

import '../data/models/product.dart';
import '../data/models/user_profile.dart';
import '../data/models/meal_plan.dart';

/// Запрос на генерацию плана меню.
class PlanRequest {
  const PlanRequest({
    required this.products,
    required this.profile,
    required this.startDate,
    this.days = 7,
    this.seed = 0,
    this.maxCookMinutes = 0,
  });

  /// Активные продукты холодильника (со сроками).
  final List<Product> products;

  /// Профиль питания (калораж, БЖУ, диета, аллергии, приёмы пищи).
  final UserProfile profile;

  /// Первый день плана (только дата).
  final DateTime startDate;

  /// Горизонт планирования (по умолчанию неделя — 7 дней).
  final int days;

  /// Зерно детерминизма: тот же seed + те же данные = тот же план.
  final int seed;

  /// Максимальное время готовки, минут; 0 — без ограничения.
  final int maxCookMinutes;

  PlanRequest copyWith({int? seed}) => PlanRequest(
        products: products,
        profile: profile,
        startDate: startDate,
        days: days,
        seed: seed ?? this.seed,
        maxCookMinutes: maxCookMinutes,
      );

  @override
  String toString() => 'PlanRequest(${products.length} продуктов, '
      '${profile.dailyCalories} ккал/день, $days дн., seed=$seed)';
}

/// Интерфейс провайдера генерации меню.
abstract interface class MealPlanner {
  /// Стабильный идентификатор провайдера (пишется в meal_plans.source).
  String get id;

  /// Человекочитаемое название (для настроек, Шаг 3).
  String get label;

  Future<GeneratedPlan> generate(PlanRequest request);
}
