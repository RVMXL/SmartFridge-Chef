/// Цены Wegmans (США) — официальный открытый API (v0.5.8, эксперимент;
/// общий контракт [PriceHit]).
///
/// developer.wegmans.io — самосервисный портал: пользователь бесплатно
/// регистрируется и получает subscription-key (Azure API Management);
/// ключ хранится ТОЛЬКО в настройках приложения на устройстве. Пути и
/// версии — по официальной коллекции Wegmans.io (api-version=2018-10-18):
///
///   GET https://api.wegmans.io/stores
///       ?api-version=2018-10-18&subscription-key=…       — список магазинов
///   GET https://api.wegmans.io/products/search
///       ?q={запрос}&store={№}&api-version=…&subscription-key=…
///                                                        — поиск (sku+name)
///   GET https://api.wegmans.io/products/{sku}/prices/{store}
///       ?api-version=…&subscription-key=…                — цена магазина
///
/// Поиск возвращает sku и название без цены, поэтому флоу двухшаговый:
/// поиск → цены первых 4 sku (каждая — цена конкретного магазина, как в
/// Kroger). Неудачи: network (таймаут), auth (401/403 — отклонён ключ),
/// blocked (прочие не-200). В выдаче нет штрих-кодов/КБЖУ — пищевая
/// ценность по-прежнему из Open Food Facts. Магазины — северо-восток США.
library;

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'price_source.dart';

export 'price_source.dart'
    show PriceFailReason, PriceHit, PriceUnavailable, normalizeForMatch;

/// Магазин Wegmans (для выбора в настройках).
class WegmansStore {
  const WegmansStore({
    required this.storeNumber,
    required this.name,
    this.addressLine,
    this.city,
    this.state,
  });

  /// Номер магазина (в путях цен: /products/{sku}/prices/{store}).
  final String storeNumber;

  /// «Pittsford» — человеческое имя.
  final String name;
  final String? addressLine;
  final String? city;
  final String? state;

  String get shortAddress {
    final parts = [
      if (addressLine != null && addressLine!.isNotEmpty) addressLine,
      if (city != null && city!.isNotEmpty) city,
      if (state != null && state!.isNotEmpty) state,
    ];
    return parts.join(', ');
  }
}

/// Чистый парсер ответа /stores: список магазинов из stores[]/data[].
/// Схема по официальной документации (store: номер, name, address).
List<WegmansStore> parseWegmansStoresJson(Map<String, dynamic> json) {
  final raw = json['stores'] ?? json['data'];
  if (raw is! List) return const [];

  final result = <WegmansStore>[];
  for (final item in raw) {
    if (item is! Map<String, dynamic>) continue;
    final number = (item['store'] ?? item['storeNumber'] ?? item['number'])
        ?.toString() ?? '';
    if (number.isEmpty) continue;
    final address = item['address'];
    String? field(Object? v) {
      final s = v?.toString().trim();
      return (s == null || s.isEmpty) ? null : s;
    }

    result.add(WegmansStore(
      storeNumber: number,
      name: field(item['name']) ?? 'Wegmans',
      addressLine: address is Map<String, dynamic>
          ? field(address['addressLine1'] ?? address['addressLine'])
          : field(address),
      city: address is Map<String, dynamic> ? field(address['city']) : null,
      state: address is Map<String, dynamic> ? field(address['state']) : null,
    ));
  }
  return result;
}

/// Чистый парсер ответа /products/search: результаты {sku, name} без цены.
/// Ключ результата — пара (sku, name), цена добирается отдельным запросом.
List<({String sku, String name})> parseWegmansSearchJson(
    Map<String, dynamic> json) {
  final raw = json['results'] ?? json['data'];
  if (raw is! List) return const [];

  final found = <({String sku, String name})>[];
  for (final item in raw) {
    if (item is! Map<String, dynamic>) continue;
    final sku = item['sku']?.toString() ?? '';
    final name = ((item['name'] ?? item['description']) as String?)
            ?.trim() ?? '';
    if (sku.isEmpty || sku == 'null' || name.isEmpty) continue;
    found.add((sku: sku, name: name));
  }
  return found;
}

