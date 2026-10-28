/// Цены Kroger (США) — официальный Public API (v0.5.6).
///
/// developer.kroger.com, Public tier (самосервисная бесплатная регистрация):
/// пользователь сам создаёт приложение и получает client_id/client_secret,
/// ключ хранится ТОЛЬКО в настройках приложения на устройстве. Авторизация
/// — OAuth2 client_credentials (сервисный токен без логина пользователя):
///   POST https://api.kroger.com/v1/connect/oauth2/token
///   Authorization: Basic base64(client_id:client_secret)
///   grant_type=client_credentials&scope=product.compact
/// Дальше Bearer-токен (короткоживущий, кэшируется в памяти):
///   GET /v1/locations?filter.zipCode.near={zip}          — выбор магазина
///   GET /v1/products?filter.term={q}&filter.locationId=  — поиск цены
/// Лимит Public API — 10 000 вызовов/день на пару ключей.
/// В выдаче есть цена (price.regular/price.promo) и флаги исполнения
/// (instore/curbside/delivery); остатков на полке API не отдаёт
/// (stockLevel опционален) — «наличие» трактуем как «продаётся в магазине».
///
/// В отличие от Пятёрочки здесь нет WAF-заглушек: неудачи — это сеть
/// (network) или отклонённый ключ (auth, HTTP 401/403).
library;

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'price_source.dart';

/// Магазин из ответа Locations API (для выбора в настройках).
class KrogerLocation {
  const KrogerLocation({
    required this.locationId,
    required this.name,
    required this.chain,
    this.addressLine,
    this.city,
    this.state,
    this.zipCode,
    this.distanceMiles,
  });

  final String locationId;

  /// «Kroger - Loveland» — человеческое имя магазина.
  final String name;

  /// Бренд сети: KROGER / RALPHS / FRED MEYER / KING SOOPERS / …
  final String chain;
  final String? addressLine;
  final String? city;
  final String? state;
  final String? zipCode;
  final double? distanceMiles;

  /// Однострочное представление для списка выбора.
  String get shortAddress {
    final parts = [
      if (addressLine != null && addressLine!.isNotEmpty) addressLine,
      if (city != null && city!.isNotEmpty) city,
      if (state != null && state!.isNotEmpty) state,
    ];
    return parts.join(', ');
  }
}

/// Чистый парсер ответа /v1/locations (схема по официальной документации:
/// data[] с locationId/chain/name/address/geolocation).
List<KrogerLocation> parseKrogerLocationsJson(Map<String, dynamic> json) {
  final raw = json['data'];
  if (raw is! List) return const [];

  final result = <KrogerLocation>[];
  for (final item in raw) {
    if (item is! Map<String, dynamic>) continue;
    final id = (item['locationId'] ?? item['location_id'])?.toString() ?? '';
    if (id.isEmpty) continue;
    final address = item['address'];
    final geo = item['geolocation'];
    String? field(String? v) {
      final s = v?.trim();
      return (s == null || s.isEmpty) ? null : s;
    }

    result.add(KrogerLocation(
      locationId: id,
      name: field(jsonStr(item['name'])) ?? 'Kroger',
      chain: field(jsonStr(item['chain'])) ?? '',
      addressLine: field(address is Map<String, dynamic>
          ? jsonStr(address['addressLine1'])
          : null),
      city: field(
          address is Map<String, dynamic>
              ? jsonStr(address['city'])
              : null),
      state: field(
          address is Map<String, dynamic>
              ? jsonStr(address['state'])
              : null),
      zipCode: field(address is Map<String, dynamic>
          ? address['zipCode']?.toString()
          : null),
      distanceMiles: parsePriceValue(item['distance']),
    ));
    // geolocation парсить не нужно — пригодится только для карты.
    assert(geo == null || geo is Map<String, dynamic>);
  }
  return result;
}

/// Чистый парсер ответа /v1/products (data[] с description/items[].price).
List<PriceHit> parseKrogerProductsJson(Map<String, dynamic> json) {
  final raw = json['data'];
  if (raw is! List) return const [];

  final hits = <PriceHit>[];
  for (final item in raw) {
    if (item is! Map<String, dynamic>) continue;
    final name = (jsonStr(item['description']) ?? '').trim();
    if (name.isEmpty) continue;

    // Цена лежит в items[].price (regular/promo); товаров-вариантов может
    // быть несколько — берём первый с ценой.
    final items = item['items'];
    double? regular;
    double? promo;
    if (items is List) {
      for (final it in items) {
        if (it is! Map<String, dynamic>) continue;
        final p = it['price'];
        if (p is! Map<String, dynamic>) continue;
        regular = parsePriceValue(p['regular']);
        promo = parsePriceValue(p['promo']);
        if (regular != null) break;
      }
    }
    if (regular == null) continue;

    // Семантика как у Пятёрочки: в price — то, что платишь сейчас
    // (акционная цена, если активна), в oldPrice — «старая» цена.
    final promoActive = promo != null && promo > 0 && promo < regular;
    final current = promoActive ? promo : regular;

    // «Наличие»: instore-флаг с locationId-запроса; нет флага — считаем
    // доступным (запрос без locationId цену и не вернёт).
    final instore = item['instore'];
    hits.add(PriceHit(
      name: name,
      price: current,
      oldPrice: promoActive ? regular : null,
      isAvailable: instore is bool ? instore : true,
      packageQuantity: _cleanText(jsonStr(item['size'])),
      currencySymbol: r'$',
    ));
  }
  return hits;
}

