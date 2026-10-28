/// Разбор текста чека, распознанного ML Kit (Шаг 3) — чистый Dart.
///
/// ML Kit отдаёт строки распознанного текста; здесь они превращаются в
/// кандидатов на добавление в холодильник: название + цена + количество.
/// Эвристики рассчитаны на RU- и EN-чеки супермаркетов и намеренно
/// консервативны: спорные строки пользователь правит на экране чека
/// перед добавлением.
library;

/// Кандидат из чека на добавление в холодильник.
class ReceiptCandidate {
  const ReceiptCandidate({
    required this.name,
    this.price,
    this.quantity = 1,
    required this.rawLine,
  });

  /// Очищенное название товара.
  final String name;

  /// Цена позиции (если распознана), в валюте чека.
  final double? price;

  /// Количество (2, если в строке «2 х Молоко» / «Moloko x2»).
  final int quantity;

  /// Исходная строка чека (показывается в UI для сверки).
  final String rawLine;

  @override
  bool operator ==(Object other) =>
      other is ReceiptCandidate &&
      other.name.toLowerCase() == name.toLowerCase();

  @override
  int get hashCode => name.toLowerCase().hashCode;

  @override
  String toString() =>
      'ReceiptCandidate($name, x$quantity${price == null ? '' : ', $price'})';
}

/// Служебные слова чеков, по которым строка выбрасывается целиком
/// (итоги, касса, оплата, налоги, шапка магазина).
///
/// SCAN-1 (аудит 2026-10-28): совпадение — НЕ по подстроке, а по границам
/// слов: токен строки равен стему или стему + падежному окончанию
/// (см. [_isServiceLine]). Иначе «карт» выбрасывал «Картофель/Картошка»,
/// «пакет» — «Пакетик чая», EN «cash» — «Cashews», «card» — «Cardamom»,
/// «market» ловил чужие бренды подстрокой. Многословные фразы — в
/// [kReceiptServicePhrases] (проверка по подстроке — внутри фразы граница
/// и так есть).
const List<String> kReceiptServiceWords = [
  // RU (стемы: токен = стем + падежное окончание из _ruEndings)
  'итог', 'сумма', 'касс', 'чек', 'сдача', 'налич', 'карт', 'безнал',
  'скидк', 'бонус', 'ндс', 'ндфл', 'налог', 'фискаль', 'знв', 'окп',
  'смен', 'транзакц', 'терминал', 'спасибо', 'балл', 'пакет', 'внесен',
  'продавец', 'инн', 'кассир', 'приход', 'возврат', 'штрих',
  'ооо', 'оао', 'зао', 'ип', 'обществ', 'супермаркет', 'магазин',
  'сайт', 'заказ', 'доставка',
  // EN (токен = стем + -s/-es или точное совпадение)
  'total', 'subtotal', 'cash', 'change', 'card', 'visa', 'mastercard',
  'payment', 'tax', 'vat', 'discount', 'receipt', 'thank',
  'balance', 'loyalty', 'points', 'cashier', 'store', 'terminal',
  'market', 'supermarket', 'order', 'delivery', 'llc', 'inc.',
];

/// Многословные служебные фразы чеков (проверка по подстроке).
const List<String> kReceiptServicePhrases = [
  'change due',
  'сумма документа',
  'итого к оплате',
];

/// Падежные окончания, которые «доращивают» стем до словоформы
/// (итог/итого/итоги, касса/кассы, картой/карту — но не картофель).
const Set<String> _ruEndings = {
  '', 'а', 'я', 'ы', 'и', 'у', 'ю', 'е', 'о',
  'ой', 'ом', 'ам', 'ах', 'ями', 'ами', 'ов', 'ев', 'ей', 'ий', 'ия',
  'ые', 'ый', 'ими', 'ыми', 'ую', 'юю', 'ем', 'ях', 'ии', 'ие', 'ь',
  // прилагательные: наличные/наличным/сменные…
  'ные', 'ный', 'ная', 'ной', 'ному', 'ными',
};

/// Английские словоформы стемов (total → totals, card → cards).
const Set<String> _enEndings = {'', 's', 'es'};

/// Токен — последовательность букв/цифр (латиница + кириллица).
final RegExp _tokenSeparator = RegExp(r'[^a-zа-яё0-9]+');

/// Регулярка цены в конце строки: «59,90» / «59.90» / «59 90».
final RegExp _priceEnd = RegExp(r'(\d{1,6})[.,\s](\d{2})(?=\s*$)');

