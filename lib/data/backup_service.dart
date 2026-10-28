/// Резервное копирование и восстановление данных (экспорт/импорт, v0.6.3).
///
/// Формат — JSON-конверт `formatVersion: 1` с «сырыми» строками SQLite
/// (map column → value). Экспортируется всё ценное пользователю:
/// продукты, профиль питания, сохранённые планы меню (снимки рецептов),
/// список покупок и офлайн-кэш штрих-кодов («найденное раз — офлайн
/// навсегда»). Настройки интерфейса/магазинов добавляются отдельным
/// блоком `settings` (белый список не-секретных ключей — см.
/// SettingsController.exportSettings).
///
/// НЕ экспортируется намеренно:
///  * `mercadona_index` — перезагружаемый каталог цен, приедет фоновым
///    обновлением при первом сканировании (данные не пользовательские);
///  * секреты пользователя (KEYS-1: Kroger client id/secret, ключ
///    Wegmans) — в открытом JSON им не место; после импорта они
///    вводятся заново.
///
/// Импорт — REPLACE-ALL: валидация конверта и строк выполняется ДО
/// стирания текущих данных, сама замена — одна транзакция SQLite
/// (порядок удаления/вставки учитывает внешние ключи planned_meals /
/// shopping_items → meal_plans). Идентификаторы строк сохраняются,
/// sqlite_sequence при вставке явных id корректируется автоматически.
library;

import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import 'database.dart';

/// Причина отказа импорта — выбирает текст SnackBar на UI-слое.
enum BackupError {
  /// Файл вообще не конверт SmartFridge (битый JSON, чужой файл).
  notBackup,

  /// Конверт из более новой версии формата — сначала обновить приложение.
  newerVersion,

  /// Конверт наш, но данные внутри повреждены (нет обязательных колонок).
  corrupted,
}

class BackupException implements Exception {
  const BackupException(this.kind, [this.detail = '']);

  final BackupError kind;
  final String detail;

  @override
  String toString() => 'BackupException($kind${detail.isEmpty ? '' : ': $detail'})';
}

/// Требования к строке таблицы: обязательные NOT NULL-колонки без DEFAULT
/// (плюс первичный ключ). Колонки с DEFAULT могут отсутствовать — вставка
/// подставит значения схемы. Nullable-колонки проверять не нужно.
class _TableSpec {
  const _TableSpec(this.name, this.required);

  final String name;
  final List<String> required;
}

/// Результат импорта — counts по таблицам для SnackBar/логов.
class ImportResult {
  const ImportResult(this.counts);

  /// Таблица → число восстановленных строк.
  final Map<String, int> counts;

  int get products => counts['products'] ?? 0;
  int get plans => counts['meal_plans'] ?? 0;
  int get total =>
      counts.values.fold(0, (sum, n) => sum + n);
}

class BackupService {
  BackupService(this._openDb);

  /// Открыватель базы — как у контроллеров состояния (тесты подставляют
  /// свой Database через AppDatabase.open(absolutePath: ...)).
  final Future<Database> Function() _openDb;

  /// Версия формата конверта. При изменении состава данных/колонок —
  /// увеличивать и уметь читать старые версии в [importBundle].
  ///
  /// v2 (v0.6.4): в user_profile добавилась колонка equipment (техника
  /// на кухне). Экспорт пишет полные строки, поэтому формат вырос
  /// автоматически: старое приложение (v1) чисто откажется импортировать
  /// новый файл (validateEnvelope → newerVersion), новое читает и v1
  /// (профиль без equipment → «всё есть»), и v2.
  static const int formatVersion = 2;

  /// Метка принадлежности файла этому приложению.
  static const String appMarker = 'smart_fridge_chef';

  /// Порядок таблиц при вставке: родители раньше детей (FK).
  static const List<_TableSpec> _specs = [
    _TableSpec('user_profile', ['id', 'created_at', 'updated_at']),
    _TableSpec('products', ['name', 'category_key', 'expiry_date', 'added_at']),
    _TableSpec('meal_plans', [
      'id', 'created_at', 'start_date', 'days_count', 'kcal_target', 'seed',
    ]),
    _TableSpec('planned_meals', [
      'plan_id', 'day_index', 'slot', 'recipe_id', 'recipe_json', 'kcal',
    ]),
    _TableSpec('shopping_items', ['plan_id', 'ing_key', 'name']),
    _TableSpec('barcode_cache', ['code', 'name', 'fetched_at']),
  ];