String? _cleanText(String? raw) {
  final v = raw?.replaceAll(RegExp(r'\s+'), ' ').trim() ?? '';
  return v.isEmpty ? null : v;
}

/// HTTP-клиент Kroger Public API. Неудачи бросаются только как
/// [PriceUnavailable]: network — таймаут/нет связи; auth — ключ отклонён
/// (401/403 на токен или на запрос); blocked — прочие не-200.
class KrogerService {
  KrogerService({http.Client? httpClient, this.timeout = const Duration(seconds: 8)})
      : _client = httpClient;

  static const String _host = 'api.kroger.com';
  static const String _scope = 'product.compact';

  final http.Client? _client;
  http.Client? _ownClient;
  final Duration timeout;

  String? _cachedToken;
  DateTime _cachedUntil = DateTime.fromMillisecondsSinceEpoch(0);

  /// NET-1 (аудит 2026-10-28): один переиспользуемый клиент на сервис.
  /// http.Client() на каждый запрос утекал вместе с keep-alive-пулом
  /// (пик — 153 клиента за одну сборку индекса Mercadona); сервис —
  /// синглтон приложения, собственный клиент живёт столько же.
  http.Client get _effectiveClient {
    final injected = _client;
    if (injected != null) return injected;
    return _ownClient ??= http.Client();
  }

  /// Закрыть собственный клиент (инжектированный извне не наш — не трогаем).
  void dispose() => _ownClient?.close();

  /// Сервисный Bearer-токен (client_credentials) с кэшем в памяти.
  /// Бросает [PriceUnavailable] с reason auth при 401/403.
  Future<String> _accessToken(String clientId, String clientSecret) async {
    final now = DateTime.now();
    if (_cachedToken != null && now.isBefore(_cachedUntil)) {
      return _cachedToken!;
    }

    final basic = base64Encode(utf8.encode(
        '${clientId.trim()}:${clientSecret.trim()}'));
    final http.Response response;
    try {
      response = await _effectiveClient
          .post(
            Uri.https(_host, '/v1/connect/oauth2/token'),
            headers: {
              'Authorization': 'Basic $basic',
              'Content-Type': 'application/x-www-form-urlencoded',
              'Accept': 'application/json',
            },
            body: 'grant_type=client_credentials&scope=$_scope',
          )
          .timeout(timeout);
    } on Exception catch (e) {
      throwNetwork(e);
    }

    if (response.statusCode == 401 || response.statusCode == 403) {
      throw const PriceUnavailable(PriceFailReason.auth);
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
    final token = decoded['access_token']?.toString() ?? '';
    if (token.isEmpty) {
      throw const PriceUnavailable(PriceFailReason.auth);
    }
    final expiresIn =
        (decoded['expires_in'] is num) ? decoded['expires_in'] as num : 1800;
    // Запас 60 секунд — токен успевает дожить до запроса.
    _cachedToken = token;
    _cachedUntil =
        now.add(Duration(seconds: expiresIn.toInt() - 60 < 30 ? 30 : expiresIn.toInt() - 60));
    return token;
  }

  /// Поиск цены по названию в выбранном магазине (locationId из настроек).
  Future<List<PriceHit>> search({
    required String clientId,
    required String clientSecret,
    required String locationId,
    required String query,
    int limit = 12,
  }) async {
    final cleanLocation = locationId.trim();
    final cleanQuery = query.trim();
    if (cleanLocation.isEmpty ||
        cleanQuery.isEmpty ||
        clientId.trim().isEmpty ||
        clientSecret.trim().isEmpty) {
      return const [];
    }

    final token = await _accessToken(clientId, clientSecret);
    final uri = Uri.https(_host, '/v1/products', {
      'filter.term': cleanQuery,
      'filter.locationId': cleanLocation,
      'filter.limit': '$limit',
    });

    final body = await _getJson(uri, token);
    return parseKrogerProductsJson(body);
  }

  /// Магазины рядом с ZIP-кодом (настройки → выбор магазина).
  Future<List<KrogerLocation>> locations({
    required String clientId,
    required String clientSecret,
    required String zipCode,
    int limit = 15,
  }) async {
    final zip = zipCode.trim();
    if (zip.isEmpty || clientId.trim().isEmpty || clientSecret.trim().isEmpty) {
      return const [];
    }

    final token = await _accessToken(clientId, clientSecret);
    final uri = Uri.https(_host, '/v1/locations', {
      'filter.zipCode.near': zip,
      'filter.limit': '$limit',
    });

    final body = await _getJson(uri, token);
    return parseKrogerLocationsJson(body);
  }

  /// GET c Bearer-токеном; 401/403 → auth, HTML/не-200 → blocked.
  Future<Map<String, dynamic>> _getJson(Uri uri, String token) async {
    final http.Response response;
    try {
      response = await _effectiveClient
          .get(uri, headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          })
          .timeout(timeout);
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
