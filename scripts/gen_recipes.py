# -*- coding: utf-8 -*-
"""Сборка встроенной базы рецептов assets/data/recipes.json.

Запуск:  python3 scripts/gen_recipes.py [garn_per]
  garn_per — сколько гарниров на пару (белок, способ) у основных блюд
             (по умолчанию 3; поднимайте, если нужно дожать до 500+).

Валидация: уникальность id/названий, КБЖУ в разумных границах,
аллергены из разрешённого набора, у каждого рецепта >= 3 шагов.
"""

import json
import sys
import os
from collections import Counter

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                "gen"))

from foods import FOODS, PANTRY_KEYS, ALLERGEN_KEYS  # noqa: E402
from dishes_breakfast import build_breakfast  # noqa: E402
from dishes_soup_side import build_soup_side  # noqa: E402
from dishes_main import build_main  # noqa: E402
from dishes_cold import build_cold  # noqa: E402

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..",
                   "smart_fridge_chef", "assets", "data", "recipes.json")

CATEGORY_ORDER = ["breakfast", "soup", "main", "pasta", "salad", "side",
                  "snack", "dessert"]


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

    # Стабильная сортировка: категория -> название
    unique.sort(key=lambda r: (CATEGORY_ORDER.index(r["category"]),
                               r["title"]["ru"]))
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


def main():
    garn_per = int(sys.argv[1]) if len(sys.argv) > 1 else 3
    recipes = assemble(garn_per)

    # Дожимаем до 500+, наращивая гарниры у основных блюд
    while len(recipes) < 500 and garn_per < 8:
        garn_per += 1
        recipes = assemble(garn_per)

    errors = validate(recipes)
    if errors:
        print("ОШИБКИ ВАЛИДАЦИИ:")
        for e in errors[:40]:
            print("  -", e)
        sys.exit(1)

    doc = {
        "schema": "recipes.v1",
        "generated_at": "2026-10-24",
        "generator": "scripts/gen_recipes.py (rvmxl, Apache-2.0)",
        "count": len(recipes),
        "note": "Встроенная база рецептов для RuleBasedPlanner. "
                "КБЖУ приблизительные, на порцию. Панtry-ингредиенты "
                "(соль/масло/специи) считаются всегда доступными.",
        "recipes": recipes,
    }

    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="utf-8") as f:
        json.dump(doc, f, ensure_ascii=False,
                  separators=(",", ":"), indent=None)

    size_kb = os.path.getsize(OUT) / 1024
    cats = Counter(r["category"] for r in recipes)
    flags = Counter()
    for r in recipes:
        for fl, v in r["flags"].items():
            if v:
                flags[fl] += 1

    print(f"OK: {len(recipes)} рецептов -> {OUT} ({size_kb:.0f} КБ), "
          f"garn_per={garn_per}")
    print("По категориям:", dict(cats))
    print("Флаги:", dict(flags))
    fam = Counter(r["family"] for r in recipes)
    print("Топ семей блюд:", fam.most_common(8))
    print("КБЖУ-проверка: мин", min(r["nutrition"]["kcal"] for r in recipes),
          "макс", max(r["nutrition"]["kcal"] for r in recipes))


if __name__ == "__main__":
    main()