  /// Имя файла экспорта с датой-временем: smart_fridge_backup_20261029_1415.json
  static String suggestFileName(DateTime now) {
    String two(int n) => n.toString().padLeft(2, '0');
    return 'smart_fridge_backup_'
        '${now.year}${two(now.month)}${two(now.day)}_'
        '${two(now.hour)}${two(now.minute)}.json';
  }

  /// Собирает конверт из текущей базы. [settings] — не-секретные
  /// предпочтения (может быть null в тестах).
  Future<Map<String, Object?>> buildBundle({
    required String appVersion,
    Map<String, Object?>? settings,
    DateTime? now,
  }) async {
    final db = await _openDb();
    final data = <String, Object?>{};
    for (final spec in _specs) {
      data[spec.name] = await db.query(spec.name, orderBy: 'rowid');
    }
    return <String, Object?>{
      'app': appMarker,
      'kind': 'backup',
      'formatVersion': formatVersion,
      'appVersion': appVersion,
      // Схема базы источника — полезно для диагностики и будущих
      // миграций формата; импорту не требуется.
      'schemaVersion': AppDatabase.dbVersion,
      'exportedAt': (now ?? DateTime.now()).toUtc().toIso8601String(),
      'data': data,
      'settings': ?settings,
    };
  }

  /// Конверт → текст файла (с отступами — файл можно открыть глазами).
  String encodeBundle(Map<String, Object?> bundle) =>
      const JsonEncoder.withIndent('  ').convert(bundle);

  /// Быстрая проверка конверта без обращения к базе и без стирания данных.
  void validateEnvelope(Map<String, Object?> json) {
    if (json['app'] != appMarker ||
        json['kind'] != 'backup' ||
        json['data'] is! Map) {
      throw BackupException(
        BackupError.notBackup,
        'ожидались app/kind/data, получено: '
        '${json.keys.toList()}',
      );
    }
    final version = json['formatVersion'];
    if (version is! int || version < 1) {
      throw BackupException(
        BackupError.notBackup,
        'formatVersion=$version',
      );
    }
    if (version > formatVersion) {
      throw BackupException(
        BackupError.newerVersion,
        'файл: $version, приложение поддерживает: $formatVersion',
      );
    }
  }

  /// Полный импорт: validateEnvelope → проверка строк → REPLACE-ALL
  /// в одной транзакции. Никаких изменений до успешной валидации.
  Future<ImportResult> importBundle(Map<String, Object?> json) async {
    validateEnvelope(json);

    final data = (json['data'] as Map).cast<String, Object?>();
    final rows = <String, List<Map<String, Object?>>>{};
    for (final spec in _specs) {
      final raw = data[spec.name];
      if (raw is! List) {
        throw BackupException(
          BackupError.notBackup,
          'нет таблицы ${spec.name} в data',
        );
      }
      final list = <Map<String, Object?>>[];
      for (final item in raw) {
        if (item is! Map) {
          throw BackupException(
            BackupError.corrupted,
            '${spec.name}: строка не объект',
          );
        }
        final row = item.cast<String, Object?>();
        for (final col in spec.required) {
          // NULL в NOT NULL-колонке — повреждение конверта.
          if (row[col] == null) {
            throw BackupException(
              BackupError.corrupted,
              '${spec.name}: отсутствует $col',
            );
          }
        }
        list.add(row);
      }
      rows[spec.name] = list;
    }

    final db = await _openDb();
    await db.transaction((txn) async {
      // Стирание: дети раньше родителей (FK planned_meals/shopping_items
      // → meal_plans каскадный, но удаляем явно — надёжнее для читаемости).
      await txn.delete('planned_meals');
      await txn.delete('shopping_items');
      await txn.delete('meal_plans');
      await txn.delete('barcode_cache');
      await txn.delete('products');
      await txn.delete('user_profile');

      // Вставка одним батчем в порядке родителей раньше детей.
      final batch = txn.batch();
      for (final spec in _specs) {
        for (final row in rows[spec.name]!) {
          batch.insert(spec.name, row);
        }
      }
      await batch.commit(noResult: true);
    });

    return ImportResult({
      for (final spec in _specs) spec.name: rows[spec.name]!.length,
    });
  }
}
