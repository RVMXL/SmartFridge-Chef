/// Модель профиля пользователя (таблица `user_profile`, Шаг 1 ТЗ).
///
/// Профиль один на устройство (строка с id = 1): настраивается в онбординге
/// и используется Суперпланером (Шаг 2) для персонализации меню.
library;

import 'dart:convert';

/// Диета пользователя: ограничение на целые группы продуктов.
enum Diet {
  none('none'),
  vegetarian('vegetarian'),
  vegan('vegan'),

  /// Православный пост: по ограничениям близок к веганскому рациону.
  lent('lent'),
  pescatarian('pescatarian'),

  /// Низкоуглеводный рацион.
  lowCarb('low_carb');

  const Diet(this.key);
  final String key;

  static Diet fromKey(String key) => values.firstWhere(
        (d) => d.key == key,
        orElse: () => Diet.none,
      );
}

/// Пищевая аллергия/непереносимость (исключается из рецептов меню).
enum Allergen {
  milk('milk'),
  eggs('eggs'),
  fish('fish'),
  shellfish('shellfish'),
  nuts('nuts'),
  peanuts('peanuts'),
  soy('soy'),

  /// Пшеница/глютен.
  wheat('wheat'),
  sesame('sesame');

  const Allergen(this.key);
  final String key;

  static Allergen fromKey(String key) => values.firstWhere(
        (a) => a.key == key,
        orElse: () => Allergen.milk,
      );
}

/// Профиль питания пользователя.
class UserProfile {
  const UserProfile({
    this.id = 1,
    this.dailyCalories = 2000,
    this.proteinG = 150,
    this.fatG = 67,
    this.carbsG = 200,
    this.diet = Diet.none,
    this.allergies = const [],
    this.mealsPerDay = 3,
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

  final Diet diet;

  /// Аллергены — исключаются при генерации меню.
  final List<Allergen> allergies;

  /// Количество приёмов пищи в день (2–6).
  final int mealsPerDay;

  /// Геолокация (город/регион) — для учёта сезонности продуктов на рынках.
  final String? regionName;
  final double? latitude;
  final double? longitude;

  /// Пройден ли онбординг.
  final bool onboarded;

  final DateTime createdAt;
  final DateTime updatedAt;

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
    Diet? diet,
    List<Allergen>? allergies,
    int? mealsPerDay,
    String? regionName,
    double? latitude,
    double? longitude,
    bool? onboarded,
    DateTime? updatedAt,
  }) {
    return UserProfile(
      id: id,
      dailyCalories: dailyCalories ?? this.dailyCalories,
      proteinG: proteinG ?? this.proteinG,
      fatG: fatG ?? this.fatG,
      carbsG: carbsG ?? this.carbsG,
      diet: diet ?? this.diet,
      allergies: allergies ?? this.allergies,
      mealsPerDay: mealsPerDay ?? this.mealsPerDay,
      regionName: regionName ?? this.regionName,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      onboarded: onboarded ?? this.onboarded,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'daily_calories': dailyCalories,
        'protein_g': proteinG,
        'fat_g': fatG,
        'carbs_g': carbsG,
        'diet': diet.key,
        'allergies': jsonEncode(allergies.map((a) => a.key).toList()),
        'meals_per_day': mealsPerDay,
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
    return UserProfile(
      id: (map['id'] as int?) ?? 1,
      dailyCalories: (map['daily_calories'] as int?) ?? 2000,
      proteinG: (map['protein_g'] as int?) ?? 150,
      fatG: (map['fat_g'] as int?) ?? 67,
      carbsG: (map['carbs_g'] as int?) ?? 200,
      diet: Diet.fromKey(map['diet'] as String? ?? 'none'),
      allergies:
          rawAllergies.map((k) => Allergen.fromKey(k as String)).toList(),
      mealsPerDay: (map['meals_per_day'] as int?) ?? 3,
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
      '$proteinG/$fatG/$carbsG, ${diet.key}, аллергии: '
      '${allergies.map((a) => a.key).join(",")}, приёмов: $mealsPerDay)';
}
