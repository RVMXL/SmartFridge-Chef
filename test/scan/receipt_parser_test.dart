/// Тесты OCR-парсера чеков (Шаг 3): RU/EN-чеки, служебные строки,
/// количества, цены, дубликаты.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:smart_fridge_chef/scan/receipt_parser.dart';

void main() {
  group('parseReceipt', () {
    test('реалистичный русский чек: товары, цены, количества', () {
      const text = '''
ООО "Пятёрочка"
Молоко Простоквашино 3,2% 930мл
59,90
Кефир 1% 1л х2
119,80
Хлеб Бородинский
42,50
Яблоки Гала 2,145 кг
184,47
ИТОГО: 406,67
НАЛИЧНЫЕ 500,00
СДАЧА 93,33
* ФИСКАЛЬНЫЙ ЧЕК *
''';
      final items = parseReceipt(text);
      final names = items.map((i) => i.name).toList();

      // Служебные строки отброшены.
      expect(names, isNot(contains('Итого')));
      expect(names.any((n) => n.toLowerCase().contains('фискаль')), isFalse);

      // Молоко: название + цена.
      final milk = items.firstWhere((i) => i.name.toLowerCase().contains('молоко'));
      expect(milk.price, 59.90);
      expect(milk.quantity, 1);

      // Кефир с количеством х2.
      final kefir = items.firstWhere((i) => i.name.toLowerCase().contains('кефир'));
      expect(kefir.quantity, 2);
      expect(kefir.price, 119.80);

      expect(items, hasLength(4));
    });

    test('английский чек', () {
      const text = '''
SUPERMARKET #12
Milk 1L
2.49
Bread x2
3.98
TOTAL 6.47
CASH 10.00
CHANGE 3.53
THANK YOU
''';
      final items = parseReceipt(text);
      expect(items.map((i) => i.name.toLowerCase()), contains('milk 1l'));
      expect(items.map((i) => i.name.toLowerCase()), contains('bread'));
      expect(items, hasLength(2));
      final bread = items.firstWhere((i) => i.name == 'Bread');
      expect(bread.quantity, 2);
      expect(bread.price, 3.98);
    });

    test('дубликаты схлопываются, количество суммируется', () {
      const text = '''
Молоко
59,90
МОЛОКО
59,90
''';
      final items = parseReceipt(text);
      expect(items, hasLength(1));
      expect(items.single.quantity, 2);
    });

    test('строки из одних цифр и мусор отбрасываются', () {
      const text = '''
123456
78
===-===
Молоко
''';
      final items = parseReceipt(text);
      expect(items, hasLength(1));
      expect(items.single.name, 'Молоко');
    });

    test('пустой текст и только служебные строки — пустой список', () {
      expect(parseReceipt(''), isEmpty);
      expect(parseReceipt('ИТОГО 100,00\nНАЛИЧНЫЕ'), isEmpty);
    });

    test('короткие названия (2+ букв) допускаются, обрывки нет', () {
      const text = '''
Сок
Мо
x
''';
      final items = parseReceipt(text);
      expect(items.map((i) => i.name), contains('Сок'));
    });

    test('цена с точкой и с запятой распознаётся одинаково', () {
      final a = parseReceipt('Сыр\n99,90');
      final b = parseReceipt('Сыр\n99.90');
      expect(a.single.price, b.single.price);
      expect(a.single.price, 99.90);
    });

    test('количество в префиксе «2 х Молоко»', () {
      final items = parseReceipt('2 х Молоко\n120,00');
      expect(items.single.quantity, 2);
      expect(items.single.name, 'Молоко');
    });
  });

  group('SCAN-1: границы слов стоп-слов (аудит 2026-10-28)', () {
    test('товары со «стоп-подстрокой» внутри выживают', () {
      final items = parseReceipt(
          'Картофель 59,90\nКартошка 45,00\nПакетик чая 89,90\n'
          'Cashews 2.49\nCardamom 0.50');
      final names = items.map((i) => i.name).toSet();
      expect(names, contains('Картофель'));
      expect(names, contains('Картошка'));
      expect(names, contains('Пакетик чая'));
      expect(names, contains('Cashews'));
      expect(names, contains('Cardamom'));
    });

    test('служебные строки по-прежнему выбрасываются', () {
      final items = parseReceipt(
          'ИТОГ 500,00\nИтого к оплате 500,00\nКасса 1\nКарта оплаты\n'
          'Сдача 0,00\nПакет 5,00\nTOTAL 25.00\nCASH 100.00\n'
          'Card 25.00\nCHANGE DUE 75.00\nМолоко 89,90');
      expect(items, hasLength(1));
      expect(items.single.name, 'Молоко');
    });

    test('словоформы стоп-слов ловятся, чужие слова — нет', () {
      // «Итог/Итого/Итоги» — стоп; «Чек» — стоп; «Чечевица» — товар.
      final items = parseReceipt(
          'Чечевица 120,00\nЧек №123456\nСайт магазина\n'
          'Магазин «У дома»');
      final names = items.map((i) => i.name).toSet();
      expect(names, contains('Чечевица'));
      expect(names, hasLength(1));
    });
  });

  group('ReceiptCandidate', () {
    test('равенство по имени без учёта регистра', () {
      const a = ReceiptCandidate(name: 'Молоко', rawLine: 'Молоко');
      const b = ReceiptCandidate(name: 'молоко', rawLine: 'МОЛОКО');
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });
  });
}
