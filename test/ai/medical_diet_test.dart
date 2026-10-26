/// Юнит-тесты каталога лечебных столов по Певзнеру (v0.5.9).
///
/// Инварианты данных: полнота каталога (№1–15), валидность ключей
/// запретов против реальной базы recipes.json, достаточность пула
/// рецептов каждого стола для недельного плана, стабильность ключей
/// хранения и человеческих причин исключения.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:smart_fridge_chef/data/models/medical_diet.dart';
import 'package:smart_fridge_chef/data/models/recipe.dart';

Recipe recipe(List<String> ingredientKeys) => Recipe(
      id: 'test',
      titleRu: 'Тест',
      titleEn: 'Test',
      category: 'main',
      minutes: 20,
      servings: 2,
      kcal: 300,
      protein: 20,
      fat: 10,
      carbs: 30,
      vegetarian: false,
      vegan: false,
      glutenFree: true,
      lowCarb: false,
      hasMeat: true,
      hasFish: false,
      allergens: const [],
      family: 'test',
      secondFamily: '',
      ingredients: [
        for (final key in ingredientKeys)
          RecipeIngredient(
              key: key, ru: key, en: key, grams: 100, pantry: false),
      ],
      stepsRu: const [],
      stepsEn: const [],
    );

void main() {
  group('каталог столов', () {
    test('ровно 15 столов, номера и ключи уникальны и последовательны', () {
      expect(medicalDiets.length, 15);
      final numbers = medicalDiets.map((d) => d.number).toSet();
      expect(numbers, {1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15});
      final keys = medicalDiets.map((d) => d.key).toSet();
      expect(keys.length, 15);
      for (var n = 1; n <= 15; n++) {
        expect(medicalDiets[n - 1].key, 'table$n');
      }
    });

    test('тексты заполнены на обоих языках', () {
      for (final d in medicalDiets) {
        expect(d.nameRu, isNotEmpty, reason: 'nameRu стола ${d.number}');
        expect(d.nameEn, isNotEmpty, reason: 'nameEn стола ${d.number}');
        expect(d.shortRu, isNotEmpty, reason: 'shortRu стола ${d.number}');
        expect(d.shortEn, isNotEmpty, reason: 'shortEn стола ${d.number}');
        expect(d.indicationsRu, isNotEmpty,
            reason: 'indicationsRu стола ${d.number}');
        expect(d.indicationsEn, isNotEmpty,
            reason: 'indicationsEn стола ${d.number}');
        expect(d.forbiddenRu, isNotEmpty,
            reason: 'forbiddenRu стола ${d.number}');
        expect(d.forbiddenEn, isNotEmpty,
            reason: 'forbiddenEn стола ${d.number}');
      }
    });

    test('столы 11 и 15 расширяющие — без запретов, остальные с ними', () {
      for (final d in medicalDiets) {
        if (d.number == 11 || d.number == 15) {
          expect(d.forbiddenKeys, isEmpty, reason: 'стол ${d.number}');
        } else {
          expect(d.forbiddenKeys, isNotEmpty, reason: 'стол ${d.number}');
        }
      }
    });

    test('все запрещённые ключи реально встречаются в базе рецептов',
        () async {
      final raw =
          jsonDecode(await File('assets/data/recipes.json').readAsString())
              as Map<String, Object?>;
      final recipes =
          (raw['recipes'] as List<dynamic>).cast<Map<String, Object?>>();
      final known = <String>{
        for (final r in recipes)
          for (final i in r['ingredients'] as List<dynamic>)
            (i as Map<String, Object?>)['key'] as String,
      };
      for (final d in medicalDiets) {
        for (final key in d.forbiddenKeys) {
          expect(known, contains(key),
              reason: 'стол ${d.number}: ключ "$key" не встречается '
                  'в recipes.json — опечатка');
        }
      }
    });

    test('у каждого стола с запретами достаточный пул рецептов (60+)',
        () async {
      final raw =
          jsonDecode(await File('assets/data/recipes.json').readAsString())
              as Map<String, Object?>;
      final recipes =
          (raw['recipes'] as List<dynamic>).cast<Map<String, Object?>>();
      for (final d in medicalDiets) {
        if (d.forbiddenKeys.isEmpty) continue;
        final kept = recipes
            .where((r) => !(r['ingredients'] as List<dynamic>).any(
                (i) => d.forbiddenKeys
                    .contains((i as Map<String, Object?>)['key'])))
            .length;
        expect(kept, greaterThanOrEqualTo(60),
            reason: 'стол ${d.number}: осталось $kept рецептов — '
                'недельному планеру этого мало');
      }
    });

    test('таблица калибровки: пул каждого стола совпадает с ожидаемым',
        () async {
      // Значения из scripts/pevzner_coverage.py (v0.5.9). При изменении
      // списков запретов или базы рецептов обновите ожидания осознанно.
      final expected = {
        1: 408, 2: 417, 3: 457, 4: 197, 5: 418, 6: 384, 7: 444, 8: 330,
        9: 432, 10: 437, 12: 132, 13: 81, 14: 108,
      };
      final raw =
          jsonDecode(await File('assets/data/recipes.json').readAsString())
              as Map<String, Object?>;
      final recipes =
          (raw['recipes'] as List<dynamic>).cast<Map<String, Object?>>();
      for (final entry in expected.entries) {
        final d = MedicalDiet.byNumber(entry.key)!;
        final kept = recipes
            .where((r) => !(r['ingredients'] as List<dynamic>).any(
                (i) => d.forbiddenKeys
                    .contains((i as Map<String, Object?>)['key'])))
            .length;
        expect(kept, entry.value,
            reason: 'пул стола ${entry.key} изменился — списки запретов '
                'или база рецептов обновились');
      }
    });
  });

  group('поиск нарушений', () {
    test('violationIn возвращает первый запрещённый ингредиент', () {
      final t5 = medicalDiets[4]; // стол 5
      expect(t5.number, 5);
      expect(t5.violationIn(recipe(['pork', 'potato'])), 'pork');
      expect(t5.violationIn(recipe(['potato', 'chicken_breast'])), isNull);
      expect(t5.violationIn(recipe([])), isNull);
    });

    test('стол 4 запрещает цельное молоко и свежие салаты, но не грудинку',
        () {
      final t4 = medicalDiets[3];
      expect(t4.violationIn(recipe(['milk', 'oat_flakes'])), 'milk');
      expect(t4.violationIn(recipe(['tomato', 'cucumber'])), 'tomato');
      expect(t4.violationIn(recipe(['chicken_breast', 'rice'])), isNull);
    });

    test('стол 9 исключает быстрые углеводы', () {
      final t9 = medicalDiets[8];
      expect(t9.violationIn(recipe(['sugar'])), 'sugar');
      expect(t9.violationIn(recipe(['honey', 'kefir'])), 'honey');
      expect(t9.violationIn(recipe(['buckwheat', 'cod'])), isNull);
    });

    test('стол 6 запрещает красное мясо и субпродукты, но не птицу', () {
      final t6 = medicalDiets[5];
      expect(t6.violationIn(recipe(['beef'])), 'beef');
      expect(t6.violationIn(recipe(['minced_beef'])), 'minced_beef');
      expect(t6.violationIn(recipe(['chicken_liver'])), 'chicken_liver');
      expect(t6.violationIn(recipe(['turkey', 'buckwheat'])), isNull);
    });

    test('расширяющие столы 11 и 15 ничего не запрещают', () {
      final full = recipe(['pork', 'milk', 'chocolate', 'sugar']);
      expect(medicalDiets[10].violationIn(full), isNull); // 11
      expect(medicalDiets[14].violationIn(full), isNull); // 15
    });
  });

  group('ключи и причины', () {
    test('byKey / byNumber / keysFromStorage', () {
      expect(MedicalDiet.byKey('table1')?.number, 1);
      expect(MedicalDiet.byKey('nope'), isNull);
      expect(MedicalDiet.byNumber(9)?.key, 'table9');
      expect(MedicalDiet.byNumber(16), isNull);
      expect(
        MedicalDiet.keysFromStorage(
            ['table5', 'garbage', 42, 'table1', 'table99']),
        ['table5', 'table1'],
      );
    });

    test('причина исключения содержит номер первого стола по порядку',
        () {
      final r = recipe(['pork', 'chocolate']);
      expect(MedicalDiet.exclusionReason(r, const []),
          isNull, reason: 'пустой список — фильтр выключен');
      expect(MedicalDiet.exclusionReason(r, const ['table1']),
          'стол №1: pork');
      // Стол 1 младше 5 — проверяется первым (свинина в обоих списках).
      expect(MedicalDiet.exclusionReason(r, const ['table5', 'table1']),
          'стол №1: pork');
      // Шоколад запрещён только столом 12 из выбранных.
      expect(MedicalDiet.exclusionReason(recipe(['chocolate']),
          const ['table9', 'table12']), 'стол №9: chocolate');
      expect(MedicalDiet.exclusionReason(recipe(['turkey']),
          const ['table1', 'table5']), isNull);
    });
  });
}
