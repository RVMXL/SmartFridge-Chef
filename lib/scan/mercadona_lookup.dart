/// Цены Mercadona (Испания) — каталог tienda.mercadona.es (v0.5.8,
/// эксперимент; общий контракт [PriceHit]).
///
/// Открытый каталог веб-фронта не требует ключей и авторизации, поискового
/// эндпоинта у него НЕТ (проверено 2026-10: /api/search → 404). Поэтому
/// поиск по названию делается локально: сервис один раз собирает индекс
/// товаров по всем категориям (26 верхних → 152 категории 1-го уровня,
/// примерно 20–40 секунд), кэширует его в памяти и SQLite (SCAN-6,
/// аудит 2026-10-28: раньше индекс ≈0,5 МБ жил в SharedPreferences —
/// XML-пресеты грузятся целиком при первом доступе и jank-ят старт) и
/// дальше отвечает мгновенно. Индекс устаревает через [kCatalogTtl] и
/// обновляется в фоне при первом поиске после истечения срока.
///
///   GET https://tienda.mercadona.es/api/categories/        — дерево
///   GET https://tienda.mercadona.es/api/categories/{id}/   — категория
/// Продукт: display_name, price_instructions.unit_price (цена за упаковку,
/// строка в евро), price_instructions.previous_unit_price (цена до скидки),
/// packaging, unit_size + size_format. Прямые топ-идентификаторы
/// (/api/categories/12/) отдают 404 — фетчить можно только категории
/// 1-го уровня из дерева.
///
/// Цены — складские (без выбора магазина); запросы идут ПРЯМО С
/// УСТРОЙСТВА, наружу не передаётся ничего, кроме самого запроса каталога.
/// Любая неудача — [PriceUnavailable]: приложение остаётся без цены.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../data/data_store.dart';

import 'price_source.dart';

export 'price_source.dart'
    show PriceFailReason, PriceHit, PriceUnavailable, normalizeForMatch;

/// Жизнь кэша индекса: цены Mercadona стабильны, акции меняются еженедельно.
const Duration kMercadonaCatalogTtl = Duration(days: 3);

/// Пауза между запросами категорий, чтобы не грузить каталог залпом.
const Duration kMercadonaPacing = Duration(milliseconds: 100);

/// Чистый парсер ответа /api/categories/{id}/: рекурсивно обходит
/// categories[] и собирает products[] в [PriceHit]. Битые позиции
/// пропускаются. Неизвестные поля игнорируются.
List<PriceHit> parseMercadonaCategoryJson(Map<String, dynamic> json) {
  final hits = <PriceHit>[];
  void walkCategory(Map<String, dynamic> node) {
    final children = node['categories'];
    if (children is List) {
      for (final child in children) {
        if (child is Map<String, dynamic>) walkCategory(child);
      }
    }
    final products = node['products'];
    if (products is List) {
      for (final product in products) {
        if (product is Map<String, dynamic>) {
          final hit = _parseMercadonaProduct(product);
          if (hit != null) hits.add(hit);
        }
      }
    }
  }

  walkCategory(json);
  return hits;
}

PriceHit? _parseMercadonaProduct(Map<String, dynamic> item) {
  // Непубликуемые товары пропускаем целиком.
  if (item['published'] == false) return null;

  final name = (jsonStr(item['display_name']) ?? '').trim();
  if (name.isEmpty) return null;

  final pi = item['price_instructions'];
  if (pi is! Map<String, dynamic>) return null;

  final price = parsePriceValue(pi['unit_price']);
  if (price == null || price <= 0) return null;

  var oldPrice = parsePriceValue(pi['previous_unit_price']);
  if (oldPrice != null && oldPrice <= price) oldPrice = null;

  return PriceHit(
    name: name,
    price: price,
    oldPrice: oldPrice,
    packageQuantity: _mercadonaQuantity(
      packaging: jsonStr(item['packaging']),
      unitSize: pi['unit_size'],
      sizeFormat: jsonStr(pi['size_format']),
    ),
    currencySymbol: '€',
  );
}

