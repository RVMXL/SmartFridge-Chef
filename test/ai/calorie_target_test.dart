/// Тесты распределения калоража по слотам (Шаг 2).
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:smart_fridge_chef/ai/calorie_target.dart';
import 'package:smart_fridge_chef/data/models/recipe.dart';

void main() {
  group('splitsForMealsPerDay', () {
    for (var n = 2; n <= 6; n++) {
      test('при $n приёмах доли в сумме дают 1.0', () {
        final splits = splitsForMealsPerDay(n);
        final sum = splits.fold<double>(0, (s, x) => s + x.share);
        expect(sum, closeTo(1.0, 0.0001));
        expect(splits.length, n);
      });
    }

    test('выход за границы прижимается к схемам 2 и 6', () {
      expect(splitsForMealsPerDay(0).length, 2);
      expect(splitsForMealsPerDay(1).length, 2);
      expect(splitsForMealsPerDay(7).length, 6);
      expect(splitsForMealsPerDay(99).length, 6);
    });

    test('3 приёма: завтрак/обед/ужин в правильном порядке', () {
      final splits = splitsForMealsPerDay(3);
      expect(splits.map((s) => s.slot).toList(),
          [MealSlot.breakfast, MealSlot.lunch, MealSlot.dinner]);
      expect(splits.map((s) => s.order).toList(), [0, 1, 2]);
    });

    test('4 приёма: появляется перекус', () {
      final splits = splitsForMealsPerDay(4);
      expect(splits.where((s) => s.slot == MealSlot.snack).length, 1);
    });

    test('5 приёмов: два перекуса; 6 приёмов: три', () {
      expect(
          splitsForMealsPerDay(5)
              .where((s) => s.slot == MealSlot.snack)
              .length,
          2);
      expect(
          splitsForMealsPerDay(6)
              .where((s) => s.slot == MealSlot.snack)
              .length,
          3);
    });
  });

  group('slotTargetKcal', () {
    test('доли калоража соответствуют схеме', () {
      final splits = splitsForMealsPerDay(3);
      final targets =
          splits.map((s) => slotTargetKcal(2000, s)).toList();
      expect(targets[0], 600); // завтрак 30%
      expect(targets[1], 800); // обед 40%
      expect(targets[2], 600); // ужин 30%
    });

    test('минимум 120 ккал: крошечный перекус не обнуляется', () {
      final tiny = splitsForMealsPerDay(6)
          .where((s) => s.slot == MealSlot.snack)
          .first;
      expect(slotTargetKcal(1200, tiny), greaterThanOrEqualTo(120));
    });

    test('цель не превышает дневной калораж', () {
      final split = splitsForMealsPerDay(2).first;
      expect(slotTargetKcal(1000, split), lessThanOrEqualTo(1000));
    });
  });

  group('карты категорий слотов', () {
    test('каждый слот имеет допустимые категории', () {
      for (final slot in MealSlot.values) {
        expect(slotCategories[slot], isNotEmpty,
            reason: 'нет категорий для ${slot.key}');
        expect(preferredCategories[slot], isNotEmpty);
        // Приоритетные категории — подмножество допустимых.
        for (final c in preferredCategories[slot]!) {
          expect(slotCategories[slot], contains(c));
        }
      }
    });

    test('завтрак — только завтраки, перекус — перекусы/десерты', () {
      expect(slotCategories[MealSlot.breakfast], ['breakfast']);
      expect(
          slotCategories[MealSlot.snack], containsAll(['snack', 'dessert']));
    });
  });
}
