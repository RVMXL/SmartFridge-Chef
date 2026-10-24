/// Тесты автопоиска по штрих-коду (Шаг 3.1): парсер ответа Open Food
/// Facts, маппинг категорий, кэш и офлайн-поведение сервиса.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:smart_fridge_chef/data/database.dart';
import 'package:smart_fridge_chef/data/models/product.dart';
import 'package:smart_fridge_chef/scan/barcode_lookup.dart';

/// Ответ с корректным charset: без него http.Response кодирует тело
/// latin1 и падает на кириллице (в реальной сети OFF всегда отдаёт UTF-8).
http.Response offHttp(Map<String, dynamic> json) => http.Response(
      jsonEncode(json),
      200,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  Map<String, dynamic> offResponse({
    int status = 1,
    String? nameRu,
    String? name,
    String? generic,
    String? brands,
    List<String> categories = const [],
  }) => {
          'status': status,
          if (status == 1)
            'product': {
              'product_name_ru': nameRu,
              'product_name': name,
              'generic_name': generic,
              'brands': brands,
              'categories_tags': categories,
            },
        };

  group('parseOpenFoodFactsJson — разбор ответа', () {
    test('русское имя приоритетнее, бренд добавляется в скобках', () {
      final r = parseOpenFoodFactsJson(
        offResponse(
          nameRu: 'Молоко 3,2%',
          name: 'Milk 3.2%',
          brands: 'Простоквашино, Другие бренды',
          categories: ['en:milks'],
        ),
        langCode: 'ru',
      );
      expect(r, isNotNull);
      expect(r!.name, 'Молоко 3,2% (Простоквашино)');
      expect(r.category, ProductCategory.dairy);
    });

    test('бренд, уже входящий в имя, не дублируется', () {
      final r = parseOpenFoodFactsJson(
        offResponse(nameRu: 'Coca-Cola 0,5 л', brands: 'Coca-Cola'),
        langCode: 'ru',
      );
      expect(r!.name, 'Coca-Cola 0,5 л');
    });

    test('юридическое название вместо бренда не добавляется к имени', () {
      final r = parseOpenFoodFactsJson(
        offResponse(
          nameRu: 'Coca Cola',
          brands: 'COCA-COLA SERVICES SA/NV',
          categories: ['en:beverages'],
        ),
        langCode: 'ru',
      );
      expect(r!.name, 'Coca Cola');
      expect(r.category, ProductCategory.beverages);
    });

    test('бренд-юрлицо «ООО …» отбрасывается', () {
      final r = parseOpenFoodFactsJson(
        offResponse(nameRu: 'Молоко 3,2%', brands: 'ООО Молвест'),
        langCode: 'ru',
      );
      expect(r!.name, 'Молоко 3,2%');
    });

    test('английская локаль берёт международное имя', () {
      final r = parseOpenFoodFactsJson(
        offResponse(nameRu: 'Молоко', name: 'Milk 3.2%'),
        langCode: 'en',
      );
      expect(r!.name, 'Milk 3.2%');
    });

    test('фолбэк на generic_name, когда product_name пуст', () {
      final r = parseOpenFoodFactsJson(
        offResponse(generic: 'Йогурт'),
        langCode: 'ru',
      );
      expect(r!.name, 'Йогурт');
    });

    test('нет имён, но есть бренд — возвращается бренд', () {
      final r = parseOpenFoodFactsJson(
        offResponse(brands: 'Фрутоняня'),
        langCode: 'ru',
      );
      expect(r!.name, 'Фрутоняня');
    });

    test('полностью пустой product — null (нечего показывать)', () {
      final r = parseOpenFoodFactsJson(offResponse(), langCode: 'ru');
      expect(r, isNull);
    });

    test('status 0 (товара нет в базе) — null', () {
      final r = parseOpenFoodFactsJson(
          const {'status': 0}, langCode: 'ru');
      expect(r, isNull);
    });

    test('мусор вместо полей — null, без исключений', () {
      final r = parseOpenFoodFactsJson(
        {'status': 1, 'product': 'не объект'},
        langCode: 'ru',
      );
      expect(r, isNull);
    });

    test('пробелы схлопываются', () {
      final r = parseOpenFoodFactsJson(
        offResponse(nameRu: '  Кефир   1%   с отрубями  '),
        langCode: 'ru',
      );
      expect(r!.name, 'Кефир 1% с отрубями');
    });

    test('длинное имя обрезается до 80 символов по границе слова', () {
      final long = 'Очень длинное название продукта ' * 4; // > 80 символов
      final r = parseOpenFoodFactsJson(
        offResponse(nameRu: long),
        langCode: 'ru',
      );
      expect(r!.name.length, lessThanOrEqualTo(80));
      expect(r.name.endsWith('…'), isTrue);
    });
  });

  group('маппинг категорий Open Food Facts', () {
    ProductCategory? map(List<String> tags) => parseOpenFoodFactsJson(
          offResponse(nameRu: 'X', categories: tags),
          langCode: 'ru',
        )?.category;

    test('типовые теги', () {
      expect(map(['en:cheeses']), ProductCategory.dairy);
      expect(map(['en:meats', 'en:chilled']), ProductCategory.meat);
      expect(map(['en:fishes']), ProductCategory.fish);
      expect(map(['en:vegetables']), ProductCategory.vegetables);
      expect(map(['en:fruits']), ProductCategory.fruits);
      expect(map(['en:breads']), ProductCategory.bakery);
      expect(map(['en:pastas']), ProductCategory.grains);
      expect(map(['en:frozen-foods']), ProductCategory.frozen);
      expect(map(['en:beverages']), ProductCategory.beverages);
      expect(map(['en:sweet-snacks']), ProductCategory.sweets);
      expect(map(['en:sauces']), ProductCategory.condiments);
    });

    test('неизвестные теги — категория не определена (null)', () {
      expect(map(['ru:что-то-экзотическое']), isNull);
      expect(map(<String>[]), isNull);
    });

    test('первый узнанный тег из списка выигрывает', () {
      expect(
        map(['en:unknown-tag', 'en:milks', 'en:snacks']),
        ProductCategory.dairy,
      );
    });

    test('фолбэк: без тегов категория угадывается по названию', () {
      // Типовой срок в форме ставится от категории: колбасы — это мясо
      // (+3 дня), а не «другое» (+14), даже если OFF не дал тегов.
      ProductCategory? guess(String nameRu) => parseOpenFoodFactsJson(
            offResponse(nameRu: nameRu),
            langCode: 'ru',
          )?.category;
      expect(guess('Сосиски Молочные Вязанка'), ProductCategory.meat);
      expect(guess('Пельмени Сибирская коллекция'), ProductCategory.frozen);
      expect(guess('Сок апельсиновый 100%'), ProductCategory.beverages);
      expect(guess('Молоко 3,2%'), ProductCategory.dairy);
      expect(guess('Печенье овсяное'), ProductCategory.sweets);
      // Незнакомые названия остаются без категории — форма возьмёт other.
      expect(guess('Coca-Cola 0,5 л'), isNull);
      expect(guess('Нечто невообразимое'), isNull);
    });
  });

  group('BarcodeLookupService — кэш и офлайн', () {
    late Directory tmp;
    late String dbPath;
    late Database db;

    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('barcode_lookup_test');
      dbPath = '${tmp.path}/test.db';
      db = await AppDatabase.open(absolutePath: dbPath);
    });

    tearDown(() async {
      await db.close();
      await tmp.delete(recursive: true);
    });

    test('найдено в сети → кэшируется; повторный скан работает без сети',
        () async {
      var calls = 0;
      final service = BarcodeLookupService(
        openDb: () async => db,
        client: MockClient((request) async {
          calls++;
          return offHttp(offResponse(
            nameRu: 'Сыр Голландский',
            brands: 'Брест-Литовск',
            categories: ['en:cheeses'],
          ));
        }),
      );

      final first = await service.lookup('4600338011634');
      expect(first, isNotNull);
      expect(first!.name, 'Сыр Голландский (Брест-Литовск)');
      expect(first.fromCache, isFalse);
      expect(calls, 1);

      // Сеть «умирает» — результат всё равно приходит из кэша.
      final offlineService = BarcodeLookupService(
        openDb: () async => db,
        client: MockClient(
            (request) async => throw const SocketException('нет сети')),
      );
      final second = await offlineService.lookup('4600338011634');
      expect(second, isNotNull);
      expect(second!.name, 'Сыр Голландский (Брест-Литовск)');
      expect(second.category, ProductCategory.dairy);
      expect(second.fromCache, isTrue);
      expect(calls, 1); // повторный запрос в сеть не уходил
    });

    test('товара нет в базе (status 0) — null, без кэширования', () async {
      final service = BarcodeLookupService(
        openDb: () async => db,
        client: MockClient(
            (request) async => offHttp(const {'status': 0})),
      );
      expect(await service.lookup('2000000000009'), isNull);
      // И в кэше пусто — база пополняется, стоит пробовать снова.
      expect(await db.query('barcode_cache'), isEmpty);
    });

    test('ошибка сети — null и никаких исключений наружу', () async {
      final service = BarcodeLookupService(
        openDb: () async => db,
        client: MockClient(
            (request) async => throw const SocketException('нет сети')),
      );
      expect(await service.lookup('4600338011634'), isNull);
    });

    test('короткий/пустой код не уходит ни в кэш, ни в сеть', () async {
      var calls = 0;
      final service = BarcodeLookupService(
        openDb: () async => db,
        client: MockClient((request) async {
          calls++;
          return http.Response(jsonEncode({'status': 0}), 200);
        }),
      );
      expect(await service.lookup('123'), isNull);
      expect(await service.lookup(''), isNull);
      expect(await service.lookup('  '), isNull);
      expect(calls, 0);
    });

    test('код очищается от пробелов перед поиском', () async {
      final service = BarcodeLookupService(
        openDb: () async => db,
        client: MockClient((request) async {
          expect(request.url.path, contains('4600338011634'));
          return offHttp(offResponse(nameRu: 'Молоко'));
        }),
      );
      final r = await service.lookup(' 4600338011634 ');
      expect(r!.name, 'Молоко');
    });
  });
}
