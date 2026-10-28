/// DAO профиля пользователя: одна строка (id = 1), upsert-семантика.
library;

import 'package:sqflite/sqflite.dart';

import '../models/user_profile.dart';

class ProfileDao {
  const ProfileDao(this._db);

  final Database _db;

  static const String _table = 'user_profile';

  /// Профиль или null, если онбординг ещё не проходили.
  Future<UserProfile?> getProfile() async {
    final rows = await _db.query(_table, limit: 1);
    return rows.isEmpty ? null : UserProfile.fromMap(rows.first);
  }

  /// Есть ли запись профиля в базе.
  Future<bool> exists() async {
    final rows = await _db.query(_table,
        columns: ['id'], limit: 1);
    return rows.isNotEmpty;
  }

  /// Сохраняет профиль (создание или обновление) — всегда строка id = 1.
  ///
  /// DATA-4 (аудит 2026-10-28, v0.6.2): replace-вставка перезаписывала
  /// created_at тем, что пришло в объекте; защита датой жила только в
  /// контроллере. DAO гарантирует сам: у существующей строки created_at
  /// не меняется никогда, updated_at — всегда «сейчас».
  Future<void> save(UserProfile profile) async {
    assert(profile.id == 1, 'Профиль ровно один: id = 1');
    final map = profile.toMap();
    final rows = await _db.query(_table,
        columns: ['created_at'], limit: 1);
    if (rows.isNotEmpty && rows.first['created_at'] != null) {
      map['created_at'] = rows.first['created_at'];
    }
    map['updated_at'] = DateTime.now().toIso8601String();
    await _db.insert(
      _table,
      map,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Помечает онбординг пройденным (без перезаписи остальных полей).
  Future<int> markOnboarded() async {
    final now = DateTime.now().toIso8601String();
    if (!await exists()) {
      final nowDt = DateTime.now();
      await save(UserProfile(
        onboarded: true,
        createdAt: nowDt,
        updatedAt: nowDt,
      ));
      return 1;
    }
    return _db.update(
      _table,
      {'onboarded': 1, 'updated_at': now},
      where: 'id = ?',
      whereArgs: [1],
    );
  }
}
