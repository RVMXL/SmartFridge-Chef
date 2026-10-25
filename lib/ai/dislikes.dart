/// Движок «нелюбимых продуктов» (v0.5.4).
///
/// Пользователь отмечает то, что не любит и не покупает. В отличие от
/// аллергий (безопасность — исключаем всегда), нелюбимое работает с
/// порогом по ДОЛЕ продукта в блюде:
///
///  • режим «только если основа блюда» (по умолчанию): продукт,
///    составляющий >= [majorShare] массы рецепта, делает блюдо
///    «не таким» — оно исключается из плана; если продукт лишь приправа
///    (лук в поджарке, чеснок в соусе) — блюдо остаётся, но в плане
///    помечается «содержит: лук»;
///  • режим «исключать всегда» — блюдо исключается при любом количестве.
///
/// Доля считается по массе всех ингредиентов рецепта (включая кладовые
/// и воду) — так лук в супе (100 г из ~2000 г ≈ 5%) остаётся «вкусом»,
/// а в луковом супе (60%+) — основой.
///
/// Правила могут задаваться:
///  • каноническим ключом IngredientMatcher (`onion`);
///  • ключом группы [groups] (`fish_any` — вся рыба одним пунктом);
///  • произвольным названием («цветная капуста», «кинза») — матчится
///    по нормализованному названию ингредиента.
library;

import '../data/models/recipe.dart';
import '../data/models/user_profile.dart';
import 'ingredient_matcher.dart';

class DislikeEngine {
  const DislikeEngine._();

  /// Порог «основы блюда»: доля disliked-продукта в общей массе рецепта,
  /// начиная с которой блюдо исключается в режиме «основа».
  static const double majorShare = 0.10;

  /// Группы пресетов: один пункт настройки → несколько ключей рецептов.
  static const Map<String, Set<String>> groups = {
    'fish_any': {'salmon', 'cod', 'pollock', 'herring', 'tuna_can',
      'minced_fish'},
    'seafood_any': {'shrimp', 'squid'},
    'citrus_any': {'orange', 'lemon'},
    'liver_any': {'chicken_liver'},
  };

  /// Пункт настройки → ключ правила. Показ в UI (RU/EN) — тут же.
  static const List<DislikePreset> presets = [
    DislikePreset('onion', 'Лук', 'Onion'),
    DislikePreset('garlic', 'Чеснок', 'Garlic'),
    DislikePreset('mushroom', 'Грибы', 'Mushrooms'),
    DislikePreset('celery', 'Сельдерей', 'Celery'),
    DislikePreset('olives', 'Оливки и маслины', 'Olives'),
    DislikePreset('cabbage', 'Капуста', 'Cabbage'),
    DislikePreset('cauliflower', 'Цветная капуста', 'Cauliflower'),
    DislikePreset('broccoli', 'Брокколи', 'Broccoli'),
    DislikePreset('eggplant', 'Баклажаны', 'Eggplant'),
    DislikePreset('beetroot', 'Свёкла', 'Beetroot'),
    DislikePreset('pumpkin', 'Тыква', 'Pumpkin'),
    DislikePreset('zucchini', 'Кабачки', 'Zucchini'),
    DislikePreset('spinach', 'Шпинат', 'Spinach'),
    DislikePreset('radish', 'Редис', 'Radish'),
    DislikePreset('pickles', 'Солёные огурцы', 'Pickles'),
    DislikePreset('tomato', 'Помидоры', 'Tomatoes'),
    DislikePreset('cucumber', 'Огурцы', 'Cucumbers'),
    DislikePreset('bell_pepper', 'Болгарский перец', 'Bell pepper'),
    DislikePreset('greens', 'Зелень (укроп, петрушка)', 'Fresh herbs'),
    DislikePreset('fish_any', 'Рыба (вся)', 'Any fish'),
    DislikePreset('seafood_any', 'Морепродукты', 'Seafood'),
    DislikePreset('liver_any', 'Печень', 'Liver'),
    DislikePreset('cottage_cheese', 'Творог', 'Cottage cheese'),
    DislikePreset('sour_cream', 'Сметана', 'Sour cream'),
    DislikePreset('yogurt', 'Йогурт', 'Yogurt'),
    DislikePreset('kefir', 'Кефир', 'Kefir'),
    DislikePreset('cheese', 'Сыр', 'Cheese'),
    DislikePreset('butter', 'Сливочное масло', 'Butter'),
    DislikePreset('egg', 'Яйца', 'Eggs'),
    DislikePreset('mustard', 'Горчица', 'Mustard'),
    DislikePreset('mayo', 'Майонез', 'Mayo'),
    DislikePreset('soy_sauce', 'Соевый соус', 'Soy sauce'),
    DislikePreset('citrus_any', 'Цитрусовые', 'Citrus'),
    DislikePreset('banana', 'Бананы', 'Bananas'),
    DislikePreset('avocado', 'Авокадо', 'Avocado'),
    DislikePreset('raisins', 'Изюм', 'Raisins'),
  ];

