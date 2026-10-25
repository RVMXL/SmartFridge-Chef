/// Тесты Open Prices (v0.5.6): парсер на реальной фикстуре (снята curl'ом
/// с prices.openfoodfacts.org), свежесть записей, скидки, мусор-устойчивость
/// и клиент без ключей.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:smart_fridge_chef/scan/openprices_lookup.dart';
import 'package:smart_fridge_chef/scan/price_source.dart';

Future<Map<String, dynamic>> _fixture() async {
  final file = File('test/fixtures/openprices_prices.json');
  return jsonDecode(await file.readAsString()) as Map<String, dynamic>;
}

void main() {
  group('parseOpenPricesJson — реальная выдача по штрихкоду', () {
    test('записи сортируются по дате (свежие первыми)', () async {
      final hits = parseOpenPricesJson(await _fixture());

      expect(hits, hasLength(2));
      expect(hits.first.price, 1.1); // 2026-04-06 HiperDino
      expect(hits.first.name, 'HiperDino');
      expect(hits.first.currencySymbol, '€');
      expect(hits.last.price, 0.99); // 2024-11-15 Franprix
      expect(hits.last.name, 'Franprix');
      expect(hits.first.oldPrice, isNull);
      expect(hits.first.isPromo, isFalse);
    });

    test('скидка: price_without_discount → oldPrice, isPromo', () {
      final hits = parseOpenPricesJson({
        'items': [
          {
            'price': 1.5,
            'currency': 'USD',
            'date': '2026-10-01',
            'price_is_discounted': true,
            'price_without_discount': 2.29,
            'location': {'osm_brand': 'Kroger', 'osm_name': 'Kroger 929'},
            'product': {'product_name': 'Milk'},
          },
        ],
      });
      expect(hits.single.price, 1.5);
      expect(hits.single.oldPrice, 2.29);
      expect(hits.single.isPromo, isTrue);
      expect(hits.single.currencySymbol, r'$');
    });

    test('мусор и пропуски: без цены/без items — пусто, не роняется', () {
      expect(parseOpenPricesJson({}), isEmpty);
      expect(parseOpenPricesJson({'items': null}), isEmpty);
      expect(
        parseOpenPricesJson({
          'items': [
            'строка',
            {'price': null},
            {'price': 'не число'},
            {'price': 3.2, 'currency': null, 'location': null},
          ],
        }),
        hasLength(1),
      );
      // Запись без location → нейтральное имя.
      expect(
        parseOpenPricesJson({
          'items': [
            {'price': 3.2},
          ],
        }).single.name,
        'Open Prices',
      );
    });

    test('currencySymbolFor: известные и неизвестные коды', () {
      expect(currencySymbolFor('RUB'), '₽');
      expect(currencySymbolFor('usd'), r'$');
      expect(currencySymbolFor('EUR'), '€');
      expect(currencySymbolFor('GBP'), '£');
      expect(currencySymbolFor('CHF'), 'CHF ');
      expect(currencySymbolFor(null), '₽');
    });
  });

  group('OpenPricesService — клиент без ключей (MockClient)', () {
    test('200: URL с product_code/limit, парсер фикстуры', () async {
      final fixtureJson = await _fixture();
      Uri? requested;
      Map<String, String>? headers;
      final service = OpenPricesService(
        httpClient: MockClient((req) async {
          requested = req.url;
          headers = req.headers;
          return http.Response(jsonEncode(fixtureJson), 200,
              headers: {'content-type': 'application/json'});
        }),
      );
      final hits = await service.lookupBarcode('5449000000996');
      expect(hits, hasLength(2));
      expect(requested!.host, 'prices.openfoodfacts.org');
      expect(requested!.path, '/api/v1/prices');
      expect(requested!.queryParameters['product_code'], '5449000000996');
      expect(requested!.queryParameters['limit'], '30');
      expect(headers!['User-Agent'], contains('SmartFridgeChef'));
    });

    test('пустой штрихкод — без сети', () async {
      var called = false;
      final service = OpenPricesService(
        httpClient: MockClient((req) async {
          called = true;
          return http.Response('{}', 200);
        }),
      );
      expect(await service.lookupBarcode('  '), isEmpty);
      expect(called, isFalse);
    });

    test('не-200 → PriceUnavailable(blocked)', () async {
      final service = OpenPricesService(
        httpClient: MockClient((_) async => http.Response('err', 500)),
      );
      expect(
        () => service.lookupBarcode('123'),
        throwsA(isA<PriceUnavailable>().having(
            (e) => e.reason, 'reason', PriceFailReason.blocked)),
      );
    });

    test('HTML-заглушка при 200 → blocked', () async {
      final service = OpenPricesService(
        httpClient: MockClient(
            (_) async => http.Response('<html>proxy error</html>', 200)),
      );
      expect(
        () => service.lookupBarcode('123'),
        throwsA(isA<PriceUnavailable>().having(
            (e) => e.reason, 'reason', PriceFailReason.blocked)),
      );
    });
  });
}
