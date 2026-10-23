/// Провайдер локальной LLM (Шаг 2 — каркас, подключение модели — Шаг 3).
///
/// Идея архитектуры: модель отвечает ТОЛЬКО за тексты и вариативность,
/// а валидность плана гарантирует слой контракта. Ответ LLM должен
/// соответствовать тому же JSON-контракту, что и RuleBasedPlanner;
/// невалидный ответ → автоматическая пересборка фолбэком.
///
/// План подключения (Шаг 3, документация docs/ARCHITECTURE.md):
///  1. Пакет flutter_gemma (MediaPipe LLM Inference, Gemma 2B/3n IT).
///  2. Файл модели ~1.5 ГБ пользователь скачивает один раз в настройках,
///     хранится в приватной папке приложения (allowBackup=false).
///  3. Промпт собирается из [PlanRequest] (продукты, профиль, слоты),
///     ответ валидируется контрактом; брак — фолбэк на RuleBasedPlanner.
///  4. Устройства без поддержки нейроускорения остаются на движке
///     рецептов — приложение ни при каких условиях не деградирует.
library;

import '../data/models/meal_plan.dart' show GeneratedPlan;
import 'planner.dart';

/// Состояние локальной модели на устройстве.
enum LlmStatus {
  /// Модель не скачана (стартовое состояние; движок рецептов активен).
  notInstalled,

  /// Модель скачивается (Шаг 3: прогресс в настройках).
  downloading,

  /// Модель готова — провайдер может генерировать.
  ready,

  /// Ошибка загрузки/инициализации; работает фолбэк.
  error,
}

class LocalLlmPlanner implements MealPlanner {
  /// Фолбэк-провайдер — обязательно RuleBasedPlanner или эквивалент.
  LocalLlmPlanner({required this._fallback});

  final MealPlanner _fallback;

  LlmStatus status = LlmStatus.notInstalled;

  /// Имя файла модели в приватной папке (Шаг 3).
  String? modelName;

  @override
  String get id => 'local_llm';

  @override
  String get label => 'Локальная нейросеть (Gemma, опционально)';

  /// True, если генерация уйдёт в LLM, а не в фолбэк.
  bool get isActive => status == LlmStatus.ready;

  @override
  Future<GeneratedPlan> generate(PlanRequest request) async {
    // Шаг 3: собрать промпт -> сгенерировать -> валидировать контрактом.
    // Пока модель не подключена, провайдер прозрачен: план собирает
    // детерминированный движок рецептов.
    return _fallback.generate(request);
  }
}

/// Точка расширения под системные нейронки (Android AICore,
/// Apple Foundation Models). Сознательно пустой интерфейс-заготовка:
/// зрелых Flutter-биндингов пока нет, но контракт [MealPlanner] уже
/// позволяет подключить такой провайдер без изменения остальных слоёв.
abstract interface class PlatformAiPlanner implements MealPlanner {
  /// Поддерживает ли текущее устройство системный AI (Шаг 3+).
  bool get isSupported;
}
