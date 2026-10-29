# -*- coding: utf-8 -*-
"""Помощники генератора: сборка рецепта, nutrition, шаги приготовления.

Каждый рецепт собирается в dict с полями будущего recipes.json:
  id, title{ru,en}, category, minutes, servings,
  nutrition{kcal,protein,fat,carbs} (на порцию),
  flags{vegetarian,vegan,gluten_free,low_carb,has_meat,has_fish},
  allergens[], family (главный ингредиент для анти-повторов),
  ingredients[{key,ru,en,grams}], steps{ru[],en[]}
"""

from foods import FOODS, PANTRY_KEYS

MEAT_CLASSES = {"meat"}
# REC-4 (аудит 2026-10-28, v0.6.2): креветки/кальмары (cls="seafood") —
# не рыба: has_fish становится false, флаг has_shellfish их помечает.
FISH_CLASSES = {"fish"}
SEAFOOD_CLASSES = {"seafood"}
ANIMAL_CLASSES = {"meat", "fish", "seafood", "dairy", "egg"}
NON_VEGAN_FOODS = {"honey"}  # не животный продукт, но не веганский


def draft(category, title_ru, title_en, minutes, servings, ings,
          steps_ru, steps_en, family=None):
    """Собирает рецепт: считает КБЖУ на порцию, флаги диеты и аллергены.

    ings — список (key, grams_всего_на_рецепт); кладовая-продукты (соль,
    масло, специи) разрешены и просто помечаются pantry в валидаторе.
    """
    kcal = prot = fat = carb = 0.0
    allergens = set()
    has_meat = has_fish = has_seafood = has_animal = has_gluten = False

    # Слияние дубликатов ключей (соль встречается и в базе, и в блюде)
    merged = {}
    for key, grams in ings:
        merged[key] = merged.get(key, 0) + grams
    ings = list(merged.items())

    for key, grams in ings:
        f = FOODS[key]
        share = grams / 100.0
        kcal += f["kcal"] * share
        prot += f["p"] * share
        fat += f["f"] * share
        carb += f["c"] * share
        allergens |= f.get("allergens", set())
        if f["cls"] in MEAT_CLASSES:
            has_meat = True
        if f["cls"] in FISH_CLASSES:
            has_fish = True
        if f["cls"] in SEAFOOD_CLASSES:
            has_seafood = True
        if f["cls"] in ANIMAL_CLASSES or key in NON_VEGAN_FOODS:
            has_animal = True
        if f.get("gluten"):
            has_gluten = True

    # family: главный (не кладовый) ингредиент — для штрафов за повторы
    # second_family: второй по весу (гарнир/основа) — против «5 дней с пюре»
    ranked = sorted(
        ((key, grams * (2 if FOODS[key]["cls"] in ANIMAL_CLASSES else 1))
         for key, grams in ings if key not in PANTRY_KEYS),
        key=lambda x: x[1], reverse=True)
    if family is None:
        family = ranked[0][0] if ranked else ""
    second_family = next((k for k, _ in ranked if k != family), "")

    return {
        "title": {"ru": title_ru, "en": title_en},
        "category": category,
        "minutes": minutes,
        "servings": servings,
        "nutrition": {
            "kcal": int(round(kcal / servings)),
            "protein": int(round(prot / servings)),
            "fat": int(round(fat / servings)),
            "carbs": int(round(carb / servings)),
        },
        "flags": {
            "vegetarian": not has_meat and not has_fish and not has_seafood,
            "vegan": (not has_meat and not has_fish and not has_animal),
            "gluten_free": not has_gluten,
            "low_carb": round(carb / servings) <= 30,
            "has_meat": has_meat,
            "has_fish": has_fish,
        },
        "allergens": sorted(allergens),
        "family": family,
        "second_family": second_family,
        "ingredients": [
            {"key": k,
             "ru": FOODS[k]["ru"],
             "en": FOODS[k]["en"],
             "grams": g,
             "pantry": k in PANTRY_KEYS}
            for k, g in ings
        ],
        "steps": {"ru": steps_ru, "en": steps_en},
    }


def ing(key, per_serving):
    """Ингредиент в расчёте на порцию -> (key, грамм на весь рецепт)."""
    return (key, int(per_serving))


