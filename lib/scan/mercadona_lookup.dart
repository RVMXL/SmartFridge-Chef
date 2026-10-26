/// Цены Mercadona (Испания) — каталог tienda.mercadona.es (v0.5.8,
/// эксперимент; общий контракт [PriceHit]).
///
/// Открытый каталог веб-фронта не требует ключей и авторизации, поискового
/// эндпоинта у него НЕТ (проверено 2026-10: /api/search → 404). Поэтому
/// поиск по названию делается локально: сервис один раз собирает индекс
/// товаров по всем категориям (26 верхних → 152 категории 1-го уровня,
/// примерно 20–40 секунд), кэширует его в памяти и SharedPreferences и
/// дальше отвечает мгновенно. Индекс устаревает через [kCatalogTtl] и
/// обновляется в фоне при первом поиске после истечения срока.
///
///   GET https://tienda.mercadona.es/api/categories/        — дерево
///   GET https://tienda.mercadona.es/api/categories/{id}/   — категория
/// Продукт: display_name, price_instructions.unit_price (цена за упаковку,
/// строка в евро), price_instructions.previous_unit_price (цена до скидки),
/// packaging, unit_size + size_format. Прямые топ-идентификаторы
/// (/api/categories/12/) отдают 404 — фетчить можно только категории
/// 1-го уровня из дерева.
///
/// Цены — складские (без выбора магазина); запросы идут ПРЯМО С
/// УСТРОЙСТВА, наружу не передаётся ничего, кроме самого запроса каталога.
/// Любая неудача — [PriceUnavailable]: приложение остаётся без цены.
library;

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'price_source.dart';

export 'price_source.dart'
    show PriceFailReason, PriceHit, PriceUnavailable, normalizeForMatch;

/// Жизнь кэша индекса: цены Mercadona стабильны, акции меняются еженедельно.
const Duration kMercadonaCatalogTtl = Duration(days: 3);

/// Пауза между запросами категорий, чтобы не грузить каталог залпом.
const Duration kMercadonaPacing = Duration(milliseconds: 100);

/// Чистый парсер ответа /api/categories/{id}/: рекурсивно обходит
/// categories[] и собирает products[] в [PriceHit]. Битые позиции
/// пропускаются. Неизвестные поля игнорируются.
List<PriceHit> parseMercadonaCategoryJson(Map<String, dynamic> json) {
  final hits = <PriceHit>[];
  void walkCategory(Map<String, dynamic> node) {
    final children = node['categories'];
    if (children is List) {
      for (final child in children) {
        if (child is Map<String, dynamic>) walkCategory(child);
      }
    }
    final products = node['products'];
    if (products is List) {
      for (final product in products) {
        if (product is Map<String, dynamic>) {
          final hit = _parseMercadonaProduct(product);
          if (hit != null) hits.add(hit);
        }
      }
    }
  }

  walkCategory(json);
  return hits;
}

PriceHit? _parseMercadonaProduct(Map<String, dynamic> item) {
  // Непубликуемые товары пропускаем целиком.
  if (item['published'] == false) return null;

  final name = (item['display_name'] as String?)?.trim() ?? '';
  if (name.isEmpty) return null;

  final pi = item['price_instructions'];
  if (pi is! Map<String, dynamic>) return null;

  final price = parsePriceValue(pi['unit_price']);
  if (price == null || price <= 0) return null;

  var oldPrice = parsePriceValue(pi['previous_unit_price']);
  if (oldPrice != null && oldPrice <= price) oldPrice = null;

  return PriceHit(
    name: name,
    price: price,
    oldPrice: oldPrice,
    packageQuantity: _mercadonaQuantity(
      packaging: item['packaging'] as String?,
      unitSize: pi['unit_size'],
      sizeFormat: pi['size_format'] as String?,
    ),
    currencySymbol: '€',
  );
}

