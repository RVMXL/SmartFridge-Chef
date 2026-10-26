/// Модель рецепта встроенной базы (assets/data/recipes.json, Шаг 2).
///
/// Чистый Dart без зависимости от Flutter — используется AI-слоем,
/// DAO снимков планов и юнит-тестами. Схема JSON: recipes.v1
/// (генератор — scripts/gen_recipes.py в корне внешнего проекта).
library;

import 'user_profile.dart';

/// Приём пищи в плане меню.
enum MealSlot {
  breakfast('breakfast'),
  snack('snack'),
  lunch('lunch'),
  dinner('dinner');

  const MealSlot(this.key);
  final String key;

  static MealSlot fromKey(String key) => values.firstWhere(
        (s) => s.key == key,
        orElse: () => MealSlot.lunch,
      );
}

/// Один ингредиент рецепта в конкретной массе на весь рецепт.
class RecipeIngredient {
  const RecipeIngredient({
    required this.key,
    required this.ru,
    required this.en,
    required this.grams,
    required this.pantry,
  });

  /// Стабильный ключ продукта (алфавит совпадает с IngredientMatcher).
  final String key;
  final String ru;
  final String en;

  /// Грамм на весь рецепт (не на порцию).
  final int grams;

  /// Кладовый продукт (соль, масло, специи): считается всегда доступным,
  /// не влияет на покрытие холодильника и список покупок.
  final bool pantry;

  static RecipeIngredient fromJson(Map<String, Object?> j) =>
      RecipeIngredient(
        key: j['key'] as String,
        ru: j['ru'] as String,
        en: j['en'] as String,
        grams: (j['grams'] as num).toInt(),
        pantry: (j['pantry'] as bool?) ?? false,
      );

  Map<String, Object?> toJson() => {
        'key': key,
        'ru': ru,
        'en': en,
        'grams': grams,
        'pantry': pantry,
      };

  @override
  String toString() => 'RecipeIngredient($key, ${grams}g)';
}

/// Рецепт из встроенной базы.
class Recipe {
  const Recipe({
    required this.id,
    required this.titleRu,
    required this.titleEn,
    required this.category,
    required this.minutes,
    required this.servings,
    required this.kcal,
    required this.protein,
    required this.fat,
    required this.carbs,
    required this.vegetarian,
    required this.vegan,
    required this.glutenFree,
    required this.lowCarb,
    required this.hasMeat,
    required this.hasFish,

    // Религиозные флаги опциональны (default false): ручные конструкторы
    // в тестах/DAO не обязаны их указывать, JSON-загрузка задаёт всегда.
    this.hasPork = false,
    this.hasAlcohol = false,
    this.hasBeef = false,
    this.hasShellfish = false,
    this.hasDairy = false,
    required this.allergens,
    required this.family,
    required this.secondFamily,
    required this.ingredients,
    required this.stepsRu,
    required this.stepsEn,
  });

  final String id;
  final String titleRu;
  final String titleEn;

  /// breakfast | soup | main | salad | side | snack | dessert
  final String category;
  final int minutes;
  final int servings;

  /// КБЖУ на порцию (приблизительно, +-10%).
  final int kcal;
  final int protein;
  final int fat;
  final int carbs;

  final bool vegetarian;
  final bool vegan;
  final bool glutenFree;
  final bool lowCarb;
  final bool hasMeat;
  final bool hasFish;

  // --- флаги религиозных диет (v0.4.3) -------------------------------
  // Считаются по ключам ингредиентов скриптом
  // scripts/enrich_recipe_diet_flags.py; инварианты «ключ → флаг»
  // закреплены тестом в test/ai/recipe_repository_test.dart.

  /// Свинина и производные (бекон, сало, ветчина, салями, желатин) —
  /// запрещена в халяле и кошере.
  final bool hasPork;

  /// Алкоголь в составе (вино, пиво, коньяк...) — запрещён в халяле
  /// и кошере. В текущей базе рецептов алкоголя нет, флаг — страховка.
  final bool hasAlcohol;

  /// Говядина/телятина, включая говяжий фарш — запрещена в индуизме.
  final bool hasBeef;

  /// Морепродукты без плавников и чешуи (креветки, кальмары, крабы...) —
  /// запрещены в кошере; халяль разрешает все морепродукты.
  final bool hasShellfish;

  /// Молочные продукты (в т.ч. кладовое сливочное масло) — вместе с
  /// [hasMeat] запрещены в кошере (мясо + молоко в одном блюде).
  final bool hasDairy;

