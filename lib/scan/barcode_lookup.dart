/// Автопоиск продукта по штрих-коду (Шаг 3.1).
///
/// Порядок: локальный кэш → открытая база Open Food Facts (без ключей
/// и аккаунтов, только GET-запрос самого кода) → кэширование найденного.
/// Любая ошибка сети/разбора даёт null — приложение остаётся offline-first:
/// пользователь просто заполняет форму вручную, как раньше.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';

import '../ai/ingredient_matcher.dart';
import '../core/constants.dart';
import '../data/dao/barcode_cache_dao.dart';
import '../data/data_store.dart';
import '../data/models/product.dart';

/// Найденный товар: имя для карточки и категория (если определена).
class BarcodeLookupResult {
  const BarcodeLookupResult({
    required this.name,
    required this.category,
    required this.fromCache,
  });

  final String name;
  final ProductCategory? category;
  final bool fromCache;
}

/// Сервис автопоиска. [client] и [openDb] внедряются для тестов.
class BarcodeLookupService {
  BarcodeLookupService({
    this.client,
    Future<Database> Function()? openDb,
    this.timeout = const Duration(seconds: 6),
  }) : _openDb = openDb ?? AppDataStore.instance.database;

  static const String _host = 'world.openfoodfacts.org';

  /// Open Food Facts просит приложение представляться в User-Agent
  /// (PLAT-4/VER-1: версия берётся из kAppVersion, а не фиксированная «0.4»).
  static final String _userAgent =
      'SmartFridge-Chef/$kAppVersion (Flutter; +https://github.com/RVMXL/SmartFridge-Chef)';

  /// HTTP-клиент (внедряется в тестах; в рантайме — обычный).
  final http.Client? client;
  http.Client? _ownClient;

  /// NET-1 (аудит 2026-10-28): один переиспользуемый клиент на сервис.
  /// http.Client() на каждый запрос утекал вместе с keep-alive-пулом
  /// (пик — 153 клиента за одну сборку индекса Mercadona); сервис —
  /// синглтон приложения, собственный клиент живёт столько же.
  http.Client get _effectiveClient {
    final injected = client;
    if (injected != null) return injected;
    return _ownClient ??= http.Client();
  }

  /// Закрыть собственный клиент (инжектированный извне не наш — не трогаем).
  void dispose() => _ownClient?.close();


  final Future<Database> Function() _openDb;
  final Duration timeout;

  bool _dbReady = false;
  BarcodeCacheDao? _dao;

  Future<BarcodeCacheDao?> _cache() async {
    if (!_dbReady) {
      try {
        _dao = BarcodeCacheDao(await _openDb());
        _dbReady = true;
      } catch (_) {
        // База недоступна — поиск всё равно возможен, только без кэша.
      }
    }
    return _dao;
  }

  /// Ищет товар: кэш → сеть. null — не найдено или нет сети.
  Future<BarcodeLookupResult?> lookup(
    String code, {
    String langCode = 'ru',
  }) async {
    final clean = code.trim();
    if (clean.length < 4) return null;

    // 1. Кэш: мгновенно и офлайн.
    final dao = await _cache();
    final cached = await dao?.get(clean);
    if (cached != null) {
      return BarcodeLookupResult(
        name: cached.name,
        category: cached.category,
        fromCache: true,
      );
    }

    // 2. Открытая база Open Food Facts.
    final hit = await _fetchFromOpenFoodFacts(clean, langCode);
    if (hit == null) return null;

    // 3. Запоминаем навсегда — следующий скан работает офлайн.
    await dao?.put(clean, hit.name, hit.category);
    return BarcodeLookupResult(
      name: hit.name,
      category: hit.category,
      fromCache: false,
    );
  }

