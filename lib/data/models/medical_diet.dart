/// Лечебные диеты — «столы» по Певзнеру №1–15 (v0.5.9).
///
/// Классическая советская система нумерованных диетических столов,
/// назначаемых при конкретных заболеваниях. Пользователь выбирает
/// назначенные врачом столы в профиле питания, планер исключает из меню
/// рецепты с запрещёнными продуктами — тем же «жёстким» способом, что
/// аллергии (безопасность, не скоринг).
///
/// Механика та же, что у аллергенов (v0.5.4/v0.5.7): запреты задаются
/// ключами ингредиентов канонического словаря IngredientMatcher и
/// проверяются по составу рецепта на лету — без перегенерации
/// recipes.json. Подбор списков калиброван по реальной базе
/// (scripts/pevzner_coverage.py): у каждого стола остаётся достаточный
/// пул рецептов для недельного плана.
///
/// Принцип консервативности — как у аллергенов: лучше исключить лишний
/// рецепт, чем предложить неподходящий больному. Это v1 фичи: списки
/// покрывают типовые запреты столов на составе встроенной базы и НЕ
/// заменяют индивидуальные указания врача (в диалоге выбора есть
/// предупреждение).
library;

import 'recipe.dart';

class MedicalDiet {
  const MedicalDiet({
    required this.number,
    required this.nameRu,
    required this.nameEn,
    required this.shortRu,
    required this.shortEn,
    required this.indicationsRu,
    required this.indicationsEn,
    required this.forbiddenRu,
    required this.forbiddenEn,
    this.forbiddenKeys = const {},
  });

  /// Номер стола (1–15) — он же отображаемый «№N».
  final int number;

  /// Полное название без префикса «Стол №N —» (составляется в UI).
  final String nameRu;
  final String nameEn;

  /// Короткая подпись чипа выбора.
  final String shortRu;
  final String shortEn;

  /// Для каких состояний назначается (справочно).
  final String indicationsRu;
  final String indicationsEn;

  /// Что исключает (человеческая сводка для диалога).
  final String forbiddenRu;
  final String forbiddenEn;

  /// Запрещённые ключи ингредиентов — жёсткий фильтр планера.
  final Set<String> forbiddenKeys;

  /// Стабильный ключ хранения в профиле: table1 … table15.
  String get key => 'table$number';

  String title(String localeTag) => localeTag.startsWith('ru')
      ? 'Стол №$number — $nameRu'
      : 'Table $number — $nameEn';

  String shortLabel(String localeTag) =>
      localeTag.startsWith('ru') ? shortRu : shortEn;

  String indications(String localeTag) =>
      localeTag.startsWith('ru') ? indicationsRu : indicationsEn;

  String forbiddenSummary(String localeTag) =>
      localeTag.startsWith('ru') ? forbiddenRu : forbiddenEn;

  /// Первый запрещённый ингредиент рецепта (для причины исключения)
  /// или null, если рецепт столу соответствует.
  String? violationIn(Recipe recipe) {
    for (final i in recipe.ingredients) {
      if (forbiddenKeys.contains(i.key)) {
        return i.ru.isNotEmpty ? i.ru : i.key;
      }
    }
    return null;
  }

  static MedicalDiet? byKey(String key) {
    for (final d in medicalDiets) {
      if (d.key == key) return d;
    }
    return null;
  }

  static MedicalDiet? byNumber(int number) {
    for (final d in medicalDiets) {
      if (d.number == number) return d;
    }
    return null;
  }

  /// Разбирает сохранённый список ключей (неизвестные игнорируются —
  /// каталог может меняться между версиями).
  static List<String> keysFromStorage(List<dynamic> raw) =>
      raw.whereType<String>().where((k) => byKey(k) != null).toList();

