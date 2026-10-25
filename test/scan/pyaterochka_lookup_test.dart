/// Тесты цен Пятёрочки (v0.5.5, контракт v0.5.6): парсер реальной выдачи
/// (fixture с телефона пользователя, Task 14), выбор лучшего совпадения,
/// детекция блокировки WAF и хранение анонимного deviceId.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:smart_fridge_chef/scan/pyaterochka_lookup.dart';

Future<Map<String, dynamic>> _fixture() async {
  final file = File('test/fixtures/pyaterochka_search.json');
  return jsonDecode(await file.readAsString()) as Map<String, dynamic>;
}

void main() {
  group('parsePyaterochkaSearchJson — реальный ответ поиска', () {
    test('три товара с ценами, фасовкой и рейтингом', () async {
      final hits = parsePyaterochkaSearchJson(await _fixture());

      expect(hits, hasLength(3));

      final classic = hits.firstWhere((h) => h.name.contains('классическое'));
      expect(classic.name, 'Печенье Посиделкино Овсяное классическое 320г');
      expect(classic.price, 89.99);
      expect(classic.oldPrice, isNull);
      expect(classic.isAvailable, isTrue);
      expect(classic.packageQuantity, '320 г');
      expect(classic.currencySymbol, '₽');
      expect(classic.rating, closeTo(4.89, 0.001));
      expect(classic.ratesCount, 7289);
      expect(classic.isPromo, isFalse);

      final chocolate = hits.firstWhere((h) => h.name.contains('шоколада'));
      expect(chocolate.price, 109.99);
      expect(chocolate.packageQuantity, '310 г');

      final raisin = hits.firstWhere((h) => h.name.contains('изюмом'));
      expect(raisin.price, 84.99);
      expect(raisin.ratesCount, 5628);
    });

    test('мусор не роняет парсер: пусто/без products/битые позиции', () {
      expect(parsePyaterochkaSearchJson({}), isEmpty);
      expect(parsePyaterochkaSearchJson({'products': null}), isEmpty);
      expect(
        parsePyaterochkaSearchJson({
          'products': [
            'строка вместо объекта',
            {'name': 'Без plu'},
            {'plu': 1}, // без имени
            {'plu': 2, 'name': 'Без цены'},
            {'plu': 3, 'name': 'Цена строкой с запятой', 'prices': {'regular': '45,50'}},
          ],
        }),
        hasLength(1),
      );
    });

    test('акция: discount больше regular → isPromo', () {
      final hits = parsePyaterochkaSearchJson({
        'products': [
          {
            'plu': 10,
            'name': 'Молоко 3,2% 930 мл',
            'prices': {'regular': '79.99', 'discount': '94.99'},
          },
        ],
      });
      expect(hits.single.price, 79.99);
      expect(hits.single.oldPrice, 94.99);
      expect(hits.single.isPromo, isTrue);
    });
  });

  group('pickBestPyaterochkaHit — сопоставление с названием продукта', () {
    late List<PriceHit> hits;
    setUp(() async {
      hits = parsePyaterochkaSearchJson(await _fixture());
    });

    test('полный запрос выбирает «классическое» (совпадение по всем токенам)',
        () {
      final best = pickBestPyaterochkaHit(
        hits,
        'Печенье Посиделкино Овсяное классическое',
      );
      expect(best?.name, contains('классическое'));
    });

    test('неоднозначный запрос: при равном счёте выигрывает популярнее', () {
      // Все три товара содержат оба токена — побеждает наибольшее число
      // оценок (классическое, 7289).
      final best = pickBestPyaterochkaHit(hits, 'Посиделкино овсяное');
      expect(best?.name, contains('классическое'));
    });

    test('нормализация: ё→е, регистр и пунктуация не мешают', () {
      final best = pickBestPyaterochkaHit(hits, 'печенье, овсяное (кусок. шоколада)!');
      expect(best?.name, contains('шоколада'));
    });

    test('запрос не про эти товары → null, а не случайная цена', () {
      expect(pickBestPyaterochkaHit(hits, 'Молоко Простоквашино'), isNull);
      expect(pickBestPyaterochkaHit(hits, ''), isNull);
      expect(pickBestPyaterochkaHit(const [], 'Что угодно'), isNull);
    });
  });

  group('PyaterochkaService — сеть и блокировки (MockClient)', () {
    late Map<String, dynamic> fixtureJson;
    setUp(() async {
      fixtureJson = await _fixture();
      SharedPreferences.setMockInitialValues({});
    });

    test('200 JSON: возвращает парсер, шлёт обязательные заголовки фронта',
        () async {
      Uri? requested;
      Map<String, String>? headers;
      final client = MockClient((req) async {
        requested = req.url;
        headers = req.headers;
        return http.Response(jsonEncode(fixtureJson), 200, headers: {
          'content-type': 'application/json; charset=utf-8',
        });
      });
      final service = PyaterochkaService(httpClient: client);
      final hits = await service.search(
        storeCode: '35XY',
        query: 'печенье посиделкино',
      );
      expect(hits, hasLength(3));

      expect(requested!.host, '5d.5ka.ru');
      expect(requested!.path, '/api/catalog/v3/stores/35XY/search');
      expect(requested!.queryParameters['q'], 'печенье посиделкино');
      expect(requested!.queryParameters['mode'], 'store');
      expect(headers!['x-app-version'], '0.1.1.dev');
      expect(headers!['x-platform'], 'webapp');
      expect(headers!['x-tenant-id'], 'TC5');
      expect(headers!['x-device-id'], hasLength(36));
    });

    test('403 → PriceUnavailable(blocked), не исключение сети', () async {
      final service = PyaterochkaService(
        httpClient: MockClient((_) async => http.Response('Forbidden', 403)),
      );
      expect(
        () => service.search(storeCode: '35XY', query: 'молоко'),
        throwsA(isA<PriceUnavailable>().having(
          (e) => e.reason, 'reason', PriceFailReason.blocked,
        )),
      );
    });

    test('200 с HTML-заглушкой WAF («Проблемы со связью») → blocked',
        () async {
      final service = PyaterochkaService(
        httpClient: MockClient((_) async => http.Response(
          '<html><body>Проблемы со связью. Service_connect@x5.ru</body></html>',
          200,
          headers: {'content-type': 'text/html; charset=utf-8'},
        )),
      );
      expect(
        () => service.search(storeCode: '35XY', query: 'молоко'),
        throwsA(isA<PriceUnavailable>().having(
          (e) => e.reason, 'reason', PriceFailReason.blocked,
        )),
      );
    });

    test('200 с не-JSON телом → blocked', () async {
      final service = PyaterochkaService(
        httpClient: MockClient((_) async => http.Response('ok', 200)),
      );
      expect(
        () => service.search(storeCode: '35XY', query: 'молоко'),
        throwsA(isA<PriceUnavailable>()),
      );
    });

    test('пустые аргументы — без сети, пустой ответ', () async {
      var called = false;
      final service = PyaterochkaService(
        httpClient: MockClient((req) async {
          called = true;
          return http.Response('{}', 200);
        }),
      );
      expect(await service.search(storeCode: '', query: 'молоко'), isEmpty);
      expect(await service.search(storeCode: '35XY', query: '  '), isEmpty);
      expect(called, isFalse);
    });

    test('deviceId генерируется один раз и переиспользуется', () async {
      SharedPreferences.setMockInitialValues({});
      final service = PyaterochkaService(
        httpClient: MockClient((_) async => http.Response('{}', 200)),
      );
      final first = await service.ensureDeviceId();
      final second = await service.ensureDeviceId();
      expect(first, second);
      expect(RegExp(r'^[0-9a-f-]{36}$').hasMatch(first), isTrue);

      // Новый инстанс сервиса читает тот же id из prefs.
      final another = PyaterochkaService(
        httpClient: MockClient((_) async => http.Response('{}', 200)),
      );
      expect(await another.ensureDeviceId(), first);
    });
  });
}
