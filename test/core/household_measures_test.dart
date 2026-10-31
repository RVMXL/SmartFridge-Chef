/// Тесты бытовых мер ингредиентов (v0.6.8): подбор меры по граммам,
/// RU-склонения и EN-формы, кулинарные дроби, пороги применимости,
/// откат к граммам и покрытие ключей таблицы реальной базой рецептов.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:smart_fridge_chef/core/household_measures.dart';

void main() {
  group('RU: подбор меры и склонения', () {
    test('соль: щепотка на 1–2 г, чайная ложка выше', () {
      expect(
        formatHouseholdAmount(key: 'salt', grams: 2, localeTag: 'ru'),
        '2 щепотки / 2 г',
      );
      // 5 г ≈ 0.83 ч.л. — хвост прижимается к целому (зона > 0.8).
      expect(
        formatHouseholdAmount(key: 'salt', grams: 5, localeTag: 'ru'),
        '1 чайная ложка / 5 г',
      );
    });

    test('сахар: ложки на малых, стакан на больших', () {
      expect(
        formatHouseholdAmount(key: 'sugar', grams: 5, localeTag: 'ru'),
        '1 чайная ложка / 5 г',
      );
      expect(
        formatHouseholdAmount(key: 'sugar', grams: 100, localeTag: 'ru'),
        '½ стакана / 100 г',
      );
    });

    test('яйца: штуки, дробные — половинками', () {
      expect(
        formatHouseholdAmount(key: 'egg', grams: 120, localeTag: 'ru'),
        '2 штуки / 120 г',
      );
      expect(
        formatHouseholdAmount(key: 'egg', grams: 30, localeTag: 'ru'),
        '½ штуки / 30 г',
      );
      // Меньше половины штуки — только граммы.
      expect(
        formatHouseholdAmount(key: 'egg', grams: 15, localeTag: 'ru'),
        '15 г',
      );
    });

    test('чеснок: зубчики', () {
      expect(
        formatHouseholdAmount(key: 'garlic', grams: 12, localeTag: 'ru'),
        '2 зубчика / 12 г',
      );
      expect(
        formatHouseholdAmount(key: 'garlic', grams: 6, localeTag: 'ru'),
        '1 зубчик / 6 г',
      );
    });

    test('мука: ложки на малых, стакан на больших', () {
      expect(
        formatHouseholdAmount(key: 'flour', grams: 15, localeTag: 'ru'),
        '1 столовая ложка / 15 г',
      );
      expect(
        formatHouseholdAmount(key: 'flour', grams: 130, localeTag: 'ru'),
        '1 стакан / 130 г',
      );
    });

    test('молоко: стакан и откат к граммам на малых', () {
      expect(
        formatHouseholdAmount(key: 'milk', grams: 250, localeTag: 'ru'),
        '1 стакан / 250 г',
      );
      expect(
        formatHouseholdAmount(key: 'milk', grams: 40, localeTag: 'ru'),
        '40 г',
      );
    });

    test('лавровый лист и хлеб', () {
      expect(
        formatHouseholdAmount(key: 'bay_leaf', grams: 1, localeTag: 'ru'),
        '1 лист / 1 г',
      );
      expect(
        formatHouseholdAmount(key: 'bread', grams: 60, localeTag: 'ru'),
        '2 ломтика / 60 г',
      );
    });

    test('RU-склонение 5+: «чайных ложек», «штук»', () {
      // 30 г сахара → 6 чайных ложек (порог tsp до 15 г не сработал бы:
      // 30 > 15 → tbsp 20 г → 1.5; берём соль для чистого случая).
      expect(
        formatHouseholdAmount(key: 'vinegar', grams: 25, localeTag: 'ru'),
        '5 чайных ложек / 25 г',
      );
      expect(
        formatHouseholdAmount(key: 'egg', grams: 300, localeTag: 'ru'),
        '5 штук / 300 г',
      );
    });

    test('кулинарные дроби: ⅓ стакана и 1½ столовой ложки', () {
      // 60 г риса / 190 = 0.316 → ⅓.
      expect(
        formatHouseholdAmount(key: 'rice', grams: 60, localeTag: 'ru'),
        '⅓ стакана / 60 г',
      );
      // 30 г сахара / 20 = 1.5 → «1½ столовой ложки» (род. ед.ч.).
      expect(
        formatHouseholdAmount(key: 'sugar', grams: 30, localeTag: 'ru'),
        '1½ столовой ложки / 30 г',
      );
    });

    test('лимон: долька на малых, штука на целых', () {
      expect(
        formatHouseholdAmount(key: 'lemon', grams: 10, localeTag: 'ru'),
        '½ дольки / 10 г',
      );
      expect(
        formatHouseholdAmount(key: 'lemon', grams: 100, localeTag: 'ru'),
        '1 штука / 100 г',
      );
    });
  });

  group('EN: устоявшиеся бытовые названия', () {
    const gramUnitEn = 'g';

    test('ложки: teaspoons/tablespoons', () {
      expect(
        formatHouseholdAmount(
            key: 'sugar', grams: 10, localeTag: 'en', gramUnit: gramUnitEn),
        '2 teaspoons / 10 g',
      );
      expect(
        formatHouseholdAmount(
            key: 'olive_oil', grams: 17, localeTag: 'en', gramUnit: gramUnitEn),
        '1 tablespoon / 17 g',
      );
    });

    test('счётные: существительное продукта вместо piece', () {
      expect(
        formatHouseholdAmount(
            key: 'egg', grams: 120, localeTag: 'en', gramUnit: gramUnitEn),
        '2 eggs / 120 g',
      );
      expect(
        formatHouseholdAmount(
            key: 'onion', grams: 100, localeTag: 'en', gramUnit: gramUnitEn),
        '1 onion / 100 g',
      );
      expect(
        formatHouseholdAmount(
            key: 'garlic', grams: 12, localeTag: 'en', gramUnit: gramUnitEn),
        '2 cloves / 12 g',
      );
    });

    test('стакан и дроби', () {
      expect(
        formatHouseholdAmount(
            key: 'flour', grams: 130, localeTag: 'en', gramUnit: gramUnitEn),
        '1 cup / 130 g',
      );
      expect(
        formatHouseholdAmount(
            key: 'sugar', grams: 100, localeTag: 'en', gramUnit: gramUnitEn),
        '½ cup / 100 g',
      );
    });

    test('щепотка и неправильное множественное листьев', () {
      expect(
        formatHouseholdAmount(
            key: 'salt', grams: 2, localeTag: 'en', gramUnit: gramUnitEn),
        '2 pinches / 2 g',
      );
      expect(
        formatHouseholdAmount(
            key: 'lettuce', grams: 160, localeTag: 'en', gramUnit: gramUnitEn),
        '8 leaves / 160 g',
      );
    });
  });

  group('краевые случаи', () {
    test('ключ без меры — только граммы', () {
      expect(
        formatHouseholdAmount(key: 'beef', grams: 300, localeTag: 'ru'),
        '300 г',
      );
    });

    test('ноль и отрицательные — только граммы', () {
      expect(
        formatHouseholdAmount(key: 'sugar', grams: 0, localeTag: 'ru'),
        '0 г',
      );
      expect(
        formatHouseholdAmount(key: 'water', grams: 0, localeTag: 'ru'),
        '0 г',
      );
    });

    test('крупные количества прижимаются к целым', () {
      // 500 г лука / 100 = 5 штук — без «5½».
      expect(
        formatHouseholdAmount(key: 'onion', grams: 500, localeTag: 'ru'),
        '5 штук / 500 г',
      );
    });
  });

  group('покрытие таблицы', () {
    test('каждый ключ таблицы существует в реальной базе рецептов',
        () async {
      final json = await File('assets/data/recipes.json').readAsString();
      expect(
        _keysFromDb(json),
        containsAll(kHouseholdMeasures.keys),
        reason: 'опечатка в ключе таблицы делает меру мёртвой',
      );
    });
  });
}

/// Все ключи ингредиентов базы recipes.json.
Set<String> _keysFromDb(String json) {
  // Лёгкий разбор без зависимости от Recipe: ключи — значения
  // "key": "..." внутри массива ingredients.
  final keys = <String>{};
  final re = RegExp(r'"key"\s*:\s*"([^"]+)"');
  for (final m in re.allMatches(json)) {
    keys.add(m.group(1)!);
  }
  return keys;
}