/// Фасовка «Garrafa · 5 l»; без упаковки — просто «5 l», без размеров — null.
String? _mercadonaQuantity({
  String? packaging,
  Object? unitSize,
  String? sizeFormat,
}) {
  final parts = <String>[];
  final pack = packaging?.replaceAll(RegExp(r'\s+'), ' ').trim() ?? '';
  if (pack.isNotEmpty) parts.add(pack);

  final size = unitSize;
  final format = sizeFormat?.trim() ?? '';
  if (size is num && size > 0 && format.isNotEmpty) {
    final shown =
        size == size.roundToDouble() ? size.round().toString() : '$size';
    parts.add('$shown $format');
  }
  return parts.isEmpty ? null : parts.join(' · ');
}

// ---------------------------------------------------------------------------
// Компактное хранение индекса: {"n": имя, "p": цена, "o": старая, "q": фасовка}
// ---------------------------------------------------------------------------

/// Кодирование списка хитов в компактный JSON (SharedPreferences не
/// любит большие структуры — экономим каждый байт: ~7 000 товаров).
String encodeMercadonaIndex(List<PriceHit> hits) {
  final list = [
    for (final h in hits)
      {
        'n': h.name,
        'p': h.price,
        if (h.oldPrice != null) 'o': h.oldPrice,
        if (h.packageQuantity != null) 'q': h.packageQuantity,
      },
  ];
  return jsonEncode(list);
}

/// Обратное преобразование; битые записи пропускаются.
List<PriceHit> decodeMercadonaIndex(String raw) {
  final Object decoded;
  try {
    decoded = jsonDecode(raw);
  } on FormatException {
    return const [];
  }
  if (decoded is! List) return const [];
  final hits = <PriceHit>[];
  for (final entry in decoded) {
    if (entry is! Map<String, dynamic>) continue;
    final price = parsePriceValue(entry['p']);
    final name = (jsonStr(entry['n']) ?? '').trim();
    if (name.isEmpty || price == null || price <= 0) continue;
    final old = parsePriceValue(entry['o']);
    hits.add(PriceHit(
      name: name,
      price: price,
      oldPrice: (old != null && old > price) ? old : null,
      packageQuantity: jsonStr(entry['q'])?.trim(),
      currencySymbol: '€',
    ));
  }
  return hits;
}

/// HTTP-клиент каталога Mercadona с локальным индексом-кэшем.
/// Все методы бросают только [PriceUnavailable].
class MercadonaService {
  MercadonaService({
    http.Client? httpClient,
    this.timeout = const Duration(seconds: 8),
    this.pacing = kMercadonaPacing,
    this.ttl = kMercadonaCatalogTtl,
    Future<Database> Function()? openDb,
  })  : _client = httpClient,
        _openDb = openDb ?? AppDataStore.instance.database;

  static const String _host = 'tienda.mercadona.es';

  static const String _table = 'mercadona_index';
  /// Старый prefs-ключ (v0.5.8): читается один раз при апгрейде и удаляется.
  static const String _legacyIndexPref = 'pref_mercadona_catalog_json';
  /// TTL-метка — маленький int, SharedPreferences здесь уместны.
  static const String _indexAtPref = 'pref_mercadona_catalog_at';

  final Future<Database> Function() _openDb;

  final http.Client? _client;
  http.Client? _ownClient;
  final Duration timeout;
  final Duration pacing;
  final Duration ttl;

  /// NET-7 (аудит 2026-10-28): бюджет полной сборки индекса — 152
  /// категории × до 8 с могли длиться 20+ минут без дедлайна.
  static const Duration indexBuildBudget = Duration(seconds: 60);

  /// UI-8 (аудит 2026-10-28): ход сборки индекса для UI. null — сборка
  /// не идёт; иначе (сделано, всего) — пользователь видит прогресс и
  /// может отменить ([requestCancelBuild]).
  final ValueNotifier<(int, int)?> buildProgress = ValueNotifier(null);
  bool _cancelRequested = false;

  /// Просит остановить текущую сборку индекса (уже скачанное
  /// персистится — продолжение будет поверх частичного кэша).
  void requestCancelBuild() => _cancelRequested = true;

  List<PriceHit>? _index;
  Future<List<PriceHit>?>? _building;

  /// NET-1 (аудит 2026-10-28): один переиспользуемый клиент на сервис.
  /// http.Client() на каждый запрос утекал вместе с keep-alive-пулом
  /// (пик — 153 клиента за одну сборку индекса Mercadona); сервис —
  /// синглтон приложения, собственный клиент живёт столько же.
  http.Client get _effectiveClient {
    final injected = _client;
    if (injected != null) return injected;
    return _ownClient ??= http.Client();
  }