  /// Результат оценки рецепта против правил профиля.
  ///
  /// [exclusionReason] не null — рецепт исключается (первая причина).
  /// [toleratedMarks] — человеческие названия tolerated-продуктов
  /// («Лук») для пометки «содержит: …» в плане.
  static EvaluatedDislikes evaluate(Recipe recipe, List<DislikeRule> rules) {
    if (rules.isEmpty) return const EvaluatedDislikes.empty();
    final totalGrams =
        recipe.ingredients.fold<int>(0, (s, i) => s + i.grams);
    if (totalGrams <= 0) return const EvaluatedDislikes.empty();

    String? reason;
    final marks = <String>{};
    for (final rule in rules) {
      final matches = recipe.ingredients
          .where((ing) => matchesIngredient(rule.key, ing))
          .toList(growable: false);
      if (matches.isEmpty) continue;
      final label = matches.first.ru;
      if (rule.always) {
        reason ??= 'не любите: $label';
        continue;
      }
      final grams = matches.fold<int>(0, (s, i) => s + i.grams);
      if (grams / totalGrams >= majorShare) {
        reason ??= 'не любите: $label — основа блюда';
      } else {
        marks.add(label);
      }
    }
    return EvaluatedDislikes(
      exclusionReason: reason,
      toleratedMarks: marks.toList(growable: false),
    );
  }

  /// Сопоставление правила с ингредиентом рецепта.
  ///
  /// Ключ группы разворачивается в набор ключей; канонический ключ
  /// сравнивается напрямую; произвольное название — нормализованным
  /// стемом по ru/en названию ингредиента (для коротких правил < 4
  /// символов — только точное совпадение имени, чтобы «лук» не поймал
  /// «лукум» и «рис» — «рисовый уксус»).
  static bool matchesIngredient(String ruleKey, RecipeIngredient ing) {
    final group = groups[ruleKey];
    if (group != null) return group.contains(ing.key);
    if (ing.key == ruleKey) return true;

    final norm = IngredientMatcher.normalize(ruleKey);
    if (norm.isEmpty) return false;
    final ru = IngredientMatcher.normalize(ing.ru);
    final en = IngredientMatcher.normalize(ing.en);
    if (norm.length < 4) return norm == ru || norm == en;
    return ru.startsWith(norm) ||
        en.startsWith(norm) ||
        ru.contains(norm) ||
        en.contains(norm);
  }
}

/// Итог оценки рецепта правилами «не люблю».
class EvaluatedDislikes {
  const EvaluatedDislikes({
    required this.exclusionReason,
    required this.toleratedMarks,
  });

  const EvaluatedDislikes.empty()
      : exclusionReason = null,
        toleratedMarks = const [];

  /// Причина исключения («не любите: лук — основа блюда») или null.
  final String? exclusionReason;

  /// Названия tolerated-продуктов для пометки «содержит: …».
  final List<String> toleratedMarks;

  bool get isAllowed => exclusionReason == null;
}

/// Пресет пункта настройки: ключ правила + подписи RU/EN.
class DislikePreset {
  const DislikePreset(this.key, this.ru, this.en);

  final String key;
  final String ru;
  final String en;

  String label(String localeTag) => localeTag.startsWith('ru') ? ru : en;
}
