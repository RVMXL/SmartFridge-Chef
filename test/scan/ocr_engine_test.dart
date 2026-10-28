/// Тесты OCR-движков (OCR-1, v0.6.2).
///
/// Сетевые/нативные движки подменяются фейками: проверяется ЛОГИКА
/// автовыбора AutoOcrEngine — кириллица → Tesseract без фолбэка,
/// латиница → сравнение качества, тихие сбои, полная неудача.
/// Нативная часть (модель, плагин) проверяется на устройстве.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:smart_fridge_chef/scan/ocr_engine.dart';

class _FakeEngine implements OcrEngine {
  _FakeEngine(this.name, this.text, {this.error});

  @override
  final String name;
  final String text;
  final Object? error;
  int calls = 0;
  bool disposed = false;

  @override
  Future<OcrOutcome> recognize(String imagePath) async {
    calls++;
    if (error != null) throw error!;
    return OcrOutcome(text: text, engine: name);
  }

  @override
  void dispose() => disposed = true;
}

void main() {
  group('AutoOcrEngine — автовыбор движка', () {
    test('кириллица в тексте Tesseract → результат сразу, ML Kit не зовётся',
        () async {
      final tesseract = _FakeEngine(
          'tesseract_rus',
          'МОЛОКО 89,90\nХЛЕБ 45\nСЫР 199,00\nИТОГО 333,90');
      final mlkit = _FakeEngine('mlkit_latin', 'garbage');
      final engine = AutoOcrEngine(tesseract: tesseract, mlkit: mlkit);

      final outcome = await engine.recognize('/tmp/receipt.jpg');

      expect(outcome.engine, 'tesseract_rus');
      expect(outcome.text, contains('МОЛОКО'));
      expect(mlkit.calls, 0); // кириллица — фолбэк бессмыслен
    });

    test('латиница → оба движка, побеждает более парсящийся текст', () async {
      final tesseract = _FakeEngine('tesseract_rus', 'MLK 89');
      final mlkit = _FakeEngine(
          'mlkit_latin', 'Milk 89.90\nBread 45.00\nCheese 199.00');
      final engine = AutoOcrEngine(tesseract: tesseract, mlkit: mlkit);

      final outcome = await engine.recognize('/tmp/receipt.jpg');

      expect(outcome.engine, 'mlkit_latin');
      expect(outcome.text, contains('Milk'));
      expect(tesseract.calls, 1);
      expect(mlkit.calls, 1);
    });

    test('латиница + слабый ML Kit → остаётся результат Tesseract', () async {
      final tesseract = _FakeEngine('tesseract_rus', 'Milk 89.90\nBread 45');
      final mlkit = _FakeEngine('mlkit_latin', '');
      final engine = AutoOcrEngine(tesseract: tesseract, mlkit: mlkit);

      final outcome = await engine.recognize('/tmp/receipt.jpg');

      expect(outcome.engine, 'tesseract_rus');
    });

    test('тихий сбой Tesseract → ML Kit используется', () async {
      final tesseract = _FakeEngine('tesseract_rus', '', error: Exception('so'));
      final mlkit = _FakeEngine('mlkit_latin', 'Milk 2.49\nEggs 3.99');
      final engine = AutoOcrEngine(tesseract: tesseract, mlkit: mlkit);

      final outcome = await engine.recognize('/tmp/receipt.jpg');

      expect(outcome.engine, 'mlkit_latin');
    });

    test('оба упали → исключение первого (Tesseract) наружу', () async {
      final tesseract = _FakeEngine('tesseract_rus', '', error: StateError('t'));
      final mlkit = _FakeEngine('mlkit_latin', '', error: StateError('m'));
      final engine = AutoOcrEngine(tesseract: tesseract, mlkit: mlkit);

      await expectLater(
        engine.recognize('/tmp/receipt.jpg'),
        throwsStateError,
      );
    });

    test('dispose закрывает оба движка', () {
      final tesseract = _FakeEngine('tesseract_rus', '');
      final mlkit = _FakeEngine('mlkit_latin', '');
      final engine = AutoOcrEngine(tesseract: tesseract, mlkit: mlkit);

      engine.dispose();

      expect(tesseract.disposed, isTrue);
      expect(mlkit.disposed, isTrue);
    });
  });

  group('quality — эвристика качества текста', () {
    test('пустой текст — 0', () {
      expect(AutoOcrEngine.quality(''), 0);
    });

    test('позиции весят больше, чем мусорные символы', () {
      final junk = AutoOcrEngine.quality('abcdef123456789');
      final items = AutoOcrEngine.quality(
          'МОЛОКО 89,90\nХЛЕБ 45,00\nСЫР 199,00\nИТОГО 333,90');
      expect(items, greaterThan(junk));
    });
  });
}
