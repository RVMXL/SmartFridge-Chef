/// Тесты кодека обмена продуктами (v0.5.0): формат страниц Amnezia
/// (magic 1984, чанки 850 байт, base64url), одиночная передача,
/// дедупликация, восстановление порядка, устойчивость к мусору.
library;

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
}
