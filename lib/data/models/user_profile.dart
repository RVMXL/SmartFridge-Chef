/// Модель профиля пользователя (таблица `user_profile`, Шаг 1 ТЗ).
///
/// Профиль один на устройство (строка с id = 1): настраивается в онбординге
/// и используется Суперпланером (Шаг 2) для персонализации меню.
library;

import 'dart:convert';

import '../../ai/equipment.dart';
import 'medical_diet.dart';

/// Диета пользователя: ограничение на целые группы продуктов.
enum Diet {
  none('none'),
  vegetarian('vegetarian'),
  vegan('vegan'),

  /// Православный пост: по ограничениям близок к веганскому рациону.
  lent('lent'),
  pescatarian('pescatarian'),

  /// Низкоуглеводный рацион.
  lowCarb('low_carb'),

  /// Халяль (мусульманская): исключает свинину и алкоголь.
  /// Морепродукты разрешены целиком.
  halal('halal'),

  /// Кошер (еврейская): исключает свинину, алкоголь, морепродукты без
  /// плавников и чешуи (креветки, кальмары, крабы...) и смешение мяса
  /// с молочным в одном блюде. Рыба — «парве», с молочным совместима.
  kosher('kosher'),

  /// Индуизм: исключает говядину и телятину (включая говяжий фарш).
  hindu('hindu');

  const Diet(this.key);
  final String key;

  static Diet fromKey(String key) => values.firstWhere(
        (d) => d.key == key,
        orElse: () => Diet.none,
      );
}

/// Пищевая аллергия/непереносимость (исключается из рецептов меню).
///
/// Состав доведён до «большой 14» ЕС (v0.5.4): к молоку, яйцам, рыбе,
/// ракообразным/моллюскам, орехам, арахису, сое, глютену и кунжуту
/// добавлены сельдерей, горчица, сульфиты и люпин.
///
/// v0.5.7 — расширенный список частых аллергенов по клиническим
/// наблюдениям (NAOS и др.): мёд, шоколад/какао/кофе, красные и
/// оранжевые плоды, грибы, пряности (чеснок, корица), курица, говядина,
/// свинина, а также группы умеренной аллергенности — персики/абрикосы/
/// виноград, рис/гречка/кукуруза, перец/картофель/горох.
/// Гипоаллергенные продукты (зелёные яблоки, кабачки, баранина...)
/// в список не включены — это «безопасная» часть классификации.
enum Allergen {
  milk('milk'),
  eggs('eggs'),
  fish('fish'),
  /// Ракообразные (креветки, крабы, лангусты) — отдельный аллерген ЕС
  /// (LEG-2, аудит 2026-10-28: раньше был слит с моллюсками в один чип).
  crustaceans('crustaceans'),

  /// Моллюски (мидии, устрицы, кальмары) — отдельный аллерген ЕС.
  molluscs('molluscs'),
  nuts('nuts'),
  peanuts('peanuts'),
  soy('soy'),

  /// Пшеница/глютен.
  wheat('wheat'),
  sesame('sesame'),

  /// Сельдерей (в т.ч. корневой и стеблевой) — аллерген ЕС.
  celery('celery'),

  /// Горчица и соусы на её основе — аллерген ЕС.
  mustard('mustard'),

  /// Сульфиты (консервант E220–E228): винный уксус, вино, сухофрукты.
  /// В базе рецептов помечаются уксус и вино.
  sulphites('sulphites'),

  /// Люпин (мука/белок, встречается в выпечке) — аллерген ЕС.
  /// В текущей базе рецептов люпина нет — на будущее.
  lupin('lupin'),

  // ---- v0.5.7: расширенный список частых аллергенов ----

  /// Мёд и продукты пчеловодства (пыльца, прополис, перга).
  honey('honey'),

  /// Шоколад, какао, кофе.
  chocolate('chocolate'),

  /// Красные и оранжевые плоды: цитрусовые, клубника, малина, вишня,
  /// томаты, морковь, свёкла, тыква. Общие «ягоды» без уточнения цвета
  /// отнесены сюда консервативно — безопаснее перестраховаться.
  redProduce('red_produce'),

  /// Грибы (шампиньоны, вешенки, лесные).
  mushrooms('mushrooms'),

  /// Пряности и специи: чеснок, корица, чёрный перец, смеси, сушёные
  /// травы, лавровый лист. Горчица и сельдерей — отдельные аллергены
  /// «большой 14», сюда не входят.
  spices('spices'),

