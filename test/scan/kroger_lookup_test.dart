/// Тесты Kroger Public API (v0.5.6): парсеры ответов (схемы — по
/// официальной документации developer.kroger.com), client_credentials
/// с кэшем токена в памяти, детекция отклонённого ключа (401/403).
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:smart_fridge_chef/scan/kroger_lookup.dart';
import 'package:smart_fridge_chef/scan/price_source.dart';

Future<Map<String, dynamic>> _fixture(String name) async {
  final file = File('test/fixtures/$name');
  return jsonDecode(await file.readAsString()) as Map<String, dynamic>;
}

void main() {
  group('parseKrogerLocationsJson — выбор магазина', () {
    test('фикстура: 2 магазина из 4 позиций (битые пропущены)', () async {
      final stores = parseKrogerLocationsJson(
          await _fixture('kroger_locations.json'));

      expect(stores, hasLength(2));

      final loveland = stores.first;
      expect(loveland.locationId, '01400413');
      expect(loveland.name, 'Kroger - Loveland');
      expect(loveland.chain, 'KROGER');
      expect(loveland.addressLine, '800 Loveland Madeira Rd');
      expect(loveland.city, 'Loveland');
      expect(loveland.state, 'OH');
      expect(loveland.zipCode, '45140');
      expect(loveland.distanceMiles, 2.4);
      expect(loveland.shortAddress, '800 Loveland Madeira Rd, Loveland, OH');

      final ralphs = stores[1];
      expect(ralphs.locationId, '01400929');
      expect(ralphs.chain, 'RALPHS');
      expect(ralphs.distanceMiles, isNull);
    });

    test('мусор: пусто/без data → пустой список', () {
      expect(parseKrogerLocationsJson({}), isEmpty);
      expect(parseKrogerLocationsJson({'data': null}), isEmpty);
    });
  });

  group('parseKrogerProductsJson — поиск цены', () {
    test('фикстура: 2 товара из 5 позиций, активная акция → isPromo', () async {
      final hits =
          parseKrogerProductsJson(await _fixture('kroger_products.json'));

      expect(hits, hasLength(2));

      final milk = hits.first;
      expect(milk.name, 'Kroger 2% Reduced Fat Milk');
      // promo 2.99 < regular 3.29 → платим 2.99, старая 3.29 зачёркнута.
      expect(milk.price, 2.99);
      expect(milk.oldPrice, 3.29);
      expect(milk.isPromo, isTrue);
      expect(milk.packageQuantity, '1 gal');
      expect(milk.currencySymbol, r'$');
      expect(milk.isAvailable, isTrue);

      final organic = hits[1];
      expect(organic.price, 4.49); // без promo
      expect(organic.oldPrice, isNull);
      expect(organic.isPromo, isFalse);
      expect(organic.isAvailable, isFalse); // instore: false
    });

    test('promo дороже regular — акция не активна', () {
      final hits = parseKrogerProductsJson({
        'data': [
          {
            'description': 'Bread',
            'items': [
              {'price': {'regular': 2.49, 'promo': 2.99}}
            ],
            'instore': true,
          },
        ],
      });
      expect(hits.single.price, 2.49);
      expect(hits.single.oldPrice, isNull);
      expect(hits.single.isPromo, isFalse);
      expect(parsePriceValue('2,49'), 2.49);
    });

    test('мусор не роняет парсер', () {
      expect(parseKrogerProductsJson({}), isEmpty);
      expect(parseKrogerProductsJson({'data': 'строка'}), isEmpty);
    });
  });

  group('KrogerService — авторизация и поиск (MockClient)', () {
    test('токен запрашивается один раз и кэшируется; Bearer в поиске',
        () async {
      final tokenJson = await _fixture('kroger_token.json');
      final productsJson = await _fixture('kroger_products.json');

      final requests = <Uri>[];
      final headers = <Uri, Map<String, String>>{};
      final client = MockClient((req) async {
        requests.add(req.url);
        headers[req.url] = req.headers;
        if (req.url.path.endsWith('/token')) {
          return http.Response(jsonEncode(tokenJson), 200,
              headers: {'content-type': 'application/json'});
        }
        return http.Response(jsonEncode(productsJson), 200,
            headers: {'content-type': 'application/json'});
      });

      final service = KrogerService(httpClient: client);
      final hits1 = await service.search(
        clientId: 'id',
        clientSecret: 'secret',
        locationId: '01400413',
        query: 'milk',
      );
      final hits2 = await service.search(
        clientId: 'id',
        clientSecret: 'secret',
        locationId: '01400413',
        query: 'bread',
      );

      expect(hits1, hasLength(2));
      expect(hits2, hasLength(2));
      // token + 2 поиска = 3 запроса; токен из кэша.
      expect(requests, hasLength(3));
      expect(requests.first.host, 'api.kroger.com');
      expect(requests.first.path, '/v1/connect/oauth2/token');

      // Токен-запрос: Basic-авторизация и grant_type.
      final tokenHeaders = headers[requests.first]!;
      expect(tokenHeaders['Authorization'],
          'Basic ${base64Encode(utf8.encode('id:secret'))}');
      // MockClient кодирует body строкой — проверяем содержимое.
      // (содержимое body проверяется отдельным тестом ниже)

      // Поисковый запрос: Bearer + параметры.
      final searchUri = requests[1];
      expect(searchUri.path, '/v1/products');
      expect(searchUri.queryParameters['filter.term'], 'milk');
      expect(searchUri.queryParameters['filter.locationId'], '01400413');
      expect(headers[searchUri]!['Authorization'], startsWith('Bearer '));
    });

    test('тело токен-запроса: grant_type=client_credentials&scope', () async {
      final client = MockClient((req) async {
        if (req.url.path.endsWith('/token')) {
          expect(req.body,
              'grant_type=client_credentials&scope=product.compact');
          return http.Response(
              jsonEncode({'access_token': 't', 'expires_in': 1800}), 200);
        }
        return http.Response(jsonEncode({'data': []}), 200);
      });
      final service = KrogerService(httpClient: client);
      final hits = await service.search(
        clientId: 'id',
        clientSecret: 'secret',
        locationId: 'L',
        query: 'milk',
      );
      expect(hits, isEmpty);
    });

    test('неверный ключ: 401 на токен → PriceUnavailable(auth)', () async {
      final service = KrogerService(
        httpClient: MockClient(
            (_) async => http.Response('{"error":"invalid_client"}', 401)),
      );
      expect(
        () => service.search(
            clientId: 'bad', clientSecret: 'bad', locationId: 'L', query: 'm'),
        throwsA(isA<PriceUnavailable>().having(
            (e) => e.reason, 'reason', PriceFailReason.auth)),
      );
    });

    test('403 на продуктовый запрос (после валидного токена) → auth',
        () async {
      var call = 0;
      final service = KrogerService(
        httpClient: MockClient((req) async {
          call++;
          if (req.url.path.endsWith('/token')) {
            return http.Response(
                jsonEncode({'access_token': 't', 'expires_in': 1800}), 200);
          }
          return http.Response('Forbidden', 403);
        }),
      );
      await expectLater(
        service.search(
            clientId: 'id', clientSecret: 's', locationId: 'L', query: 'm'),
        throwsA(isA<PriceUnavailable>().having(
            (e) => e.reason, 'reason', PriceFailReason.auth)),
      );
      expect(call, 2); // токен + попытка поиска
    });

    test('HTML вместо JSON → blocked', () async {
      final service = KrogerService(
        httpClient: MockClient((req) async {
          if (req.url.path.endsWith('/token')) {
            return http.Response(
                jsonEncode({'access_token': 't'}), 200);
          }
          return http.Response('<html>bot check</html>', 200);
        }),
      );
      await expectLater(
        service.search(
            clientId: 'id', clientSecret: 's', locationId: 'L', query: 'm'),
        throwsA(isA<PriceUnavailable>().having(
            (e) => e.reason, 'reason', PriceFailReason.blocked)),
      );
    });

    test('пустые ключи/магазин — без сети, пустой ответ', () async {
      var called = false;
      final service = KrogerService(
        httpClient: MockClient((req) async {
          called = true;
          return http.Response('{}', 200);
        }),
      );
      expect(
        await service.search(
            clientId: '', clientSecret: 's', locationId: 'L', query: 'm'),
        isEmpty,
      );
      expect(
        await service.search(
            clientId: 'id', clientSecret: 's', locationId: '', query: 'm'),
        isEmpty,
      );
      expect(await service.locations(clientId: 'id', clientSecret: 's', zipCode: ''), isEmpty);
      expect(called, isFalse);
    });

    test('locations: URL filter.zipCode.near + парсер фикстуры', () async {
      final tokenJson = await _fixture('kroger_token.json');
      final locationsJson = await _fixture('kroger_locations.json');
      Uri? locationsUri;
      final service = KrogerService(
        httpClient: MockClient((req) async {
          if (req.url.path.endsWith('/token')) {
            return http.Response(jsonEncode(tokenJson), 200);
          }
          locationsUri = req.url;
          return http.Response(jsonEncode(locationsJson), 200,
              headers: {'content-type': 'application/json; charset=utf-8'});
        }),
      );
      final stores = await service.locations(
        clientId: 'id',
        clientSecret: 'secret',
        zipCode: '45140',
      );
      expect(stores, hasLength(2));
      expect(locationsUri!.path, '/v1/locations');
      expect(locationsUri!.queryParameters['filter.zipCode.near'], '45140');
      expect(locationsUri!.queryParameters['filter.limit'], '15');
    });
  });
}