/// Префикс количества: «2 x», «2х», «x2», «х2» в начале или внутри.
final RegExp _qtyPrefix = RegExp(r'^\s*(\d{1,2})\s*[xх*]\s*', caseSensitive: false);
final RegExp _qtySuffix = RegExp(r'\s*[xх*]\s*(\d{1,2})\s*$', caseSensitive: false);

/// Разбирает полный текст чека в список кандидатов.
///
/// Особенность реальных чеков: цена часто печатается на ОТДЕЛЬНОЙ строке
/// под названием товара — такая строка прикрепляется к предыдущей позиции.
/// Дубликаты (одно и то же имя в разном регистре) схлопываются,
/// количество суммируется — в чеке товар часто печатается в 2 строки.
List<ReceiptCandidate> parseReceipt(String text) {
  final merged = <String, ReceiptCandidate>{};
  final order = <String>[];

  for (final rawLine in text.split(RegExp(r'\r?\n'))) {
    final line = rawLine.trim();
    if (line.length < 3) continue;
    final lowered = line.toLowerCase();
    if (_isServiceLine(lowered)) continue;

    double? price;
    var body = line;

    // Цена в конце строки: «… 59,90» / «Milk 2.49».
    final pm = _priceEnd.firstMatch(body);
    if (pm != null) {
      price = double.parse('${pm.group(1)}.${pm.group(2)}');
      body = body.substring(0, pm.start);
    }

    var qty = 1;
    final qp = _qtyPrefix.firstMatch(body);
    if (qp != null) {
      qty = int.parse(qp.group(1)!);
      body = body.substring(qp.end);
    } else {
      final qs = _qtySuffix.firstMatch(body);
      if (qs != null && int.parse(qs.group(1)!) > 1) {
        qty = int.parse(qs.group(1)!);
        body = body.substring(0, qs.start);
      }
    }

    final name = _cleanName(body);

    // Цена на отдельной строке → прикрепляем к предыдущей позиции.
    if (name == null && price != null && order.isNotEmpty) {
      final lastKey = order.last;
      final last = merged[lastKey]!;
      if (last.price == null) {
        merged[lastKey] = ReceiptCandidate(
          name: last.name,
          price: price,
          quantity: last.quantity,
          rawLine: last.rawLine,
        );
      }
      continue;
    }
    if (name == null) continue;

    final key = name.toLowerCase();
    final existing = merged[key];
    if (existing != null) {
      merged[key] = ReceiptCandidate(
        name: existing.name,
        price: existing.price ?? price,
        quantity: existing.quantity + qty,
        rawLine: existing.rawLine,
      );
    } else {
      merged[key] = ReceiptCandidate(
        name: name,
        price: price,
        quantity: qty,
        rawLine: line,
      );
      order.add(key);
    }
  }

  return [for (final k in order) merged[k]!];
}

/// SCAN-1: строка служебная, если хотя бы один её токен равен стему
/// стоп-слова или является стемом с падежным окончанием.
bool _isServiceLine(String lowered) {
  if (kReceiptServicePhrases.any(lowered.contains)) return true;
  for (final token in lowered.split(_tokenSeparator)) {
    if (token.isEmpty) continue;
    for (final stem in kReceiptServiceWords) {
      if (!token.startsWith(stem)) continue;
      final rest = token.substring(stem.length);
      if (_ruEndings.contains(rest) || _enEndings.contains(rest)) {
        return true;
      }
    }
  }
  return false;
}

/// Чистит «тело» строки до названия товара.
///
/// Правила: выбрасываем цифры-артикулы и одиночные латинско-цифровые
/// обрывки, обрезаем по 40 символов, капителим первую букву. Строка без
/// хотя бы двух букв подряд — не товар.
String? _cleanName(String body) {
  var s = body
      .replaceAll(RegExp(r'[#:*|=<>{}\[\]\\/_]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  // Хвостовые артикулы: « 123456», « №12».
  s = s.replaceAll(RegExp(r'\s*№?\s*\d{4,}\s*$'), '');

  if (s.length > 40) s = s.substring(0, 40).trim();

  // Должна остаться хотя бы одна «словесная» часть из 2+ букв
  // (RU или латиница) — отсекает строки из одних цифр и мусора.
  if (!RegExp(r'[а-яёa-z]{2,}', caseSensitive: false).hasMatch(s)) {
    return null;
  }

  if (s.isEmpty) return null;
  final first = s[0].toUpperCase();
  return first + s.substring(1);
}