  /// Куриное мясо и другая птица (филе, бёдра, фарш, печень, индейка).
  poultry('poultry'),

  /// Говядина и телятина (в т.ч. говяжий фарш).
  beef('beef'),

  /// Свинина.
  pork('pork'),

  /// Фрукты умеренной аллергенности: персики, абрикосы, виноград
  /// (включая изюм), ананасы. В базе рецептов группа покрывается
  /// изюмом; свежих персиков/абрикосов/ананасов пока нет — на будущее.
  mildFruits('mild_fruits'),

  /// Крупы умеренной аллергенности: рис, гречка, кукуруза.
  mildCereals('mild_cereals'),

  /// Овощи умеренной аллергенности: перец (в т.ч. болгарский),
  /// картофель, горох (свежий и сушёный).
  mildVegetables('mild_vegetables');

  const Allergen(this.key);
  final String key;

  /// Неизвестный/повреждённый ключ → null (ключ отбрасывается), а не
  /// «аллергия на молоко по умолчанию»: default-ветка с молоком внезапно
  /// выкидывала 210 рецептов плана без объяснения (AI-7, аудит 2026-10-28).
  static Allergen? fromKey(String key) {
    for (final a in values) {
      if (a.key == key) return a;
    }
    return null;
  }
}

/// Правило «не люблю и не покупаю» (v0.5.4).
///
/// [key] — канонический ключ IngredientMatcher, ключ группы из
/// DislikeEngine.groups (например fish_any) или произвольное название
/// продукта (матчится по названию ингредиента в рецептах).
/// [always] — режим:
///  • true — «не переношу вовсе»: исключить блюдо при любом количестве;
///  • false — «только как основа блюда»: исключить, если доля продукта
///    >= DislikeEngine.majorShare массы блюда; в малом количестве блюдо
///    разрешено, но помечается «содержит: …» в плане.
class DislikeRule {
  const DislikeRule({required this.key, this.always = false});

  final String key;
  final bool always;

  DislikeRule copyWith({String? key, bool? always}) =>
      DislikeRule(key: key ?? this.key, always: always ?? this.always);

  Map<String, Object?> toJson() => {'key': key, 'always': always};

  static DislikeRule fromJson(Map<String, Object?> j) => DislikeRule(
        key: j['key'] as String,
        always: (j['always'] as bool?) ?? false,
      );

  @override
  bool operator ==(Object other) =>
      other is DislikeRule && other.key == key && other.always == always;

  @override
  int get hashCode => Object.hash(key, always);

  @override
  String toString() => 'DislikeRule($key, ${always ? "всегда" : "основа"})';
}