  Future<BarcodeLookupResult?> _fetchFromOpenFoodFacts(
    String code,
    String langCode,
  ) async {
    try {
      final uri = Uri.https(_host, '/api/v2/product/$code.json', {
        'fields': 'product_name,product_name_ru,generic_name,'
            'brands,categories_tags',
      });
      final response = _effectiveClient
          .get(uri, headers: {'User-Agent': _userAgent})
          .timeout(timeout);
      final body = await response;
      if (body.statusCode != 200) return null;
      final json = jsonDecode(utf8.decode(body.bodyBytes));
      if (json is! Map<String, dynamic>) return null;
      return parseOpenFoodFactsJson(json, langCode: langCode);
    } on TimeoutException {
      return null;
    } on SocketException {
      return null;
    } on FormatException {
      return null;
    } catch (_) {
      return null;
    }
  }
}

/// Нормализация строки: схлопнуть пробелы, обрезать края, null для пустых.
String? _cleanField(String? raw) {
  if (raw == null) return null;
  final v = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
  return v.isEmpty ? null : v;
}

/// Чистый парсер ответа Open Food Facts API v2 (без сети — удобно тестировать).
///
/// Ожидает {"status": 1, "product": {...}}; возвращает null для status 0,
/// пустых данных и мусора. Имя выбирается по языку: для русского сначала
/// product_name_ru, для остальных — product_name; бренд добавляется
/// в скобках, если он ещё не в названии.
BarcodeLookupResult? parseOpenFoodFactsJson(
  Map<String, dynamic> json, {
  required String langCode,
}) {
  if (json['status'] != 1) return null;
  final product = json['product'];
  if (product is! Map<String, dynamic>) return null;

  final ruName = _cleanField(product['product_name_ru'] as String?);
  final intlName = _cleanField(product['product_name'] as String?);
  final generic = _cleanField(product['generic_name'] as String?);

  // Русская локаль: локализованное имя приоритетнее; иначе —
  // международное (часто это оригинальное название товара), потом общее.
  final candidates = langCode.toLowerCase().startsWith('ru')
      ? [ruName, intlName, generic]
      : [intlName, generic, ruName];
  var name = candidates.firstWhere((n) => n != null, orElse: () => null);

  final brand = _cleanBrand(product['brands'] as String?);
  if (name == null) {
    name = brand; // Названия нет — хотя бы бренд («Coca-Cola»).
  } else if (brand != null &&
      !name.toLowerCase().contains(brand.toLowerCase())) {
    final combined = '$name ($brand)';
    name = combined.length <= 80 ? combined : name;
  }
  if (name == null) return null;
  if (name.length > 80) {
    // Обрезаем по границе слова, чтобы карточка не ломалась.
    final cut = name.substring(0, 80);
    final space = cut.lastIndexOf(' ');
    name = space > 40 ? '${cut.substring(0, space)}…' : '$cut…';
  }

  return BarcodeLookupResult(
    name: name,
    // Категория из тегов OFF; если их нет/не распознали — угадываем
    // по названию через словарь матчера: без этого форма ставила бы
    // generic «другое» (+14 дней) вместо типового срока категории.
    category: _categoryFromTags(product['categories_tags']) ??
        const IngredientMatcher().categoryFor(name),
    fromCache: false,
  );
}

/// Первое имя бренда из поля brands или null, если это юридическое
/// название («COCA-COLA SERVICES SA/NV», «ООО Молвест») — такие
/// в карточке товара выглядят шумно.
String? _cleanBrand(String? raw) {
  final brand = _cleanField(raw?.split(',').first);
  if (brand == null || brand.length > 30) return null;
  final padded = ' ${brand.toLowerCase()} ';
  const corporate = [
    ' sa/nv', ' s.a.', ' s.a ', ' n.v.', ' llc', ' ltd', ' inc.',
    ' gmbh', ' plc', ' corp.', ' oj', ' ag ', ' ag.', ' co.',
    ' ооо', ' зао', ' оао', ' пао', ' ао ', ' ао)',
    ' trading', ' services', ' international', ' company', ' group',
    ' holding', ' foods', ' products',
  ];
  for (final marker in corporate) {
    if (padded.contains(marker)) return null;
  }
  return brand;
}