/// Чистый парсер ответа /products/{sku}/prices/{store}: {prices: [...]}.
/// Берём первую цену (текущая розница магазина); promo-поля, если есть,
/// уходят в oldPrice.
double? parseWegmansPriceJson(Map<String, dynamic> json) {
  final raw = json['prices'] ?? json['data'];
  if (raw is! List) return null;
  for (final item in raw) {
    if (item is! Map<String, dynamic>) continue;
    final price = parsePriceValue(item['price']);
    if (price != null && price > 0) return price;
  }
  return null;
}

/// HTTP-клиент Wegmans API. Неудачи бросаются только как
/// [PriceUnavailable] (см. шапку).
class WegmansService {
  WegmansService({http.Client? httpClient, this.timeout = const Duration(seconds: 8)})
      : _client = httpClient;

  static const String _host = 'api.wegmans.io';
  static const String _apiVersion = '2018-10-18';

  /// Сколько sku обрабатывать ценами на один поиск (каждый — отдельный
  /// запрос /prices; экономим лимиты ключа пользователя).
  static const int pricedResults = 4;

  final http.Client? _client;
  final Duration timeout;

  http.Client get _effectiveClient => _client ?? http.Client();

  /// Магазины для выбора в настройках.
  Future<List<WegmansStore>> stores({required String subscriptionKey}) async {
    if (subscriptionKey.trim().isEmpty) return const [];
    final uri = Uri.https(_host, '/stores', {
      'api-version': _apiVersion,
      'subscription-key': subscriptionKey.trim(),
    });
    final body = await _getJson(uri);
    return parseWegmansStoresJson(body);
  }

  /// Поиск цены по названию в выбранном магазине: /products/search →
  /// цены первых [pricedResults] sku. Хиты без цены пропускаются.
  Future<List<PriceHit>> search({
    required String subscriptionKey,
    required String storeNumber,
    required String query,
  }) async {
    final key = subscriptionKey.trim();
    final store = storeNumber.trim();
    final cleanQuery = query.trim();
    if (key.isEmpty || store.isEmpty || cleanQuery.isEmpty) return const [];

    final searchUri = Uri.https(_host, '/products/search', {
      'q': cleanQuery,
      'store': store,
      'api-version': _apiVersion,
      'subscription-key': key,
    });
    final searchBody = await _getJson(searchUri);
    final found = parseWegmansSearchJson(searchBody);
    if (found.isEmpty) return const [];

    final hits = <PriceHit>[];
    for (final entry in found.take(pricedResults)) {
      final priceUri = Uri.https(
          _host, '/products/${entry.sku}/prices/$store', {
        'api-version': _apiVersion,
        'subscription-key': key,
      });
      try {
        final priceBody = await _getJson(priceUri);
        final price = parseWegmansPriceJson(priceBody);
        if (price == null) continue;
        hits.add(PriceHit(
          name: entry.name,
          price: price,
          currencySymbol: r'$',
        ));
      } on PriceUnavailable catch (e) {
        // Цена отдельного sku не получена — не валим весь поиск.
        if (e.reason == PriceFailReason.auth) rethrow;
        continue;
      }
    }
    return hits;
  }

  /// GET с subscription-key; 401/403 → auth, HTML/не-200 → blocked.
  Future<Map<String, dynamic>> _getJson(Uri uri) async {
    final http.Response response;
    try {
      response = await _effectiveClient.get(uri, headers: {
        'Accept': 'application/json',
      }).timeout(timeout);
    } on Exception catch (e) {
      throwNetwork(e);
    }

    final body = utf8.decode(response.bodyBytes, allowMalformed: true);
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw const PriceUnavailable(PriceFailReason.auth);
    }
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
