/// Бытовые меры ингредиентов (v0.6.8): ложки, стаканы, штуки, зубчики,
/// дольки, щепотки. Ответ на запрос пользователя «не все ингредиенты
/// удобно мерить по весу»: карточка рецепта показывает количество и
/// привычной бытовой мерой, и точными граммами — «2 чайные ложки / 12 г».
///
/// Грамм остаётся канонической единицей (планер, список покупок и
/// списание холодильника считают только его) — бытовая мера это слой
/// ОТОБРАЖЕНИЯ, приблизительный по своей природе, и подсказка об этом
/// показывается в карточке рецепта.
///
/// Английские названия — устоявшиеся бытовые меры англоязычных рецептов:
/// teaspoon/tablespoon/cup, clove (чеснок), slice (хлеб), pinch и т.д.
/// Для счётных продуктов вместо безликого "piece" подставляется
/// существительное продукта ("2 eggs", "1 onion") через [enNoun].
///
/// Чистый Dart без зависимости от Flutter — юнит-тесты на хосте.
library;

import 'dart:math';

/// Вид бытовой меры: определяет склоняемые подписи (RU) и формы (EN).
enum HouseholdUnitKind {
  tsp,
  tbsp,
  cup,
  piece,
  clove,
  wedge,
  slice,
  pinch,
  bunch,
  leaf,
  pack,
  can,
  handful,
}

/// Подписи одного вида меры.
///
/// RU-формы: именительный ед.ч. («чайная ложка»), формы 2–4
/// («чайные ложки»), формы 5+ («чайных ложек») и родительный ед.ч.
/// для дробных количеств («½ чайной ложки», «1½ чайной ложки»).
class _UnitLabels {
  const _UnitLabels(
    this.ruOne,
    this.ruFew,
    this.ruMany,
    this.ruFrac,
    this.enOne,
    this.enMany,
  );

  final String ruOne;
  final String ruFew;
  final String ruMany;
  final String ruFrac;
  final String enOne;
  final String enMany;
}

const Map<HouseholdUnitKind, _UnitLabels> _labels = {
  HouseholdUnitKind.tsp: _UnitLabels(
      'чайная ложка', 'чайные ложки', 'чайных ложек', 'чайной ложки',
      'teaspoon', 'teaspoons'),
  HouseholdUnitKind.tbsp: _UnitLabels(
      'столовая ложка', 'столовые ложки', 'столовых ложек', 'столовой ложки',
      'tablespoon', 'tablespoons'),
  HouseholdUnitKind.cup: _UnitLabels('стакан', 'стакана', 'стаканов',
      'стакана', 'cup', 'cups'),
  HouseholdUnitKind.piece: _UnitLabels('штука', 'штуки', 'штук', 'штуки',
      'piece', 'pieces'),
  HouseholdUnitKind.clove: _UnitLabels('зубчик', 'зубчика', 'зубчиков',
      'зубчика', 'clove', 'cloves'),
  HouseholdUnitKind.wedge: _UnitLabels('долька', 'дольки', 'долек',
      'дольки', 'wedge', 'wedges'),
  HouseholdUnitKind.slice: _UnitLabels('ломтик', 'ломтика', 'ломтиков',
      'ломтика', 'slice', 'slices'),
  HouseholdUnitKind.pinch: _UnitLabels('щепотка', 'щепотки', 'щепоток',
      'щепотки', 'pinch', 'pinches'),
  HouseholdUnitKind.bunch: _UnitLabels('пучок', 'пучка', 'пучков',
      'пучка', 'bunch', 'bunches'),
  HouseholdUnitKind.leaf: _UnitLabels('лист', 'листа', 'листов', 'листа',
      'leaf', 'leaves'),
  HouseholdUnitKind.pack: _UnitLabels('пачка', 'пачки', 'пачек', 'пачки',
      'pack', 'packs'),
  HouseholdUnitKind.can: _UnitLabels('банка', 'банки', 'банок', 'банки',
      'can', 'cans'),
  HouseholdUnitKind.handful: _UnitLabels('горсть', 'горсти', 'горстей',
      'горсти', 'handful', 'handfuls'),
};

