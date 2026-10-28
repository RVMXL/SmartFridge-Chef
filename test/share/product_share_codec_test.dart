/// Тесты кодека обмена продуктами (v0.5.0): формат страниц Amnezia
/// (magic 1984, чанки 850 байт, base64url), одиночная передача,
/// дедупликация, восстановление порядка, устойчивость к мусору.
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:smart_fridge_chef/data/models/product.dart';
import 'package:smart_fridge_chef/share/product_share_codec.dart';

Product product(
  String name, {
  ProductCategory category = ProductCategory.other,
  ProductUnit unit = ProductUnit.pcs,
  double quantity = 1,
  String? barcode,
  int inDays = 7,
  double? kcal,
}) =>
    Product(
      name: name,
      category: category,
      unit: unit,
      quantity: quantity,
      barcode: barcode,
      expiryDate: DateTime(2026, 11, 1).add(Duration(days: inDays)),
      addedAt: DateTime(2026, 10, 25),
      kcalPer100: kcal,
    );

void main() {
  group('payload', () {
    test('компактный JSON: имя/категория/срок/количество/единица/код',
        () {
      final payload = ProductShareCodec.buildPayload([
        product('Молоко Простоквашино 3,2%',
            category: ProductCategory.dairy,
            unit: ProductUnit.milliliter,
            quantity: 930,
            barcode: '4600338011817',
            kcal: 58),
      ]);
      expect(payload, contains('"v":1'));
      expect(payload, contains('"n":1'));
      expect(payload, contains('Молоко Простоквашино 3,2%'));
      expect(payload, contains('4600338011817'));
    });

    test('roundtrip: все поля возвращаются на место', () {
      final original = [
        product('Рис',
            category: ProductCategory.grains,
            unit: ProductUnit.gram,
            quantity: 800),
        product('Сельдь',
            category: ProductCategory.fish,
            unit: ProductUnit.pcs,
            quantity: 2,
            barcode: '2000000012345'),
        product('Йогурт',
            category: ProductCategory.dairy,
            unit: ProductUnit.gram,
            quantity: 290,
            kcal: 84),
      ];
      final restored = ProductShareCodec.decodePayload(
        ProductShareCodec.buildPayload(original),
      ).products;

      expect(restored.length, 3);
      expect(restored[0].name, 'Рис');
      expect(restored[0].category, ProductCategory.grains);
      expect(restored[0].unit, ProductUnit.gram);
      expect(restored[0].quantity, 800);
      expect(restored[0].barcode, isNull);
      expect(restored[0].kcalPer100, isNull);
      expect(restored[1].barcode, '2000000012345');
      expect(restored[2].kcalPer100, 84);
      expect(restored[2].expiryDate, original[2].expiryDate);
    });
  });

  group('многостраничность', () {
    test('мало продуктов — одиночный QR (plain payload)', () {
      final pages = ProductShareCodec.encode([product('Молоко')]);
      expect(pages.length, 1);
      expect(pages.single.startsWith('{'), isTrue);
    });

    test('много продуктов — серия страниц формата Amnezia', () {
      // ~350 продуктов с длинными названиями: payload > 2400 байт.
      final products = [
        for (var i = 0; i < 350; i++)
          product('Продукт с очень длинным названием номер $i '
              'для объёмной передачи'),
      ];
      final pages = ProductShareCodec.encode(products);
      expect(pages.length, greaterThan(1));
      // Каждая страница — base64url без '=' и без '+/'.
      for (final page in pages) {
        expect(page.contains('='), isFalse);
        expect(page.contains('+'), isFalse);
        expect(page.contains('/'), isFalse);
        final chunk = ProductShareCodec.tryParseChunk(page);
        expect(chunk, isNotNull);
        expect(chunk!.total, pages.length);
      }
      // Номера 0..n-1 без пропусков.
      final ids = pages
          .map((p) => ProductShareCodec.tryParseChunk(p)!.id)
          .toSet();
      expect(ids.length, pages.length);
    });

    test('предел 255 страниц: свыше — ошибка', () {
      // 10000 продуктов по ~50 байт: payload ~500КБ > 216 КБ.
      final products = [
        for (var i = 0; i < 10000; i++) product('Продукт номер $i'),
      ];
      expect(
          () => ProductShareCodec.encode(products), throwsArgumentError);
    });

    test('roundtrip через страницы в перемешанном порядке', () {
      final products = [
        for (var i = 0; i < 120; i++)
          product('Товар $i',
              category: ProductCategory.vegetables,
              unit: ProductUnit.gram,
              quantity: 100.0 + i),
      ];
      final pages = ProductShareCodec.encode(products);
      expect(pages.length, greaterThan(1));

      // Приёмник: страницы приходят в случайном порядке, часть —
      // дубликаты (камера видит один и тот же код несколько раз).
      final received = <int, List<int>>{};
      var scans = 0;
      final shuffled = [...pages]..shuffle();
      for (final page in shuffled) {
        final chunk = ProductShareCodec.tryParseChunk(page)!;
        scans++;
        received.putIfAbsent(chunk.id, () => chunk.bodyBytes);
        if (received.length == chunk.total) break;
      }
      expect(received.length, pages.length);
      expect(scans, greaterThanOrEqualTo(pages.length));

      final payload = ProductShareCodec.assemble(received, pages.length);
      expect(payload, isNotNull);
      final restored = ProductShareCodec.decodePayload(payload!).products;
      expect(restored.length, products.length);
      expect(restored.map((p) => p.name).toSet(),
          products.map((p) => p.name).toSet());
    });
  });

  group('устойчивость приёмника', () {
    test('мусор и чужие коды не принимаются', () {
      expect(ProductShareCodec.tryParseChunk('4600338011817'), isNull);
      expect(ProductShareCodec.tryParseChunk(''), isNull);
      expect(ProductShareCodec.tryParseChunk('hello world'), isNull);
      expect(ProductShareCodec.tryParseChunk('{"foo":1}'), isNull);
      expect(ProductShareCodec.tryParseChunk('{"v":1,"n":1,"i":[]}'),
          isNotNull); // одиночный payload валиден
    });

    test('невалидная длина base64 — null', () {
      // Строка длиной % 4 == 1 — некорректный base64url.
      expect(ProductShareCodec.tryParseChunk('abcdefg'), isNull);
    });

    test('заголовок врёт о длине данных — null', () {
      // magic=1984, total=3, id=1, len=12345 — а данных 2 байта.
      final bogus = ProductShareCodec.b64urlEncode(
          [0x07, 0xC0, 3, 1, 0, 0, 0x30, 0x39, 1, 2]);
      expect(ProductShareCodec.tryParseChunk(bogus), isNull);
    });

    test('неполная серия не собирается', () {
      final pages = ProductShareCodec.encode([
        for (var i = 0; i < 200; i++) product('Товар $i'),
      ]);
      expect(pages.length, greaterThan(2));
      final chunk0 = ProductShareCodec.tryParseChunk(pages.first)!;
      final chunkLast = ProductShareCodec.tryParseChunk(pages.last)!;
      // Не хватает середины.
      final partial = {
        chunk0.id: chunk0.bodyBytes,
        chunkLast.id: chunkLast.bodyBytes,
      };
      expect(ProductShareCodec.assemble(partial, chunk0.total), isNull);
    });

    test('дубликаты штрих-кодов внутри передачи отбрасываются', () {
      final payload = ProductShareCodec.buildPayload([
        product('Молоко', barcode: '4600338011817'),
        product('Кефир', barcode: '4600338011817'),
        product('Творог', barcode: '4600338011817'),
      ]);
      final result = ProductShareCodec.decodePayload(payload);
      expect(result.products, hasLength(1));
      expect(result.products.single.name, 'Молоко');
      expect(result.duplicateIds, hasLength(2));
    });
  });

  group('SHARE-5: враждебные значения внутри валидного payload', () {
    // SHARE-3 (v0.6.2): «n» обязано совпадать с числом позиций —
    // враждебные тесты строят payload как настоящий отправитель.
    String hostile(List<List<Object?>> items) =>
        '{"v":1,"n":${items.length},"i":${jsonEncode(items)}}';

    test('отрицательное/нулевое quantity → 1.0', () {
      final r = ProductShareCodec.decodePayload(hostile([
        ['Зло-1', 'dairy', '2026-11-01', -5, 'g', ''],
        ['Зло-2', 'dairy', '2026-11-01', 0, 'g', ''],
      ]));
      expect(r.products.map((p) => p.quantity), everyElement(1.0));
    });

    test('1e999 → Infinity quantity → 1.0 (не течёт в базу)', () {
      // 1e999 — валидный JSON-токен; Dart парсит его как double.infinity,
      // поэтому собираем payload вручную (jsonEncode не кодирует Infinity).
      final r = ProductShareCodec.decodePayload(
          '{"v":1,"n":1,"i":[['
          '"Бесконечность","dairy","2026-11-01",1e999,"g",""]]}');
      expect(r.products.single.quantity, 1.0);
    });

    test('гигантское quantity зажимается до 1 000 000', () {
      final r = ProductShareCodec.decodePayload(hostile([
        ['Море молока', 'dairy', '2026-11-01', 5e9, 'ml', ''],
      ]));
      expect(r.products.single.quantity, 1000000);
    });

    test('гигантское имя обрезается до 200 символов, control-символы чистятся',
        () {
      final r = ProductShareCodec.decodePayload(hostile([
        ['A' * 500, 'dairy', '2026-11-01', 1, 'g', ''],
        ['Зло\u0000влево', 'dairy', '2026-11-01', 1, 'g', ''],
      ]));
      expect(r.products[0].name.length, 200);
      expect(r.products[1].name, 'Зловлево'); // control-символ удалён
    });

    test('имя из одних пробелов/control-символов отбрасывается', () {
      final r = ProductShareCodec.decodePayload(hostile([
        ['   ', 'dairy', '2026-11-01', 1, 'g', ''],
        ['\u0000\u0003', 'dairy', '2026-11-01', 1, 'g', ''],
      ]));
      expect(r.products, isEmpty);
    });

    test('недопустимый штрих-код → null (буквы, длинный, пустой)', () {
      final r = ProductShareCodec.decodePayload(hostile([
        ['Буквы', 'dairy', '2026-11-01', 1, 'g', 'abc123'],
        ['Длинный', 'dairy', '2026-11-01', 1, 'g', '12345678901234567890'],
        ['Пустой', 'dairy', '2026-11-01', 1, 'g', '   '],
      ]));
      expect(r.products.map((p) => p.barcode), everyElement(isNull));
    });

    test('БЖУ: отрицательные → null, бесконечность → null, гигант → 10000',
        () {
      final r = ProductShareCodec.decodePayload(
          '{"v":1,"n":1,"i":[['
          '"Питание","dairy","2026-11-01",1,"g","",'
          '[-5,1e999,999999,12.5]]]}');
      final p = r.products.single;
      expect(p.kcalPer100, isNull); // отрицательный → null
      expect(p.proteinPer100, isNull); // Infinity → null
      expect(p.fatPer100, 10000); // зажат сверху
      expect(p.carbsPer100, 12.5);
    });
  });

  group('SHARE-2/3/4 (v0.6.2)', () {
    test('SHARE-3: расхождение «n» с числом позиций — FormatException',
        () {
      final payload = jsonDecode(ProductShareCodec.buildPayload([
        product('Молоко'), product('Хлеб'),
      ])) as Map<String, dynamic>;
      payload['n'] = 5; // заявлено 5, фактически 2
      expect(() => ProductShareCodec.decodePayload(jsonEncode(payload)),
          throwsFormatException);
    });

    test('SHARE-2: битая дата отбрасывается и считается, не «сегодня»',
        () {
      final payload = jsonDecode(ProductShareCodec.buildPayload([
        product('Молоко'),
      ])) as Map<String, dynamic>;
      final items = (payload['i'] as List<dynamic>).toList();
      items[0][2] = 'not-a-date';
      payload['i'] = items;
      final result = ProductShareCodec.decodePayload(jsonEncode(payload));
      expect(result.products, isEmpty);
      expect(result.invalidCount, 1);
    });

    test('SHARE-2: нереальная дата 31.02 — тоже битая', () {
      final payload = jsonDecode(ProductShareCodec.buildPayload([
        product('Молоко'),
      ])) as Map<String, dynamic>;
      final items = (payload['i'] as List<dynamic>).toList();
      items[0][2] = '2026-02-31';
      payload['i'] = items;
      final result = ProductShareCodec.decodePayload(jsonEncode(payload));
      expect(result.products, isEmpty);
      expect(result.invalidCount, 1);
    });

    test('валидная передача — invalidCount = 0', () {
      final result = ProductShareCodec.decodePayload(
          ProductShareCodec.buildPayload([product('Молоко')]));
      expect(result.invalidCount, 0);
      expect(result.products, hasLength(1));
    });
  });

  group('SHARE-4: QrChunkCollector', () {
    List<String> pagesOf(List<Product> ps) => ProductShareCodec.encode(ps);

    test('полная передача собирается', () {
      final pages = pagesOf([product('Молоко'), product('Хлеб')]);
      if (pages.length == 1) {
        // одна страница — payload целиком
        final c = ProductShareCodec.tryParseChunk(pages.single)!;
        expect(QrChunkCollector().add(c), isNotNull);
        return;
      }
      final collector = QrChunkCollector();
      String? payload;
      for (final p in pages) {
        payload = collector.add(ProductShareCodec.tryParseChunk(p)!);
      }
      expect(payload, isNotNull);
    });

    test('та же страница с ДРУГИМ содержимым начинает сбор заново '
        '(передача с тем же total больше не залипает)', () {
      final pagesA = pagesOf([product('Молоко'), product('Хлеб')]);
      if (pagesA.length < 2) {
        return markTestSkipped('данные влезли в одну страницу');
      }
      final pagesB = pagesOf([product('Сыр'), product('Кефир')]);
      if (pagesB.length != pagesA.length) {
        return markTestSkipped('разное число страниц в фикстурах');
      }
      final collector = QrChunkCollector();
      // Первая передача: страницы 0 и 1 (не полная? собирается — сбросим
      // тестовый сценарий: возьмём страницы 0,1 из A, потом 0 из B).
      collector.add(ProductShareCodec.tryParseChunk(pagesA[0])!);
      collector.add(ProductShareCodec.tryParseChunk(pagesA[1])!);
      // Страница 0 из B — другое содержимое при том же total:
      // сбор начинается заново, старая страница A[1] забыта.
      collector.add(ProductShareCodec.tryParseChunk(pagesB[0])!);
      expect(collector.received, 1, reason: 'старые страницы сброшены');
      // Добираем B — собирается именно передача B.
      String? payload;
      for (var i = 1; i < pagesB.length; i++) {
        payload = collector.add(ProductShareCodec.tryParseChunk(pagesB[i])!);
      }
      expect(payload, isNotNull);
      final result = ProductShareCodec.decodePayload(payload!);
      expect(result.products.map((p) => p.name),
          pagesB.length == 2 ? ['Сыр', 'Кефир'] : isNotEmpty);
    });

    test('недобор сбрасывается по таймауту сессии', () {
      final pages = pagesOf([product('Молоко'), product('Хлеб')]);
      if (pages.length < 2) return markTestSkipped('одна страница');
      final collector = QrChunkCollector(
          sessionTimeout: const Duration(seconds: 45));
      final t0 = DateTime(2026, 10, 28, 12, 0, 0);
      collector.add(ProductShareCodec.tryParseChunk(pages[0])!,
          now: t0);
      expect(collector.received, 1);
      // Через час — передача считается заброшенной: страница 0 той же
      // передачи трактуется как новая попытка (без дубля-игнора).
      collector.add(ProductShareCodec.tryParseChunk(pages[0])!,
          now: t0.add(const Duration(hours: 1)));
      expect(collector.received, 1, reason: 'сессия перезапущена');
    });

    test('дубликат страницы (то же содержимое) игнорируется', () {
      final pages = pagesOf([product('Молоко'), product('Хлеб')]);
      if (pages.length < 2) return markTestSkipped('одна страница');
      final collector = QrChunkCollector();
      collector.add(ProductShareCodec.tryParseChunk(pages[0])!);
      collector.add(ProductShareCodec.tryParseChunk(pages[0])!);
      expect(collector.received, 1);
    });
  });
}