  /// Ключи аллергенов из [Allergen] — жёсткий фильтр планера.
  final List<Allergen> allergens;

  /// Главный ингредиент («семья блюда») — штраф за повторы в неделе.
  final String family;

  /// Второй по весу ингредиент (гарнир/основа) — мягкий штраф,
  /// чтобы неделя не превратилась в «5 ужинов с пюре».
  final String secondFamily;
  final List<RecipeIngredient> ingredients;
  final List<String> stepsRu;
  final List<String> stepsEn;

  String title(String localeTag) =>
      localeTag.startsWith('ru') ? titleRu : titleEn;

  List<String> steps(String localeTag) =>
      localeTag.startsWith('ru') ? stepsRu : stepsEn;

  /// Ингредиенты, влияющие на планирование (без кладовых).
  List<RecipeIngredient> get cookingIngredients =>
      ingredients.where((i) => !i.pantry).toList();

  static Recipe fromJson(Map<String, Object?> j) {
    final nutrition = j['nutrition'] as Map<String, Object?>;
    final flags = j['flags'] as Map<String, Object?>;
    final title = j['title'] as Map<String, Object?>;
    final steps = j['steps'] as Map<String, Object?>;
    return Recipe(
      id: j['id'] as String,
      titleRu: title['ru'] as String,
      titleEn: title['en'] as String,
      category: j['category'] as String,
      minutes: (j['minutes'] as num).toInt(),
      servings: (j['servings'] as num).toInt(),
      kcal: (nutrition['kcal'] as num).toInt(),
      protein: (nutrition['protein'] as num).toInt(),
      fat: (nutrition['fat'] as num).toInt(),
      carbs: (nutrition['carbs'] as num).toInt(),
      vegetarian: (flags['vegetarian'] as bool?) ?? false,
      vegan: (flags['vegan'] as bool?) ?? false,
      glutenFree: (flags['gluten_free'] as bool?) ?? false,
      lowCarb: (flags['low_carb'] as bool?) ?? false,
      hasMeat: (flags['has_meat'] as bool?) ?? false,
      hasFish: (flags['has_fish'] as bool?) ?? false,
      hasPork: (flags['has_pork'] as bool?) ?? false,
      hasAlcohol: (flags['has_alcohol'] as bool?) ?? false,
      hasBeef: (flags['has_beef'] as bool?) ?? false,
      hasShellfish: (flags['has_shellfish'] as bool?) ?? false,
      hasDairy: (flags['has_dairy'] as bool?) ?? false,
      allergens: _allergensOf(j),
      family: (j['family'] as String?) ?? '',
      secondFamily: (j['second_family'] as String?) ?? '',
      ingredients: (j['ingredients'] as List<dynamic>? ?? const [])
          .map((e) => RecipeIngredient.fromJson(e as Map<String, Object?>))
          .toList(),
      stepsRu: (steps['ru'] as List<dynamic>? ?? const [])
          .map((e) => e as String)
          .toList(),
      stepsEn: (steps['en'] as List<dynamic>? ?? const [])
          .map((e) => e as String)
          .toList(),
    );
  }

  /// Аллергены рецепта: список из JSON (9 базовых, считается генератором
  /// базы) ОБЪЕДИНЯЕТСЯ с аллергенами, выводимыми по ключам ингредиентов —
  /// для «большой 14» (v0.5.4: сельдерей, горчица, сульфиты) и для
  /// расширенного списка частых аллергенов (v0.5.7). Так новые аллергены
  /// не требуют перегенерации recipes.json.
  static List<Allergen> _allergensOf(Map<String, Object?> j) {
    final result =
        (j['allergens'] as List<dynamic>? ?? const [])
            .map((a) => Allergen.fromKey(a as String))
            .toSet();
    final ingredients = j['ingredients'] as List<dynamic>? ?? const [];
    for (final raw in ingredients) {
      final key = (raw as Map<String, Object?>)['key'] as String?;
      final derived = _allergenByKey[key];
      if (derived != null) result.add(derived);
    }
    return result.toList(growable: false);
  }