/// Одна бытовая мера ингредиента: сколько граммов в единице и до какого
/// количества граммов эта мера применяется (первые подходящие в списке
/// побеждают — так мелкие количества меряются ложками, крупные стаканами).
class HouseholdMeasure {
  const HouseholdMeasure(
    this.kind,
    this.grams, {
    this.maxGrams,
    this.enNoun,
  });

  final HouseholdUnitKind kind;

  /// Граммов в одной бытовой единице (приблизительно).
  final double grams;

  /// Верхняя граница применимости в граммах (null — без границы).
  /// Списки мер отсортированы по возрастанию [maxGrams] (null — последним).
  final double? maxGrams;

  /// Переопределение EN существительного для счётных продуктов:
  /// у яйца это "egg" («2 eggs»), у луковицы "onion" — привычнее, чем
  /// безликое "2 pieces".
  final String? enNoun;
}

/// Дроби, которыми отображаются нецелые количества (1/12 сетка даёт
/// привычные кулинарные доли: четверти, трети, половины).
const String _fQuarter = '¼';
const String _fThird = '⅓';
const String _fHalf = '½';
const String _fTwoThirds = '⅔';
const String _fThreeQuarters = '¾';

/// Таблица бытовых мер по стабильным ключам ингредиентов
/// ( IngredientMatcher / recipes.json). Ключи без записи показываются
/// только граммами — мясо, рыба и сыр честно взвешиваются.
///
/// Граммы в единицах — общепринятые кулинарные справочные значения
/// (чайная ложка соли ≈ 6 г, столовая ложка сахара ≈ 20 г,
/// стакан муки ≈ 130 г, яйцо С1 ≈ 60 г, зубчик чеснока ≈ 6 г).
const Map<String, List<HouseholdMeasure>> kHouseholdMeasures = {
  // ---- специи и мелкие добавки: щепотка → чайная ложка -----------------
  'salt': [
    HouseholdMeasure(HouseholdUnitKind.pinch, 1, maxGrams: 2),
    HouseholdMeasure(HouseholdUnitKind.tsp, 6, maxGrams: 12),
    HouseholdMeasure(HouseholdUnitKind.tbsp, 25),
  ],
  'pepper': [
    HouseholdMeasure(HouseholdUnitKind.pinch, 1, maxGrams: 2),
    HouseholdMeasure(HouseholdUnitKind.tsp, 3),
  ],
  'spices': [
    HouseholdMeasure(HouseholdUnitKind.pinch, 1, maxGrams: 2),
    HouseholdMeasure(HouseholdUnitKind.tsp, 3),
  ],
  'cinnamon': [
    HouseholdMeasure(HouseholdUnitKind.pinch, 1, maxGrams: 2),
    HouseholdMeasure(HouseholdUnitKind.tsp, 3),
  ],
  'herbs_dried': [
    HouseholdMeasure(HouseholdUnitKind.pinch, 1, maxGrams: 2),
    HouseholdMeasure(HouseholdUnitKind.tsp, 2),
  ],
  'bay_leaf': [HouseholdMeasure(HouseholdUnitKind.leaf, 1)],
  'baking_powder': [HouseholdMeasure(HouseholdUnitKind.tsp, 4)],
  // ---- сахар и сладкое: ложки, для крупных количеств стакан ------------
  'sugar': [
    HouseholdMeasure(HouseholdUnitKind.tsp, 5, maxGrams: 15),
    HouseholdMeasure(HouseholdUnitKind.tbsp, 20, maxGrams: 50),
    HouseholdMeasure(HouseholdUnitKind.cup, 200),
  ],
  'honey': [
    HouseholdMeasure(HouseholdUnitKind.tsp, 8, maxGrams: 12),
    HouseholdMeasure(HouseholdUnitKind.tbsp, 25),
  ],
  'jam': [HouseholdMeasure(HouseholdUnitKind.tbsp, 25)],
  'peanut_butter': [HouseholdMeasure(HouseholdUnitKind.tbsp, 20)],
  // ---- масла и соусы: столовая ложка -----------------------------------
  'vegetable_oil': [
    HouseholdMeasure(HouseholdUnitKind.tsp, 5, maxGrams: 10),
    HouseholdMeasure(HouseholdUnitKind.tbsp, 17),
  ],
  'olive_oil': [
    HouseholdMeasure(HouseholdUnitKind.tsp, 5, maxGrams: 10),
    HouseholdMeasure(HouseholdUnitKind.tbsp, 17),
  ],
  'butter': [
    HouseholdMeasure(HouseholdUnitKind.tsp, 5, maxGrams: 12),
    HouseholdMeasure(HouseholdUnitKind.tbsp, 20),
  ],
  'mayo': [HouseholdMeasure(HouseholdUnitKind.tbsp, 20)],
  'soy_sauce': [HouseholdMeasure(HouseholdUnitKind.tbsp, 16)],
  'vinegar': [HouseholdMeasure(HouseholdUnitKind.tsp, 5)],
  'mustard': [HouseholdMeasure(HouseholdUnitKind.tsp, 5)],
  'tomato_paste': [
    HouseholdMeasure(HouseholdUnitKind.tsp, 10, maxGrams: 12),
    HouseholdMeasure(HouseholdUnitKind.tbsp, 20),
  ],
  // ---- жидкости и молочное: стакан, мелкие количества граммами ---------
  'milk': [HouseholdMeasure(HouseholdUnitKind.cup, 250)],
  'kefir': [HouseholdMeasure(HouseholdUnitKind.cup, 250)],
  'cream': [HouseholdMeasure(HouseholdUnitKind.cup, 250)],
  'yogurt': [HouseholdMeasure(HouseholdUnitKind.cup, 250)],
  'water': [HouseholdMeasure(HouseholdUnitKind.cup, 250)],
  'sour_cream': [
    HouseholdMeasure(HouseholdUnitKind.tbsp, 20, maxGrams: 50),
    HouseholdMeasure(HouseholdUnitKind.cup, 250),
  ],
  // ---- сыпучие: ложки → стакан ------------------------------------------
  'flour': [
    HouseholdMeasure(HouseholdUnitKind.tbsp, 15, maxGrams: 30),
    HouseholdMeasure(HouseholdUnitKind.cup, 130),
  ],
  'semolina': [HouseholdMeasure(HouseholdUnitKind.cup, 160)],
  'oat_flakes': [HouseholdMeasure(HouseholdUnitKind.cup, 90)],
  'rice': [HouseholdMeasure(HouseholdUnitKind.cup, 190)],
  'buckwheat': [HouseholdMeasure(HouseholdUnitKind.cup, 170)],
  'millet': [HouseholdMeasure(HouseholdUnitKind.cup, 180)],
  'split_peas': [HouseholdMeasure(HouseholdUnitKind.cup, 190)],
  'lentils': [HouseholdMeasure(HouseholdUnitKind.cup, 190)],
  'beans': [HouseholdMeasure(HouseholdUnitKind.cup, 190)],
  'bulgur_cooked': [HouseholdMeasure(HouseholdUnitKind.cup, 220)],
  'couscous_cooked': [HouseholdMeasure(HouseholdUnitKind.cup, 220)],
  'barley_cooked': [HouseholdMeasure(HouseholdUnitKind.cup, 220)],
  // ---- счётные продукты --------------------------------------------------
  'egg': [HouseholdMeasure(HouseholdUnitKind.piece, 60, enNoun: 'egg')],
  'garlic': [HouseholdMeasure(HouseholdUnitKind.clove, 6)],
  'onion': [HouseholdMeasure(HouseholdUnitKind.piece, 100, enNoun: 'onion')],
  'carrot': [HouseholdMeasure(HouseholdUnitKind.piece, 70, enNoun: 'carrot')],
  'potato': [
    HouseholdMeasure(HouseholdUnitKind.piece, 130, enNoun: 'potato'),
  ],
  'tomato': [
    HouseholdMeasure(HouseholdUnitKind.piece, 150, enNoun: 'tomato'),
  ],
  'cucumber': [
    HouseholdMeasure(HouseholdUnitKind.piece, 140, enNoun: 'cucumber'),
  ],
  'bell_pepper': [
    HouseholdMeasure(HouseholdUnitKind.piece, 130, enNoun: 'pepper'),
  ],
  'zucchini': [
    HouseholdMeasure(HouseholdUnitKind.piece, 250, enNoun: 'zucchini'),
  ],
  'apple': [HouseholdMeasure(HouseholdUnitKind.piece, 150, enNoun: 'apple')],
  'pear': [HouseholdMeasure(HouseholdUnitKind.piece, 100, enNoun: 'pear')],
  'orange': [
    HouseholdMeasure(HouseholdUnitKind.piece, 100, enNoun: 'orange'),
  ],
  'banana': [
    HouseholdMeasure(HouseholdUnitKind.piece, 100, enNoun: 'banana'),
  ],
  'lemon': [
    HouseholdMeasure(HouseholdUnitKind.wedge, 20, maxGrams: 12),
    HouseholdMeasure(HouseholdUnitKind.piece, 100, enNoun: 'lemon'),
  ],
  'beetroot': [
    HouseholdMeasure(HouseholdUnitKind.piece, 250, enNoun: 'beet'),
  ],
  'avocado': [
    HouseholdMeasure(HouseholdUnitKind.piece, 130, enNoun: 'avocado'),
  ],
  'pickles': [
    HouseholdMeasure(HouseholdUnitKind.piece, 75, enNoun: 'pickle'),
  ],
  'mushroom': [
    HouseholdMeasure(HouseholdUnitKind.piece, 30, enNoun: 'mushroom'),
  ],
  'bread': [HouseholdMeasure(HouseholdUnitKind.slice, 30)],
  'greens': [HouseholdMeasure(HouseholdUnitKind.bunch, 40)],
  'lettuce': [HouseholdMeasure(HouseholdUnitKind.leaf, 20)],
  'berries': [HouseholdMeasure(HouseholdUnitKind.handful, 50)],
  'cottage_cheese': [HouseholdMeasure(HouseholdUnitKind.pack, 200)],
  'tofu': [HouseholdMeasure(HouseholdUnitKind.pack, 200)],
  'tuna_can': [HouseholdMeasure(HouseholdUnitKind.can, 150)],
};

