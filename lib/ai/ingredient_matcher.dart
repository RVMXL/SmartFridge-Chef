/// Сопоставление продуктов холодильника с ингредиентами рецептов (Шаг 2).
///
/// Пользователь пишет «Куриное филе», «помидоры», «Рис» — рецепту нужны
/// ключи `chicken_breast`, `tomato`, `rice`. Матчер нормализует ввод
/// (нижний регистр, ё→е, без пунктуации) и ищет совпадение по словарю
/// синонимов. Матч — на уровне токенов (слов): каждый токен алиаса
/// должен быть префиксом отдельного слова названия, порядок слов не
/// важен («масло сливочное» == «Сливочное масло»), падежные окончания
/// допускаются («гречка», «гречи», «гречневая» — всё стем «греч»). Это
/// убирает ложные срабатывания коротких стемов внутри чужих слов:
/// «печенье» больше не печень, «сливочное масло» больше не слива.
///
/// Поверх словаря работают стоп-фразы: если название содержит стоп
/// («морская капуста», «печень трески», «кетчуп»), перечисленные в правиле
/// ключи запрещены — продукт уходит в нераспознанные (`raw:`), что
/// безопаснее ложного «закрытия» ингредиента.
///
/// Детерминизм и покрытие словаря закреплены тестами
/// (test/ai/ingredient_matcher_test.dart).
library;

import '../data/models/product.dart';
import '../data/models/recipe.dart';

/// Продукт холодильника, спроецированный на канонический ключ.
class FridgeKey {
  const FridgeKey({
    required this.key,
    required this.productName,
    required this.daysLeft,
    this.grams,
  });

  final String key;
  final String productName;

  /// Полных дней до истечения срока (может быть отрицательным).
  final int daysLeft;

  /// Сколько продукта в холодильнике в граммах/миллилитрах
  /// (плотность принимается за 1: 1 мл ≈ 1 г).
  /// null — счётный товар (штуки/упаковка): масса позиции неизвестна,
  /// такая позиция считается ДОСТАТОЧНОЙ для любого ингредиента —
  /// иначе потребовалась бы таблица весов штуки для каждого продукта.
  final double? grams;

  /// Продукт истекает в порог «съесть сейчас» (<= 2 дней).
  bool get isUrgent => daysLeft >= 0 && daysLeft <= 2;

  /// Продукт желательно использовать в ближайшие дни (<= 5 дней).
  bool get isSoon => daysLeft >= 0 && daysLeft <= 5;

  @override
  String toString() => 'FridgeKey($key, $productName, $daysLeft дн., '
      '${grams == null ? "шт." : "${grams!.round()} г"})';
}

/// Результат сопоставления рецепта с содержимым холодильника.
class RecipeMatch {
  const RecipeMatch({
    required this.coverage,
    required this.matchedKeys,
    required this.expiringNames,
  });

  /// Доля некладовых ингредиентов, найденных в холодильнике (0..1).
  final double coverage;

  /// Канонические ключи, закрытые холодильником.
  final Set<String> matchedKeys;

  /// Названия срочных продуктов (<= 2 дней), используемых рецептом.
  final List<String> expiringNames;
}

class IngredientMatcher {
  const IngredientMatcher();

  /// Нормализация: нижний регистр, ё→е, удаление пунктуации, сжатие пробелов.
  static String normalize(String raw) {
    final lowered = raw.toLowerCase().replaceAll('ё', 'е');
    final buffer = StringBuffer();
    var prevSpace = true; // схлопывает ведущие и двойные пробелы
    for (final code in lowered.runes) {
      final ch = String.fromCharCode(code);
      if (_letterOrDigit(code)) {
        buffer.write(ch);
        prevSpace = false;
      } else if (!prevSpace) {
        buffer.write(' ');
        prevSpace = true;
      }
    }
    return buffer.toString().trim();
  }

