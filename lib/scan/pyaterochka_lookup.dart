/// Цены «Пятёрочки» — второй источник данных (v0.5.5, эксперимент).
///
/// Каталог 5ka.ru не требует ключей и авторизации, но его WAF пускает
/// только «домашние» IP: запросы выполняются ПРЯМО С УСТРОЙСТВА
/// пользователя (natивные HTTP без CORS). Датацентровые и VPN-адреса
/// получают HTML-заглушку «Проблемы со связью» — это детектируется и
/// превращается в [PyaterochkaUnavailable]: приложение просто остаётся
/// без цены, всё остальное работает как раньше (offline-first).
///
/// Документированные эндпоинты (см. scripts/pyaterochka_fixture_search.json
/// и worklog, Task 14-pyaterochka-close):
///   GET https://5d.5ka.ru/api/catalog/v3/stores/{sapCode}/search
///       ?mode=store&include_restrict=true&q={запрос}&limit={n}
/// Заголовки, которые шлёт веб-фронт (без них — блокировка):
///   x-device-id (анонимный uuid), x-app-version: 0.1.1.dev,
///   x-platform: webapp, x-tenant-id: TC5.
/// В выдаче поиска НЕТ штрих-кода/КБЖУ/состава — Пятёрочка даёт только
/// цену/наличие/остатки; пищевая ценность по-прежнему из Open Food Facts.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Найденный в каталоге товар: минимум для подстановки цены.
class PyaterochkaHit {
  const PyaterochkaHit({
    required this.plu,
    required this.name,
    required this.price,
    this.oldPrice,
    this.isAvailable = true,
    this.packageQuantity,
    this.rating,
    this.ratesCount,
  });

  /// Идентификатор карточки товара в каталоге Пятёрочки.
  final int plu;
  final String name;

  /// Текущая цена за упаковку, ₽ (prices.regular).
  final double price;

  /// «Старая цена» из акции (prices.discount), если есть.
  final double? oldPrice;

  /// Есть ли товар в выбранном магазине.
  final bool isAvailable;

  /// Фасовка как в каталоге («310 г», «930 мл»).
  final String? packageQuantity;

  final double? rating;
  final int? ratesCount;

  bool get isPromo => oldPrice != null && oldPrice! > price;
}

/// Почему не получилось получить цены.
enum PyaterochkaFailReason {
  /// WAF: датацентровый/VPN IP, HTML-заглушка, не-200 ответ.
  blocked,

  /// Сеть: таймаут, нет соединения.
  network,
}

/// Цены недоступны — приложению следует молча продолжать без них.
class PyaterochkaUnavailable implements Exception {
  const PyaterochkaUnavailable(this.reason);

  final PyaterochkaFailReason reason;

