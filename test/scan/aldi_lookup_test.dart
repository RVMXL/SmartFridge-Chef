/// Тесты Aldi Süd (v0.5.8): парсер /v3/product-search по схеме
/// aldiscount (центы, wasPriceDisplay), параметры запроса, отсутствие
/// кастомного User-Agent, WAF-поведение (403 → blocked).
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:smart_fridge_chef/scan/aldi_lookup.dart';

Future<Map<String, dynamic>> _fixture(String name) async {
  final file = File('test/fixtures/$name');
  return jsonDecode(await file.readAsString()) as Map<String, dynamic>;
}

http.Response _json(Object body, {int code = 200}) =>
    http.Response(jsonEncode(body), code, headers: {
      'content-type': 'application/json',
    });

void main() {
  group('parseAldiSearchJson — поиск по каталогу', () {
    test('фикстура: 3 товара из 4 (discontinued пропущен)', () async {
      final hits =
          parseAldiSearchJson(await _fixture('aldi_search.json'));

      expect(hits, hasLength(3));

      final milk = hits.first;
      expect(milk.name, 'MILSANI Vollmilch 3,5%'); // бренд + название
      expect(milk.price, 1.19); // 119 центов
      expect(milk.oldPrice, isNull);
      expect(milk.packageQuantity, '1 l');
      expect(milk.currencySymbol, '€');
      expect(milk.isAvailable, isTrue);

      final juice = hits[1];
      expect(juice.name, 'VALENSINA Orangensaft 1 l');
      expect(juice.price, 1.29);
      expect(juice.oldPrice, 1.99); // wasPriceDisplay «1,99 €»
      expect(juice.isPromo, isTrue);

      // notForSale=true — это «нельзя купить в вебшопе», товар полки.
      final meat = hits[2];
      expect(meat.name, 'GUT BIO Hackfleisch gemischt');
      expect(meat.price, 5.49);
      expect(meat.isAvailable, isTrue);
      expect(meat.packageQuantity, '500 g');
    });

    test('wasPriceDisplay: немецкий формат и мусор', () {
      final hits = parseAldiSearchJson({
        'data': [
          {
            'name': 'A',
            'discontinued': false,
            'price': {
              'amount': 100,
              'amountRelevant': 100,
              'wasPriceDisplay': '2,49 €',
              'currencySymbol': '€',
            },
          },
          {
            'name': 'B',
            'discontinued': false,
            'price': {
              'amount': 200,
              'amountRelevant': 200,
              'wasPriceDisplay': 'aktion!',
              'currencySymbol': '€',
            },
          },
          {
            'name': 'C',
            'discontinued': false,
            'price': {
              'amount': 300,
              'amountRelevant': 300,
              // Странно: старая ниже текущей — не акция.
              'wasPriceDisplay': '1,00 €',
              'currencySymbol': '€',
            },
          },
        ],
      });
      expect(hits[0].oldPrice, 2.49);
      expect(hits[1].oldPrice, isNull);
      expect(hits[2].oldPrice, isNull);
    });

    test('amountRelevant приоритетнее amount (весовые товары)', () {
      final hits = parseAldiSearchJson({
        'data': [
          {
            'name': 'Weighed',
            'price': {
              'amount': 500,
              'amountRelevant': 375,
              'currencySymbol': '€',
            },
          },
        ],
      });
      expect(hits.single.price, 3.75);
    });

    test('без цены или без name — пропуск; пустой data — пусто', () {
      expect(parseAldiSearchJson({}), isEmpty);
      expect(parseAldiSearchJson({'data': []}), isEmpty);
      expect(
        parseAldiSearchJson({
          'data': [
            {'name': 'No price', 'price': null},
            {'name': '', 'price': {'amount': 100}},
            {'name': 'No cents', 'price': {'amount': 0}},
          ],
        }),
        isEmpty,
      );
    });

    test('конверт ошибок с HTTP 200 → blocked (не «пусто»)', () {
      expect(
        () => parseAldiSearchJson({
          'errors': [
            {'code': 3731, 'message': 'bad page size'}
          ],
          'data': <dynamic>[],
        }),
        throwsA(isA<PriceUnavailable>().having(
            (e) => e.reason, 'reason', PriceFailReason.blocked)),
      );
    });
  });

  group('AldiService — запрос и границы', () {
    test('URL/параметры; User-Agent НЕ переопределяется', () async {
      final requests = <http.Request>[];
      final fixture = await _fixture('aldi_search.json');
      final service = AldiService(
        httpClient: MockClient((request) async {
          requests.add(request);
          return _json(fixture);
        }),
      );

      final hits = await service.search(query: 'milch');
      expect(hits, hasLength(3));

      final uri = requests.single.url;
      expect(uri.scheme, 'https');
      expect(uri.host, 'api.aldi-sued.de');
      expect(uri.path, '/v3/product-search');
      expect(uri.queryParameters['serviceType'], 'walk-in');
      expect(uri.queryParameters['currency'], 'EUR');
      expect(uri.queryParameters['limit'], '12');
      expect(uri.queryParameters['offset'], '0');
      expect(uri.queryParameters['sort'], 'relevance');
      expect(uri.queryParameters['q'], 'milch');
      // Akamai отклоняет кастомный UA — заголовка быть не должно.
      expect(requests.single.headers.containsKey('user-agent'), isFalse);
      expect(requests.single.headers['accept'], 'application/json');
    });

    test('limit нормализуется к допустимым {12,16,24,30,32,48,60}', () async {
      final requests = <http.Request>[];
      final service = AldiService(
        httpClient: MockClient((request) async {
          requests.add(request);
          return _json({'data': []});
        }),
      );
      await service.search(query: 'kaffee', limit: 10); // → 12
      await service.search(query: 'kaffee', limit: 60); // → 60
      expect(requests[0].url.queryParameters['limit'], '12');
      expect(requests[1].url.queryParameters['limit'], '60');
    });

    test('403 Akamai и HTML → blocked; сеть → network', () async {
      final blocked = AldiService(
        httpClient: MockClient((request) async =>
            http.Response('<HTML>Access Denied</HTML>', 403)),
      );
      await expectLater(
        blocked.search(query: 'milch'),
        throwsA(isA<PriceUnavailable>().having(
            (e) => e.reason, 'reason', PriceFailReason.blocked)),
      );

      final htmlOk = AldiService(
        httpClient: MockClient((request) async =>
            http.Response('<html>waf stub</html>', 200)),
      );
      await expectLater(
        htmlOk.search(query: 'milch'),
        throwsA(isA<PriceUnavailable>().having(
            (e) => e.reason, 'reason', PriceFailReason.blocked)),
      );

      final offline = AldiService(
        httpClient: MockClient((request) async =>
            throw http.ClientException('offline')),
      );
      await expectLater(
        offline.search(query: 'milch'),
        throwsA(isA<PriceUnavailable>().having(
            (e) => e.reason, 'reason', PriceFailReason.network)),
      );
    });
  });

  group('pickBestAldiHit — общий матчер', () {
    test('выбирает товар со всеми токенами запроса', () async {
      final hits =
          parseAldiSearchJson(await _fixture('aldi_search.json'));
      final best = pickBestAldiHit(hits, 'milsani vollmilch');
      expect(best, isNotNull);
      expect(best!.name, 'MILSANI Vollmilch 3,5%');
      expect(pickBestAldiHit(hits, 'qq zz ww'), isNull);
    });
  });
}
