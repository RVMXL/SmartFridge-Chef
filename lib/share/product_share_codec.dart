/// Кодек обмена продуктами через многостраничный QR-код (v0.5.0).
///
/// Формат страниц — как в AmneziaVPN (core/utils/qrCodeUtils.cpp), тот же
/// приём используется в WarpScoutGUI-AWG (qrPagesFor): длинный payload
/// режется на страницы по 850 байт, каждая кодируется как
///
///   base64url( int16be 1984 ‖ uint8 всего ‖ uint8 № ‖ uint32be длина ‖ данные )
///
/// (QDataStream — big-endian). Если payload влезает в один QR целиком
/// (~2.4 КБ), он передаётся одним кодом как есть (без обёртки) —
/// читается и постраничным приёмником, и сторонними сканерами.
///
/// Пределы: всего страниц — uint8, максимум 255 → 255 × 850 = 216 750
/// байт полезной нагрузки (~3000 продуктов с запасом). Приёмник
/// собирает страницы по номеру, дубликаты игнорируются, порядок не
/// важен — страницы можно показывать/сканировать в любом порядке.
///
/// Сам payload — компактный JSON:
///
///   {"v":1,"n":<кол-во>,"i":[[имя,категория,срок,кол-во,единица,штрих-код,[ккал,б,ж,у]],...]}
///
/// Питательная ценность (на 100 г) — необязательный хвост массива,
/// null если не известна. Ничего не передаёт наружу, кроме продуктов.
library;

import 'dart:convert';
import 'dart:typed_data';

import '../data/models/product.dart';

/// Одна страница многостраничного QR.
class QrChunk {
  const QrChunk({
    required this.total,
    required this.id,
    required this.bodyBytes,
  });

  /// Всего страниц в передаче (1..255).
  final int total;

  /// Номер страницы (0-based).
  final int id;

  /// Сырые байты куска payload. Специально НЕ строка: граница чанка
  /// может пройти посреди многобайтового UTF-8 символа — декодировать
  /// можно только собранный целиком payload (см. [ProductShareCodec.assemble]).
  final List<int> bodyBytes;
}

/// Собранный приёмником результат: продукты + дубликаты штрих-кодов.
class SharedProducts {
  const SharedProducts({
    required this.products,
    required this.duplicateIds,
    this.invalidCount = 0,
  });

  /// Продукты к добавлению (addedAt проставляется здесь, id даст БД).
  final List<Product> products;

  /// Штрих-коды, повторяющиеся внутри самой передачи (не записаны).
  final List<String> duplicateIds;

  /// SHARE-2 (v0.6.2): позиции с битой датой/именем — отброшены,
  /// а не «молча сегодня»; приёмщик видит честное число потерь.
  final int invalidCount;
}

class ProductShareCodec {
  ProductShareCodec._();

  /// Байт данных на страницу — ровно как в qrCodeUtils.cpp Amnezia.
  static const int chunkSize = 850;

  /// Магия начала страницы (qrMagicCode).
  static const int magic = 1984;

  /// Ёмкость одиночного QR с запасом: максимальная версия (40-L) держит
  /// 2953 байта; payload до 2400 байт передаём одним кодом как есть.
  static const int singleLimit = 2400;

  // --- SHARE-1 (аудит 2026-10-28): пределы валидации чужого QR-приёма ---
  /// Максимальная длина имени продукта.
  static const int _maxNameLength = 200;

  /// Максимальное количество (г/мл/шт) — защита от 1e999.
  static const double _maxQuantity = 1000000;

  /// Максимальное значение БЖУ/ккал на 100 г.
  static const double _maxNutrient = 10000;

  /// Штрих-код: только цифры, 1–14 знаков (EAN-8/UPC/EAN-13).
  static final RegExp _barcodePattern = RegExp(r'^\d{1,14}$');

  /// Control-символы, вычищаемые из имён чужих продуктов.
  static final RegExp _controlChars = RegExp(r'[\x00-\x1F\x7F]');

  // ------------------------------------------------------------ кодирование

