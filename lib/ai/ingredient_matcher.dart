/// Сопоставление продуктов холодильника с ингредиентами рецептов (Шаг 2).
///
/// Пользователь пишет «Куриное филе», «помидоры», «Рис» — рецепту нужны
/// ключи `chicken_breast`, `tomato`, `rice`. Матчер нормализует ввод
/// (нижний регистр, ё→е, без пунктуации) и ищет совпадение по словарю
/// синонимов: точное имя → самое длинное вхождение стема.
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
  });

  final String key;
  final String productName;

  /// Полных дней до истечения срока (может быть отрицательным).
  final int daysLeft;

  /// Продукт истекает в порог «съесть сейчас» (<= 2 дней).
  bool get isUrgent => daysLeft >= 0 && daysLeft <= 2;

  /// Продукт желательно использовать в ближайшие дни (<= 5 дней).
  bool get isSoon => daysLeft >= 0 && daysLeft <= 5;

  @override
  String toString() => 'FridgeKey($key, $productName, $daysLeft дн.)';
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

  /// Синонимы: канонический ключ → стемы для поиска вхождением.
  /// Побеждает самое длинное вхождение (чтобы «куриные бёдра» стало
  /// thigh, а не breast).
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
    'chicken_liver': ['куриную печень', 'печень кур', 'печеньк', 'печень'],
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

  /// Канонический ключ для названия продукта или null.
  ///
  /// Порядок: точное совпадение нормализованного имени с алиасом →
  /// самое длинное вхождение стема (стемы короче 3 символов пропускаем).
  String? matchProduct(String productName) {
    final norm = normalize(productName);
    if (norm.isEmpty) return null;

    String? bestKey;
    var bestLen = 0;
    _synonyms.forEach((key, aliases) {
      for (final alias in aliases) {
        if (alias.length <= bestLen) continue;
        if (norm == alias || (alias.length >= 3 && norm.contains(alias))) {
          bestKey = key;
          bestLen = alias.length;
        }
      }
    });
    return bestKey;
  }

  /// Индекс холодильника: активные продукты → ключи.
  /// Продукты, не распознанные по имени, остаются в индексе под
  /// техническим ключом `raw:<id>` — они не матчатся с рецептами,
  /// но попадают в предупреждения «используйте вне плана».
  Map<String, FridgeKey> indexProducts(List<Product> products,
      {DateTime? now}) {
    final today = now ?? DateTime.now();
    final result = <String, FridgeKey>{};
    for (final p in products) {
      if (p.status != ProductStatus.active) continue;
      final key = matchProduct(p.name) ?? 'raw:${p.id ?? p.name}';
      result[key] = FridgeKey(
        key: key,
        productName: p.name,
        daysLeft: _daysLeft(p.expiryDate, today),
      );
    }
    return result;
  }

  static int _daysLeft(DateTime expiry, DateTime today) {
    final t = DateTime(today.year, today.month, today.day);
    final e = DateTime(expiry.year, expiry.month, expiry.day);
    return e.difference(t).inDays;
  }

  /// Сопоставление рецепта с индексом холодильника.
  RecipeMatch matchRecipe(Recipe recipe, Map<String, FridgeKey> fridge) {
    var relevant = 0;
    var matched = 0;
    final keys = <String>{};
    final expiring = <String>[];
    for (final ing in recipe.ingredients) {
      if (ing.pantry) continue;
      relevant++;
      final fk = fridge[ing.key];
      if (fk == null) continue;
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