  /// Закрыть собственный клиент (инжектированный извне не наш — не трогаем).
  void dispose() => _ownClient?.close();

  /// NET-2 (аудит 2026-10-28): .timeout() лишь перестаёт ждать —
  /// подвисший запрос продолжает качаться в фоне и жечь батарею.
  /// Закрываем собственный клиент (обрываем сокеты); следующий запрос
  /// создаст свежий. Инжектированный извне клиент (тесты) не наш —
  /// его не трогаем.
  void _cancelStuck() {
    if (_client != null) return;
    _ownClient?.close();
    _ownClient = null;
  }

  /// Кандидаты для поиска: весь индекс каталога. Подбор совпадения —
  /// общий матчер [pickBestPriceHit] на стороне вызова.
  ///
  /// Первый вызов на устройстве без кэша собирает индекс по сети
  /// (десятки секунд); с кэшем — мгновенный. Устаревший кэш отдаётся
  /// сразу, а обновление идёт в фоне.
  Future<List<PriceHit>> search({required String query}) async {
    if (query.trim().isEmpty) return const [];
    final index = await ensureIndex();
    return index ?? const <PriceHit>[];
  }

  /// Гарантирует наличие индекса (single-flight: параллельные вызовы
  /// ждут одну и ту же сборку).
  Future<List<PriceHit>?> ensureIndex() {
    if (_index != null) return Future.value(_index);
    final running = _building;
    if (running != null) return running;
    final tracked = _loadOrBuild().whenComplete(() => _building = null);
    _building = tracked;
    return tracked;
  }

  Future<List<PriceHit>?> _loadOrBuild() async {
    final cached = await _loadFromStore();
    if (cached != null && cached.isNotEmpty) {
      _index = cached;
      if (await _isStale()) {
        // Фоновое обновление: текущий поиск отвечает по старому индексу.
        unawaited(_rebuildInBackground());
      }
      return _index;
    }
    try {
      return await _buildAndPersist();
    } on PriceUnavailable {
      rethrow;
    }
  }

  Future<void> _rebuildInBackground() async {
    try {
      await _buildAndPersist();
    } on PriceUnavailable {
      // Стройка не удалась — продолжаем жить со старым индексом.
    }
  }

  Future<List<PriceHit>> _buildAndPersist({
    void Function(int done, int total)? onProgress,
    bool Function()? isCancelled,
  }) async {
    _cancelRequested = false;
    buildProgress.value = (0, 0);
    try {
      final hits = await _buildIndexFromNetwork(
        onProgress: (done, total) {
          onProgress?.call(done, total);
          buildProgress.value = (done, total);
        },
        isCancelled: isCancelled ?? () => _cancelRequested,
      );
      _index = hits;
      await _persist(hits);
      return hits;
    } finally {
      buildProgress.value = null;
    }
  }

  Future<List<PriceHit>> _buildIndexFromNetwork({
    void Function(int done, int total)? onProgress,
    bool Function()? isCancelled,
  }) async {
    final root = await _getJson(Uri.https(_host, '/api/categories/'));
    final tops = root['results'];
    if (tops is! List) {
      throw const PriceUnavailable(PriceFailReason.blocked);
    }

    // Фетчить можно только категории 1-го уровня (прямые топ-коды дают 404).
    final levelOneIds = <int>[];
    for (final top in tops) {
      if (top is! Map<String, dynamic>) continue;
      final children = top['categories'];
      if (children is! List) continue;
      for (final child in children) {
        if (child is! Map<String, dynamic>) continue;
        final id = child['id'];
        if (id is int) levelOneIds.add(id);
      }
    }
    if (levelOneIds.isEmpty) {
      throw const PriceUnavailable(PriceFailReason.blocked);
    }

    // NET-7 (аудит 2026-10-28): сборка больше не all-or-nothing.
    // Бюджет 60 с, отмена, отказ одной категории не аннулирует уже
    // полученные: индекс персистится частями каждые 10 категорий,
    // следующий запуск продолжит со свежим TTL поверх частичного кэша.
    final deadline = DateTime.now().add(indexBuildBudget);
    final total = levelOneIds.length;
    final hits = <PriceHit>[];
    for (var i = 0; i < total; i++) {
      if (isCancelled != null && isCancelled()) break;
      if (DateTime.now().isAfter(deadline)) break;
      try {
        final category = await _getJson(
          Uri.https(_host, '/api/categories/${levelOneIds[i]}/'),
        );
        hits.addAll(parseMercadonaCategoryJson(category));
      } on PriceUnavailable {
        continue; // категория недоступна — остальные продолжаем
      }
      onProgress?.call(i + 1, total);
      if ((i + 1) % 10 == 0 && hits.isNotEmpty) {
        await _persist(List<PriceHit>.of(hits));
      }
      if (i < total - 1) {
        await Future<void>.delayed(pacing);
      }
    }
    return hits;
  }