  /// Человеческая причина исключения рецепта выбранными столами
  /// («стол №5: шампиньоны») или null. Порядок — по номеру стола.
  static String? exclusionReason(Recipe recipe, List<String> keys) {
    if (keys.isEmpty) return null;
    final diets = keys.map(byKey).whereType<MedicalDiet>().toList()
      ..sort((a, b) => a.number.compareTo(b.number));
    for (final d in diets) {
      final violated = d.violationIn(recipe);
      if (violated != null) return 'стол №${d.number}: $violated';
    }
    return null;
  }
}

/// Каталог столов №1–15 по Певзнеру. Ключи запретов калиброваны по
/// базе assets/data/recipes.json (инвариант закреплён тестом:
/// каждый ключ реально встречается в базе, у каждого стола достаточный
/// пул рецептов).
const List<MedicalDiet> medicalDiets = [
  MedicalDiet(
    number: 1,
    nameRu: 'щадящая при язве и гастрите',
    nameEn: 'bland diet for ulcer and gastritis',
    shortRu: 'Язва, гастрит',
    shortEn: 'Ulcer, gastritis',
    indicationsRu: 'Язвенная болезнь желудка и двенадцатиперстной кишки, '
        'гастрит с повышенной кислотностью (вне обострения)',
    indicationsEn: 'Peptic ulcer of stomach and duodenum, gastritis with '
        'high acidity (out of flare)',
    forbiddenRu: 'Свинина, белокочанная капуста, грибы, бобовые, перловка, '
        'майонез, соленья и маринады, шоколад',
    forbiddenEn: 'Pork, white cabbage, mushrooms, legumes, pearl barley, '
        'mayonnaise, pickles, chocolate',
    forbiddenKeys: {
      'pork', 'cabbage', 'mushroom', 'beans', 'split_peas', 'lentils',
      'chickpeas', 'mayo', 'chocolate', 'pearl_barley', 'barley_cooked',
      'pickles',
    },
  ),
  MedicalDiet(
    number: 2,
    nameRu: 'при пониженной кислотности',
    nameEn: 'for low stomach acid',
    shortRu: 'Пониж. кислотность',
    shortEn: 'Low stomach acid',
    indicationsRu: 'Хронический гастрит с пониженной кислотностью, '
        'хронический колит вне обострения',
    indicationsEn: 'Chronic gastritis with low acidity, chronic colitis '
        'out of flare',
    forbiddenRu: 'Свинина, белокочанная капуста, грибы, бобовые, перловка, '
        'майонез, соленья',
    forbiddenEn: 'Pork, white cabbage, mushrooms, legumes, pearl barley, '
        'mayonnaise, pickles',
    forbiddenKeys: {
      'pork', 'cabbage', 'mushroom', 'beans', 'split_peas', 'lentils',
      'chickpeas', 'mayo', 'pickles', 'pearl_barley', 'barley_cooked',
    },
  ),
  MedicalDiet(
    number: 3,
    nameRu: 'при запорах',
    nameEn: 'for constipation',
    shortRu: 'Запоры',
    shortEn: 'Constipation',
    indicationsRu: 'Хронические запоры; рацион усиливает перистальтику '
        'клетчаткой и кисломолочными',
    indicationsEn: 'Chronic constipation; diet boosts motility with fiber '
        'and fermented dairy',
    forbiddenRu: 'Рис, манная крупа, шоколад — продукты, закрепляющие стул',
    forbiddenEn: 'Rice, semolina, chocolate — stool-binding products',
    forbiddenKeys: {'rice', 'semolina', 'chocolate'},
  ),
  MedicalDiet(
    number: 4,
    nameRu: 'кишечная, щадящая (вариант 4Б)',
    nameEn: 'bland bowel diet (variant 4B)',
    shortRu: 'Кишечник (4Б)',
    shortEn: 'Bowel (4B)',
    indicationsRu: 'Острые и хронические заболевания кишечника, период '
        'выздоровления. Реализован щадящий вариант 4Б; в остром периоде '
        'рацион согласуйте с врачом',
    indicationsEn: 'Acute and chronic bowel disease, recovery stage. '
        'The mild 4B variant is implemented; in acute stage follow your '
        'doctor\'s list',
    forbiddenRu: 'Цельное молоко, сливки, свинина, грибы, бобовые, капуста, '
        'свежие овощи и салаты (огурцы, помидоры, листовой салат), орехи, '
        'шоколад, мёд, варенье, соленья, уксус',
    forbiddenEn: 'Whole milk, cream, pork, mushrooms, legumes, cabbage, '
        'raw vegetables and salads (cucumber, tomato, lettuce), nuts, '
        'chocolate, honey, jam, pickles, vinegar',
    forbiddenKeys: {
      'milk', 'cream', 'mayo', 'pork', 'mushroom', 'beans', 'split_peas',
      'lentils', 'chickpeas', 'cabbage', 'spinach', 'beetroot',
      'bell_pepper', 'greens', 'pickles', 'vinegar', 'soy_sauce', 'almond',
      'walnut', 'peanut_butter', 'chocolate', 'honey', 'jam', 'raisins',
      'cucumber', 'tomato', 'lettuce',
    },
  ),
  MedicalDiet(
    number: 5,
    nameRu: 'при болезнях печени и жёлчного пузыря',
    nameEn: 'for liver and gallbladder disease',
    shortRu: 'Печень, жёлчный',
    shortEn: 'Liver, gallbladder',
    indicationsRu: 'Хронические гепатит, холецистит, желчнокаменная болезнь '
        'вне обострения',
    indicationsEn: 'Chronic hepatitis, cholecystitis, gallstone disease '
        'out of flare',
    forbiddenRu: 'Свинина, печень и субпродукты, бобовые, грибы, соленья и '
        'маринады, уксус, чеснок, шоколад, майонез, шпинат, сливки',
    forbiddenEn: 'Pork, liver and offal, legumes, mushrooms, pickles, '
        'vinegar, garlic, chocolate, mayonnaise, spinach, cream',
    forbiddenKeys: {
      'pork', 'chicken_liver', 'beans', 'split_peas', 'lentils',
      'chickpeas', 'mushroom', 'pickles', 'vinegar', 'garlic', 'chocolate',
      'mayo', 'spinach', 'cream',
    },
  ),
  MedicalDiet(
    number: 6,
    nameRu: 'при подагре',
    nameEn: 'for gout',
    shortRu: 'Подагра',
    shortEn: 'Gout',
    indicationsRu: 'Подагра, мочекаменная болезнь с образованием уратов; '
        'рацион с малым количеством пуринов',
    indicationsEn: 'Gout, urate kidney stones; low-purine diet',
    forbiddenRu: 'Красное мясо и фарш, свинина, субпродукты, грибы, '
        'бобовые, шоколад, креветки и кальмары',
    forbiddenEn: 'Red meat and minced beef, pork, offal, mushrooms, '
        'legumes, chocolate, shrimp and squid',
    forbiddenKeys: {
      'pork', 'beef', 'minced_beef', 'chicken_liver', 'mushroom', 'beans',
      'split_peas', 'lentils', 'chickpeas', 'chocolate', 'shrimp', 'squid',
    },
  ),
  MedicalDiet(
    number: 7,
    nameRu: 'при болезнях почек',
    nameEn: 'for kidney disease',
    shortRu: 'Почки',
    shortEn: 'Kidneys',
    indicationsRu: 'Хронический нефрит с изменениями в осадке мочи; '
        'количество соли и белка — по назначению врача',
    indicationsEn: 'Chronic nephritis with urinary sediment changes; salt '
        'and protein limits per doctor\'s orders',
    forbiddenRu: 'Соленья, грибы, острый сыр, бобовые, чеснок, майонез, '
        'шоколад',
    forbiddenEn: 'Pickles, mushrooms, sharp cheese, legumes, garlic, '
        'mayonnaise, chocolate',
    forbiddenKeys: {
      'pickles', 'mushroom', 'chocolate', 'cheese', 'beans', 'split_peas',
      'lentils', 'chickpeas', 'garlic', 'mayo',
    },
  ),
  MedicalDiet(
    number: 8,
    nameRu: 'при ожирении',
    nameEn: 'for obesity',
    shortRu: 'Ожирение',
    shortEn: 'Obesity',
    indicationsRu: 'Ожирение без сопутствующих заболеваний пищеварительных '
        'органов; целевой калораж задаётся в профиле',
    indicationsEn: 'Obesity without digestive comorbidities; target '
        'calories are set in the profile',
    forbiddenRu: 'Сахар, варенье, мёд, шоколад, макароны, бананы, изюм, '
        'свинина, сливки, майонез, арахисовая паста',
    forbiddenEn: 'Sugar, jam, honey, chocolate, pasta, bananas, raisins, '
        'pork, cream, mayonnaise, peanut butter',
    forbiddenKeys: {
      'sugar', 'jam', 'honey', 'chocolate', 'mayo', 'pasta', 'pork',
      'cream', 'banana', 'raisins', 'peanut_butter',
    },
  ),
  MedicalDiet(
    number: 9,
    nameRu: 'при сахарном диабете',
    nameEn: 'for diabetes mellitus',
    shortRu: 'Диабет',
    shortEn: 'Diabetes',
    indicationsRu: 'Сахарный диабет II типа лёгкой и средней тяжести; '
        'быстрые углеводы исключены, следите за КБЖУ в профиле',
    indicationsEn: 'Type II diabetes of mild to moderate severity; fast '
        'carbs excluded, watch the BJU targets in the profile',
    forbiddenRu: 'Сахар, варенье, мёд, шоколад, бананы, изюм',
    forbiddenEn: 'Sugar, jam, honey, chocolate, bananas, raisins',
    forbiddenKeys: {'sugar', 'jam', 'honey', 'chocolate', 'banana',
      'raisins'},
  ),
  MedicalDiet(
    number: 10,
    nameRu: 'при болезнях сердца и сосудов',
    nameEn: 'for cardiovascular disease',
    shortRu: 'Сердце и сосуды',
    shortEn: 'Heart, vessels',
    indicationsRu: 'Гипертоническая болезнь, ишемическая болезнь сердца, '
        'атеросклероз; соль и жидкость — по назначению врача',
    indicationsEn: 'Hypertension, coronary heart disease, atherosclerosis; '
        'salt and fluid limits per doctor\'s orders',
    forbiddenRu: 'Соленья, шоколад, чеснок, горчица, свинина, печень, '
        'бобовые, майонез',
    forbiddenEn: 'Pickles, chocolate, garlic, mustard, pork, liver, '
        'legumes, mayonnaise',
    forbiddenKeys: {
      'pickles', 'chocolate', 'garlic', 'mustard', 'pork', 'chicken_liver',
      'mayo', 'beans', 'split_peas', 'lentils', 'chickpeas',
    },
  ),
  MedicalDiet(
    number: 11,
    nameRu: 'усиленное питание',
    nameEn: 'high-calorie diet',
    shortRu: 'Усиленное питание',
    shortEn: 'High-calorie',
    indicationsRu: 'Туберкулёз, истощение после болезней и операций; '
        'рацион высококалорийный — запретов в базе рецептов нет',
    indicationsEn: 'Tuberculosis, exhaustion after illness and surgery; '
        'high-calorie diet — no restrictions in the recipe base',
    forbiddenRu: 'Ограничений в базе рецептов нет (стол расширяющий)',
    forbiddenEn: 'No restrictions in the recipe base (expanding diet)',
  ),
  MedicalDiet(
    number: 12,
    nameRu: 'при болезнях нервной системы',
    nameEn: 'for nervous system disorders',
    shortRu: 'Нервная система',
    shortEn: 'Nervous system',
    indicationsRu: 'Заболевания нервной системы; исключаются '
        'возбуждающие продукты',
    indicationsEn: 'Nervous system disorders; stimulating products are '
        'excluded',
    forbiddenRu: 'Шоколад и какао, чеснок, чёрный перец, горчица, смеси '
        'пряностей',
    forbiddenEn: 'Chocolate and cocoa, garlic, black pepper, mustard, '
        'spice blends',
    forbiddenKeys: {'garlic', 'pepper', 'mustard', 'chocolate', 'spices'},
  ),
  MedicalDiet(
    number: 13,
    nameRu: 'при инфекционных болезнях',
    nameEn: 'for infectious diseases',
    shortRu: 'Инфекции',
    shortEn: 'Infections',
    indicationsRu: 'Острые инфекционные заболевания, лихорадочный период; '
        'пища лёгкая, щадящая',
    indicationsEn: 'Acute infectious diseases, fever period; light, bland '
        'food',
    forbiddenRu: 'Свинина, сливки, майонез, бобовые, капуста, грибы, '
        'свежий хлеб, сыр, пряности, соленья, шоколад, слива, вишня, '
        'ягоды',
    forbiddenEn: 'Pork, cream, mayonnaise, legumes, cabbage, mushrooms, '
        'fresh bread, cheese, spices, pickles, chocolate, plum, cherry, '
        'berries',
    forbiddenKeys: {
      'pork', 'cream', 'mayo', 'beans', 'split_peas', 'lentils',
      'chickpeas', 'cabbage', 'mushroom', 'bread', 'cheese', 'spices',
      'pepper', 'garlic', 'mustard', 'pickles', 'chocolate', 'berries',
      'cherry', 'plum',
    },
  ),
  MedicalDiet(
    number: 14,
    nameRu: 'при фосфатурии',
    nameEn: 'for phosphaturia',
    shortRu: 'Фосфатурия',
    shortEn: 'Phosphaturia',
    indicationsRu: 'Фосфатурия — щелочная реакция мочи; рацион сдвигают в '
        'кислую сторону: основа — мясо, рыба, крупы и хлеб',
    indicationsEn: 'Phosphaturia — alkaline urine; the diet shifts acidic: '
        'meat, fish, cereals and bread as the base',
    forbiddenRu: 'Молочные продукты, большинство овощей и фруктов '
        '(картофель, морковь, капуста, томаты, яблоки, цитрусовые и др.)',
    forbiddenEn: 'Dairy products, most vegetables and fruits (potato, '
        'carrot, cabbage, tomato, apple, citrus, etc.)',
    forbiddenKeys: {
      'milk', 'cheese', 'cottage_cheese', 'sour_cream', 'cream', 'yogurt',
      'kefir', 'butter', 'potato', 'carrot', 'beetroot', 'cabbage',
      'cucumber', 'pumpkin', 'zucchini', 'spinach', 'lettuce', 'greens',
      'tomato', 'bell_pepper', 'onion', 'garlic', 'avocado', 'apple',
      'pear', 'banana', 'orange', 'lemon', 'berries', 'cherry', 'plum',
      'jam', 'honey', 'mushroom', 'beans', 'split_peas', 'lentils',
      'chickpeas', 'broccoli', 'cauliflower', 'celery', 'olives',
      'pickles',
    },
  ),
  MedicalDiet(
    number: 15,
    nameRu: 'общий',
    nameEn: 'general',
    shortRu: 'Общий стол',
    shortEn: 'General table',
    indicationsRu: 'Период выздоровления без особых показаний; рацион без '
        'ограничений, кроме жирного и острого по самочувствию',
    indicationsEn: 'Recovery period without special indications; no '
        'restrictions apart from fatty and spicy foods as tolerated',
    forbiddenRu: 'Ограничений в базе рецептов нет (стол общий)',
    forbiddenEn: 'No restrictions in the recipe base (general diet)',
  ),
];