  /// Ключ ингредиента → аллерген (вывод по составу). Уксус помечается
  /// сульфитами консервативно: винный/бальзамический уксус их содержит.
  ///
  /// v0.5.7 — расширенный список частых аллергенов:
  ///  • wheat дополнен овсяными хлопьями (рожь/ячмень и пшеничные крупы —
  ///    манка, булгур, кускус — генератор уже пометил, а овсянку нет);
  ///  • мёд, шоколад, грибы, красные/оранжевые плоды, пряности, птица,
  ///    говядина, свинина, крупы и овощи умеренной аллергенности
  ///    выводятся из ключей ингредиентов;
  ///  • группа «персики, абрикосы, виноград» покрывается изюмом (сушёный
  ///    виноград); свежих персиков/абрикосов/ананасов в базе нет.
  static const Map<String, Allergen> _allergenByKey = {
    'celery': Allergen.celery,
    'mustard': Allergen.mustard,
    'vinegar': Allergen.sulphites,
    // Злаки с глютеном: овёс (рожь/ячмень уже помечены генератором).
    'oat_flakes': Allergen.wheat,
    // Мёд и продукты пчеловодства.
    'honey': Allergen.honey,
    // Шоколад/какао (кофе в рецептах не встречается).
    'chocolate': Allergen.chocolate,
    // Красные и оранжевые плоды: цитрусовые, красные ягоды, томаты,
    // морковь, свёкла, тыква. Общие «ягоды» — консервативно сюда же.
    'orange': Allergen.redProduce,
    'lemon': Allergen.redProduce,
    'strawberry': Allergen.redProduce,
    'raspberry': Allergen.redProduce,
    'cherry': Allergen.redProduce,
    'berries': Allergen.redProduce,
    'tomato': Allergen.redProduce,
    'tomato_paste': Allergen.redProduce,
    'carrot': Allergen.redProduce,
    'beetroot': Allergen.redProduce,
    'pumpkin': Allergen.redProduce,
    // Грибы.
    'mushroom': Allergen.mushrooms,
    // Пряности: чеснок, корица, чёрный перец, смеси, травы, лавр.
    'garlic': Allergen.spices,
    'cinnamon': Allergen.spices,
    'spices': Allergen.spices,
    'pepper': Allergen.spices,
    'herbs_dried': Allergen.spices,
    'bay_leaf': Allergen.spices,
    // Курица и другая птица.
    'chicken_breast': Allergen.poultry,
    'chicken_thigh': Allergen.poultry,
    'minced_chicken': Allergen.poultry,
    'turkey': Allergen.poultry,
    'minced_turkey': Allergen.poultry,
    'chicken_liver': Allergen.poultry,
    // Говядина.
    'beef': Allergen.beef,
    'minced_beef': Allergen.beef,
    // Свинина.
    'pork': Allergen.pork,
    // Фрукты умеренной аллергенности (виноград = изюм).
    'raisins': Allergen.mildFruits,
    // Крупы умеренной аллергенности.
    'rice': Allergen.mildCereals,
    'buckwheat': Allergen.mildCereals,
    'corn': Allergen.mildCereals,
    // Овощи умеренной аллергенности.
    'bell_pepper': Allergen.mildVegetables,
    'potato': Allergen.mildVegetables,
    'green_peas': Allergen.mildVegetables,
    'split_peas': Allergen.mildVegetables,
    // Соя и её производные: соевый соус содержит сою (и пшеницу —
    // её уже помечает генератор), тофу — соевый творог.
    'soy_sauce': Allergen.soy,
    'tofu': Allergen.soy,
  };

  Map<String, Object?> toJson() => {
        'id': id,
        'title': {'ru': titleRu, 'en': titleEn},
        'category': category,
        'minutes': minutes,
        'servings': servings,
        'nutrition': {
          'kcal': kcal,
          'protein': protein,
          'fat': fat,
          'carbs': carbs,
        },
        'flags': {
          'vegetarian': vegetarian,
          'vegan': vegan,
          'gluten_free': glutenFree,
          'low_carb': lowCarb,
          'has_meat': hasMeat,
          'has_fish': hasFish,
          'has_pork': hasPork,
          'has_alcohol': hasAlcohol,
          'has_beef': hasBeef,
          'has_shellfish': hasShellfish,
          'has_dairy': hasDairy,
        },
        'allergens': allergens.map((a) => a.key).toList(),
        'family': family,
        'second_family': secondFamily,
        'ingredients': ingredients.map((i) => i.toJson()).toList(),
        'steps': {'ru': stepsRu, 'en': stepsEn},
      };

  @override
  String toString() => 'Recipe($id, $titleRu, $category, $kcal ккал)';
}