/// Маппинг тегов категорий Open Food Facts на категории приложения.
/// Проверяются по порядку: первый узнанный тег выигрывает.
ProductCategory? _categoryFromTags(dynamic tags) {
  if (tags is! List) return null;
  for (final tag in tags) {
    final mapped = _categoryByOffTag[tag as String? ?? ''];
    if (mapped != null) return mapped;
  }
  return null;
}

const Map<String, ProductCategory> _categoryByOffTag = {
  // Молочное и яйца.
  'en:milks': ProductCategory.dairy,
  'en:dairy': ProductCategory.dairy,
  'en:cheeses': ProductCategory.dairy,
  'en:fermented-dairy-products': ProductCategory.dairy,
  'en:fermented-milk-products': ProductCategory.dairy,
  'en:yogurts': ProductCategory.dairy,
  'en:butter': ProductCategory.dairy,
  'en:cream': ProductCategory.dairy,
  'en:eggs': ProductCategory.dairy,
  // Мясо и рыба.
  'en:meats': ProductCategory.meat,
  'en:meat': ProductCategory.meat,
  'en:chicken': ProductCategory.meat,
  'en:sausages': ProductCategory.meat,
  'en:delicatessen': ProductCategory.meat,
  'en:fish': ProductCategory.fish,
  'en:fishes': ProductCategory.fish,
  'en:seafood': ProductCategory.fish,
  'en:canned-fish': ProductCategory.fish,
  // Овощи и фрукты.
  'en:vegetables': ProductCategory.vegetables,
  'en:vegetable': ProductCategory.vegetables,
  'en:canned-vegetables': ProductCategory.vegetables,
  'en:pickles': ProductCategory.vegetables,
  'en:fruits': ProductCategory.fruits,
  'en:fruit': ProductCategory.fruits,
  'en:canned-fruits': ProductCategory.fruits,
  'en:berries': ProductCategory.fruits,
  // Хлеб и выпечка.
  'en:breads': ProductCategory.bakery,
  'en:bread': ProductCategory.bakery,
  'en:baked-goods': ProductCategory.bakery,
  'en:pastries': ProductCategory.bakery,
  // Крупы, макароны, мука.
  'en:cereals': ProductCategory.grains,
  'en:cereals-and-potatoes': ProductCategory.grains,
  'en:pastas': ProductCategory.grains,
  'en:pasta': ProductCategory.grains,
  'en:rice': ProductCategory.grains,
  'en:flours': ProductCategory.grains,
  'en:groats': ProductCategory.grains,
  // Заморозка.
  'en:frozen-foods': ProductCategory.frozen,
  'en:frozen': ProductCategory.frozen,
  'en:ice-creams': ProductCategory.frozen,
  // Напитки.
  'en:beverages': ProductCategory.beverages,
  'en:beverage': ProductCategory.beverages,
  'en:juices': ProductCategory.beverages,
  'en:juice': ProductCategory.beverages,
  'en:waters': ProductCategory.beverages,
  'en:carbonated-drinks': ProductCategory.beverages,
  'en:teas': ProductCategory.beverages,
  'en:coffees': ProductCategory.beverages,
  // Сладкое и снеки.
  'en:snacks': ProductCategory.sweets,
  'en:sweet-snacks': ProductCategory.sweets,
  'en:sweets': ProductCategory.sweets,
  'en:confectionery': ProductCategory.sweets,
  'en:chocolates': ProductCategory.sweets,
  'en:candies': ProductCategory.sweets,
  'en:biscuits': ProductCategory.sweets,
  'en:cookies': ProductCategory.sweets,
  // Соусы и приправы.
  'en:sauces': ProductCategory.condiments,
  'en:condiments': ProductCategory.condiments,
  'en:salad-dressings': ProductCategory.condiments,
  'en:spices': ProductCategory.condiments,
  'en:oils': ProductCategory.condiments,
  'en:vegetable-oils': ProductCategory.condiments,
  'en:mayonnaises': ProductCategory.condiments,
  'en:ketchups': ProductCategory.condiments,
};