  @override
  String toString() => 'PyaterochkaUnavailable(${reason.name})';
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

/// Чистый парсер ответа поиска Пятёрочки (без сети — удобно тестировать).
///
/// Ожидает {"products": [...]}; неизвестные поля игнорируются, битые
/// позиции пропускаются. Пустой список — валидный ответ «ничего не нашли».
List<PyaterochkaHit> parsePyaterochkaSearchJson(Map<String, dynamic> json) {
  final raw = json['products'] ?? json['items'];
  if (raw is! List) return const [];

  final hits = <PyaterochkaHit>[];
  for (final item in raw) {
    if (item is! Map<String, dynamic>) continue;
    final name = (item['name'] as String?)?.trim() ?? '';
    final plu = item['plu'];
    if (name.isEmpty || plu is! int) continue;

    final prices = item['prices'];
    final price = _parsePrice(
      prices is Map<String, dynamic> ? prices['regular'] : null,
    );
    if (price == null) continue;

    final oldPrice = _parsePrice(
      prices is Map<String, dynamic> ? prices['discount'] : null,
    );
    final rating = item['rating'];
    hits.add(PyaterochkaHit(
      plu: plu,
      name: name,
      price: price,
      oldPrice: oldPrice,
      isAvailable: item['is_available'] is bool
          ? item['is_available'] as bool
          : true,
      packageQuantity:
          _cleanText(item['package_quantity'] as String? ?? item['property_clarification'] as String?),
      rating: (rating is Map<String, dynamic>
              ? rating['rating_average']
              : null)
          ?.toDouble(),
      ratesCount: rating is Map<String, dynamic>
          ? (rating['rates_count'] as num?)?.toInt()
          : null,
    ));
  }
  return hits;
}

/// Выбор лучшего совпадения с запросом среди [hits].
///
/// Счёт: +2 за каждый токен запроса, найденный в названии товара,
/// +3 если товар содержит весь запрос целиком. При равенстве выигрывает
/// популярнее товар (больше оценок), затем выше рейтинг. Товары без
/// ни одного совпадения не предлагаются (null) — чтобы не подставлять
/// цену случайного товара.
PyaterochkaHit? pickBestPyaterochkaHit(
  List<PyaterochkaHit> hits,
  String query,
) {
  final q = normalizeForMatch(query);
  if (q.isEmpty) return null;
  final tokens = q.split(' ').where((t) => t.length >= 2).toSet();

  PyaterochkaHit? best;
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

String? _cleanText(String? raw) {
  final v = raw?.replaceAll(RegExp(r'\s+'), ' ').trim() ?? '';
  return v.isEmpty ? null : v;
}

double? _parsePrice(dynamic raw) {
  if (raw == null) return null;
  if (raw is num) return raw.toDouble();
  return double.tryParse(raw.toString().replaceAll(',', '.').trim());
}

/// HTTP-клиент каталога Пятёрочки. Все методы могут бросить только
/// [PyaterochkaUnavailable] — любого рода неудача означает «цены нет».
class PyaterochkaService {
  PyaterochkaService({
    http.Client? httpClient,
    this.timeout = const Duration(seconds: 6),
  }) : _client = httpClient;

  static const String _host = '5d.5ka.ru';

  /// Версия веб-фронта, зафиксированная при эксперименте (Task 14).
  static const String _appVersion = '0.1.1.dev';

  static const String _storeCodePref = 'pref_pyat_device_id';

  final http.Client? _client;
  final Duration timeout;

  /// Анонимный идентификатор устройства, как у веб-фронта: генерируется
  /// один раз и хранится локально. Наружу не передаётся ничего, кроме
  /// самого запроса поиска (это часть протокола 5ka.ru).
  Future<String> ensureDeviceId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing = prefs.getString(_storeCodePref);
      if (existing != null && existing.isNotEmpty) return existing;
      final id = _generateUuidV4();
      await prefs.setString(_storeCodePref, id);
      return id;
    } catch (_) {
      // SharedPreferences недоступен (тесты) — одноразовый id на запуск.
      return _generateUuidV4();
    }
  }

  /// Поиск по каталогу выбранного магазина.
  ///
  /// [storeCode] — SAP-код магазина (см. настройки). Бросает
  /// [PyaterochkaUnavailable] при блокировке WAF или проблемах сети.
  Future<List<PyaterochkaHit>> search({
    required String storeCode,
    required String query,
    int limit = 12,
  }) async {
    final cleanStore = storeCode.trim();
    final cleanQuery = query.trim();
    if (cleanStore.isEmpty || cleanQuery.isEmpty) return const [];

    final deviceId = await ensureDeviceId();
    final uri = Uri.https(_host, '/api/catalog/v3/stores/$cleanStore/search', {
      'mode': 'store',
      'include_restrict': 'true',
      'q': cleanQuery,
      'limit': '$limit',
    });

    final http.Response response;
    try {
      response = await (_client ?? http.Client())
          .get(uri, headers: {
            'Accept': 'application/json, text/plain, */*',
            'User-Agent': _mobileUserAgent,
            'Referer': 'https://5ka.ru/',
            'x-device-id': deviceId,
            'x-app-version': _appVersion,
            'x-platform': 'webapp',
            'x-tenant-id': 'TC5',
          })
          .timeout(timeout);
    } on TimeoutException {
      throw const PyaterochkaUnavailable(PyaterochkaFailReason.network);
    } on SocketException {
      throw const PyaterochkaUnavailable(PyaterochkaFailReason.network);
    } on http.ClientException {
      throw const PyaterochkaUnavailable(PyaterochkaFailReason.network);
    }

    // WAF: не-200 или HTML-заглушка «Проблемы со связью» (VPN/датацентр).
    final body = utf8.decode(response.bodyBytes, allowMalformed: true);
    if (response.statusCode != 200 || body.trimLeft().startsWith('<')) {
      throw const PyaterochkaUnavailable(PyaterochkaFailReason.blocked);
    }

    final Object decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      throw const PyaterochkaUnavailable(PyaterochkaFailReason.blocked);
    }
    if (decoded is! Map<String, dynamic>) {
      throw const PyaterochkaUnavailable(PyaterochkaFailReason.blocked);
    }
    return parsePyaterochkaSearchJson(decoded);
  }
}

/// Мобильный Chrome UA: с «голым» Dart-клиентом WAF строже, чем с браузерным.
const String _mobileUserAgent =
    'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36';

String _generateUuidV4() {
  final rnd = Random.secure();
  final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40; // версия 4
  bytes[8] = (bytes[8] & 0x3f) | 0x80; // вариант RFC 4122
  String hex(int b) => b.toRadixString(16).padLeft(2, '0');
  final h = bytes.map(hex).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-'
      '${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
}