/// Фасовка «Garrafa · 5 l»; без упаковки — просто «5 l», без размеров — null.
String? _mercadonaQuantity({
  String? packaging,
  Object? unitSize,
  String? sizeFormat,
}) {
  final parts = <String>[];
  final pack = packaging?.replaceAll(RegExp(r'\s+'), ' ').trim() ?? '';
  if (pack.isNotEmpty) parts.add(pack);

  final size = unitSize;
  final format = sizeFormat?.trim() ?? '';
  if (size is num && size > 0 && format.isNotEmpty) {
    final shown =
        size == size.roundToDouble() ? size.round().toString() : '$size';
    parts.add('$shown $format');
  }
  return parts.isEmpty ? null : parts.join(' · ');
}

// ---------------------------------------------------------------------------
// Компактное хранение индекса: {"n": имя, "p": цена, "o": старая, "q": фасовка}
// ---------------------------------------------------------------------------

/// Кодирование списка хитов в компактный JSON (SharedPreferences не
/// любит большие структуры — экономим каждый байт: ~7 000 товаров).
String encodeMercadonaIndex(List<PriceHit> hits) {
  final list = [
    for (final h in hits)
      {
        'n': h.name,
        'p': h.price,
        if (h.oldPrice != null) 'o': h.oldPrice,
        if (h.packageQuantity != null) 'q': h.packageQuantity,
      },
  ];
  return jsonEncode(list);
}

/// Обратное преобразование; битые записи пропускаются.
List<PriceHit> decodeMercadonaIndex(String raw) {
  final Object decoded;
  try {
    decoded = jsonDecode(raw);
  } on FormatException {
    return const [];
  }
  if (decoded is! List) return const [];
  final hits = <PriceHit>[];
  for (final entry in decoded) {
    if (entry is! Map<String, dynamic>) continue;
    final price = parsePriceValue(entry['p']);
    final name = (entry['n'] as String?)?.trim() ?? '';
    if (name.isEmpty || price == null || price <= 0) continue;
    final old = parsePriceValue(entry['o']);
    hits.add(PriceHit(
      name: name,
      price: price,
      oldPrice: (old != null && old > price) ? old : null,
      packageQuantity: (entry['q'] as String?)?.trim(),
      currencySymbol: '€',
    ));
  }
  return hits;
}

/// HTTP-клиент каталога Mercadona с локальным индексом-кэшем.
/// Все методы бросают только [PriceUnavailable].
class MercadonaService {
  MercadonaService({
    http.Client? httpClient,
    this.timeout = const Duration(seconds: 8),
    this.pacing = kMercadonaPacing,
    this.ttl = kMercadonaCatalogTtl,
  }) : _client = httpClient;

  static const String _host = 'tienda.mercadona.es';

  static const String _indexPref = 'pref_mercadona_catalog_json';
  static const String _indexAtPref = 'pref_mercadona_catalog_at';

  final http.Client? _client;
  final Duration timeout;
  final Duration pacing;
  final Duration ttl;

  List<PriceHit>? _index;
  Future<List<PriceHit>?>? _building;

  http.Client get _effectiveClient => _client ?? http.Client();

  /// Кандидаты для поиска: весь индекс каталога. Подбор совпадения —
  /// общий матчер [pickBestPriceHit] на стороне вызова.
  ///
  /// Первый вызов на устройстве без кэша собирает индекс по сети
  /// (десятки секунд); с кэшем — мгновенный. Устаревший кэш отдаётся
  /// сразу, а обновление идёт в фоне.
  Future<List<PriceHit>> search({required String query}) async {
    if (query.trim().isEmpty) return const [];
    final index = await ensureIndex();
    return index ?? const <PriceHit>[];
  }

  /// Гарантирует наличие индекса (single-flight: параллельные вызовы
  /// ждут одну и ту же сборку).
  Future<List<PriceHit>?> ensureIndex() {
    if (_index != null) return Future.value(_index);
    final running = _building;
    if (running != null) return running;
    final tracked = _loadOrBuild().whenComplete(() => _building = null);
    _building = tracked;
    return tracked;
  }