  static bool _letterOrDigit(int code) {
    // Буквы/цифры любых алфавитов (латиница, кириллица) и цифры.
    return (code >= 0x30 && code <= 0x39) ||
        (code >= 0x41 && code <= 0x5A) ||
        (code >= 0x61 && code <= 0x7A) ||
        (code >= 0x0400 && code <= 0x04FF);
  }

  /// Синонимы: канонический ключ → стемы. Матч на уровне токенов: каждый
  /// токен стема — префикс отдельного слова названия (порядок не важен),
  /// побеждает самый длинный стем (чтобы «куриные бёдра» стало thigh,
  /// а не breast, и «томатная паста» стало tomato_paste, а не tomato).
  static const Map<String, List<String>> _synonyms = {
    // ---- мясо
    'chicken_breast': ['куриная грудка', 'грудк', 'куриное филе',
      'филе курицы', 'курица', 'chicken breast', 'chicken'],
    'chicken_thigh': ['окороч', 'бедро', 'бедра', 'бедрышк', 'chicken thigh'],
    'turkey': ['индейк', 'turkey'],
    'beef': ['говядин', 'beef'],
    'pork': ['свинин', 'pork'],
    'minced_beef': ['говяжий фарш', 'фарш говядин', 'фарш'],
    'minced_chicken': ['куриный фарш', 'фарш курицы'],
    'minced_turkey': ['фарш индейки', 'индюшиный фарш'],
    'minced_fish': ['рыбный фарш', 'фарш рыбы'],
    // Без голого стема «печень»: он ловил «печенье» и «печень трески».
    // «Печень кур» покрывает и «куриная печень», и «печень куриную».
    'chicken_liver': ['куриная печень', 'куриную печень', 'печень кур',
      'chicken liver'],
    // ---- рыба/морепродукты
    'salmon': ['лосос', 'сёмг', 'семг', 'форель', 'salmon'],
    'cod': ['треск', 'cod'],
    'pollock': ['минта', 'pollock'],
    'herring': ['сельд', 'селедк', 'herring'],
    'tuna_can': ['тунец', 'тунца', 'tuna'],
    'shrimp': ['креветк', 'shrimp', 'prawn'],
    'squid': ['кальмар', 'squid'],
    // ---- яйцо/молочка
    'egg': ['яйц', 'яичк', 'egg'],
    'milk': ['молок', 'milk'],
    'kefir': ['кефир', 'kefir'],
    'yogurt': ['йогурт', 'yogurt', 'yoghurt'],
    'sour_cream': ['сметан', 'sour cream'],
    'cottage_cheese': ['творог', 'творожн', 'cottage cheese', 'curd'],
    'cheese': ['сыр', 'сырн', 'cheese'],
    'butter': ['сливочное масло', 'сливочн масл', 'butter'],
    'cream': ['сливк', 'cream'],
    // ---- овощи
    'potato': ['картоф', 'картошк', 'potato'],
    'carrot': ['морков', 'carrot'],
    'onion': ['лук', 'onion'],
    'garlic': ['чеснок', 'чесноч', 'garlic'],
    'cabbage': ['капуст', 'cabbage'],
    'cauliflower': ['цветная капуст', 'cauliflower'],
    'broccoli': ['брокколи', 'broccoli'],
    'zucchini': ['кабач', 'цукин', 'zucchini', 'courgette'],
    'eggplant': ['баклажан', 'eggplant', 'aubergine'],
    'tomato': ['помидор', 'томат', 'tomato'],
    'cucumber': ['огурц', 'огуреч', 'огурчик', 'cucumber'],
    'bell_pepper': ['болгарский перец', 'перец болг', 'bell pepper'],
    'beetroot': ['свекл', 'бурак', 'beet'],
    'pumpkin': ['тыкв', 'pumpkin'],
    'green_peas': ['горошек', 'горошк', 'peas'],
    'corn': ['кукуруз', 'corn'],
    'mushroom': ['шампиньон', 'гриб', 'mushroom'],
    'spinach': ['шпинат', 'spinach'],
    'lettuce': ['салат лист', 'листья салата', 'латук', 'lettuce'],
    'radish': ['редис', 'radish'],
    'greens': ['зелень', 'укроп', 'петрушк', 'herbs'],
    'avocado': ['авокадо', 'avocado'],
    'celery': ['сельдерей', 'celery'],
    'pickles': ['соленые огурц', 'соленья', 'маринован огурц', 'pickles'],
    // ---- фрукты/ягоды
    'apple': ['яблок', 'яблочк', 'apple'],
    'banana': ['банан', 'banana'],
    'pear': ['груш', 'pear'],
    'orange': ['апельсин', 'orange'],
    'lemon': ['лимон', 'lemon'],
    'berries': ['ягод', 'berries'],
    'strawberry': ['клубник', 'strawberry'],
    'raspberry': ['малин', 'raspberry'],
    'cherry': ['вишн', 'cherries', 'cherry'],
    'plum': ['слив', 'plum'],
    'raisins': ['изюм', 'raisins'],
    // ---- крупы/бобовые/мучное
    'rice': ['рис', 'rice'],
    'buckwheat': ['греч', 'buckwheat'],
    'millet': ['пшено', 'millet'],
    'pearl_barley': ['перловк', 'barley'],
    'lentils': ['чечевиц', 'lentil'],
    'chickpeas': ['нут', 'chickpea', 'garbanzo'],
    'split_peas': ['горох', 'split pea'],
    'beans': ['фасол', 'bean'],
    'tofu': ['тофу', 'tofu'],
    'pasta': ['макарон', 'макарошк', 'паста', 'вермишель', 'спагетти',
      'pasta', 'spaghetti', 'noodle'],
    'bulgur_cooked': ['булгур', 'bulgur'],
    'couscous_cooked': ['кускус', 'couscous'],
    'barley_cooked': ['перловка отварная'],
    'oat_flakes': ['овсян', 'овсяные хлопья', 'геркулес', 'oat'],
    'semolina': ['манка', 'манн', 'semolina'],
    'flour': ['мук', 'flour'],
    'bread': ['хлеб', 'батон', 'булк', 'тост', 'bread', 'toast'],
    'bread_rye': ['ржаной хлеб', 'черный хлеб', 'rye bread'],
    // ---- прочее
    'walnut': ['грецкий орех', 'грецкие орехи', 'орех', 'walnut'],
    'almond': ['миндал', 'almond'],
    'peanut_butter': ['арахисовая паста', 'арахисов паст', 'peanut butter'],
    'honey': ['мед', 'honey'],
    'chocolate': ['шоколад', 'шокол', 'chocolate'],
    'olives': ['оливк', 'маслин', 'olive'],
    'jam': ['варень', 'джем', 'jam'],
    // ---- кладовая (для полноты алфавита; на покрытие не влияют)
    'vegetable_oil': ['растительное масло', 'растительн масл',
      'подсолнечн масл'],
    'olive_oil': ['оливковое масло', 'оливков масл'],
    'tomato_paste': ['томатная паста', 'томатн паст'],
    'soy_sauce': ['соевый соус', 'соев соус'],
    'mayo': ['майонез', 'mayo'],
    'mustard': ['горчиц', 'mustard'],
    'sugar': ['сахар', 'sugar'],
    'salt': ['соль', 'salt'],
    'pepper': ['черный перец', 'перец молот', 'black pepper'],
    'spices': ['специ', 'приправ', 'spices'],
    'cinnamon': ['кориц', 'cinnamon'],
    'vanilla': ['ванил', 'vanilla'],
    'baking_powder': ['разрыхлител', 'baking powder'],
    'bay_leaf': ['лавров', 'bay leaf'],
    'vinegar': ['уксус', 'vinegar'],
    'herbs_dried': ['сушеные травы', 'сушен трав'],
    'water': ['вода', 'water'],
  };

