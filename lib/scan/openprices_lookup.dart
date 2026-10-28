/// Open Prices — открытая база цен проекта Open Food Facts (v0.5.6).
///
/// prices.openfoodfacts.org: REST API без ключей и регистрации, данные
/// под ODbL (краудсорс: чеки и ценники со всего мира). Покрытие неравномерное
/// (Европа плотнее, США растёт), поэтому источник — дополнительный: цена
/// подставляется, только если штрих-коды в базе нашлись. Запрос выполняется
/// ПРЯМО С УСТРОЙСТВА по уже отсканированному коду; наружу не передаётся
/// ничего, кроме самого штрих-кода.
///
///   GET https://prices.openfoodfacts.org/api/v1/prices
///       ?product_code={код}&limit={n}
/// Ответ: {"items":[{price, currency, date, price_is_discounted,
/// price_without_discount, location:{osm_name, osm_brand, …}, product:…}]}
/// Цена берётся самая свежая (date); для акционных записей
/// price_without_discount идёт в PriceHit.oldPrice.
library;

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/constants.dart';
import 'price_source.dart';

/// Символ валюты для ISO-кода Open Prices (популярные; остальное — код).
String currencySymbolFor(String? iso) {
  switch (iso?.toUpperCase()) {
    case 'RUB':
      return '₽';
    case 'USD':
      return r'$';
    case 'EUR':
      return '€';
    case 'GBP':
      return '£';
    case 'UAH':
      return '₴';
    case 'KZT':
      return '₸';
    case 'TRY':
      return '₺';
    case 'INR':
      return '₹';
    case 'CNY':
      return '¥';
    case 'JPY':
      return '¥';
    case 'BRL':
      return 'R\$';
    default:
      return iso == null || iso.isEmpty ? '₽' : '$iso ';
  }
}

/// Чистый парсер ответа /api/v1/prices. Битые записи пропускаются;
/// сортировка — по дате по убыванию (свежие первыми) независимо от
/// порядка выдачи.
List<PriceHit> parseOpenPricesJson(Map<String, dynamic> json) {
  final raw = json['items'];
  if (raw is! List) return const [];

  final parsed = <_OpenPricesRecord>[];
  for (final item in raw) {
    if (item is! Map<String, dynamic>) continue;
    final price = parsePriceValue(item['price']);
    if (price == null) continue;

    final discounted = item['price_is_discounted'] is bool
        ? item['price_is_discounted'] as bool
        : false;
    final withoutDiscount =
        parsePriceValue(item['price_without_discount']);

    final location = item['location'];
    String storeName = '';
    if (location is Map<String, dynamic>) {
      storeName = (jsonStr(location['osm_brand']) ??
              jsonStr(location['osm_name']) ??
              '')
          .trim();
    }
    final product = item['product'];
    final productName = product is Map<String, dynamic>
        ? (jsonStr(product['product_name']) ?? '').trim()
        : '';

    parsed.add(_OpenPricesRecord(
      hit: PriceHit(
        name: storeName.isEmpty ? 'Open Prices' : storeName,
        price: price,
        oldPrice: (discounted &&
                withoutDiscount != null &&
                withoutDiscount > price)
            ? withoutDiscount
            : null,
        packageQuantity: productName.isEmpty ? null : productName,
        currencySymbol: currencySymbolFor(item['currency']?.toString()),
      ),
      date: jsonStr(item['date']) ?? '',
    ));
  }
  parsed.sort((a, b) => b.date.compareTo(a.date));
  return parsed.map((r) => r.hit).toList(growable: false);
}

class _OpenPricesRecord {
  const _OpenPricesRecord({required this.hit, required this.date});

  final PriceHit hit;
  final String date;
}

/// HTTP-клиент Open Prices. Ключей нет, авторизации нет; неудачи —
/// только сеть (network) или не-200 (blocked).
class OpenPricesService {
  OpenPricesService({http.Client? httpClient, this.timeout = const Duration(seconds: 8)})
      : _client = httpClient;

  static const String _host = 'prices.openfoodfacts.org';

  final http.Client? _client;
  http.Client? _ownClient;

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

  /// NET-2 (аудит 2026-10-28): .timeout() лишь перестаёт ждать —
  /// подвисший запрос продолжает качаться в фоне и жечь батарею.
  /// Закрываем собственный клиент (обрываем сокеты); следующий запрос
  /// создаст свежий. Инжектированный извне клиент (тесты) не наш —
  /// его не трогаем.
  void _cancelStuck() {
    if (_client != null) return;
    _ownClient?.close();
    _ownClient = null;
  }

  final Duration timeout;

  /// Цены по штрих-коду, самые свежие первыми. Пустой список — в базе
  /// цен на этот код нет.
  Future<List<PriceHit>> lookupBarcode(
    String barcode, {
    int limit = 30,
  }) async {
    final code = barcode.trim();
    if (code.isEmpty) return const [];

    final uri = Uri.https(_host, '/api/v1/prices', {
      'product_code': code,
      'limit': '$limit',
    });

    final http.Response response;
    try {
      response = await _effectiveClient
          .get(uri, headers: {
            'Accept': 'application/json',
            'User-Agent': 'SmartFridgeChef/$kAppVersion (price lookup)',
          })
          .timeout(timeout);
    } on Exception catch (e) {
      _cancelStuck(); // NET-2: обрываем подвисший запрос
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
    return parseOpenPricesJson(decoded);
  }
}