  Future<Database?> _openDbSafe() async {
    try {
      return await _openDb();
    } catch (_) {
      return null; // база недоступна — индекс живёт в памяти.
    }
  }

  /// Индекс из SQLite (SCAN-6); если база пуста — одноразовый импорт из
  /// prefs апгрейдера со старой версией (после импорта prefs-ключ
  /// удаляется: SharedPreferences больше не растёт на мегабайты).
  Future<List<PriceHit>?> _loadFromStore() async {
    final db = await _openDbSafe();
    if (db != null) {
      try {
        final rows = await db.query(_table);
        final hits = <PriceHit>[];
        for (final row in rows) {
          final price = parsePriceValue(row['price']);
          final name = (jsonStr(row['name']) ?? '').trim();
          if (name.isEmpty || price == null || price <= 0) continue;
          final old = parsePriceValue(row['old_price']);
          hits.add(PriceHit(
            name: name,
            price: price,
            oldPrice: (old != null && old > price) ? old : null,
            packageQuantity: jsonStr(row['package_quantity'])?.trim(),
            currencySymbol: '€',
          ));
        }
        if (hits.isNotEmpty) return hits;
      } catch (_) {
        // Таблицы может не быть у базы, открытой до v8, — импорт/сеть.
      }
    }
    return _importLegacyPrefs(db);
  }

  Future<List<PriceHit>?> _importLegacyPrefs(Database? db) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_legacyIndexPref);
      if (raw == null || raw.isEmpty) return null;
      final hits = decodeMercadonaIndex(raw);
      if (hits.isNotEmpty && db != null) {
        await _persistToDb(db, hits);
      }
      await prefs.remove(_legacyIndexPref);
      return hits.isEmpty ? null : hits;
    } catch (_) {
      return null; // prefs недоступны (тесты) — только сетевая стройка.
    }
  }

  Future<bool> _isStale() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final at = prefs.getInt(_indexAtPref) ?? 0;
      final age = DateTime.now().millisecondsSinceEpoch - at;
      return age > ttl.inMilliseconds;
    } catch (_) {
      return false;
    }
  }

  Future<void> _persist(List<PriceHit> hits) async {
    final db = await _openDbSafe();
    if (db == null) return; // базы нет — индекс живёт в памяти до перезапуска.
    try {
      await _persistToDb(db, hits);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
          _indexAtPref, DateTime.now().millisecondsSinceEpoch);
    } catch (_) {
      // База недоступна — индекс живёт в памяти до перезапуска.
    }
  }

  Future<void> _persistToDb(Database db, List<PriceHit> hits) async {
    await db.transaction((txn) async {
      await txn.delete(_table);
      final batch = txn.batch();
      for (final h in hits) {
        batch.insert(_table, {
          'name': h.name,
          'price': h.price,
          'old_price': h.oldPrice,
          'package_quantity': h.packageQuantity,
        });
      }
      await batch.commit(noResult: true);
    });
  }

  Future<Map<String, dynamic>> _getJson(Uri uri) async {
    final http.Response response;
    try {
      response = await _effectiveClient
          .get(uri, headers: {
            'Accept': 'application/json',
            'User-Agent': _mobileUserAgent,
            'Referer': 'https://tienda.mercadona.es/',
          })
          .timeout(timeout);
    } on Exception catch (e) {
      _cancelStuck(); // NET-2: обрываем подвисший запрос
      throwNetwork(e);
    }

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
    return decoded;
  }
}

/// Мобильный Chrome UA — как у веб-фронта tienda.mercadona.es.
const String _mobileUserAgent =
    'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36';
