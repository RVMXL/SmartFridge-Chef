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
  Future<void> save(UserProfile profile) async {
    assert(profile.id == 1, 'Профиль ровно один: id = 1');
    await _db.insert(
      _table,
      profile.toMap(),
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