  /// Стоп-правила: нормализованная фраза → запрещённые ключи.
  ///
  /// «Морская капуста» — это ламинария, а не белокочанная капуста;
  /// «печень трески» — не куриная печень и не треска-филе; кетчуп и
  /// томатный соус — не помидоры; сок — не фрукт; сосиски «молочные» —
  /// не молоко; печенье — не овсяные хлопья. Без этих правил короткие
  /// стемы дают ложные срабатывания, искажающие покрытие холодильника.
  ///
  /// Режимы: exact — токен названия равен фразе; prefix — токен начинается
  /// с фразы; seq — фраза это последовательность префиксов подряд идущих
  /// токенов.
  static const Map<String, Set<String>> _stopExact = {
    'сок': {'tomato', 'orange', 'lemon', 'apple', 'cherry', 'plum', 'pear',
      'berries', 'raspberry', 'strawberry', 'cucumber'},
  };
  static const Map<String, Set<String>> _stopPrefix = {
    'кетчуп': {'tomato'},
    'сосиск': {'milk'},
    'печенье': {'oat_flakes', 'chicken_liver', 'sugar', 'flour', 'butter'},
    'лукум': {'onion'},
  };
  static const Map<String, Set<String>> _stopSeq = {
    'морская капуста': {'cabbage', 'cauliflower'},
    'печень треск': {'chicken_liver', 'cod'},
    'печень минта': {'chicken_liver', 'pollock'},
    'томатный соус': {'tomato'},
  };

