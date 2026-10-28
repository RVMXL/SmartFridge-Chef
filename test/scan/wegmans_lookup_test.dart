/// Тесты Wegmans (v0.5.8): парсеры stores/search/prices (схемы — по
/// официальной коллекции Wegmans.io), двухшаговый поиск (search → цены
/// первых sku), api-version и subscription-key в URL, auth на 401/403.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:smart_fridge_chef/scan/wegmans_lookup.dart';

Future<Map<String, dynamic>> _fixture(String name) async {
  final file = File('test/fixtures/$name');
  return jsonDecode(await file.readAsString()) as Map<String, dynamic>;
}

http.Response _json(Object body, {int code = 200}) =>
    http.Response(jsonEncode(body), code, headers: {
      'content-type': 'application/json',
    });

void main() {
  group('parseWegmansStoresJson — список магазинов', () {
    test('фикстура: 3 магазина, разные схемы адреса и номера', () async {
      final stores =
          parseWegmansStoresJson(await _fixture('wegmans_stores.json'));

      expect(stores, hasLength(3));

      final pittsford = stores.first;
      expect(pittsford.storeNumber, '68');
      expect(pittsford.name, 'Pittsford');
      expect(pittsford.addressLine, '3195 Monroe Ave');
      expect(pittsford.city, 'Rochester');
      expect(pittsford.state, 'NY');
      expect(pittsford.shortAddress, '3195 Monroe Ave, Rochester, NY');

      final ithaca = stores[1];
      expect(ithaca.storeNumber, '110');

      // storeNumber вместо store; адрес строкой.
      final broken = stores[2];
      expect(broken.storeNumber, '42');
      expect(broken.addressLine, '100 Main St, Lancaster, NY');
    });

    test('мусор: пусто/без списка → пусто', () {
      expect(parseWegmansStoresJson({}), isEmpty);
      expect(parseWegmansStoresJson({'stores': null}), isEmpty);
    });
  });

  group('parseWegmansSearchJson — результаты поиска', () {
    test('фикстура: 3 sku из 5 (без имени/номера — пропущены)', () async {
      final found =
          parseWegmansSearchJson(await _fixture('wegmans_search.json'));
      expect(found, hasLength(3));
      expect(found[0].sku, '484208');
      expect(found[0].name, 'Wegmans Organic 2% Milk');
      expect(found[1].sku, '5891');
      expect(found[2].sku, '300300');
    });

    test('мусор: без results/data → пусто', () {
      expect(parseWegmansSearchJson({}), isEmpty);
      expect(parseWegmansSearchJson({'results': null}), isEmpty);
    });
  });

  group('parseWegmansPriceJson — цена магазина', () {
    test('фикстура: первая цена из prices', () async {
      final parsed =
          parseWegmansPriceJson(await _fixture('wegmans_prices.json'));
      expect(parsed, isNotNull);
      expect(parsed!.price, 3.79);
      expect(parsed.oldPrice, isNull);
    });

    test('пусто/без цены → null; строковая цена парсится', () {
      expect(parseWegmansPriceJson({}), isNull);
      expect(parseWegmansPriceJson({'prices': []}), isNull);
      final parsed = parseWegmansPriceJson({
        'prices': [
          {'price': '2.49'},
        ],
      });
      expect(parsed, isNotNull);
      expect(parsed!.price, 2.49);
    });

    test('NET-8: wasPrice > price → oldPrice (акция), wasPrice < price — игнор', () {
      final promo = parseWegmansPriceJson({
        'prices': [
          {'price': 3.79, 'wasPrice': 4.99},
        ],
      });
      expect(promo, isNotNull);
      expect(promo!.price, 3.79);
      expect(promo.oldPrice, 4.99);

      final promoAlt = parseWegmansPriceJson({
        'prices': [
          // promo НИЖЕ цены — цена уже промо, «старой» нет.
          {'price': 3.0, 'promoPrice': 1.0},
        ],
      });
      expect(promoAlt!.oldPrice, isNull);

      final plain = parseWegmansPriceJson({
        'prices': [
          {'price': 5.0, 'wasPrice': 1.0},
        ],
      });
      expect(plain!.oldPrice, isNull);
    });
  });

  group('WegmansService — двухшаговый поиск', () {
    test('search → цены первых sku; SEC-2: ключ в заголовке, не в URL', () async {
      final requests = <http.Request>[];
      final stores = await _fixture('wegmans_stores.json');
      final search = await _fixture('wegmans_search.json');
      final prices = await _fixture('wegmans_prices.json');
      final service = WegmansService(
        httpClient: MockClient((request) async {
          requests.add(request);
          if (request.url.path == '/stores') {
            return _json(stores);
          }
          if (request.url.path == '/products/search') {
            return _json(search);
          }
          if (request.url.path.startsWith('/products/') &&
              request.url.path.endsWith('/prices/68')) {
            return _json(prices);
          }
          return _json({'type': 'error'}, code: 500);
        }),
      );

      final storeList =
          await service.stores(subscriptionKey: 'KEY-1');
      expect(storeList, hasLength(3));

      final hits = await service.search(
        subscriptionKey: 'KEY-1',
        storeNumber: '68',
        query: 'milk',
      );
      // 1 поиск + цены 3 валидных sku (pricedResults=4, валидных меньше).
      expect(requests, hasLength(5));

      final searchUri = requests[1].url;
      expect(searchUri.host, 'api.wegmans.io');
      expect(searchUri.path, '/products/search');
      expect(searchUri.queryParameters['q'], 'milk');
      expect(searchUri.queryParameters['store'], '68');
      expect(searchUri.queryParameters['api-version'], '2018-10-18');
      // SEC-2 (аудит 2026-10-28): ключ в заголовке
      // Ocp-Apim-Subscription-Key (стандарт Azure APIM) — в URL его быть
      // не должно: URL попадает в серверные/прокси-логи и дампы.
      expect(searchUri.queryParameters['subscription-key'], isNull);
      expect(requests[1].headers['Ocp-Apim-Subscription-Key'], 'KEY-1');
      // И в /stores — тоже заголовок, не URL.
      expect(requests[0].url.queryParameters['subscription-key'], isNull);
      expect(requests[0].headers['Ocp-Apim-Subscription-Key'], 'KEY-1');

      final priceUri = requests[2].url;
      expect(priceUri.path, '/products/484208/prices/68');
      expect(priceUri.queryParameters['api-version'], '2018-10-18');
      expect(priceUri.queryParameters['subscription-key'], isNull);
      expect(requests[2].headers['Ocp-Apim-Subscription-Key'], 'KEY-1');

      expect(hits, hasLength(3));
      expect(hits.first.name, 'Wegmans Organic 2% Milk');
      expect(hits.first.price, 3.79);
      expect(hits.first.currencySymbol, r'$');
    });

    test('401 на поиске → auth', () async {
      final service = WegmansService(
        httpClient: MockClient((request) async =>
            _json({'title': 'Access Denied'}, code: 401)),
      );
      await expectLater(
        service.search(
            subscriptionKey: 'BAD', storeNumber: '68', query: 'milk'),
        throwsA(isA<PriceUnavailable>().having(
            (e) => e.reason, 'reason', PriceFailReason.auth)),
      );
    });

    test('цена одного sku недоступна — остальные доживают', () async {
      final search = await _fixture('wegmans_search.json');
      final prices = await _fixture('wegmans_prices.json');
      var priceCalls = 0;
      final service = WegmansService(
        httpClient: MockClient((request) async {
          if (request.url.path == '/products/search') {
            return _json(search);
          }
          priceCalls++;
          if (priceCalls == 1) {
            return http.Response('<html>oops</html>', 503);
          }
          return _json(prices);
        }),
      );
      final hits = await service.search(
        subscriptionKey: 'KEY',
        storeNumber: '68',
        query: 'milk',
      );
      // 3 валидных sku, первый ценовой запрос умер → остаются 2.
      expect(hits, hasLength(2));
    });

    test('пустые аргументы → пусто, сети нет', () async {
      final service = WegmansService(
        httpClient: MockClient((request) async {
          fail('не должно быть сетевых вызовов');
        }),
      );
      expect(
        await service.search(
            subscriptionKey: '', storeNumber: '68', query: 'milk'),
        isEmpty,
      );
      expect(
        await service.search(
            subscriptionKey: 'KEY', storeNumber: '', query: 'milk'),
        isEmpty,
      );
      expect(
        await service.search(
            subscriptionKey: 'KEY', storeNumber: '68', query: '  '),
        isEmpty,
      );
      expect(await service.stores(subscriptionKey: ''), isEmpty);
    });
  });
}
