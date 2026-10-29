# -*- coding: utf-8 -*-
"""Сборка встроенной базы рецептов assets/data/recipes.json.

Запуск:  python3 scripts/gen_recipes.py [--check] [garn_per]
  --check   — собрать базу в памяти и побайтно сравнить с ассетом,
              ничего не записывая (exit 1 при расхождении);
  garn_per  — сколько гарниров на пару (белок, способ) у основных блюд.
              Зафиксирован: garn_per=5 — именно с этим значением собран
              текущий ассет (554 рецепта). Менять только осознанно.

Структура сборки (v0.6.6, выравнивание генератора):
  1. Пулы gen/ (breakfast, soup+side, main, cold) — сортировка
     (категория -> RU-название), как в исходной генерации;
  2. Хвост второй волны gen/dishes_wave_tail.py — 13 рецептов в
     АВТОРСКОМ порядке, без сортировки (так они лежат в ассете с v0.6.3).

Валидация: уникальность id/названий, КБЖУ в разумных границах,
аллергены из разрешённого набора, у каждого рецепта >= 2 шагов.

Правило проекта: ассет меняется ТОЛЬКО через этот генератор. После
правок gen/ запускайте без --check и коммитьте ассет вместе с gen/.
"""

import json
import sys
import os
from collections import Counter

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                "gen"))

from foods import FOODS, ALLERGEN_KEYS  # noqa: E402
from dishes_breakfast import build_breakfast  # noqa: E402
from dishes_soup_side import build_soup_side  # noqa: E402
from dishes_main import build_main  # noqa: E402
from dishes_cold import build_cold  # noqa: E402
from dishes_wave_tail import build_wave_tail  # noqa: E402

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..",
                   "assets", "data", "recipes.json")

DEFAULT_GARN_PER = 5

CATEGORY_ORDER = ["breakfast", "soup", "main", "pasta", "salad", "side",
                  "snack", "dessert"]

# Дата генерации — константа (как в ассете); обновляется вручную
# вместе с содержательным изменением базы.
GENERATED_AT = "2026-10-24"


def assemble(garn_per: int):
    recipes = (build_breakfast() + build_soup_side() + build_main(garn_per)
               + build_cold())

    # Дедупликация по RU-названию
    seen, unique = set(), []
    for r in recipes:
        key = r["title"]["ru"]
        if key in seen:
            continue
        seen.add(key)
        unique.append(r)

    # Стабильная сортировка основного блока: категория -> название
    unique.sort(key=lambda r: (CATEGORY_ORDER.index(r["category"]),
                               r["title"]["ru"]))

    # Хвост второй волны — авторский порядок, без сортировки
    unique += build_wave_tail()

    for i, r in enumerate(unique, 1):
        r["id"] = f"r{i:04d}"
    return unique


def validate(recipes):
    errors = []
    ids = [r["id"] for r in recipes]
    titles = [r["title"]["ru"] for r in recipes]
    if len(ids) != len(set(ids)):
        errors.append("дубликаты id")
    if len(titles) != len(set(titles)):
        errors.append("дубликаты названий")

    for r in recipes:
        rid = r["id"]
        n = r["nutrition"]
        if not (80 <= n["kcal"] <= 950):
            errors.append(f"{rid}: kcal {n['kcal']} вне диапазона")
        if not (0 <= n["protein"] <= 90) or not (0 <= n["fat"] <= 95) \
                or not (0 <= n["carbs"] <= 130):
            errors.append(f"{rid}: БЖУ вне диапазона: {n}")
        for a in r["allergens"]:
            if a not in ALLERGEN_KEYS:
                errors.append(f"{rid}: неизвестный аллерген {a}")
        if len(r["steps"]["ru"]) < 2 or len(r["steps"]["en"]) < 2:
            errors.append(f"{rid}: мало шагов")
        if not r["ingredients"]:
            errors.append(f"{rid}: нет ингредиентов")
        for ing in r["ingredients"]:
            if ing["key"] not in FOODS:
                errors.append(f"{rid}: неизвестный ключ {ing['key']}")
        if not (1 <= r["minutes"] <= 120):
            errors.append(f"{rid}: время {r['minutes']}")
        if r["category"] not in CATEGORY_ORDER:
            errors.append(f"{rid}: категория {r['category']}")
    return errors