/// Профиль питания пользователя.
class UserProfile {
  const UserProfile({
    this.id = 1,
    this.dailyCalories = 2000,
    this.proteinG = 150,
    this.fatG = 67,
    this.carbsG = 200,
    this.diets = const [],
    this.allergies = const [],
    this.dislikes = const [],
    this.medicalDiets = const [],
    this.mealsPerDay = 3,

    /// Какая техника есть на кухне (v0.6.4). null — «неизвестно/всё
    /// есть»: профили до v0.6.4 не меняют поведение (планер не
    /// фильтрует по технике), после онбординга/правки в «Настройках»
    /// список всегда явный, даже пустой.
    this.equipment,
    this.regionName,
    this.latitude,
    this.longitude,
    this.onboarded = false,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Единственная строка таблицы: id всегда 1.
  final int id;

  /// Суточный калораж, ккал.
  final int dailyCalories;

  /// БЖУ, граммов в сутки.
  final int proteinG;
  final int fatG;
  final int carbsG;

  /// Диеты (v0.5.0 — список: халяль + кошер и т.п.). Ограничения
  /// комбинируются: рецепт обязан удовлетворять КАЖДОЙ выбранной диете.
  /// Пустой список = без ограничений (раньше это был Diet.none).
  /// [Diet.none] внутри списка не хранится.
  final List<Diet> diets;

  /// Аллергены — исключаются при генерации меню.
  final List<Allergen> allergies;

  /// Нелюбимые продукты (v0.5.4) — правила «не люблю и не покупаю».
  /// В отличие от аллергий работают с порогом по доле в блюде:
  /// «основа блюда» исключается, «приправа для вкуса» — допустима
  /// с пометкой в плане.
  final List<DislikeRule> dislikes;

  /// Лечебные столы по Певзнеру (v0.5.9) — ключи каталога
  /// [medicalDiets] (table1 … table15). Ограничения комбинируются:
  /// рецепт обязан соответствовать КАЖДОМУ выбранному столу.
  /// Неизвестные ключи (из старых версий) отбрасываются при чтении.
  final List<String> medicalDiets;

  /// Количество приёмов пищи в день (2–6).
  final int mealsPerDay;

  /// Техника на кухне (v0.6.4; с v0.6.7 — духовка, блендер, тостер,
  /// гриль, пароварка — по составу базы рецептов). null =
  /// «неизвестно/всё есть» (старые профили); явный пустой список =
  /// «техники нет» — духовочные блюда на 4+ порций исключаются,
  /// остальные предлагаются с пометкой замены (см.
  /// lib/ai/equipment.dart). Хранение: v0.6.4–0.6.6 писали голый
  /// массив ключей, с v0.6.7 — объект {"v":2,"owned":[…]} (чтение
  /// понимает оба; при чтении массива гриль/пароварка добавляются —
  /// чипов в той версии ещё не было).
  final List<KitchenEquipment>? equipment;

  /// Геолокация (город/регион) — для учёта сезонности продуктов на рынках.
  final String? regionName;
  final double? latitude;
  final double? longitude;

  /// Пройден ли онбординг.
  final bool onboarded;

  final DateTime createdAt;
  final DateTime updatedAt;

  /// Выбрана ли конкретная диета.
  bool hasDiet(Diet d) => d != Diet.none && diets.contains(d);

  /// Дефолтные БЖУ для [calories] по формуле 30/30/40.
  static ({int protein, int fat, int carbs}) defaultsForCalories(
    int calories,
  ) =>
      (
        protein: (calories * 0.30 / 4).round(),
        fat: (calories * 0.30 / 9).round(),
        carbs: (calories * 0.40 / 4).round(),
      );

  UserProfile copyWith({
    int? dailyCalories,
    int? proteinG,
    int? fatG,
    int? carbsG,
    List<Diet>? diets,
    List<Allergen>? allergies,
    List<DislikeRule>? dislikes,
    List<String>? medicalDiets,
    int? mealsPerDay,
    List<KitchenEquipment>? equipment,
    String? regionName,
    double? latitude,
    double? longitude,
    bool? onboarded,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserProfile(
      id: id,
      dailyCalories: dailyCalories ?? this.dailyCalories,
      proteinG: proteinG ?? this.proteinG,
      fatG: fatG ?? this.fatG,
      carbsG: carbsG ?? this.carbsG,
      diets: diets ?? this.diets,
      allergies: allergies ?? this.allergies,
      dislikes: dislikes ?? this.dislikes,
      medicalDiets: medicalDiets ?? this.medicalDiets,
      mealsPerDay: mealsPerDay ?? this.mealsPerDay,
      equipment: equipment ?? this.equipment,
      regionName: regionName ?? this.regionName,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      onboarded: onboarded ?? this.onboarded,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'daily_calories': dailyCalories,
        'protein_g': proteinG,
        'fat_g': fatG,
        'carbs_g': carbsG,
        // Старое поле остаётся заполненным (первая диета) для совместимости
        // с прежними версиями приложения и запросами отладки.
        'diet': diets.isEmpty ? Diet.none.key : diets.first.key,
        'diets': jsonEncode(diets.map((d) => d.key).toList()),
        'allergies': jsonEncode(allergies.map((a) => a.key).toList()),
        'dislikes':
            jsonEncode(dislikes.map((d) => d.toJson()).toList()),
        'medical_diets': jsonEncode(medicalDiets),
        'meals_per_day': mealsPerDay,
        // null пишется явно: колонка nullable, старые бэкапы/профили
        // читаются как «всё есть» (см. [equipment]).
        // С v0.6.7 формат — объект {"v":2,"owned":[ключи]}: маркер
        // версии внутри самого значения отличает список, сохранённый
        // ДО появления чипов гриля/пароварки (массив — консервативная
        // миграция добавляет оба), от списка, сохранённого ПОСЛЕ
        // (объект — читается как есть, снятые галочки не теряются).
        'equipment': equipment == null
            ? null
            : jsonEncode({
                'v': 2,
                'owned': equipment!.map((e) => e.key).toList(),
              }),
        'region_name': regionName,
        'latitude': latitude,
        'longitude': longitude,
        'onboarded': onboarded ? 1 : 0,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  static UserProfile fromMap(Map<String, Object?> map) {
    final rawAllergies =
        jsonDecode(map['allergies'] as String? ?? '[]') as List<dynamic>;
    final rawDislikes =
        jsonDecode(map['dislikes'] as String? ?? '[]') as List<dynamic>;
    final rawMedicalDiets =
        jsonDecode(map['medical_diets'] as String? ?? '[]') as List<dynamic>;
    final rawEquipment = map['equipment'] as String?;
    final List<KitchenEquipment>? equipment;
    if (rawEquipment == null || rawEquipment.isEmpty) {
      // Профили до v0.6.4 (или импорт старого бэкапа): техника
      // неизвестна — считаем «всё есть», поведение не меняется.
      equipment = null;
    } else {
      final decoded = jsonDecode(rawEquipment);
      if (decoded is Map<String, dynamic>) {
        // Формат v2 (v0.6.7+): читаем как есть — пользователь уже видел
        // чипы гриля/пароварки, его выбор не трогаем.
        equipment = (decoded['owned'] as List<dynamic>)
            .map((k) => KitchenEquipment.fromKey(k as String))
            .whereType<KitchenEquipment>()
            .toList();
      } else {
        // Формат v1 (массив, v0.6.4–0.6.6): чипов гриля/пароварки ещё
        // не было, их отсутствие не выражает выбор. Миграция по
        // прецеденту shellfish (LEG-2): консервативно добавляем оба —
        // покрытие пометок не расширяется против воли пользователя.
        // Пустой список НЕ трогаем: «ничего не выбрано — работают
        // замены» — сознательный выбор, добавлять в него нечестно.
        final legacy = (decoded as List<dynamic>)
            .map((k) => KitchenEquipment.fromKey(k as String))
            .whereType<KitchenEquipment>()
            .toSet();
        if (legacy.isNotEmpty) {
          legacy
            ..add(KitchenEquipment.grill)
            ..add(KitchenEquipment.steamer);
        }
        equipment = legacy.toList();
      }
    }
    // v0.5.0: источник истины — колонка diets (JSON-массив).
    // Старые записи (до миграции данных) читаются по колонке diet.
    final rawDiets = map['diets'] as String?;
    final List<Diet> diets;
    if (rawDiets != null && rawDiets.isNotEmpty && rawDiets != '[]') {
      diets = (jsonDecode(rawDiets) as List<dynamic>)
          .map((k) => Diet.fromKey(k as String))
          .where((d) => d != Diet.none)
          .toList();
    } else {
      final legacy = Diet.fromKey(map['diet'] as String? ?? 'none');
      diets = legacy == Diet.none ? const [] : [legacy];
    }
    return UserProfile(
      id: (map['id'] as int?) ?? 1,
      dailyCalories: (map['daily_calories'] as int?) ?? 2000,
      proteinG: (map['protein_g'] as int?) ?? 150,
      fatG: (map['fat_g'] as int?) ?? 67,
      carbsG: (map['carbs_g'] as int?) ?? 200,
      diets: diets,
      allergies: [
        for (final raw in rawAllergies)
          // LEG-2 (аудит 2026-10-28): чип «shellfish» старых профилей
          // покрывал и ракообразных, и моллюсков — пользователь получает
          // оба новых чипа (консервативно: покрытие не сужается).
          ...(raw == 'shellfish'
              ? const [Allergen.crustaceans, Allergen.molluscs]
              : [?Allergen.fromKey(raw as String)]),
      ],
      dislikes: rawDislikes
          .map((d) =>
              DislikeRule.fromJson(d as Map<String, Object?>))
          .toList(),
      medicalDiets: MedicalDiet.keysFromStorage(rawMedicalDiets),
      mealsPerDay: (map['meals_per_day'] as int?) ?? 3,
      equipment: equipment,
      regionName: map['region_name'] as String?,
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      onboarded: ((map['onboarded'] as int?) ?? 0) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  @override
  String toString() => 'UserProfile(ккал: $dailyCalories, Б/Ж/У: '
      '$proteinG/$fatG/$carbsG, диеты: '
      '${diets.isEmpty ? "нет" : diets.map((d) => d.key).join("+")}, '
      'аллергии: ${allergies.map((a) => a.key).join(",")}, '
      'не любит: ${dislikes.map((d) => d.key).join(",")}, '
      'столы: ${medicalDiets.join(",")}, '
      'приёмов: $mealsPerDay, '
      'техника: ${equipment == null ? "вся (по умолчанию)" : equipment!.map((e) => e.key).join(",")})';
}