  /// Компактный payload из продуктов.
  static String buildPayload(List<Product> products) {
    final items = <List<Object?>>[];
    for (final p in products) {
      final nutrition = (p.kcalPer100 != null ||
              p.proteinPer100 != null ||
              p.fatPer100 != null ||
              p.carbsPer100 != null)
          ? <Object?>[
              p.kcalPer100,
              p.proteinPer100,
              p.fatPer100,
              p.carbsPer100,
            ]
          : null;
      items.add([
        p.name,
        p.category.key,
        Product.formatDate(p.expiryDate),
        p.quantity,
        p.unit.key,
        p.barcode,
        nutrition,
      ]);
    }
    return jsonEncode({'v': 1, 'n': items.length, 'i': items});
  }

  /// Строки для QR-кодов: одиночный (plain payload) или серия страниц.
  static List<String> encode(List<Product> products) {
    final payload = buildPayload(products);
    final bytes = utf8.encode(payload);
    if (bytes.length <= singleLimit) return [payload];
    final total = (bytes.length / chunkSize).ceil();
    if (total > 255) {
      throw ArgumentError(
        'Слишком много продуктов для QR: $total страниц (максимум 255)',
      );
    }
    final pages = <String>[];
    for (var p = 0; p < total; p++) {
      final end = (p + 1) * chunkSize > bytes.length
          ? bytes.length
          : (p + 1) * chunkSize;
      final chunk = bytes.sublist(p * chunkSize, end);
      final buf = Uint8List(8 + chunk.length);
      final dv = ByteData.view(buf.buffer);
      dv.setInt16(0, magic, Endian.big);
      buf[2] = total;
      buf[3] = p;
      dv.setUint32(4, chunk.length, Endian.big);
      buf.setRange(8, buf.length, chunk);
      pages.add(b64urlEncode(buf));
    }
    return pages;
  }

  // ------------------------------------------------------------ декодирование

  /// Разбор распознанной сканером строки: страница формата Amnezia
  /// или одиночный plain-payload. null — строка не наша (чужой QR,
  /// штрих-код товара и т.п.).
  static QrChunk? tryParseChunk(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return null;
    if (value.startsWith('{')) {
      // Одиночная передача: payload как есть.
      if (_isValidPayload(value)) {
        return QrChunk(total: 1, id: 0, bodyBytes: utf8.encode(value));
      }
      return null;
    }
    final bytes = b64urlDecode(value);
    if (bytes == null || bytes.length < 9) return null;
    final dv = ByteData.view(bytes.buffer, bytes.offsetInBytes, bytes.length);
    if (dv.getInt16(0, Endian.big) != magic) return null;
    final total = bytes[2];
    final id = bytes[3];
    final len = dv.getUint32(4, Endian.big);
    if (total < 1 || id >= total || len == 0) return null;
    if (len > chunkSize || 8 + len > bytes.length) return null;
    // Байты без UTF-8-декодирования: чанк может резать символ пополам.
    return QrChunk(total: total, id: id, bodyBytes: bytes.sublist(8, 8 + len));
  }

  /// Собирает payload из принятых страниц (ключ — номер страницы)
  /// и декодирует UTF-8 один раз на цельном payload.
  /// null — набор неполный или данные повреждены.
  static String? assemble(Map<int, List<int>> chunks, int total) {
    if (total < 1 || chunks.length != total) return null;
    final buffer = BytesBuilder();
    for (var i = 0; i < total; i++) {
      final body = chunks[i];
      if (body == null) return null;
      buffer.add(body);
    }
    try {
      return utf8.decode(buffer.toBytes(), allowMalformed: false);
    } on FormatException {
      return null;
    }
  }

