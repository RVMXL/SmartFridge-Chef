/// OCR-движки распознавания чеков (OCR-1, аудит 2026-10-28).
///
/// ML Kit Text Recognition v2 официально поддерживает только латиницу,
/// китайский, деванагари, японский и корейский — кириллицы в списке нет,
/// поэтому русский чек он читает в мусор. Решение — второй движок:
/// Tesseract с русской моделью (tessdata_fast, rus.traineddata 3,7 МБ,
/// лицензия Apache 2.0 — см. NOTICE), медленнее, но кириллицу читает.
///
/// [AutoOcrEngine] комбинирует оба:
///  1. Сначала Tesseract (rus): если в тексте есть кириллица — изображение
///     точно не для ML Kit latin, отдаём результат Tesseract.
///  2. Иначе (латиница или тихий сбой Tesseract) — ML Kit, и побеждает
///     тот движок, чей текст лучше парсится в позиции чека.
///
/// Всё распознавание — на устройстве; фото никуда не отправляется.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_tesseract_ocr/flutter_tesseract_ocr.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'receipt_parser.dart';

/// Результат распознавания: текст + какой движок его дал.
class OcrOutcome {
  const OcrOutcome({required this.text, required this.engine});

  final String text;

  /// 'tesseract_rus' | 'mlkit_latin' (для логов и тестов).
  final String engine;
}

/// Один OCR-движок: путь к фото → результат.
abstract interface class OcrEngine {
  String get name;

  Future<OcrOutcome> recognize(String imagePath);

  void dispose() {}
}

/// Tesseract с русской моделью: кириллические чеки (OCR-1).
///
/// Модель rus.traineddata лежит в assets/tessdata и при первом запуске
/// копируется плагином в документы приложения (tessdata_config.json).
/// psm 4 — «одна колонка текста переменной высоты», формат чека.
class TesseractOcrEngine implements OcrEngine {
  const TesseractOcrEngine();

  @override
  String get name => 'tesseract_rus';

  @override
  Future<OcrOutcome> recognize(String imagePath) async {
    final text = await FlutterTesseractOcr.extractText(
      imagePath,
      language: 'rus',
      args: {'psm': '4', 'preserve_interword_spaces': '1'},
    );
    return OcrOutcome(text: text, engine: name);
  }

  @override
  void dispose() {} // у Tesseract-движка нет удерживаемых ресурсов
}

/// ML Kit latin — бывший единственный движок (до v0.6.2): быстрый и
/// точный для латиницы, но кириллицу не умеет по документации Google.
class MlKitLatinOcrEngine implements OcrEngine {
  final TextRecognizer _recognizer =
      TextRecognizer(script: TextRecognitionScript.latin);

  @override
  String get name => 'mlkit_latin';

  @override
  Future<OcrOutcome> recognize(String imagePath) async {
    final input = InputImage.fromFilePath(imagePath);
    final result = await _recognizer.processImage(input);
    return OcrOutcome(text: result.text, engine: name);
  }

  @override
  void dispose() => _recognizer.close();
}

/// Автовыбор движка: Tesseract (кириллица) → ML Kit (латиница).
class AutoOcrEngine implements OcrEngine {
  AutoOcrEngine({OcrEngine? tesseract, OcrEngine? mlkit})
      : _tesseract = tesseract ?? TesseractOcrEngine(),
        _mlkit = mlkit ?? MlKitLatinOcrEngine();

  final OcrEngine _tesseract;
  final OcrEngine _mlkit;

  @override
  String get name => 'auto(${_tesseract.name}+${_mlkit.name})';

  /// Сколько строк текста парсер чека узнал как позиции × 100 плюс
  /// алфанумерных символов (не больше 99) — эвристическое качество.
  @visibleForTesting
  static int quality(String text) {
    final candidates = parseReceipt(text).length;
    final alnum =
        RegExp(r'[0-9a-zа-яё]', caseSensitive: false).allMatches(text).length;
    return candidates * 100 + (alnum > 99 ? 99 : alnum);
  }

  @override
  Future<OcrOutcome> recognize(String imagePath) async {
    Object? tesseractError;
    var tesseractOutcome = const OcrOutcome(text: '', engine: 'tesseract_rus');
    var tesseractQuality = -1;
    try {
      tesseractOutcome = await _tesseract.recognize(imagePath);
      tesseractQuality = quality(tesseractOutcome.text);
    } catch (e) {
      tesseractError = e; // тихий сбой Tesseract — пробуем ML Kit
    }

    // Кириллица в тексте Tesseract → изображение точно не латиница:
    // ML Kit latin кириллицу не умеет, его фолбэк бессмыслен.
    if (tesseractQuality > 0 &&
        RegExp(r'[а-яё]', caseSensitive: false)
            .hasMatch(tesseractOutcome.text)) {
      return tesseractOutcome;
    }

    try {
      final mlkitOutcome = await _mlkit.recognize(imagePath);
      if (quality(mlkitOutcome.text) > tesseractQuality) {
        return mlkitOutcome;
      }
    } catch (e) {
      if (tesseractQuality < 0) tesseractError ??= e;
    }

    if (tesseractQuality >= 0) return tesseractOutcome;
    throw tesseractError ?? StateError('Оба OCR-движка не вернули текст');
  }

  @override
  void dispose() {
    _tesseract.dispose();
    _mlkit.dispose();
  }
}
