/// Тесты IngredientMatcher: нормализация, словарь синонимов,
/// индекс холодильника и сопоставление рецептов (Шаг 2).
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:smart_fridge_chef/ai/ingredient_matcher.dart';
import 'package:smart_fridge_chef/data/models/product.dart';
import 'package:smart_fridge_chef/data/models/recipe.dart';

void main() {
  const matcher = IngredientMatcher();

  group('normalize', () {
    test('нижний регистр, ё→е, пунктуация схлопывается', () {
      expect(IngredientMatcher.normalize('Ёлки-Палки'), 'елки палки');
      expect(IngredientMatcher.normalize('  Молоко   3,2% '),
          'молоко 3 2');
      expect(IngredientMatcher.normalize('КабачОК'), 'кабачок');
    });

    test('пустая и бессмысленная строка', () {
      expect(IngredientMatcher.normalize(''), isEmpty);
      expect(IngredientMatcher.normalize('!!!'), isEmpty);
    });
  });

  group('matchProduct: словарь синонимов', () {
    final cases = <String, String>{
      'Куриное филе': 'chicken_breast',
      'Куриная грудка': 'chicken_breast',
      'Курица': 'chicken_breast',
      'куриные бёдра': 'chicken_thigh',
      'Окорочка': 'chicken_thigh',
      'Фарш индейки': 'minced_turkey',
      'Говядина': 'beef',
      'Фарш': 'minced_beef',
      'Куриный фарш': 'minced_chicken',
      'Лосось': 'salmon',
      'Сёмга': 'salmon',
      'Креветки': 'shrimp',
      'Яйца': 'egg',
      'Молоко 3,2%': 'milk',
      'Сметана 20%': 'sour_cream',
      'Творог 5%': 'cottage_cheese',
      'Сыр российский': 'cheese',
      'Картошка': 'potato',
      'Помидоры': 'tomato',
      'Томаты в собственном соку': 'tomato',
      'Огурчики': 'cucumber',
      'Болгарский перец': 'bell_pepper',
      'Кабачок': 'zucchini',
      'Шампиньоны': 'mushroom',
      'Гречка': 'buckwheat',
      'Рис': 'rice',
      'Макароны': 'pasta',
      'Спагетти': 'pasta',
      'Овсяные хлопья': 'oat_flakes',
      'Геркулес': 'oat_flakes',
      'Банан': 'banana',
      'Яблоки Гала': 'apple',
      'Мёд': 'honey',
      'Хлеб': 'bread',
      'Молоко': 'milk',
      'молоко': 'milk',
      'Milk': 'milk',
      'Chicken': 'chicken_breast',
      'Rice 500g': 'rice',
    };
    for (final entry in cases.entries) {
      test('"${entry.key}" -> ${entry.value}', () {
        expect(matcher.matchProduct(entry.key), entry.value,
            reason: 'нормализовано: '
                '"${IngredientMatcher.normalize(entry.key)}"');
      });
    }

    test('неизвестный продукт не матчится', () {
      expect(matcher.matchProduct('Трюфель экзотический'), isNull);
      expect(matcher.matchProduct(''), isNull);
    });
  });

  group('matchProduct: порядок слов и падежи (токен-матч)', () {
    final cases = <String, String>{
      // Порядок слов не важен: раньше «Масло сливочное» ловило стем «слив»
      // и превращалось в сливу (plum).
      'Масло сливочное 82%': 'butter',
      'Сливочное масло': 'butter',
      'Масло растительное': 'vegetable_oil',
      'Черный молотый перец': 'pepper',
      'Перец чёрный молотый': 'pepper',
      'Печень куриная': 'chicken_liver',
      'Куриная печень': 'chicken_liver',
    };
    for (final entry in cases.entries) {
      test('"${entry.key}" -> ${entry.value}', () {
        expect(matcher.matchProduct(entry.key), entry.value);
      });
    }
  });

  group('matchProduct: стоп-фразы (ложные друзья стемов)', () {
    final cases = <String, String?>{
      // «печень» внутри «печенье» и «печень трески» — не куриная печень.
      'Печенье овсяное': null,
      'Печенье сахарное': null,
      'Печень трески': null,
      'Печень минтая': null,
      // «капуст» внутри «морская капуста» — это ламинария.
      'Морская капуста': null,
      // Соусы и кетчупы — не овощи.
      'Томатный соус': null,
      'Кетчуп томатный': null,
      'Томатный сок': null,
      'Сок апельсиновый': null,
      // «молок» в «молочных сосисках» — не молоко.
      'Молочные сосиски': null,
      'Сосиски Молочные Вязанка': null,
      // «лук» в «рахат-лукуме» — не лук.
      'Рахат-лукум': null,
      // Названия со штрих-кода (Open Food Facts), не закрывающие ингредиенты.
      'Докторская колбаса ГОСТ': null,
      'Пельмени Сибирская коллекция': null,
      'Мороженое эскимо': null,
    };
    for (final entry in cases.entries) {
      test('"${entry.key}" не матчится', () {
        expect(matcher.matchProduct(entry.key), entry.value);
      });
    }

    test('стоп-фраза не ломает честные названия', () {
      expect(matcher.matchProduct('Томаты в собственном соку'), 'tomato');
      expect(matcher.matchProduct('Томатная паста'), 'tomato_paste');
      expect(matcher.matchProduct('Капуста белокочанная'), 'cabbage');
      expect(matcher.matchProduct('Цветная капуста'), 'cauliflower');
      expect(matcher.matchProduct('Минеральная вода газированная'), 'water');
    });
  });

  group('categoryFor: категория по названию (типовой срок)', () {
    final cases = <String, ProductCategory>{
      'Молоко 3,2%': ProductCategory.dairy,
      'Творог обезжиренный': ProductCategory.dairy,
      'Яйца куриные С1': ProductCategory.dairy,
      'Куриное филе': ProductCategory.meat,
      'Докторская колбаса ГОСТ': ProductCategory.meat,
      'Сосиски Молочные Вязанка': ProductCategory.meat,
      'Сёмга слабосолёная': ProductCategory.fish,
      'Икра красная': ProductCategory.fish,
      'Помидоры черри': ProductCategory.vegetables,
      'Морковь': ProductCategory.vegetables,
      'Яблоки Гала': ProductCategory.fruits,
      'Хлеб Бородинский': ProductCategory.bakery,
      'Макароны Barilla': ProductCategory.grains,
      'Пельмени Сибирская коллекция': ProductCategory.frozen,
      'Мороженое эскимо': ProductCategory.frozen,
      'Сок апельсиновый 100%': ProductCategory.beverages,
      'Печенье овсяное': ProductCategory.sweets,
      'Шоколад тёмный 70%': ProductCategory.sweets,
      'Майонез Провансаль': ProductCategory.condiments,
      'Кетчуп томатный': ProductCategory.condiments,
    };
    for (final entry in cases.entries) {
      test('"${entry.key}" -> ${entry.value.key}', () {
        expect(matcher.categoryFor(entry.key), entry.value);
      });
    }

    test('незнакомые названия без категории', () {
      expect(matcher.categoryFor('Coca-Cola'), isNull);
      expect(matcher.categoryFor('Нечто невообразимое'), isNull);
      expect(matcher.categoryFor(''), isNull);
      // Морская капуста — стоп-фраза не даёт ложную «овощи».
      expect(matcher.categoryFor('Морская капуста'), isNull);
    });
  });

  group('indexProducts', () {
    test('активные проецируются на ключи, неактивные пропускаются', () {
      final fridge = matcher.indexProducts([
        product('Молоко', expiryInDays: 1),
        product('Куриное филе', expiryInDays: 2),
        product('Лук', expiryInDays: 10),
      ], now: DateTime(2026, 10, 24));
      expect(fridge.containsKey('milk'), isTrue);
      expect(fridge.containsKey('chicken_breast'), isTrue);
      expect(fridge.containsKey('onion'), isTrue);
    });

    test('неопознанное имя попадает в raw-ключ', () {
      final fridge = matcher.indexProducts([
        product('Трюфель экзотический', expiryInDays: 0),
      ], now: DateTime(2026, 10, 24));
      expect(fridge.keys.first, startsWith('raw:'));
    });

    test('потреблённые продукты не попадают в индекс', () {
      final p = product('Молоко', expiryInDays: 1)
          .copyWith(status: ProductStatus.consumed);
      final fridge = matcher.indexProducts([p],
          now: DateTime(2026, 10, 24));
      expect(fridge, isEmpty);
    });

    test('дни до истечения считаются по календарному дню', () {
      final fridge = matcher.indexProducts([
        product('A Молоко', expiryInDays: 0),
        product('B Творог', expiryInDays: 2),
        product('C Сыр', expiryInDays: 3),
        product('D Кефир', expiryInDays: 5),
      ], now: DateTime(2026, 10, 24));
      expect(fridge['milk']!.isUrgent, isTrue);
      expect(fridge['cottage_cheese']!.isUrgent, isTrue);
      expect(fridge['cheese']!.isUrgent, isFalse);
      expect(fridge['cheese']!.isSoon, isTrue);
      expect(fridge['kefir']!.isSoon, isTrue);
    });
  });

  group('matchRecipe', () {
    test('покрытие и срочные продукты', () {
      final fridge = matcher.indexProducts([
        product('Молоко', expiryInDays: 1),
        product('Овсяные хлопья', expiryInDays: 300),
        product('Банан', expiryInDays: 4),
      ], now: DateTime(2026, 10, 24));

      // Овсянка на молоке с бананом и мёдом: кладовые игнорируются.
      final oatmeal = recipeWithIngredients([
        ('oat_flakes', false),
        ('milk', false),
        ('banana', false),
        ('honey', false),
        ('salt', true),
      ]);
      final match = matcher.matchRecipe(oatmeal, fridge);

      expect(match.matchedKeys,
          containsAll(['oat_flakes', 'milk', 'banana']));
      // 3 из 4 некладовых ингредиентов (мёда в холодильнике нет).
      expect(match.coverage, closeTo(0.75, 0.001));
      // Срочное (<= 2 дней) только молоко.
      expect(match.expiringNames, ['Молоко']);
    });

    test('полностью пустой холодильник — покрытие 0', () {
      final soup = recipeWithIngredients([
        ('potato', false),
        ('carrot', false),
      ]);
      final match = matcher.matchRecipe(soup, const {});
      expect(match.coverage, 0);
      expect(match.matchedKeys, isEmpty);
    });
  });

  group('учёт граммов (v0.5.0)', () {
    Product gramProduct(String name, double quantity, ProductUnit unit) =>
        Product(
          name: name,
          category: ProductCategory.other,
          quantity: quantity,
          unit: unit,
          expiryDate: DateTime(2026, 11, 5),
          addedAt: DateTime(2026, 10, 25),
        );

    Recipe recipeWithGrams(String key, int grams) => Recipe(
          id: 'r_test_$key',
          titleRu: 'Тест $key',
          titleEn: 'Test $key',
          category: 'main',
          minutes: 20,
          servings: 2,
          kcal: 400,
          protein: 20,
          fat: 10,
          carbs: 40,
          vegetarian: true,
          vegan: true,
          glutenFree: true,
          lowCarb: false,
          hasMeat: false,
          hasFish: false,
          allergens: const [],
          family: key,
          secondFamily: '',
          ingredients: [
            RecipeIngredient(
                key: key, ru: key, en: key, grams: grams, pantry: false),
            RecipeIngredient(
                key: 'salt', ru: 'соль', en: 'salt', grams: 5, pantry: true),
          ],
          stepsRu: const ['готовить'],
          stepsEn: const ['cook'],
        );

    test('граммы конвертируются: кг → г, л → мл≈г', () {
      const matcher = IngredientMatcher();
      final fridge = matcher.indexProducts([
        gramProduct('Мука', 1.5, ProductUnit.kilogram),
        gramProduct('Молоко', 0.9, ProductUnit.liter),
      ], now: DateTime(2026, 10, 26));
      expect(fridge['flour']!.grams, 1500);
      expect(fridge['milk']!.grams, 900);
    });

    test('штуки и упаковки — масса неизвестна (null), закрывают всегда',
        () {
      const matcher = IngredientMatcher();
      final fridge = matcher.indexProducts([
        gramProduct('Огурцы', 3, ProductUnit.pcs),
        gramProduct('Гречка', 1, ProductUnit.pack),
      ], now: DateTime(2026, 10, 26));
      expect(fridge['cucumber']!.grams, isNull);
      expect(fridge['buckwheat']!.grams, isNull);
      // Счётная позиция закрывает ингредиент любого веса.
      final match =
          matcher.matchRecipe(recipeWithGrams('cucumber', 500), fridge);
      expect(match.coverage, 1.0);
    });

    test('хватает по массе — закрыто; не хватает — не закрыто', () {
      const matcher = IngredientMatcher();
      final fridge = matcher.indexProducts([
        gramProduct('Рис', 400, ProductUnit.gram),
      ], now: DateTime(2026, 10, 26));
      expect(
        matcher.matchRecipe(recipeWithGrams('rice', 300), fridge).coverage,
        1.0,
        reason: '400 г риса >= 300 г нужно',
      );
      expect(
        matcher.matchRecipe(recipeWithGrams('rice', 500), fridge).coverage,
        0.0,
        reason: '400 г риса < 500 г нужно',
      );
    });

    test('одинаковые ключи суммируются, срок — самый близкий', () {
      const matcher = IngredientMatcher();
      final fridge = matcher.indexProducts([
        Product(
          name: 'Мука',
          category: ProductCategory.grains,
          quantity: 300,
          unit: ProductUnit.gram,
          expiryDate: DateTime(2026, 10, 28), // скоро истекает
          addedAt: DateTime(2026, 10, 25),
        ),
        Product(
          name: 'Мука пшеничная',
          category: ProductCategory.grains,
          quantity: 400,
          unit: ProductUnit.gram,
          expiryDate: DateTime(2026, 12, 1),
          addedAt: DateTime(2026, 10, 25),
        ),
      ], now: DateTime(2026, 10, 26));
      final fk = fridge['flour']!;
      expect(fk.grams, 700);
      expect(fk.daysLeft, 2);
      expect(fk.isUrgent, isTrue);
    });

    test('счётная + весовая позиция одного ключа = достаточна', () {
      const matcher = IngredientMatcher();
      final fridge = matcher.indexProducts([
        gramProduct('Рис', 100, ProductUnit.gram),
        Product(
          name: 'Рис в пакетиках',
          category: ProductCategory.grains,
          quantity: 2,
          unit: ProductUnit.pcs,
          expiryDate: DateTime(2026, 12, 1),
          addedAt: DateTime(2026, 10, 25),
        ),
      ], now: DateTime(2026, 10, 26));
      expect(fridge['rice']!.grams, isNull);
    });
  });
}

// ------------------------------------------------------------- помощники

Product product(String name, {required int expiryInDays}) => Product(
      name: name,
      category: ProductCategory.other,
      expiryDate: DateTime(2026, 10, 24).add(Duration(days: expiryInDays)),
      addedAt: DateTime(2026, 10, 24),
    );

Recipe recipeWithIngredients(List<(String, bool)> ings) => Recipe(
      id: 'test_r1',
      titleRu: 'Тест',
      titleEn: 'Test',
      category: 'main',
      minutes: 30,
      servings: 2,
      kcal: 400,
      protein: 20,
      fat: 10,
      carbs: 40,
      vegetarian: true,
      vegan: false,
      glutenFree: true,
      lowCarb: false,
      hasMeat: false,
      hasFish: false,
      allergens: const [],
      family: 'test',
      secondFamily: 'test_side',
      ingredients: ings
          .map((e) => RecipeIngredient(
                key: e.$1,
                ru: e.$1,
                en: e.$1,
                grams: 100,
                pantry: e.$2,
              ))
          .toList(),
      stepsRu: const ['шаг 1', 'шаг 2'],
      stepsEn: const ['step 1', 'step 2'],
    );