  /// Payload → продукты. Бросает FormatException при повреждённых данных;
  /// продукты с неизвестной категорией/единицей получают дефолты,
  /// дубликаты штрих-кодов внутри передачи отбрасываются.
  ///
  /// SHARE-1 (аудит 2026-10-28): значения из чужого QR валидируются и
  /// зажимаются так же, как ручная форма: quantity ≤ 0 / NaN / Infinity →
  /// 1.0 (иначе 1e999 → Infinity попадал в SQLite), БЖУ/ккал — конечные,
  /// отрицательные → null, свыше 10000 → 10000; имя обрезается до 200
  /// символов и чистится от control-символов; штрих-код — только цифры,
  /// до 14 знаков, иначе null.
  static SharedProducts decodePayload(String payload) {
    final obj = jsonDecode(payload);
    if (obj is! Map || obj['v'] != 1) {
      throw const FormatException('Неизвестный формат передачи');
    }
    final items = obj['i'];
    if (items is! List) {
      throw const FormatException('Список продуктов отсутствует');
    }
    // SHARE-3 (аудит 2026-10-28, v0.6.2): заголовок «n» — заявленное
    // число позиций; расхождение с фактом = битая передача (обрезка,
    // подделка), а не «сколько-то продуктов».
    final declared = obj['n'];
    if (declared is! int || declared != items.length) {
      throw const FormatException(
          'Число позиций не совпадает с заголовком передачи');
    }
    final now = DateTime.now();
    final products = <Product>[];
    final duplicateIds = <String>[];
    final seenBarcodes = <String>{};
    var invalidCount = 0;
    for (final raw in items) {
      if (raw is! List || raw.length < 6) {
        invalidCount++;
        continue;
      }
      // SHARE-1: имя — непустое, без control-символов, до 200 символов.
      var name = '${raw[0]}'.trim().replaceAll(_controlChars, '');
      if (name.isEmpty) {
        invalidCount++;
        continue;
      }
      if (name.length > _maxNameLength) {
        name = name.substring(0, _maxNameLength);
      }
      final category = ProductCategory.fromKey('${raw[1]}');
      // SHARE-2: битая дата больше не «сегодня» — позиция отбрасывается
      // и попадает в invalidCount (продукт с сроком на месяц вперёд
      // вместо фактического сегодня опаснее отсутствующего).
      final expiry = _parseStrictDate('${raw[2]}');
      if (expiry == null) {
        invalidCount++;
        continue;
      }
      // SHARE-1: quantity — конечное положительное число, как в ручной
      // форме (qty ≤ 0 → 1.0); 1e999 → Infinity отбрасывается.
      double quantity = 1.0;
      if (raw[3] is num) {
        final q = (raw[3] as num).toDouble();
        if (q.isFinite && q > 0) {
          quantity = q > _maxQuantity ? _maxQuantity : q;
        }
      }
      final unit = ProductUnit.fromKey('${raw[4]}');
      final barcodeRaw = raw[5];
      // SHARE-1: штрих-код — цифровой, до 14 знаков (EAN-8/UPC/EAN-13),
      // мусор → null (не превращаем чужой QR в битые коды в базе).
      final barcodeStr =
          barcodeRaw is String ? barcodeRaw.trim() : null;
      final barcode = (barcodeStr != null && _barcodePattern.hasMatch(barcodeStr))
          ? barcodeStr
          : null;
      double? kcal, protein, fat, carbs;
      if (raw.length >= 7 && raw[6] is List) {
        final nut = raw[6] as List;
        double? sane(int i) {
          if (i >= nut.length || nut[i] is! num) return null;
          final v = (nut[i] as num).toDouble();
          if (!v.isFinite || v < 0) return null;
          return v > _maxNutrient ? _maxNutrient : v;
        }

        kcal = sane(0);
        protein = sane(1);
        fat = sane(2);
        carbs = sane(3);
      }
      if (barcode != null && !seenBarcodes.add(barcode)) {
        duplicateIds.add(barcode);
        continue; // дубль внутри передачи
      }
      products.add(Product(
        name: name,
        category: category,
        barcode: barcode,
        quantity: quantity,
        unit: unit,
        expiryDate: expiry,
        addedAt: now,
        kcalPer100: kcal,
        proteinPer100: protein,
        fatPer100: fat,
        carbsPer100: carbs,
        status: ProductStatus.active,
      ));
    }
    return SharedProducts(
      products: products,
      duplicateIds: duplicateIds,
      invalidCount: invalidCount,
    );
  }

