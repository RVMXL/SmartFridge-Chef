/// Репозиторий встроенной базы рецептов (assets/data/recipes.json).
///
/// Загружает JSON один раз и кэширует. В проде источником служит
/// rootBundle (актив из pubspec); в тестах подаётся загрузчик из файла
/// или строки — репозиторий не зависит от Flutter-байндингов.
library;

import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../data/models/recipe.dart';

/// Путь к встроенной базе внутри бандла приложения.
const String kRecipesAssetPath = 'assets/data/recipes.json';

/// Ожидаемый минимальный размер базы (защита от битой сборки).
const int kMinExpectedRecipes = 500;

class RecipeRepository {
  /// [_loadString] — поставщик содержимого JSON; по умолчанию rootBundle.
  RecipeRepository({Future<String> Function()? loadString})
      : _loadString = loadString ?? _defaultLoader;

  static Future<String> _defaultLoader() => rootBundle.loadString(
        kRecipesAssetPath,
      );

  final Future<String> Function() _loadString;
  List<Recipe>? _cache;

  /// Все рецепты базы (загрузка ленивая, одноразовая).
  Future<List<Recipe>> loadAll() async {
    final cached = _cache;
    if (cached != null) return cached;
    final raw = await _loadString();
    final doc = jsonDecode(raw) as Map<String, Object?>;
    if (doc['schema'] != 'recipes.v1') {
      throw StateError('Неизвестная схема базы рецептов: '
          '${doc['schema']}');
    }
    final list = (doc['recipes'] as List<dynamic>)
        .map((e) => Recipe.fromJson(e as Map<String, Object?>))
        .toList(growable: false);
    if (list.length < kMinExpectedRecipes) {
      throw StateError('База рецептов урезана: ${list.length} < '
          '$kMinExpectedRecipes');
    }
    _cache = List.unmodifiable(list);
    return _cache!;
  }

  /// Рецепт по идентификатору или null.
  Future<Recipe?> byId(String id) async {
    final all = await loadAll();
    for (final r in all) {
      if (r.id == id) return r;
    }
    return null;
  }

  /// Снимок списка для синхронного скоринга (после loadAll()).
  List<Recipe> get cachedAll {
    final cached = _cache;
    if (cached == null) {
      throw StateError('База ещё не загружена: сначала вызовите loadAll()');
    }
    return cached;
  }
}