/// Ближайшая кулинарная доля для дробной части количества.
///
/// Возвращает (целая часть, символ дроби или ''). Дробная часть
/// округляется к ближайшей из ¼ ⅓ ½ ⅔ ¾ с «зоной притяжения» к целым:
/// хвосты меньше 0.2 и больше 0.8 прижимаются к целому числу —
/// «5 г соли» честнее показать как «1 чайная ложка», чем «¾».
(int, String) _splitFraction(double count) {
  final whole = count.floor();
  final frac = count - whole;
  if (frac < 0.2) return (whole, '');
  if (frac > 0.8) return (whole + 1, '');
  const fracs = [_fQuarter, _fThird, _fHalf, _fTwoThirds, _fThreeQuarters];
  const values = [0.25, 1 / 3, 0.5, 2 / 3, 0.75];
  var best = 0;
  var bestDiff = double.infinity;
  for (var i = 0; i < values.length; i++) {
    final diff = (frac - values[i]).abs();
    if (diff < bestDiff) {
      bestDiff = diff;
      best = i;
    }
  }
  return (whole, fracs[best]);
}

/// RU-склонение целых количеств: 1 штука / 2 штуки / 5 штук.
String _ruPlural(int n, String one, String few, String many) {
  final mod10 = n % 10, mod100 = n % 100;
  if (mod10 == 1 && mod100 != 11) return one;
  if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) return few;
  return many;
}

