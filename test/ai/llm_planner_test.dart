/// Тесты LocalLlmPlanner (AI-8, v0.6.2): каркас — живое звено цепи
/// планировщика, прозрачно делегирует фолбэку, пока модель не готова.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:smart_fridge_chef/ai/llm_planner.dart';
import 'package:smart_fridge_chef/ai/planner.dart';
import 'package:smart_fridge_chef/data/models/meal_plan.dart';

class _FakePlanner implements MealPlanner {
  int calls = 0;

  @override
  String get id => 'fake';

  @override
  String get label => 'Фейковый';

  @override
  Future<GeneratedPlan> generate(PlanRequest request) async {
    calls++;
    throw UnimplementedError('generate not expected in this test');
  }
}

void main() {
  test('AI-8: LocalLlmPlanner в цепочке — статус и метки', () {
    final fallback = _FakePlanner();
    final planner = LocalLlmPlanner(fallback: fallback);

    expect(planner.id, 'local_llm');
    expect(planner.label, isNotEmpty);
    expect(planner.status, LlmStatus.notInstalled);
    expect(planner.isActive, isFalse);
  });

  test('AI-8: isActive включается только при готовой модели', () {
    final planner = LocalLlmPlanner(fallback: _FakePlanner());

    planner.status = LlmStatus.downloading;
    expect(planner.isActive, isFalse);

    planner.status = LlmStatus.ready;
    expect(planner.isActive, isTrue);

    planner.status = LlmStatus.error;
    expect(planner.isActive, isFalse);
  });
}