  /// Ключи, запрещённые для токенов названия стоп-правилами.
  static Set<String> _blockedKeys(List<String> tokens) {
    final blocked = <String>{};
    _stopExact.forEach((phrase, keys) {
      if (tokens.contains(phrase)) blocked.addAll(keys);
    });
    _stopPrefix.forEach((phrase, keys) {
      if (tokens.any((t) => t.startsWith(phrase))) blocked.addAll(keys);
    });
    _stopSeq.forEach((phrase, keys) {
      final stems = phrase.split(' ');
      if (stems.length > tokens.length) return;
      for (var i = 0; i + stems.length <= tokens.length; i++) {
        var hit = true;
        for (var j = 0; j < stems.length; j++) {
          if (!tokens[i + j].startsWith(stems[j])) {
            hit = false;
            break;
          }
        }
        if (hit) {
          blocked.addAll(keys);
          return;
        }
      }
    });
    return blocked;
  }

  /// Канонический ключ для названия продукта или null.
  ///
  /// Порядок: точное совпадение нормализованного имени с алиасом →
  /// токен-префиксный матч стема (стемы короче 3 символов матчатся
  /// только целиком). Побеждает самый длинный алиас.
  String? matchProduct(String productName) {
    final norm = normalize(productName);
    if (norm.isEmpty) return null;
    final tokens = norm.split(' ');
    final blocked = _blockedKeys(tokens);

    String? bestKey;
    var bestLen = 0;
    _synonyms.forEach((key, aliases) {
      if (blocked.contains(key)) return;
      for (final rawAlias in aliases) {
        final alias = normalize(rawAlias);
        if (alias.isEmpty || alias.length <= bestLen) continue;
        if (_aliasMatches(alias, tokens)) {
          bestKey = key;
          bestLen = alias.length;
        }
      }
    });
    return bestKey;
  }

  /// Алиас матчится, если он равен всему имени или каждый его токен —
  /// префикс отдельного токена имени (порядок слов не важен).
  static bool _aliasMatches(String alias, List<String> tokens) {
    if (tokens.length == 1 && tokens.single == alias) return true;
    final aTokens = alias.split(' ');
    if (aTokens.length == 1) {
      final a = aTokens.single;
      if (a.length < 3) return false; // короткие стемы — только точное имя
      return tokens.any((t) => t.startsWith(a));
    }
    final used = List<bool>.filled(tokens.length, false);
    for (final a in aTokens) {
      var found = false;
      for (var i = 0; i < tokens.length; i++) {
        if (!used[i] && tokens[i].startsWith(a)) {
          used[i] = true;
          found = true;
          break;
        }
      }
      if (!found) return false;
    }
    return true;
  }

