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

  group('составные приёмы (v0.6.9)', () {
    test('шаблоны состава есть только у обеда и ужина', () {
      expect(composedCourses.keys.toSet(),
          {MealSlot.lunch, MealSlot.dinner});
      // Завтрак и перекус собираются из одного блюда с добором порций.
      expect(composedCourses.containsKey(MealSlot.breakfast), isFalse);
      expect(composedCourses.containsKey(MealSlot.snack), isFalse);
    });

    test('в каждом шаблоне ровно один обязательный курс — «второе»', () {
      for (final entry in composedCourses.entries) {
        final closing =
            entry.value.where((c) => !c.optional).toList();
        expect(closing.length, 1,
            reason: 'слот ${entry.key.key}: состав не может быть без «второго»');
        expect(closing.single.categories, containsAll(['main', 'side']));
      }
    });

    test('доли курсов укладываются в цель слота', () {
      // Валидные категории базы (Recipe.category).
      const recipeCategories = {
        'breakfast', 'soup', 'main', 'salad', 'side', 'snack', 'dessert',
      };
      for (final entry in composedCourses.entries) {
        final sum =
            entry.value.fold<double>(0, (s, c) => s + c.share);
        expect(sum, lessThanOrEqualTo(1.0001),
            reason: 'слот ${entry.key.key}: $sum');
        for (final c in entry.value) {
          expect(c.share, greaterThan(0));
          expect(c.share, lessThan(1));
          for (final cat in c.categories) {
            expect(recipeCategories, contains(cat),
                reason: '${entry.key.key}: курс $cat');
          }
        }
        // Категории обязательного «второго» — из допустимых слоту
        // (для боковых курсов возможны категории состава вроде десерта,
        // которых в одиночном слоте нет).
        final closing = entry.value.firstWhere((c) => !c.optional);
        for (final cat in closing.categories) {
          expect(slotCategories[entry.key]!, contains(cat),
              reason: '${entry.key.key}: «второе» $cat');
        }
      }
    });

    test('десерт — необязательный курс больших обедов', () {
      final lunch = composedCourses[MealSlot.lunch]!;
      final dessert =
          lunch.firstWhere((c) => c.categories.contains('dessert'));
      expect(dessert.optional, isTrue);
      expect(dessert.minSlotKcal, greaterThan(0),
          reason: 'к малым приёмам десерт не добавляется');
      expect(
        composedCourses[MealSlot.dinner]!
            .any((c) => c.categories.contains('dessert')),
        isFalse,
        reason: 'ужин — второе и салат, без десерта',
      );
    });

    test('пороги состава согласованы', () {
      expect(kComposeMinSlotKcal, greaterThan(kMinCourseTargetKcal),
          reason: 'при цели ниже порога состава курсы не собираются');
      expect(kMinCourseTargetKcal, greaterThanOrEqualTo(100));
    });

    test('порядок подачи: первое → второе → салат → десерт', () {
      expect(courseServingRank('soup'), lessThan(courseServingRank('main')));
      expect(courseServingRank('main'), courseServingRank('side'),
          reason: 'гарнир — равноправное «второе»');
      expect(courseServingRank('main'), lessThan(courseServingRank('salad')));
      expect(
          courseServingRank('salad'), lessThan(courseServingRank('dessert')));
    });
  });
}
