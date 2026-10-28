/// Тесты Mercadona (v0.5.8; c v0.5.11 — SCAN-6): парсер категории
/// (рекурсивный обход categories/products), компактное кодирование
/// индекса, сборка индекса по сети (корневое дерево → категории 1-го
/// уровня) и персист в SQLite (второй сервис живёт без сети; старый
/// prefs-индекс апгрейдера импортируется один раз и удаляется).
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:smart_fridge_chef/data/database.dart';
import 'package:smart_fridge_chef/scan/mercadona_lookup.dart';

void _initFfi() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
}

/// Полная схема v8 во временной базе (как на устройстве).
Future<Database> _openTestDb(Directory tmp, {String name = 'm.db'}) {
  return AppDatabase.open(absolutePath: '${tmp.path}/$name');
}

Future<Map<String, dynamic>> _fixture(String name) async {
  final file = File('test/fixtures/$name');
  return jsonDecode(await file.readAsString()) as Map<String, dynamic>;
}

http.Response _json(Object body, {int code = 200}) =>
    http.Response(jsonEncode(body), code, headers: {
      'content-type': 'application/json',
    });

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('parseMercadonaCategoryJson — рекурсивный обход категории', () {
    test('фикстура: 2 товара из 4 (непубликуемые/без цены пропущены)',
        () async {
      final hits =
          parseMercadonaCategoryJson(await _fixture('mercadona_category.json'));

      expect(hits, hasLength(2));

      final entera = hits.first;
      expect(entera.name, 'Leche entera Hacendado');
      expect(entera.price, 0.95);
      expect(entera.oldPrice, isNull);
      expect(entera.packageQuantity, 'botella · 1 l');
      expect(entera.currencySymbol, '€');
      expect(entera.isPromo, isFalse);

      final semi = hits[1];
      expect(semi.name, 'Leche semidesnatada Hacendado');
      expect(semi.price, 5.22);
      expect(semi.oldPrice, 6.12); // цена до скидки
      expect(semi.isPromo, isTrue);
      expect(semi.packageQuantity, 'botella · 6 l');
    });

    test('мусор: пусто/без продуктов → пусто; unit_price строкой парсится',
        () {
      expect(parseMercadonaCategoryJson({}), isEmpty);
      expect(parseMercadonaCategoryJson({'categories': null}), isEmpty);
      final hits = parseMercadonaCategoryJson({
        'categories': [
          {
            'products': [
              {
                'display_name': 'Garrafa 5 l',
                'published': true,
                'price_instructions': {
                  'unit_price': '17.25',
                  'unit_size': 5.0,
                  'size_format': 'l',
                },
              },
            ],
          },
        ],
      });
      expect(hits, hasLength(1));
      expect(hits.single.price, 17.25);
      expect(hits.single.packageQuantity, '5 l');
    });

    test('published=false и цена ≤ 0 пропускаются', () {
      final hits = parseMercadonaCategoryJson({
        'categories': [
          {
            'products': [
              {
                'display_name': 'Убран с продажи',
                'published': false,
                'price_instructions': {'unit_price': '1.00'},
              },
              {
                'display_name': 'Нулевая цена',
                'published': true,
                'price_instructions': {'unit_price': '0'},
              },
              {
                'display_name': 'Нормальный',
                'published': true,
                'price_instructions': {'unit_price': 2.4},
              },
            ],
          },
        ],
      });
      expect(hits, hasLength(1));
      expect(hits.single.name, 'Нормальный');
      expect(hits.single.price, 2.4);
    });
  });

  group('индекс: кодирование/декодирование', () {
    test('roundtrip: oldPrice и фасовка сохраняются', () {
      final hits = [
        const PriceHit(
          name: 'Leche entera Hacendado',
          price: 0.95,
          packageQuantity: 'botella · 1 l',
          currencySymbol: '€',
        ),
        const PriceHit(
          name: 'Leche semidesnatada Hacendado',
          price: 5.22,
          oldPrice: 6.12,
          currencySymbol: '€',
        ),
      ];
      final decoded = decodeMercadonaIndex(encodeMercadonaIndex(hits));
      expect(decoded, hasLength(2));
      expect(decoded[0].name, 'Leche entera Hacendado');
      expect(decoded[0].price, 0.95);
      expect(decoded[0].packageQuantity, 'botella · 1 l');
      expect(decoded[0].oldPrice, isNull);
      expect(decoded[1].oldPrice, 6.12);
      expect(decoded[1].isPromo, isTrue);
    });

    test('битый JSON → пусто; старая цена ниже текущей отбрасывается', () {
      expect(decodeMercadonaIndex('not json'), isEmpty);
      expect(decodeMercadonaIndex('[]'), isEmpty);
      final decoded = decodeMercadonaIndex(
          '[{"n":"X","p":"2.00","o":"1.50"}]');
      expect(decoded.single.oldPrice, isNull);
    });
  });

  group('MercadonaService — сборка индекса и кэш', () {
    test('первый поиск строит индекс по категориям 1-го уровня', () async {
      SharedPreferences.setMockInitialValues({});
      _initFfi();
      final tmp = await Directory.systemTemp.createTemp('mercadona_test');
      final db = await _openTestDb(tmp);
      final requests = <Uri>[];
      final category = await _fixture('mercadona_category.json');
      final root = await _fixture('mercadona_root.json');
      late MercadonaService service;
      service = MercadonaService(
        pacing: Duration.zero,
        openDb: () async => db,
        httpClient: MockClient((request) async {
          requests.add(request.url);
          expect(request.url.host, 'tienda.mercadona.es');
          if (request.url.path == '/api/categories/') {
            return _json(root);
          }
          if (request.url.path.startsWith('/api/categories/')) {
            return _json(category);
          }
          return _json({'errors': [{'detail': 'No encontrado.'}]}, code: 404);
        }),
      );

      final hits = await service.search(query: 'leche');
      // root + 3 категории 1-го уровня (112, 115, 151 из фикстуры дерева).
      expect(requests, hasLength(4));
      expect(
        requests.skip(1).map((u) => u.path),
        everyElement(isIn(['/api/categories/112/', '/api/categories/115/',
            '/api/categories/151/'])),
      );
      // Индекс: 2 валидных товара × 3 категории.
      expect(hits, hasLength(6));

      // Персист (SCAN-6): после сборки индекс лежит в SQLite, а prefs
      // хранит только TTL-метку — большой JSON-ключ больше не появляется.
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('pref_mercadona_catalog_json'), isNull);
      expect(prefs.getInt('pref_mercadona_catalog_at'), greaterThan(0));
      expect(await db.query('mercadona_index'), hasLength(6));
      await db.close();
      await tmp.delete(recursive: true);
    });

    test('второй сервис читает кэш SQLite — сети не нужно', () async {
      SharedPreferences.setMockInitialValues({});
      _initFfi();
      final tmp = await Directory.systemTemp.createTemp('mercadona_test');
      final db = await _openTestDb(tmp);
      await db.insert('mercadona_index', {
        'name': 'Queso manchego',
        'price': 4.49,
        'old_price': null,
        'package_quantity': null,
      });
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('pref_mercadona_catalog_at',
          DateTime.now().millisecondsSinceEpoch);

      final service = MercadonaService(
        pacing: Duration.zero,
        openDb: () async => db,
        httpClient: MockClient((request) async {
          fail('сеть не должна вызываться при живом кэше');
        }),
      );
      final result = await service.search(query: 'queso');
      expect(result, hasLength(1));
      expect(result.single.name, 'Queso manchego');
      await db.close();
      await tmp.delete(recursive: true);
    });

    test('legacy-импорт: prefs-индекс апгрейдера переезжает в SQLite и '
        'удаляется из prefs', () async {
      SharedPreferences.setMockInitialValues({
        'pref_mercadona_catalog_json': encodeMercadonaIndex(const [
          PriceHit(
              name: 'Leche semidesnatada',
              price: 1.09,
              currencySymbol: '€'),
        ]),
      });
      _initFfi();
      final tmp = await Directory.systemTemp.createTemp('mercadona_test');
      final db = await _openTestDb(tmp, name: 'legacy.db');

      final service = MercadonaService(
        pacing: Duration.zero,
        openDb: () async => db,
        httpClient: MockClient((request) async {
          // Фоновое перестроение при истёкшем TTL — отвечаем блокировкой,
          // чтобы тест проверял именно импорт, а не сеть.
          return _json({'errors': []}, code: 404);
        }),
      );
      final result = await service.search(query: 'leche');
      expect(result, hasLength(1));
      expect(result.single.name, 'Leche semidesnatada');

      // Индекс переехал в базу, prefs-ключ удалён (критерий SCAN-6).
      expect(await db.query('mercadona_index'), hasLength(1));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('pref_mercadona_catalog_json'), isNull);
      await db.close();
      await tmp.delete(recursive: true);
    });

    test('пустой запрос → пусто, сеть не дёргается', () async {
      SharedPreferences.setMockInitialValues({});
      final service = MercadonaService(
        httpClient: MockClient((request) async {
          fail('пустой запрос не должен ходить в сеть');
        }),
      );
      expect(await service.search(query: '  '), isEmpty);
    });

    test('404 корня/HTML-заглушка → blocked', () async {
      SharedPreferences.setMockInitialValues({});
      final service = MercadonaService(
        pacing: Duration.zero,
        httpClient: MockClient((request) async {
          return _json({
            'errors': [
              {'detail': 'No encontrado.', 'code': 'not_found'}
            ]
          }, code: 404);
        }),
      );
      await expectLater(
        service.search(query: 'leche'),
        throwsA(isA<PriceUnavailable>().having(
            (e) => e.reason, 'reason', PriceFailReason.blocked)),
      );
    });
  });
}
