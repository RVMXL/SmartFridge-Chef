/// Кухонное оборудование: вывод требований рецепта и правила замены
/// (v0.6.4).
///
/// База рецептов встраивается в приложение как read-only актив, поэтому
/// требования к технике выводятся на runtime по тексту шагов — по тому же
/// принципу, что аллергены по ключам ингредиентов (Recipe._allergenByKey):
/// обновление базы не требует перегенерации.
///
/// Модель построена под пользовательское правило:
///  • техника, которой нет, но которая заменима, — блюдо ПРЕДЛАГАЕТСЯ
///    с пометкой «чем заменить» (гриль → сковорода, тостер → сухая
///    сковорода, блендер → толкушка);
///  • духовка для БОЛЬШОГО блюда замене не подлежит — блюдо жёстко
///    исключается из плана (как аллергии), но с человеческой причиной.
///
/// Файл чистый Dart, без Flutter-зависимостей — используется AI-слоем,
/// моделью профиля и юнит-тестами. Заметьте: импортирует только
/// dart:core, чтобы user_profile.dart мог импортировать отсюда enum
/// без цикла (recipe.dart → user_profile.dart).
library;

/// Виды кухонной техники, упоминаемые в шагах базы рецептов.
///
/// Список выведен сканом всех шагов recipes.json (2026-10-29):
///  • духовка — «…в духовке», «Запекайте при 180 °C», «запеките дольки»;
///  • блендер — «взбейте блендером», «пюрируйте блендером»;
///  • тостер — «подрумяньте хлеб в тостере».
///
/// Ловушки, учтённые в ключах вывода:
///  • «Выпекайте панкейки/блины» — жарка на сковороде, НЕ духовка
///    (поэтому ключ «запек», а не «выпек»);
///  • «запечённый картофель» в названии при обжарке на плите в шагах —
///    техника выводится ТОЛЬКО из шагов, не из названия.
enum KitchenEquipment {
  /// Духовка. Для малых блюд (см. [kOvenBigServings]) заменяется плитой,
  /// для больших — замене не подлежит.
  oven('oven'),

  /// Блендер (крем-супы, смузи): заменяется толкушкой/ситом.
  blender('blender'),

  /// Тостер: заменяется сухой сковородой.
  toaster('toaster');

  const KitchenEquipment(this.key);

  /// Стабильный ключ хранения (JSON в user_profile.equipment).
  final String key;

  /// Русская подпись — для диагностики плана (filter_report хранит
  /// русские причины исключения, как «аллергия: молоко»).
  String get ruLabel => switch (this) {
        KitchenEquipment.oven => 'духовка',
        KitchenEquipment.blender => 'блендер',
        KitchenEquipment.toaster => 'тостер',
      };

  /// Английская подпись — для диагностики в en-локали (если когда-нибудь
  /// понадобится; сейчас filter_report всегда на русском).
  String get enLabel => switch (this) {
        KitchenEquipment.oven => 'oven',
        KitchenEquipment.blender => 'blender',
        KitchenEquipment.toaster => 'toaster',
      };

  static KitchenEquipment? fromKey(String key) {
    for (final e in values) {
      if (e.key == key) return e;
    }
    return null;
  }
}

/// Порог «большого блюда» для духовки: рецептов на 4+ порций без духовки
/// не предложить — замене не подлежит. В текущей базе все духовочные
/// рецепты — servings = 2 (скан 2026-10-29), поэтому сегодня фильтр не
/// отсекает ничего, но правило работает на будущее.
const int kOvenBigServings = 4;

/// Расхождение «в рецепте нужна техника, которой у пользователя нет».
class EquipmentGap {
  const EquipmentGap({
    required this.equipment,
    required this.substitutable,
  });

  /// Какой техники не хватает.
  final KitchenEquipment equipment;

  /// true — блюдо предлагается с пометкой «чем заменить»;
  /// false — блюдо исключается из плана (духовка + большое блюдо).
  final bool substitutable;

  /// Подсказка замены (ru) — для пометки в плане и карточки рецепта.
  String get substitutionRu => switch (equipment) {
        KitchenEquipment.oven =>
          'сковорода или кастрюля на плите под крышкой',
        KitchenEquipment.blender => 'толкушка или сито',
        KitchenEquipment.toaster => 'сухая сковорода',
      };

  /// Подсказка замены (en).
  String get substitutionEn => switch (equipment) {
        KitchenEquipment.oven => 'a covered pan or pot on the stove',
        KitchenEquipment.blender => 'a masher or a sieve',
        KitchenEquipment.toaster => 'a dry frying pan',
      };
}

/// Вывод требований к технике и оценка расхождений.
abstract final class KitchenEquipmentEngine {
  /// Требования рецепта по тексту шагов (шаги, соединённые в одну строку,
  /// в нижнем регистре — см. [stepsTextOf]).
  ///
  /// Ключи осознанные (скан базы 2026-10-29):
  ///  • духовка: «духовк*» или «запек*» — запеканки пишут «Запекайте
  ///    при 180 °C» без слова «духовка»; «выпекайте блины» не считается
  ///    (это жарка на сковороде);
  ///  • блендер: «блендер*»;
  ///  • тостер: «тостер*».
  static Set<KitchenEquipment> requiredForSteps(String lowercasedSteps) {
    final result = <KitchenEquipment>{};
    if (lowercasedSteps.contains('духовк') ||
        lowercasedSteps.contains('запек')) {
      result.add(KitchenEquipment.oven);
    }
    if (lowercasedSteps.contains('блендер')) {
      result.add(KitchenEquipment.blender);
    }
    if (lowercasedSteps.contains('тостер')) {
      result.add(KitchenEquipment.toaster);
    }
    return result;
  }

  /// Утилита для вызывающих сторон: шаги рецепта → нормализованный текст.
  static String stepsTextOf(List<String> stepsRu) =>
      stepsRu.join('\n').toLowerCase();

  /// Все расхождения рецепта с набором техники пользователя.
  ///
  /// [owned] == null — «неизвестно/всё есть» (старые профили до v0.6.4):
  /// расхождений нет, фильтрация не меняет поведение существующих
  /// установок. Пустое множество — осознанное «техники нет совсем».
  static List<EquipmentGap> gaps({
    required Set<KitchenEquipment> needed,
    required int servings,
    required Set<KitchenEquipment>? owned,
  }) {
    final result = <EquipmentGap>[];
    final have = owned;
    if (have == null) return result;
    for (final e in needed) {
      if (have.contains(e)) continue;
      // Пока единственная нерезервируемая ситуация — духовка для
      // большого блюда; новое оборудование добавляется в switch.
      final blocking = e == KitchenEquipment.oven &&
          servings >= kOvenBigServings;
      result.add(EquipmentGap(
        equipment: e,
        substitutable: !blocking,
      ));
    }
    return result;
  }

  /// Есть ли среди расхождений нерезервируемое (жёсткий фильтр плана).
  static bool hasBlocking(List<EquipmentGap> gaps) =>
      gaps.any((g) => !g.substitutable);
}
