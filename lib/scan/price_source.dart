/// Универсальный контракт источников цен (v0.5.6).
///
/// Приложение поддерживает несколько необязательных источников цены,
/// каждый реализует одну и ту же пару «парсер + сервис»:
///
/// * Пятёрочка (Россия) — поиск по названию, каталог 5ka.ru без ключей;
///   запросы только с устройства (WAF не пускает датацентровые IP).
/// * Kroger (США) — официальный Public API с client_credentials ключом
///   самого пользователя; поиск по названию, цена конкретного магазина.
/// * Open Prices (весь мир) — открытая база цен проекта Open Food Facts,
///   без ключей, запрос по штрих-коду.
///
/// Общие правила: источник НЕ меняет поведение приложения офлайн — любая
/// неудача ([PriceUnavailable]) означает лишь «цена не подставилась»;
/// продукты по-прежнему описываются Open Food Facts (КБЖУ/состав).
library;

import 'dart:async';
import 'dart:io';

/// Универсальный найденный товар: всё, что нужно для подстановки цены.
class PriceHit {
  const PriceHit({
    required this.name,
    required this.price,
    this.oldPrice,
    this.isAvailable = true,
    this.packageQuantity,
    this.currencySymbol = '₽',
    this.rating,
    this.ratesCount,
  });

  /// Название товара в источнике (для строки «Совпало: …»).
  final String name;

  /// Текущая цена за упаковку (prices.regular / price.regular).
  final double price;

  /// «Старая цена»/цена без скидки, если есть (prices.discount,
  /// price.promo, price_without_discount).
  final double? oldPrice;

  /// Есть ли товар в выбранном магазине.
  final bool isAvailable;

  /// Фасовка как в источнике («310 г», «1 gal»).
  final String? packageQuantity;

  /// Символ валюты для поля ввода (₽ / $ / €).
  final String currencySymbol;

  final double? rating;
  final int? ratesCount;

  bool get isPromo => oldPrice != null && oldPrice! > price;
}

/// Почему не получилось получить цены.
enum PriceFailReason {
  /// Источник недоступен: WAF/антибот (HTML-заглушка), не-200 ответ.
  blocked,

  /// Сеть: таймаут, нет соединения.
  network,

  /// Ключ отклонён (Kroger: неверный client_id/secret).
  auth,
}

/// Цены недоступны — приложению следует молча продолжать без них.
class PriceUnavailable implements Exception {
  const PriceUnavailable(this.reason);

  final PriceFailReason reason;

  @override
  String toString() => 'PriceUnavailable(${reason.name})';
}

/// Нормализация названия для сопоставления: нижний регистр, ё → е,
/// знаки препинания → пробел, схлопнутые пробелы.
String normalizeForMatch(String raw) {
  final lowered = raw
      .toLowerCase()
      .replaceAll('ё', 'е')
      .replaceAll(RegExp(r'[^0-9a-zа-я]+'), ' ');
  return lowered.replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// Выбор лучшего совпадения с запросом среди [hits].
///
/// Счёт: +2 за каждый токен запроса, найденный в названии товара,
/// +3 если товар содержит весь запрос целиком. При равенстве выигрывает
/// популярнее товар (больше оценок), затем выше рейтинг. Товары без
/// ни одного совпадения не предлагаются (null) — чтобы не подставлять
/// цену случайного товара.
PriceHit? pickBestPriceHit(List<PriceHit> hits, String query) {
  final q = normalizeForMatch(query);
  if (q.isEmpty) return null;
  final tokens = q.split(' ').where((t) => t.length >= 2).toSet();

  PriceHit? best;
  var bestScore = 0;
  var bestRates = -1;
  var bestRating = -1.0;
  for (final hit in hits) {
    final name = normalizeForMatch('${hit.name} ${hit.packageQuantity ?? ''}');
    var score = 0;
    for (final token in tokens) {
      if (name.contains(token)) score += 2;
    }
    if (name.contains(q)) score += 3;
    if (score == 0) continue;

    final rates = hit.ratesCount ?? 0;
    final rating = hit.rating ?? 0.0;
    if (score > bestScore ||
        (score == bestScore &&
            (rates > bestRates ||
                (rates == bestRates && rating > bestRating)))) {
      best = hit;
      bestScore = score;
      bestRates = rates;
      bestRating = rating;
    }
  }
  return best;
}

/// Разбор числового поля цены: num как есть, строка с запятой/пробелами.
/// NET-6 (аудит 2026-10-28): безопасные чтения JSON. Неофициальные API
/// отдают неожиданные типы (число вместо строки и т.п.); `as String?`
/// бросает TypeError — это Error, а не Exception, обычные catch его не
/// ловили, ошибка уходила в unhandled zone и навсегда оставляла спиннер
/// цены. Парсеры читают поля только через эти функции.
String? jsonStr(Object? v) => v is String ? v : null;

num? jsonNum(Object? v) => v is num ? v : null;

double? parsePriceValue(dynamic raw) {
  if (raw == null) return null;
  if (raw is num) return raw.toDouble();
  return double.tryParse(raw.toString().replaceAll(',', '.').trim());
}

/// Преобразование сетевых исключений в [PriceUnavailable.network].
Never throwNetwork(Exception e) {
  if (e is TimeoutException || e is SocketException || e is HttpException) {
    throw const PriceUnavailable(PriceFailReason.network);
  }
  throw const PriceUnavailable(PriceFailReason.network);
}

/// Ожидает ли JSON-ответ (иначе считаем антибот-заглушкой).
bool looksLikeHtml(String body) => body.trimLeft().startsWith('<');