# ---------------------------------------------------------------- гарниры
# ings_per_serving — продукты (ключ FOODS, грамм на порцию);
# cook — шаг приготовления; raw_ru — название для шага «отварите …»
GARNISH = {
    "rice": dict(nom="рис отварной", ins="рисом", en="rice",
                 cook="boil", raw_ru="рис",
                 ings=[("rice", 55)]),
    "buckwheat": dict(nom="гречка отварная", ins="гречкой", en="buckwheat",
                      cook="boil", raw_ru="гречку",
                      ings=[("buckwheat", 55)]),
    "mashed": dict(nom="картофельное пюре", ins="картофельным пюре",
                   en="mashed potatoes", cook="mash",
                   ings=[("potato", 200), ("milk", 40), ("butter", 8)]),
    "baked_potato": dict(nom="картофель запечённый", ins="запечённым картофелем",
                         en="roasted potatoes", cook="bake_potato",
                         ings=[("potato", 200), ("olive_oil", 6)]),
    "pasta": dict(nom="макароны", ins="макаронами", en="pasta",
                  cook="pasta",
                  ings=[("pasta", 60)]),
    "bulgur": dict(nom="булгур отварной", ins="булгуром", en="bulgur",
                   cook="boil", raw_ru="булгур",
                   ings=[("bulgur_cooked", 150)]),
    "couscous": dict(nom="кускус отварной", ins="кускусом", en="couscous",
                     cook="boil", raw_ru="кускус",
                     ings=[("couscous_cooked", 150)]),
    "barley": dict(nom="перловка отварная", ins="перловкой", en="pearl barley",
                   cook="boil", raw_ru="перловку",
                   ings=[("barley_cooked", 150)]),
    "lentils": dict(nom="чечевица отварная", ins="чечевицей", en="lentils",
                    cook="boil", raw_ru="чечевицу",
                    ings=[("lentil_cooked", 150)]),
    "stewed_veg": dict(nom="овощи тушёные", ins="тушёными овощами",
                       en="mixed vegetables", cook="stew_veg",
                       ings=[("potato", 80), ("zucchini", 60), ("carrot", 40),
                             ("cabbage", 60), ("vegetable_oil", 8)]),
    "fresh_salad": dict(nom="салат из свежих овощей", ins="свежим салатом",
                        en="fresh salad", cook="fresh",
                        ings=[("tomato", 80), ("cucumber", 70),
                              ("olive_oil", 6)]),
}


def garnish_ings(garn, servings):
    """Ингредиенты гарнира на весь рецепт."""
    return [(k, g * servings) for k, g in garn["ings"]]

# ------------------------------------------------------------- способы
# ru_part — причастие по родам; ru_postfix — конструкция без согласования
METHODS = {
    "fry": dict(ru_part={"m": "Жареный", "f": "Жареная",
                         "n": "Жареное", "pl": "Жареные"},
                en="Pan-fried", minutes=20, oil=True),
    "bake": dict(ru_part={"m": "Запечённый", "f": "Запечённая",
                          "n": "Запечённое", "pl": "Запечённые"},
                 en="Baked", minutes=40, oil=True),
    "stew": dict(ru_part={"m": "Тушёный", "f": "Тушёная",
                          "n": "Тушёное", "pl": "Тушёные"},
                 en="Braised", minutes=45, oil=True),
    "steam": dict(ru_part=None, ru_postfix="на пару", en="Steamed",
                  minutes=30, oil=False),
    "grill": dict(ru_part=None, ru_postfix="на гриле", en="Grilled",
                  minutes=25, oil=True),
}


def main_title(prot, method_key, garn, sauce=None):
    """Название основного блюда на RU/EN."""
    m = METHODS[method_key]
    if sauce:
        ru = f"{prot['title'].capitalize()} {sauce['ru']} с {garn['ins']}"
        en = f"{prot['en'].capitalize()} {sauce['en']} with {garn['en']}"
        return ru, en
    if m["ru_part"]:
        ru = (f"{m['ru_part'][prot['g']]} {prot['title']} с {garn['ins']}")
    else:
        ru = f"{prot['title'].capitalize()} {m['ru_postfix']} с {garn['ins']}"
    en = f"{m['en']} {prot['en']} with {garn['en']}"
    return ru, en


def garnish_steps(garn):
    """Шаги приготовления гарнира (ru, en)."""
    cook = garn["cook"]
    if cook == "boil":
        return (f"Отварите {garn['raw_ru']} до готовности в подсоленной воде.",
                f"Cook the {garn['en']} in salted water until tender.")
    if cook == "pasta":
        return ("Отварите макароны в подсоленной воде до аль денте и "
                "откиньте на дуршлаг.",
                "Boil the pasta in salted water until al dente and drain.")
    if cook == "mash":
        return ("Отварите картофель до мягкости и разомните с горячим "
                "молоком и кусочком сливочного масла.",
                "Boil the potatoes until soft and mash with hot milk and a "
                "knob of butter.")
    if cook == "bake_potato":
        return ("Картофель нарежьте дольками, смешайте с маслом и специями "
                "и запеките 30–35 минут до румяности.",
                "Cut the potatoes into wedges, toss with oil and spices and "
                "roast for 30–35 minutes until golden.")
    if cook == "stew_veg":
        return ("Овощи нарежьте кубиками и потушите с ложкой масла и "
                "парой ложек воды 15 минут, посолите.",
                "Dice the vegetables and simmer with a spoonful of oil and "
                "a splash of water for 15 minutes; season with salt.")
    return ("Свежие овощи нарежьте для подачи.",
            "Slice the fresh vegetables for serving.")


