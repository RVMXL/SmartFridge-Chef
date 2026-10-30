/// Юнит-тесты движка кухонного оборудования (v0.6.4): вывод требований
/// из шагов, правила замены (замещаемое/блокирующее) и проверка вывода
/// на реальной базе рецептов (точечные контрольные рецепты).
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:smart_fridge_chef/ai/equipment.dart';
import 'package:smart_fridge_chef/data/models/recipe.dart';

void main() {
  group('вывод требований по шагам', () {
    test('«духовка» → oven', () {
      expect(
        KitchenEquipmentEngine.requiredForSteps(
            'разогрейте духовку до 180 °c'.toLowerCase()),
        {KitchenEquipment.oven},
      );
    });

    test('«запекайте при 180 °C» без слова «духовка» → oven', () {
      // Запеканки в базе пишут «Запекайте 30–35 минут при 180 °C».
      expect(
        KitchenEquipmentEngine.requiredForSteps(
            'выложите в форму и запекайте 30 минут'.toLowerCase()),
        {KitchenEquipment.oven},
      );
    });

    test('«выпекайте панкейки» — жарка на сковороде, НЕ oven', () {
      // Ловушка базы: блины/панкейки «выпекают» на плите.
      expect(
        KitchenEquipmentEngine.requiredForSteps(
            'выпекайте маленькие панкейки по 1–2 минуты'.toLowerCase()),
        isEmpty,
      );
    });

    test('«блендер» → blender, «тостер» → toaster', () {
      expect(
        KitchenEquipmentEngine.requiredForSteps(
            'взбейте блендером до однородности'.toLowerCase()),
        {KitchenEquipment.blender},
      );
      expect(
        KitchenEquipmentEngine.requiredForSteps(
            'подрумяньте хлеб в тостере'.toLowerCase()),
        {KitchenEquipment.toaster},
      );
    });

    test('«обжарьте на гриле» → grill (ключ без мягкого знака)', () {
      // В базе предложный падеж: «Обжарьте на грилЕ» — ключ «гриль»
      // не нашёл бы ни одного рецепта (v0.6.7).
      expect(
        KitchenEquipmentEngine.requiredForSteps(
            'обжарьте на гриле по 4–5 минут с каждой стороны'.toLowerCase()),
        {KitchenEquipment.grill},
      );
      // Именительный тоже ловится.
      expect(
        KitchenEquipmentEngine.requiredForSteps(
            'разогрейте гриль-сковороду'.toLowerCase()),
        {KitchenEquipment.grill},
      );
    });

    test('«готовьте на пару» и «в пароварке» → steamer', () {
      expect(
        KitchenEquipmentEngine.requiredForSteps(
            'готовьте на пару 20–25 минут до готовности'.toLowerCase()),
        {KitchenEquipment.steamer},
      );
      expect(
        KitchenEquipmentEngine.requiredForSteps(
            'выложите в пароварку и готовьте 15 минут'.toLowerCase()),
        {KitchenEquipment.steamer},
      );
    });

    test('«на пару минут» — время, НЕ пароварка (lookahead)', () {
      // Защита на будущее: «стоять на пару минут» — это не готовка
      // на пару. В текущей базе таких фраз нет (скан 2026-10-31).
      expect(
        KitchenEquipmentEngine.requiredForSteps(
            'дайте тесту отдохнуть на пару минут'.toLowerCase()),
        isEmpty,
      );
      expect(
        KitchenEquipmentEngine.requiredForSteps(
            'оставьте на пару часов в холодильнике'.toLowerCase()),
        isEmpty,
      );
      // …а «на пару 20 минут» — готовка: после «пару» идёт число.
      expect(
        KitchenEquipmentEngine.requiredForSteps(
            'варите на пару 20 минут'.toLowerCase()),
        {KitchenEquipment.steamer},
      );
    });

    test('плита без техники — пустое множество', () {
      expect(
        KitchenEquipmentEngine.requiredForSteps(
            'варите 20 минут под крышкой, обжарьте на сковороде'
                .toLowerCase()),
        isEmpty,
      );
    });
  });

  group('gaps: замещаемое и блокирующее', () {
    Set<KitchenEquipment> needed(KitchenEquipment e) => {e};

    test('owned == null — расхождений нет (профили до v0.6.4)', () {
      expect(
        KitchenEquipmentEngine.gaps(
          needed: needed(KitchenEquipment.oven),
          servings: 2,
          owned: null,
        ),
        isEmpty,
      );
    });

    test('техника есть — расхождений нет', () {
      expect(
        KitchenEquipmentEngine.gaps(
          needed: needed(KitchenEquipment.oven),
          servings: 2,
          owned: {KitchenEquipment.oven, KitchenEquipment.toaster},
        ),
        isEmpty,
      );
    });

    test('духовка, малое блюдо (servings < kOvenBigServings) — замещаемо',
        () {
      final gaps = KitchenEquipmentEngine.gaps(
        needed: needed(KitchenEquipment.oven),
        servings: kOvenBigServings - 1,
        owned: {},
      );
      expect(gaps, hasLength(1));
      expect(gaps.single.equipment, KitchenEquipment.oven);
      expect(gaps.single.substitutable, isTrue);
      expect(gaps.single.substitutionRu, isNotEmpty);
      expect(gaps.single.substitutionEn, isNotEmpty);
    });

    test('духовка, большое блюдо (servings >= kOvenBigServings) — блок',
        () {
      final gaps = KitchenEquipmentEngine.gaps(
        needed: needed(KitchenEquipment.oven),
        servings: kOvenBigServings,
        owned: {},
      );
      expect(gaps, hasLength(1));
      expect(gaps.single.substitutable, isFalse);
      expect(KitchenEquipmentEngine.hasBlocking(gaps), isTrue);
    });

    test('блендер, тостер, гриль и пароварка замещаемы всегда', () {
      for (final e in [
        KitchenEquipment.blender,
        KitchenEquipment.toaster,
        KitchenEquipment.grill,
        KitchenEquipment.steamer,
      ]) {
        final gaps = KitchenEquipmentEngine.gaps(
          needed: {e},
          servings: 8, // даже «большое» блюдо
          owned: {},
        );
        expect(gaps, hasLength(1));
        expect(gaps.single.substitutable, isTrue, reason: e.key);
      }
    });

    test('несколько расхождений сразу', () {
      final gaps = KitchenEquipmentEngine.gaps(
        needed: {
          KitchenEquipment.oven,
          KitchenEquipment.blender,
        },
        servings: 2,
        owned: {},
      );
      expect(gaps, hasLength(2));
    });
  });

  group('реальная база (контрольные рецепты)', () {
    late Map<String, Recipe> byId;

    setUpAll(() async {
      final raw =
          await File('assets/data/recipes.json').readAsString();
      final doc = jsonDecode(raw) as Map<String, Object?>;
      byId = {
        for (final e in doc['recipes'] as List<dynamic>)
          (e as Map<String, Object?>)['id'] as String:
              Recipe.fromJson(e),
      };
    });

    test('r0098 «Творожная запеканка» — oven (по «Запекайте… 180 °C»)',
        () {
      expect(
        KitchenEquipmentEngine.requiredForSteps(
            KitchenEquipmentEngine.stepsTextOf(byId['r0098']!.stepsRu)),
        {KitchenEquipment.oven},
      );
    });

    test('r0001 «Банановые панкейки» — техники нет', () {
      expect(
        KitchenEquipmentEngine.requiredForSteps(
            KitchenEquipmentEngine.stepsTextOf(byId['r0001']!.stepsRu)),
        isEmpty,
      );
    });

    test('r0029 — blender, r0102 — toaster, r0547 — пусто', () {
      expect(
        KitchenEquipmentEngine.requiredForSteps(
            KitchenEquipmentEngine.stepsTextOf(byId['r0029']!.stepsRu)),
        {KitchenEquipment.blender},
      );
      expect(
        KitchenEquipmentEngine.requiredForSteps(
            KitchenEquipmentEngine.stepsTextOf(byId['r0102']!.stepsRu)),
        {KitchenEquipment.toaster},
      );
      // Пшённая каша (после фикса v0.6.4) — плита, без техники.
      expect(
        KitchenEquipmentEngine.requiredForSteps(
            KitchenEquipmentEngine.stepsTextOf(byId['r0547']!.stepsRu)),
        isEmpty,
      );
    });

    test('r0144 — grill, r0272 — steamer, r0330 — oven+steamer (v0.6.7)',
        () {
      // «Обжарьте на гриле…» — предложный падеж ловится ключом «грил».
      expect(
        KitchenEquipmentEngine.requiredForSteps(
            KitchenEquipmentEngine.stepsTextOf(byId['r0144']!.stepsRu)),
        {KitchenEquipment.grill},
      );
      // «Готовьте на пару 20–25 минут…».
      expect(
        KitchenEquipmentEngine.requiredForSteps(
            KitchenEquipmentEngine.stepsTextOf(byId['r0272']!.stepsRu)),
        {KitchenEquipment.steamer},
      );
      // «Курица на пару с запечённым картофелем»: и пар (гарнир
      // запекается), и плита (курица) — две техники сразу.
      expect(
        KitchenEquipmentEngine.requiredForSteps(
            KitchenEquipmentEngine.stepsTextOf(byId['r0330']!.stepsRu)),
        {KitchenEquipment.oven, KitchenEquipment.steamer},
      );
    });

    test('в базе 20 гриль- и 41 паровых рецепта (скан 2026-10-31)', () {
      // Инвариант базы для v0.6.7: если изменился — перечитай пометки
      // в меню и подсказки замен (grill → сковорода, steamer →
      // кастрюля с крышкой).
      int grillCount = 0, steamCount = 0;
      for (final r in byId.values) {
        final needed = KitchenEquipmentEngine.requiredForSteps(
            KitchenEquipmentEngine.stepsTextOf(r.stepsRu));
        if (needed.contains(KitchenEquipment.grill)) grillCount++;
        if (needed.contains(KitchenEquipment.steamer)) steamCount++;
      }
      expect(grillCount, 20);
      expect(steamCount, 41);
    });

    test('больших духовочных рецептов ровно два: r0536, r0539', () {
      // Инвариант текущей базы (скан 2026-10-29): среди 102 духовочных
      // (духовк*|запек*) рецептов на 4+ порций только «Овсяное печенье
      // с бананом» и «Шарлотка с яблоками» — именно они честно
      // исключаются жёстким фильтром у пользователей без духовки
      // (печенье/шарлотку на плите не заменишь). Если база изменилась —
      // перечитай этот тест и поведение фильтра.
      final oven = byId.values
          .where((r) =>
              KitchenEquipmentEngine.requiredForSteps(
                  KitchenEquipmentEngine.stepsTextOf(r.stepsRu))
                  .contains(KitchenEquipment.oven))
          .toList();
      expect(oven, hasLength(102));
      final bigIds = oven
          .where((r) => r.servings >= kOvenBigServings)
          .map((r) => r.id)
          .toSet();
      expect(bigIds, {'r0536', 'r0539'});
    });

    test('после фикса v0.6.5 во всей базе нет «прогрейте»', () {
      // Репорты владельца: v0.6.4 — «прогрейте» в уже горячей каше;
      // v0.6.5 — термин невнятен и в супах/пастах/соусах. Все шаги
      // переписаны с указанием, ЧТО греть, НА ЧЁМ и КАК (поварите
      // в кастрюле / тушите в сковороде / томите на слабом огне).
      final confused = byId.values
          .expand((r) => r.stepsRu)
          .where((s) => s.toLowerCase().contains('прогре'))
          .toList();
      expect(confused, isEmpty);
    });

    test('после фикса v0.6.5 каждый шаг с «выпек» называет сковороду',
        () {
      // Репорт владельца: «Выпекайте маленькие панкейки…» без техники
      // читалось как «только в духовке» — на деле это жарка. Шаг,
      // упоминающий выпекание, обязан называть сковороду в том же
      // предложении (духовочные блюда пишут «запекайте», их это
      // не касается).
      final ambiguous = byId.values
          .expand((r) => r.stepsRu)
          .where((s) {
            final low = s.toLowerCase();
            return low.contains('выпек') && !low.contains('сковород');
          })
          .toList();
      expect(ambiguous, isEmpty);
    });
  });
}
