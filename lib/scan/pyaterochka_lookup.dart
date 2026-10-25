/// Цены «Пятёрочки» — источник данных для России (v0.5.5, эксперимент;
/// v0.5.6 — переведён на общий контракт [PriceHit]).
///
/// Каталог 5ka.ru не требует ключей и авторизации, но его WAF пускает
/// только «домашние» IP: запросы выполняются ПРЯМО С УСТРОЙСТВА
/// пользователя (нативные HTTP без CORS). Датацентровые и VPN-адреса
/// получают HTML-заглушку «Проблемы со связью» — это детектируется и
/// превращается в [PriceUnavailable]: приложение просто остаётся
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
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'price_source.dart';

export 'price_source.dart'
    show PriceFailReason, PriceHit, PriceUnavailable, normalizeForMatch;

/// Чистый парсер ответа поиска Пятёрочки (без сети — удобно тестировать).
///
/// Ожидает {"products": [...]}; неизвестные поля игнорируются, битые
/// позиции пропускаются. Пустой список — валидный ответ «ничего не нашли».
List<PriceHit> parsePyaterochkaSearchJson(Map<String, dynamic> json) {
  final raw = json['products'] ?? json['items'];
  if (raw is! List) return const [];

  final hits = <PriceHit>[];
  for (final item in raw) {
    if (item is! Map<String, dynamic>) continue;
    final name = (item['name'] as String?)?.trim() ?? '';
    final plu = item['plu'];
    if (name.isEmpty || plu is! int) continue;

    final prices = item['prices'];
    final price = parsePriceValue(
      prices is Map<String, dynamic> ? prices['regular'] : null,
    );
    if (price == null) continue;

    final oldPrice = parsePriceValue(
      prices is Map<String, dynamic> ? prices['discount'] : null,
    );
    final rating = item['rating'];
    hits.add(PriceHit(
      name: name,
      price: price,
      oldPrice: oldPrice,
      isAvailable: item['is_available'] is bool
          ? item['is_available'] as bool
          : true,
      packageQuantity: _cleanText(
          item['package_quantity'] as String? ??
              item['property_clarification'] as String?),
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

/// Лучшее совпадение с запросом (общий матчер, см. [pickBestPriceHit]).
PriceHit? pickBestPyaterochkaHit(List<PriceHit> hits, String query) =>
    pickBestPriceHit(hits, query);

String? _cleanText(String? raw) {
  final v = raw?.replaceAll(RegExp(r'\s+'), ' ').trim() ?? '';
  return v.isEmpty ? null : v;
}

/// HTTP-клиент каталога Пятёрочки. Все методы могут бросить только
/// [PriceUnavailable] — любого рода неудача означает «цены нет».
class PyaterochkaService {
  PyaterochkaService({
    http.Client? httpClient,
    this.timeout = const Duration(seconds: 6),
  }) : _client = httpClient;

  static const String _host = '5d.5ka.ru';

  /// Версия веб-фронта, зафиксированная при эксперименте (Task 14).
  static const String _appVersion = '0.1.1.dev';

  static const String _deviceIdPref = 'pref_pyat_device_id';

  final http.Client? _client;
  final Duration timeout;

  /// Анонимный идентификатор устройства, как у веб-фронта: генерируется
  /// один раз и хранится локально. Наружу не передаётся ничего, кроме
  /// самого запроса поиска (это часть протокола 5ka.ru).
  Future<String> ensureDeviceId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing = prefs.getString(_deviceIdPref);
      if (existing != null && existing.isNotEmpty) return existing;
      final id = _generateUuidV4();
      await prefs.setString(_deviceIdPref, id);
      return id;
    } catch (_) {
      // SharedPreferences недоступен (тесты) — одноразовый id на запуск.
      return _generateUuidV4();
    }
  }

  /// Поиск по каталогу выбранного магазина.
  ///
  /// [storeCode] — SAP-код магазина (см. настройки). Бросает
  /// [PriceUnavailable] при блокировке WAF или проблемах сети.
  Future<List<PriceHit>> search({
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
    } on Exception catch (e) {
      throwNetwork(e);
    }

    // WAF: не-200 или HTML-заглушка «Проблемы со связью» (VPN/датацентр).
    final body = utf8.decode(response.bodyBytes, allowMalformed: true);
    if (response.statusCode != 200 || looksLikeHtml(body)) {
      throw const PriceUnavailable(PriceFailReason.blocked);
    }

    final Object decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      throw const PriceUnavailable(PriceFailReason.blocked);
    }
    if (decoded is! Map<String, dynamic>) {
      throw const PriceUnavailable(PriceFailReason.blocked);
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
