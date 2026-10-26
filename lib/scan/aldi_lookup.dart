/// Цены Aldi Süd (Германия) — каталог api.aldi-sued.de (v0.5.8,
/// эксперимент; общий контракт [PriceHit]).
///
/// Сайт aldi-sued.de — SPA поверх публичного JSON-API без авторизации
/// (эндпоинты сняты с исходников ByteSizedMarius/aldiscount, 2026):
///
///   GET https://api.aldi-sued.de/v3/product-search
///       ?serviceType=walk-in&currency=EUR&limit=12&offset=0
///       &sort=relevance&q={запрос}
///
/// Ответ: {"meta":{pagination,facets}, "data":[{sku, name, brandName,
/// sellingSize, price:{amount, amountRelevant, wasPriceDisplay,
/// currencySymbol}, notForSale, discontinued, …}]}. Центы — целыми
/// евроцентами: amount = цена полки, amountRelevant = к оплате
/// (весовые товары); wasPriceDisplay — зачёркнутая цена при скидке
/// («2,49 €» — немецкий формат с запятой).
///
/// ГРАНИЦЫ: limit принимает только {12, 16, 24, 30, 32, 48, 60}; часть
/// ответов об ошибке приходит с HTTP 200 в конверте {"errors": [...]};
/// Akamai отклоняет запросы с кастомным User-Agent — заголовок не
/// переопределяется. С датацентровых IP и VPN возможен 403 — запросы
/// идут ПРЯМО С УСТРОЙСТВА, при блокировке цена просто не подставляется.
/// Поиск по названию: штрих-кодов в выдаче нет (как у Пятёрочки).
library;

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'price_source.dart';

export 'price_source.dart'
    show PriceFailReason, PriceHit, PriceUnavailable, normalizeForMatch;

/// Чистый парсер ответа /v3/product-search. Битые позиции пропускаются;
/// снятые с продажи (discontinued) не предлагаются.
List<PriceHit> parseAldiSearchJson(Map<String, dynamic> json) {
  final errors = json['errors'];
  if (errors is List && errors.isNotEmpty) {
    // Конверт ошибки с HTTP 200 — источник «недоступен», не «пусто».
    throw const PriceUnavailable(PriceFailReason.blocked);
  }

  final raw = json['data'];
  if (raw is! List) return const [];

  final hits = <PriceHit>[];
  for (final item in raw) {
    if (item is! Map<String, dynamic>) continue;
    final name = (item['name'] as String?)?.trim() ?? '';
    if (name.isEmpty) continue;
    if (item['discontinued'] == true) continue;

    final price = item['price'];
    if (price is! Map<String, dynamic>) continue;

    // К оплате: amountRelevant (весовые товары), иначе цена полки amount.
    final cents =
        _centValue(price['amountRelevant']) ?? _centValue(price['amount']);
    if (cents == null || cents <= 0) continue;

    final oldPrice = _parseEuroDisplay(price['wasPriceDisplay'] as String?);
    hits.add(PriceHit(
      name: _displayName(brand: item['brandName'] as String?, name: name),
      price: cents / 100.0,
      oldPrice:
          (oldPrice != null && oldPrice > cents / 100.0) ? oldPrice : null,
      packageQuantity: _cleanText(item['sellingSize'] as String?),
      currencySymbol:
          _cleanText(price['currencySymbol'] as String?) ?? '€',
    ));
  }
  return hits;
}

/// Лучшее совпадение с запросом (общий матчер, см. [pickBestPriceHit]).
PriceHit? pickBestAldiHit(List<PriceHit> hits, String query) =>
    pickBestPriceHit(hits, query);

/// Целые евроценты: int как есть, строка без пробелов/точек-разделителей.
int? _centValue(Object? raw) {
  if (raw is int) return raw;
  if (raw is num) return raw.round();
  if (raw is String) {
    final cleaned = raw.replaceAll(RegExp(r'[\s.]'), '');
    return int.tryParse(cleaned);
  }
  return null;
}

/// «2,49 €» → 2.49 (немецкий формат); не число — null.
double? _parseEuroDisplay(String? display) {
  if (display == null) return null;
  final match = RegExp(r'(\d+(?:[.,]\d+)?)').firstMatch(display);
  if (match == null) return null;
  return double.tryParse(match.group(1)!.replaceAll(',', '.'));
}

String _displayName({String? brand, required String name}) {
  final b = _cleanText(brand);
  if (b == null || name.toLowerCase().startsWith(b.toLowerCase())) {
    return name;
  }
  return '$b $name';
}

String? _cleanText(String? raw) {
  final v = raw?.replaceAll(RegExp(r'\s+'), ' ').trim() ?? '';
  return v.isEmpty ? null : v;
}

/// HTTP-клиент поиска Aldi Süd. Неудачи — только [PriceUnavailable]:
/// network (таймаут/нет связи), blocked (403 Akamai, конверт ошибок,
/// не-JSON). Заголовок User-Agent сознательно НЕ переопределяется —
/// кастомный UA отклоняется.
class AldiService {
  AldiService({http.Client? httpClient, this.timeout = const Duration(seconds: 8)})
      : _client = httpClient;

  static const String _host = 'api.aldi-sued.de';

  /// Допустимые размеры страницы /v3/product-search (см. шапку).
  static const List<int> allowedLimits = [12, 16, 24, 30, 32, 48, 60];

  final http.Client? _client;
  final Duration timeout;

  /// Поиск по названию по всей сети Aldi Süd (магазины через
  /// serviceType=walk-in; цена — полочная, без выбора конкретного магазина).
  Future<List<PriceHit>> search({
    required String query,
    int limit = 12,
  }) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return const [];
    final pageLimit = allowedLimits.contains(limit) ? limit : 12;

    final uri = Uri.https(_host, '/v3/product-search', {
      'serviceType': 'walk-in',
      'currency': 'EUR',
      'limit': '$pageLimit',
      'offset': '0',
      'sort': 'relevance',
      'q': cleanQuery,
    });

    final http.Response response;
    try {
      // ВАЖНО: без кастомного User-Agent (см. шапку библиотеки).
      response = await (_client ?? http.Client())
          .get(uri, headers: {'Accept': 'application/json'})
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
    return parseAldiSearchJson(decoded);
  }
}