  /// Индекс холодильника: активные продукты → ключи.
  /// Продукты, не распознанные по имени, остаются в индексе под
  /// техническим ключом `raw:<id>` — они не матчатся с рецептами,
  /// но попадают в предупреждения «используйте вне плана».
  ///
  /// Несколько продуктов с одним ключом объединяются: граммы
  /// суммируются, срок берётся самый близкий (самое скоропортящееся),
  /// если хоть одна позиция счётная (масса неизвестна) — ключ
  /// считается достаточным (grams = null).
  Map<String, FridgeKey> indexProducts(List<Product> products,
      {DateTime? now}) {
    final today = now ?? DateTime.now();
    final result = <String, FridgeKey>{};
    for (final p in products) {
      if (p.status != ProductStatus.active) continue;
      // AI-4 (аудит 2026-10-28): просроченные продукты (daysLeft < 0) НЕ
      // закрывают ингредиенты — просроченное молоко не должно «закрывать»
      // овсянку и делать план безопасным лишь видимость. О предупреждении
      // пользователю см. RuleBasedPlanner._buildWarnings.
      final daysLeft = _daysLeft(p.expiryDate, today);
      if (daysLeft < 0) continue;
      final key = matchProduct(p.name) ?? 'raw:${p.id ?? p.name}';
      final existing = result[key];
      final grams = _gramsOf(p);
      if (existing == null) {
        result[key] = FridgeKey(
          key: key,
          productName: p.name,
          daysLeft: daysLeft,
          grams: grams,
        );
        continue;
      }
      final mergedGrams = grams == null || existing.grams == null
          ? null
          : existing.grams! + grams;
      result[key] = FridgeKey(
        key: key,
        productName: existing.productName,
        daysLeft: _minDays(existing.daysLeft, daysLeft),
        grams: mergedGrams,
      );
    }
    return result;
  }

  /// Масса позиции в граммах/миллилитрах или null для счётных товаров.
  /// 1 мл ≈ 1 г — допущение для жидкостей (молоко, сливки, масло),
  /// погрешность несущественна для решения «хватит ли на блюдо».
  static double? _gramsOf(Product p) {
    switch (p.unit) {
      case ProductUnit.gram:
        return p.quantity;
      case ProductUnit.kilogram:
        return p.quantity * 1000;
      case ProductUnit.milliliter:
        return p.quantity;
      case ProductUnit.liter:
        return p.quantity * 1000;
      case ProductUnit.pcs:
      case ProductUnit.pack:
        return null;
    }
  }

  static int _minDays(int a, int b) => a < b ? a : b;

  /// Категория приложения для названия товара (автопоиск по штрих-коду).
  ///
  /// Сначала — ключ из словаря синонимов; для товаров, которых в рецептах
  /// нет (колбасы, пельмени, соки…), — отдельный список категорийных
  /// стемов. Нужно для подстановки типового срока хранения, когда
  /// Open Food Facts не отдал категорию.
  ProductCategory? categoryFor(String productName) {
    final key = matchProduct(productName);
    if (key != null && _categoryByKey.containsKey(key)) {
      return _categoryByKey[key];
    }
    final norm = normalize(productName);
    if (norm.isEmpty) return null;
    final tokens = norm.split(' ');
    for (final entry in _extraCategoryStems.entries) {
      for (final stem in entry.value) {
        // Префикс токена, а не подстрока: «морс» не должен ловиться
        // внутри «морская капуста», «квас» — внутри «квашеная».
        if (tokens.any((t) => t.startsWith(stem))) return entry.key;
      }
    }
    return null;
  }

