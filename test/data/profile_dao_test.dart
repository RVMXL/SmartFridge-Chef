/// Юнит-тесты DAO профиля пользователя (sqflite_common_ffi, хост).
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:smart_fridge_chef/data/dao/profile_dao.dart';
import 'package:smart_fridge_chef/data/database.dart';
import 'package:smart_fridge_chef/data/models/user_profile.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Directory tmp;
  late Database db;
  late ProfileDao dao;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('fridge_profile_test');
    db = await AppDatabase.open(absolutePath: '${tmp.path}/test.db');
    dao = ProfileDao(db);
  });

  tearDown(() async {
    await db.close();
    await tmp.delete(recursive: true);
  });

  UserProfile profile({
    int calories = 2100,
    List<Diet> diets = const [Diet.vegan],
    List<Allergen> allergies = const [Allergen.nuts, Allergen.milk],
    int meals = 4,
    bool onboarded = true,
    String region = 'Казань',
  }) {
    final now = DateTime(2026, 10, 24, 9, 0);
    return UserProfile(
      dailyCalories: calories,
      diets: diets,
      allergies: allergies,
      mealsPerDay: meals,
      regionName: region,
      latitude: 55.7963,
      longitude: 49.1088,
      onboarded: onboarded,
      createdAt: now,
      updatedAt: now,
    );
  }

  test('изначально профиля нет', () async {
    expect(await dao.getProfile(), isNull);
    expect(await dao.exists(), isFalse);
  });

  test('roundtrip: все поля профиля сохраняются и читаются', () async {
    await dao.save(profile());
    final loaded = (await dao.getProfile())!;

    expect(loaded.dailyCalories, 2100);
    expect(loaded.proteinG, 150);
    expect(loaded.fatG, 67);
    expect(loaded.carbsG, 200);
    expect(loaded.diets, [Diet.vegan]);
    expect(loaded.allergies, [Allergen.nuts, Allergen.milk]);
    expect(loaded.mealsPerDay, 4);
    expect(loaded.regionName, 'Казань');
    expect(loaded.latitude!, closeTo(55.7963, 1e-9));
    expect(loaded.longitude!, closeTo(49.1088, 1e-9));
    expect(loaded.onboarded, isTrue);
  });

  test('roundtrip: лечебные столы сохраняются и читаются (v0.5.9)',
      () async {
    await dao.save(profile().copyWith(
      medicalDiets: const ['table5', 'table9'],
    ));
    final loaded = (await dao.getProfile())!;
    expect(loaded.medicalDiets, ['table5', 'table9']);

    // Перезапись: старые значения не «прилипают».
    await dao.save(profile(calories: 1900));
    final cleared = (await dao.getProfile())!;
    expect(cleared.medicalDiets, isEmpty);
  });

  test('чтение: неизвестные ключи столов отбрасываются, валидные остаются',
      () async {
    await dao.save(profile());
    // Пишем в базу сырой JSON с мусорным ключом (как из старой версии).
    await db.update(
      'user_profile',
      {'medical_diets': '["table6","table42","garbage"]'},
      where: 'id = 1',
    );
    final loaded = (await dao.getProfile())!;
    expect(loaded.medicalDiets, ['table6']);
  });

  test('upsert: повторное save обновляет ту же строку', () async {
    await dao.save(profile(calories: 2100));
    await dao.save(profile(calories: 1800, diets: [Diet.lent]));
    final loaded = (await dao.getProfile())!;

    expect(loaded.id, 1);
    expect(loaded.dailyCalories, 1800);
    expect(loaded.diets, [Diet.lent]);
  });

  test('markOnboarded создаёт дефолтный профиль, если его не было', () async {
    await dao.markOnboarded();
    final loaded = (await dao.getProfile())!;
    expect(loaded.onboarded, isTrue);
    expect(loaded.dailyCalories, 2000);
    expect(loaded.diets, isEmpty);
  });

  test('markOnboarded не затирает существующие данные', () async {
    await dao.save(profile(calories: 2500, onboarded: false));
    await dao.markOnboarded();
    final loaded = (await dao.getProfile())!;
    expect(loaded.onboarded, isTrue);
    expect(loaded.dailyCalories, 2500);
  });

  test('дефолтные БЖУ сходятся с формулой 30/30/40', () {
    final d = UserProfile.defaultsForCalories(2000);
    expect(d.protein, 150);
    expect(d.fat, 67);
    expect(d.carbs, 200);
  });
}