  Future<List<PriceHit>?> _loadOrBuild() async {
    final cached = await _loadFromPrefs();
    if (cached != null && cached.isNotEmpty) {
      _index = cached;
      if (await _isStale()) {
        // Фоновое обновление: текущий поиск отвечает по старому индексу.
        unawaited(_rebuildInBackground());
      }
      return _index;
    }
    try {
      return await _buildAndPersist();
    } on PriceUnavailable {
      rethrow;
    }
  }

  Future<void> _rebuildInBackground() async {
    try {
      await _buildAndPersist();
    } on PriceUnavailable {
      // Стройка не удалась — продолжаем жить со старым индексом.
    }
  }

  Future<List<PriceHit>> _buildAndPersist() async {
    final hits = await _buildIndexFromNetwork();
    _index = hits;
    await _persist(hits);
    return hits;
  }

  Future<List<PriceHit>> _buildIndexFromNetwork() async {
    final root = await _getJson(Uri.https(_host, '/api/categories/'));
    final tops = root['results'];
    if (tops is! List) {
      throw const PriceUnavailable(PriceFailReason.blocked);
    }

    // Фетчить можно только категории 1-го уровня (прямые топ-коды дают 404).
    final levelOneIds = <int>[];
    for (final top in tops) {
      if (top is! Map<String, dynamic>) continue;
      final children = top['categories'];
      if (children is! List) continue;
      for (final child in children) {
        if (child is! Map<String, dynamic>) continue;
        final id = child['id'];
        if (id is int) levelOneIds.add(id);
      }
    }
    if (levelOneIds.isEmpty) {
      throw const PriceUnavailable(PriceFailReason.blocked);
    }

    final hits = <PriceHit>[];
    for (var i = 0; i < levelOneIds.length; i++) {
      final category = await _getJson(
        Uri.https(_host, '/api/categories/${levelOneIds[i]}/'),
      );
      hits.addAll(parseMercadonaCategoryJson(category));
      if (i < levelOneIds.length - 1) {
        await Future<void>.delayed(pacing);
      }
    }
    return hits;
  }

  Future<List<PriceHit>?> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_indexPref);
      if (raw == null || raw.isEmpty) return null;
      return decodeMercadonaIndex(raw);
    } catch (_) {
      return null; // prefs недоступны (тесты) — только сетевая стройка.
    }
  }

  Future<bool> _isStale() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final at = prefs.getInt(_indexAtPref) ?? 0;
      final age = DateTime.now().millisecondsSinceEpoch - at;
      return age > ttl.inMilliseconds;
    } catch (_) {
      return false;
    }
  }

  Future<void> _persist(List<PriceHit> hits) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_indexPref, encodeMercadonaIndex(hits));
      await prefs.setInt(
          _indexAtPref, DateTime.now().millisecondsSinceEpoch);
    } catch (_) {
      // prefs недоступны — индекс живёт в памяти до перезапуска.
    }
  }

  Future<Map<String, dynamic>> _getJson(Uri uri) async {
    final http.Response response;
    try {
      response = await _effectiveClient
          .get(uri, headers: {
            'Accept': 'application/json',
            'User-Agent': _mobileUserAgent,
            'Referer': 'https://tienda.mercadona.es/',
          })
          .timeout(timeout);
    } on Exception catch (e) {
      throwNetwork(e);
    }

    final body = utf8.decode(response.bodyBytes, allowMalformed: true);
    if (response.statusCode != 200 || looksLikeHtml(body)) {
      throw const PriceUnavailable(PriceFailReason.blocked);
    }
    final Object decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      throw const PriceUnavailable(PriceFailReason.blocked);
    }
    if (decoded is! Map<String, dynamic>) {
      throw const PriceUnavailable(PriceFailReason.blocked);
    }
    return decoded;
  }
}

/// Мобильный Chrome UA — как у веб-фронта tienda.mercadona.es.
const String _mobileUserAgent =
    'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36';