  /// Канонический ключ → категория приложения.
  static const Map<String, ProductCategory> _categoryByKey = {
    // Молочное и яйца.
    'milk': ProductCategory.dairy, 'kefir': ProductCategory.dairy,
    'yogurt': ProductCategory.dairy, 'sour_cream': ProductCategory.dairy,
    'cottage_cheese': ProductCategory.dairy, 'cheese': ProductCategory.dairy,
    'butter': ProductCategory.dairy, 'cream': ProductCategory.dairy,
    'egg': ProductCategory.dairy,
    // Мясо и рыба.
    'chicken_breast': ProductCategory.meat, 'chicken_thigh': ProductCategory.meat,
    'turkey': ProductCategory.meat, 'beef': ProductCategory.meat,
    'pork': ProductCategory.meat, 'minced_beef': ProductCategory.meat,
    'minced_chicken': ProductCategory.meat, 'minced_turkey': ProductCategory.meat,
    'chicken_liver': ProductCategory.meat,
    'salmon': ProductCategory.fish, 'cod': ProductCategory.fish,
    'pollock': ProductCategory.fish, 'herring': ProductCategory.fish,
    'tuna_can': ProductCategory.fish, 'minced_fish': ProductCategory.fish,
    'shrimp': ProductCategory.fish, 'squid': ProductCategory.fish,
    // Овощи и фрукты.
    'potato': ProductCategory.vegetables, 'carrot': ProductCategory.vegetables,
    'onion': ProductCategory.vegetables, 'garlic': ProductCategory.vegetables,
    'cabbage': ProductCategory.vegetables,
    'cauliflower': ProductCategory.vegetables,
    'broccoli': ProductCategory.vegetables,
    'zucchini': ProductCategory.vegetables,
    'eggplant': ProductCategory.vegetables,
    'tomato': ProductCategory.vegetables,
    'cucumber': ProductCategory.vegetables,
    'bell_pepper': ProductCategory.vegetables,
    'beetroot': ProductCategory.vegetables,
    'pumpkin': ProductCategory.vegetables,
    'green_peas': ProductCategory.vegetables,
    'corn': ProductCategory.vegetables,
    'mushroom': ProductCategory.vegetables,
    'spinach': ProductCategory.vegetables,
    'lettuce': ProductCategory.vegetables,
    'radish': ProductCategory.vegetables,
    'greens': ProductCategory.vegetables,
    'celery': ProductCategory.vegetables,
    'pickles': ProductCategory.vegetables,
    'apple': ProductCategory.fruits, 'banana': ProductCategory.fruits,
    'pear': ProductCategory.fruits, 'orange': ProductCategory.fruits,
    'lemon': ProductCategory.fruits, 'berries': ProductCategory.fruits,
    'strawberry': ProductCategory.fruits,
    'raspberry': ProductCategory.fruits, 'cherry': ProductCategory.fruits,
    'plum': ProductCategory.fruits, 'raisins': ProductCategory.fruits,
    'avocado': ProductCategory.fruits,
    // Хлеб и крупы.
    'bread': ProductCategory.bakery, 'bread_rye': ProductCategory.bakery,
    'rice': ProductCategory.grains, 'buckwheat': ProductCategory.grains,
    'millet': ProductCategory.grains, 'pearl_barley': ProductCategory.grains,
    'lentils': ProductCategory.grains, 'chickpeas': ProductCategory.grains,
    'split_peas': ProductCategory.grains, 'beans': ProductCategory.grains,
    'pasta': ProductCategory.grains, 'bulgur_cooked': ProductCategory.grains,
    'couscous_cooked': ProductCategory.grains,
    'barley_cooked': ProductCategory.grains,
    'oat_flakes': ProductCategory.grains, 'semolina': ProductCategory.grains,
    'flour': ProductCategory.grains,
    // Прочее.
    'water': ProductCategory.beverages, 'chocolate': ProductCategory.sweets,
    'honey': ProductCategory.sweets, 'jam': ProductCategory.sweets,
    'peanut_butter': ProductCategory.sweets,
    'vegetable_oil': ProductCategory.condiments,
    'olive_oil': ProductCategory.condiments,
    'tomato_paste': ProductCategory.condiments,
    'soy_sauce': ProductCategory.condiments,
    'mayo': ProductCategory.condiments, 'mustard': ProductCategory.condiments,
    'sugar': ProductCategory.condiments, 'salt': ProductCategory.condiments,
    'pepper': ProductCategory.condiments, 'spices': ProductCategory.condiments,
    'cinnamon': ProductCategory.condiments,
    'vanilla': ProductCategory.condiments,
    'baking_powder': ProductCategory.condiments,
    'bay_leaf': ProductCategory.condiments,
    'vinegar': ProductCategory.condiments,
    'herbs_dried': ProductCategory.condiments,
    'walnut': ProductCategory.other, 'almond': ProductCategory.other,
    'olives': ProductCategory.other, 'tofu': ProductCategory.other,
  };