  /// Валидация payload без полного парсинга (для одиночного QR).
  static bool _isValidPayload(String value) {
    try {
      final obj = jsonDecode(value);
      return obj is Map && obj['v'] == 1 && obj['i'] is List;
    } catch (_) {
      return false;
    }
  }

  /// SHARE-2 (v0.6.2): строгая дата «yyyy-mm-dd» (как пишет buildPayload).
  /// null — мусор/нереальная дата (31.02), НЕ «сегодня».
  static DateTime? _parseStrictDate(String s) {
    final p = s.split('-');
    if (p.length != 3) return null;
    final y = int.tryParse(p[0]);
    final m = int.tryParse(p[1]);
    final d = int.tryParse(p[2]);
    if (y == null || m == null || d == null) return null;
    if (m < 1 || m > 12 || d < 1 || d > 31) return null;
    final dt = DateTime(y, m, d);
    // Нормализация «31.02 → 2-3 марта» = битая дата.
    if (dt.year != y || dt.month != m || dt.day != d) return null;
    return dt;
  }

  // ------------------------------------------------------------ base64url

  /// base64url без паддинга (как в Amnezia: + → -, / → _, = срезаны).
  /// Публичный — нужен тесту для сборки «битых» страниц.
  static String b64urlEncode(List<int> bytes) {
    var s = base64Url.encode(bytes);
    s = s.replaceAll('+', '-').replaceAll('/', '_');
    while (s.endsWith('=')) {
      s = s.substring(0, s.length - 1);
    }
    return s;
  }

  /// Обратное преобразование; null при невалидных символах.
  static Uint8List? b64urlDecode(String input) {
    var s = input.replaceAll('-', '+').replaceAll('_', '/');
    final mod = s.length % 4;
    if (mod == 1) return null; // некорректная длина base64
    if (mod != 0) s += '=' * (4 - mod);
    try {
      return base64.decode(s);
    } catch (_) {
      return null;
    }
  }
}

/// SHARE-4 (аудит 2026-10-28, v0.6.2): приёмщик страниц QR-передачи
/// с защитой от «залипания». Раньше состояние жило в полях экрана:
/// сломанная передача (не все страницы) навсегда занимала слоты, и
/// НОВАЯ передача с тем же числом страниц не могла собраться — страницы
/// с теми же номерами считались дубликатами. Теперь: страница с тем же
/// номером, но другим содержимым начинает сбор заново, а недобор
/// сбрасывается по таймауту.
class QrChunkCollector {
  QrChunkCollector({this.sessionTimeout = const Duration(seconds: 45)});

  /// Через сколько секунд недобранной передачи ждать новой попытки.
  final Duration sessionTimeout;

  final Map<int, List<int>> _chunks = <int, List<int>>{};
  int? _total;
  DateTime? _lastAt;

  int? get total => _total;
  int get received => _chunks.length;

  /// Добавляет страницу; возвращает собранный payload (все страницы)
  /// или null, если передача ещё не полная.
  String? add(QrChunk chunk, {DateTime? now}) {
    final t = now ?? DateTime.now();
    // Недобор давно не пополнялся — новая попытка, а не продолжение.
    if (_lastAt != null && t.difference(_lastAt!) > sessionTimeout) {
      reset();
    }
    _lastAt = t;

    if (_total != null && chunk.total != _total) {
      // Другая передача: недобор — начинаем заново; добор — игнорируем.
      if (_chunks.length < _total!) {
        reset();
      } else {
        return null;
      }
    }
    _total ??= chunk.total;

    final existing = _chunks[chunk.id];
    if (existing != null) {
      if (_bytesEqual(existing, chunk.bodyBytes)) {
        return ProductShareCodec.assemble(_chunks, _total!);
      }
      // Тот же номер страницы, ДРУГОЕ содержимое — новая передача с тем
      // же total: сбрасываем и начинаем с этой страницы.
      reset();
      _total = chunk.total;
    }
    _chunks[chunk.id] = chunk.bodyBytes;
    return ProductShareCodec.assemble(_chunks, _total!);
  }

  void reset() {
    _chunks.clear();
    _total = null;
    _lastAt = null;
  }

  static bool _bytesEqual(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