/// Английское множественное для существительного продукта из [enNoun]:
/// «2 eggs», «1 onion». Исключения — -o с +es (potato → potatoes,
/// tomato → tomatoes; avocado → avocados — частое исключение учтено),
/// шипящие/свистящие — +es.
String _enPlural(String noun) {
  const exceptions = {'potato': 'potatoes', 'tomato': 'tomatoes'};
  final special = exceptions[noun];
  if (special != null) return special;
  final lower = noun.toLowerCase();
  const esEndings = ['s', 'x', 'z', 'ch', 'sh'];
  if (esEndings.any(lower.endsWith)) return '${noun}es';
  return '${noun}s';
}

/// Округлённое количество бытовой меры или null — «показать граммы».
/// Контракт: (целая часть, символ дроби '' — целое число).
(int, String)? _roundedCount(HouseholdMeasure m, double amount) {
  final count = amount / m.grams;
  switch (m.kind) {
    case HouseholdUnitKind.pinch:
      // Щепотка не дробится: минимум одна, дальше целыми.
      return (max(1, count.round()), '');
    case HouseholdUnitKind.tsp:
    case HouseholdUnitKind.tbsp:
    case HouseholdUnitKind.cup:
      // Объёмные меры дробятся кулинарными долями; совсем мелкие
      // количества честнее показать граммами.
      if (count < 0.2) return null;
      final (whole, frac) = _splitFraction(count);
      if (whole == 0 && frac.isEmpty) return null;
      return (whole, frac);
    case HouseholdUnitKind.piece:
    case HouseholdUnitKind.clove:
    case HouseholdUnitKind.wedge:
    case HouseholdUnitKind.slice:
    case HouseholdUnitKind.bunch:
    case HouseholdUnitKind.leaf:
    case HouseholdUnitKind.pack:
    case HouseholdUnitKind.can:
    case HouseholdUnitKind.handful:
      // Счётные: половинки и целые; от трёх штук — только целые;
      // меньше половины — граммы (четверть луковицы не бывает).
      if (count < 0.4) return null;
      if (count >= 3) return (count.round(), '');
      final halves = (count * 2).round() / 2;
      if (halves < 0.5) return null;
      if (halves == halves.roundToDouble()) {
        return (halves.toInt(), '');
      }
      return (halves.floor(), _fHalf);
  }
}