  /// Категорийные стемы для товаров, которых нет в ключах рецептов:
  /// колбасные изделия, заморозка, напитки, кондитерка. Порядок важен:
  /// более специфичные группы перечислены раньше («Молочные сосиски» —
  /// это мясо, а не молочка). Стемы матчатся как префиксы токенов;
  /// рискованные короткие стемы («морс» в «морская», «круп» в «крупный»)
  /// в список не включены.
  static const Map<ProductCategory, List<String>> _extraCategoryStems = {
    ProductCategory.meat: [
      'сосиск', 'колбас', 'сардельк', 'ветчин', 'бекон', 'буженин',
      'карбонад', 'тушенк', 'котлет',
    ],
    ProductCategory.fish: [
      'икра', 'крабов', 'шпрот', 'сардин', 'скумбри', 'мойв', 'кильк',
    ],
    ProductCategory.frozen: [
      'пельмен', 'вареник', 'морожен', 'заморож', 'наггетс', 'хинкал',
    ],
    ProductCategory.beverages: [
      'сок', 'лимонад', 'нектар', 'компот', 'квас', 'газирован',
    ],
    ProductCategory.sweets: [
      'конфет', 'вафл', 'пряник', 'зефир', 'мармелад', 'халв', 'печенье',
      'сухар', 'козинак', 'грильяж',
    ],
    ProductCategory.condiments: ['кетчуп', 'соус'],
    ProductCategory.bakery: ['баранк', 'соломк'],
  };

  static int _daysLeft(DateTime expiry, DateTime today) {
    final t = DateTime(today.year, today.month, today.day);
    final e = DateTime(expiry.year, expiry.month, expiry.day);
    return e.difference(t).inDays;
  }

  /// Сопоставление рецепта с индексом холодильника.
  ///
  /// Ингредиент закрыт, если продукт есть И его хватает по массе:
  /// в холодильнике граммов не меньше, чем нужно рецепту (когда масса
  /// известна). Счётные позиции (штуки/упаковки) закрывают всегда —
  /// масса штуки непредсказуема без таблицы весов.
  ///
  /// [remaining] — остатки на текущий день плана (AI-5, аудит
  /// 2026-10-28): планировщик списывает подобранные блюда по дням, и
  /// следующие дни видят уменьшенный запас. Ключ есть для каждого
  /// ключа холодильника; значение null — счётная позиция (не убывает).
  RecipeMatch matchRecipe(
    Recipe recipe,
    Map<String, FridgeKey> fridge, {
    Map<String, double?>? remaining,
  }) {
    var relevant = 0;
    var matched = 0;
    final keys = <String>{};
    final expiring = <String>[];
    for (final ing in recipe.ingredients) {
      if (ing.pantry) continue;
      relevant++;
      final fk = fridge[ing.key];
      if (fk == null) continue;
      final have = remaining != null && remaining.containsKey(ing.key)
          ? remaining[ing.key]
          : fk.grams;
      if (have != null && have < ing.grams) continue; // мало — не закрывает
      matched++;
      keys.add(ing.key);
      if (fk.isUrgent) expiring.add(fk.productName);
    }
    final coverage = relevant == 0 ? 0.0 : matched / relevant;
    return RecipeMatch(
      coverage: coverage,
      matchedKeys: keys,
      expiringNames: expiring,
    );
  }
}