def build_doc(garn_per: int):
    recipes = assemble(garn_per)
    errors = validate(recipes)
    if errors:
        print("ОШИБКИ ВАЛИДАЦИИ:")
        for e in errors[:40]:
            print("  -", e)
        sys.exit(1)
    return {
        "schema": "recipes.v1",
        "generated_at": GENERATED_AT,
        "generator": "scripts/gen_recipes.py (rvmxl, Apache-2.0)",
        "count": len(recipes),
        "note": "Встроенная база рецептов для RuleBasedPlanner. "
                "КБЖУ приблизительные, на порцию. Панtry-ингредиенты "
                "(соль/масло/специи) считаются всегда доступными.",
        "recipes": recipes,
    }


def serialize(doc) -> str:
    """Формат ассета: pretty-print indent=1 + перевод строки в конце."""
    return json.dumps(doc, ensure_ascii=False, indent=1) + "\n"


def report(doc, garn_per: int):
    recipes = doc["recipes"]
    cats = Counter(r["category"] for r in recipes)
    flags = Counter()
    for r in recipes:
        for fl, v in r["flags"].items():
            if v:
                flags[fl] += 1
    print(f"рецептов: {len(recipes)}, garn_per={garn_per}")
    print("По категориям:", dict(cats))
    print("Флаги:", dict(flags))
    fam = Counter(r["family"] for r in recipes)
    print("Топ семей блюд:", fam.most_common(8))
    print("КБЖУ-проверка: мин", min(r["nutrition"]["kcal"] for r in recipes),
          "макс", max(r["nutrition"]["kcal"] for r in recipes))


def main():
    argv = sys.argv[1:]
    check = "--check" in argv
    argv = [a for a in argv if a != "--check"]
    garn_per = int(argv[0]) if argv else DEFAULT_GARN_PER

    doc = build_doc(garn_per)
    fresh = serialize(doc)

    if check:
        try:
            with open(OUT, "rb") as f:
                current = f.read()
        except FileNotFoundError:
            print(f"--check: ассет не найден: {OUT}")
            sys.exit(1)
        if current == fresh.encode("utf-8"):
            print(f"--check OK: генератор воспроизводит ассет байт-в-байт "
                  f"({len(current)} байт, {len(doc['recipes'])} рецептов)")
            report(doc, garn_per)
            sys.exit(0)
        print("--check ПРОВАЛЕН: выход генератора отличается от ассета")
        # краткая диагностика первого расхождения
        cur = current.decode("utf-8", errors="replace")
        for i, (a, b) in enumerate(zip(cur, fresh)):
            if a != b:
                start = max(0, i - 120)
                print(f"первое расхождение на смещении {i}:")
                print("  ассет:     ...", cur[start:i + 120].replace("\n",
                      "\\n"))
                print("  генератор: ...", fresh[start:i + 120].replace(
                    "\n", "\\n"))
                break
        else:
            print(f"  общий префикс {min(len(cur), len(fresh))}; "
                  f"длины: ассет={len(cur)}, генератор={len(fresh)}")
        sys.exit(1)

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="utf-8", newline="\n") as f:
        f.write(fresh)

    size_kb = os.path.getsize(OUT) / 1024
    print(f"OK: {len(doc['recipes'])} рецептов -> {OUT} ({size_kb:.0f} КБ)")
    try:
        with open(OUT, "rb") as f:
            same = f.read() == fresh.encode("utf-8")
        if not same:
            print("ВНИМАНИЕ: записанный файл не совпадает со свежесобранным "
                  "— проверьте кодировку/переводы строк")
            sys.exit(1)
    except FileNotFoundError:
        pass
    report(doc, garn_per)


if __name__ == "__main__":
    main()