/// «2 чайные ложки / 12 г» для ингредиента [key] количеством [grams]
/// (граммы — каноническое значение, уже с учётом запланированных порций).
///
/// Если для ключа бытовой меры нет или количество слишком мало для неё,
/// возвращаются только граммы — «8 г». [gramUnit] — подпись грамма из
/// локализации («г» / "g").
String formatHouseholdAmount({
  required String key,
  required num grams,
  required String localeTag,
  String gramUnit = 'г',
}) {
  final amount = grams.toDouble();
  final gramsOnly =
      '${amount.round()} $gramUnit';
  final measures = kHouseholdMeasures[key];
  if (measures == null || measures.isEmpty || amount <= 0) return gramsOnly;

  HouseholdMeasure? measure;
  for (final m in measures) {
    final max = m.maxGrams;
    if (max == null || amount <= max) {
      measure = m;
      break;
    }
  }
  if (measure == null) return gramsOnly;

  final rounded = _roundedCount(measure, amount);
  if (rounded == null) return gramsOnly;
  final (whole, frac) = rounded;
  final labels = _labels[measure.kind]!;
  final isRu = localeTag.startsWith('ru');

  // Числовая часть: «2», «½», «1½».
  final String numeral;
  if (frac.isEmpty) {
    numeral = '$whole';
  } else if (whole == 0) {
    numeral = frac;
  } else {
    numeral = '$whole$frac';
  }

  // Номинал количества для выбора формы: «½ стакана» — ед.ч.,
  // «1½ стакана» — RU род. ед.ч., EN — мн.ч. при номинале > 1.
  const fracValues = {
    _fQuarter: 0.25,
    _fThird: 1 / 3,
    _fHalf: 0.5,
    _fTwoThirds: 2 / 3,
    _fThreeQuarters: 0.75,
  };
  final nominal = whole + (fracValues[frac] ?? 0);

  final String unitWord;
  if (isRu) {
    if (frac.isEmpty) {
      unitWord = _ruPlural(whole, labels.ruOne, labels.ruFew, labels.ruMany);
    } else {
      unitWord = labels.ruFrac;
    }
  } else {
    final enNoun = measure.enNoun;
    if (enNoun != null) {
      unitWord = nominal > 1 ? _enPlural(enNoun) : enNoun;
    } else {
      unitWord = nominal > 1 ? labels.enMany : labels.enOne;
    }
  }

  return '$numeral $unitWord / ${amount.round()} $gramUnit';
}