def main_steps(method_key, prot, garn, sauce=None):
    """Шаги приготовления основного блюда (ru[], en[])."""
    acc = prot["acc"]
    gs_ru, gs_en = garnish_steps(garn)
    oil_ru = "растительного масла" if method_key in ("fry", "stew") \
        else "оливкового масла"
    oil_en = "vegetable oil" if method_key in ("fry", "stew") \
        else "olive oil"

    if method_key == "fry":
        ru = [f"Нарежьте {acc} кусочками, посолите и поперчите.",
              f"Разогрейте {oil_ru} в сковороде и обжарьте {acc} 7–10 минут "
              "до румяной корочки."]
        en = [f"Cut the {prot['en']} into pieces, season with salt and pepper.",
              f"Heat the {oil_en} in a pan and fry the {prot['en']} for "
              "7–10 minutes until golden."]
        if sauce:
            ru.append(f"Добавьте ингредиенты соуса и потушите 3–4 минуты "
                      "на слабом огне, помешивая.")
            en.append("Add the sauce ingredients and simmer for 3–4 minutes "
                      "over low heat.")
    elif method_key == "bake":
        ru = ["Разогрейте духовку до 180 °C.",
              f"{acc.capitalize()} нарежьте порционно, приправьте солью, "
              "перцем и любимыми специями.",
              "Выложите в смазанную маслом форму и запекайте 30–40 минут "
              "до готовности."]
        en = ["Preheat the oven to 180 °C.",
              f"Cut the {prot['en']} into portions, season with salt, "
              "pepper and your favourite spices.",
              "Place in a greased baking dish and bake for 30–40 minutes."]
        if sauce:
            ru.insert(2, f"Залейте {acc} соусом, распределив его равномерно.")
            en.insert(2, f"Pour the sauce evenly over the {prot['en']}.")
    elif method_key == "stew":
        ru = ["Лук и морковь нарежьте и обжарьте до мягкости.",
              f"Добавьте {acc}, обжаривайте 5 минут, помешивая.",
              "Влейте полстакана воды или соус, накройте крышкой и тушите "
              "25–35 минут на слабом огне."]
        en = ["Fry the chopped onion and carrot until soft.",
              f"Add the {prot['en']} and cook for 5 minutes, stirring.",
              "Pour in half a cup of water or the sauce, cover and simmer "
              "for 25–35 minutes over low heat."]
    elif method_key == "steam":
        ru = [f"Приправьте {acc} солью и специями.",
              "Готовьте на пару 20–25 минут до полной готовности."]
        en = [f"Season the {prot['en']} with salt and spices.",
              f"Steam the {prot['en']} for 20–25 minutes until cooked."]
    else:  # grill
        ru = [f"Нарежьте {acc} порционно, смешайте с маслом и специями и "
              "оставьте на 10 минут.",
              "Обжарьте на гриле по 4–5 минут с каждой стороны."]
        en = [f"Cut the {prot['en']} into portions, toss with oil and "
              "spices and let sit for 10 minutes.",
              f"Grill the {prot['en']} for 4–5 minutes per side."]

    ru.append(gs_ru)
    en.append(gs_en)
    ru.append("Подавайте горячим, посыпав свежей зеленью.")
    en.append("Serve hot, sprinkled with fresh herbs.")
    return ru, en


# ------------------------------------------------------------- соусы
SAUCES = {
    "cream_garlic": dict(ru="в сливочно-чесночном соусе",
                         en="in creamy garlic sauce",
                         ings=[("cream", 100), ("garlic", 8)]),
    "tomato": dict(ru="в томатном соусе", en="in tomato sauce",
                   ings=[("tomato_paste", 40), ("onion", 40)]),
    "sour_cream": dict(ru="в сметанном соусе", en="in sour cream sauce",
                       ings=[("sour_cream", 80), ("onion", 40)]),
    "teriyaki": dict(ru="в соусе терияки", en="in teriyaki sauce",
                     ings=[("soy_sauce", 30), ("honey", 15)]),
}
