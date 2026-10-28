# -*- coding: utf-8 -*-
"""Основные блюда: комбинаторика белок x способ x гарнир, котлеты,
специальные блюда и паста."""

from helpers import (draft, main_title, main_steps, GARNISH, METHODS,
                     SAUCES, garnish_ings)

# ------------------------------------------------------- белки для основ
PROTEINS = {
    "chicken_breast": dict(title="курица", acc="куриное филе", g="f",
                           en="chicken breast", grams=150, cls="meat",
                           methods=["fry", "bake", "stew", "steam", "grill"],
                           garnishes=["rice", "buckwheat", "mashed",
                                      "baked_potato", "pasta", "bulgur",
                                      "stewed_veg", "fresh_salad",
                                      "couscous", "barley"]),
    "chicken_thigh": dict(title="куриные бёдра", acc="куриные бёдра", g="pl",
                          en="chicken thighs", grams=160, cls="meat",
                          methods=["fry", "bake", "stew"],
                          garnishes=["rice", "buckwheat", "mashed",
                                     "baked_potato", "bulgur",
                                     "stewed_veg", "barley"]),
    "turkey": dict(title="индейка", acc="филе индейки", g="f",
                   en="turkey", grams=150, cls="meat",
                   methods=["fry", "bake", "stew", "steam", "grill"],
                   garnishes=["rice", "buckwheat", "mashed", "pasta",
                              "bulgur", "couscous", "stewed_veg",
                              "fresh_salad"]),
    "beef": dict(title="говядина", acc="говядину", g="f",
                 en="beef", grams=150, cls="meat",
                 methods=["fry", "bake", "stew", "grill"],
                 garnishes=["rice", "buckwheat", "mashed", "baked_potato",
                            "pasta", "bulgur", "stewed_veg", "barley"]),
    "pork": dict(title="свинина", acc="свинину", g="f",
                 en="pork", grams=150, cls="meat",
                 methods=["fry", "bake", "stew", "grill"],
                 garnishes=["rice", "buckwheat", "mashed", "baked_potato",
                            "pasta", "stewed_veg", "fresh_salad",
                            "barley"]),
    "chicken_liver": dict(title="куриная печень", acc="куриную печень",
                          g="f", en="chicken liver", grams=140, cls="meat",
                          methods=["fry", "stew"],
                          garnishes=["mashed", "buckwheat", "rice",
                                     "pasta"]),
    "salmon": dict(title="лосось", acc="филе лосося", g="m",
                   en="salmon", grams=150, cls="fish",
                   methods=["fry", "bake", "stew", "steam"],
                   garnishes=["rice", "mashed", "baked_potato", "pasta",
                              "stewed_veg", "fresh_salad"]),
    "cod": dict(title="треска", acc="треску", g="f",
                en="cod", grams=160, cls="fish",
                methods=["fry", "bake", "stew", "steam"],
                garnishes=["rice", "mashed", "baked_potato",
                           "stewed_veg", "fresh_salad"]),
    "pollock": dict(title="минтай", acc="минтай", g="m",
                    en="pollock", grams=160, cls="fish",
                    methods=["fry", "bake", "stew", "steam"],
                    garnishes=["rice", "mashed", "buckwheat",
                               "stewed_veg", "fresh_salad"]),
    "shrimp": dict(title="креветки", acc="креветки", g="pl",
                   en="shrimp", grams=130, cls="seafood",
                   methods=["fry", "bake", "stew"],
                   garnishes=["rice", "pasta", "couscous", "stewed_veg",
                              "fresh_salad"]),
    "squid": dict(title="кальмары", acc="кальмары", g="pl",
                  en="squid", grams=140, cls="seafood",
                  methods=["fry", "stew"],
                  garnishes=["rice", "pasta", "stewed_veg",
                             "fresh_salad"]),
    "tofu": dict(title="тофу", acc="тофу", g="m",
                 en="tofu", grams=150, cls="plant",
                 methods=["fry", "bake", "stew"],
                 garnishes=["rice", "buckwheat", "bulgur", "couscous",
                            "stewed_veg"]),
    "chickpeas": dict(title="нут", acc="нут", g="m",
                      en="chickpeas", grams=120, cls="plant",
                      methods=["bake", "stew"],
                      garnishes=["rice", "bulgur", "couscous",
                                 "stewed_veg", "fresh_salad"]),
    "lentils": dict(title="чечевица", acc="чечевицу", g="f",
                    en="lentils", grams=120, cls="plant",
                    methods=["stew"],
                    garnishes=["rice", "buckwheat", "bulgur",
                               "stewed_veg", "fresh_salad"]),
}

GARN_PER = 3  # сколько гарниров на пару (белок, способ) — настраивается


def generic_mains(garn_per=GARN_PER):
    out = []
    for pk, prot in PROTEINS.items():
        for mi, mk in enumerate(prot["methods"]):
            m = METHODS[mk]
            garn_keys = prot["garnishes"]
            take = min(garn_per, len(garn_keys))
            for gi in range(take):
                gk = garn_keys[(mi + gi) % len(garn_keys)]
                garn = GARNISH[gk]
                ru, en = main_title(prot, mk, garn)
                ings = [(pk, prot["grams"] * 2)] + garnish_ings(garn, 2)
                if m.get("oil"):
                    ings.append(("vegetable_oil" if mk != "bake"
                                 else "olive_oil", 15))
                ings += [("salt", 2), ("pepper", 1)]
                sru, sen = main_steps(mk, prot, garn)
                out.append(draft("main", ru, en, m["minutes"], 2, ings,
                                 sru, sen))
    return out


def sauced_mains():
    """Блюда «в соусе»: 6 белков x 4 соуса x чередование гарниров."""
    sauced = ["chicken_breast", "turkey", "salmon", "cod", "pollock",
              "shrimp"]
    out = []
    for i, pk in enumerate(sauced):
        prot = PROTEINS[pk]
        for si, (sk, sauce) in enumerate(SAUCES.items()):
            gk = ["rice", "pasta"][(i + si) % 2]
            garn = GARNISH[gk]
            ru, en = main_title(prot, "stew", garn, sauce=sauce)
            ings = [(pk, prot["grams"] * 2)] + garnish_ings(garn, 2)
            for ik, ig in sauce["ings"]:
                ings.append((ik, ig))
            ings += [("salt", 2), ("pepper", 1), ("vegetable_oil", 10)]
            sru, sen = main_steps("stew", prot, garn, sauce=sauce)
            out.append(draft("main", ru, en, 40, 2, ings, sru, sen))
    return out


def cutlets():
    """Котлеты из фарша: 4 вида x 3 способа x 4 гарнира."""
    kinds = {
        "minced_beef": ("Котлеты говяжьи", "Beef cutlets", 120),
        "minced_chicken": ("Куриные котлеты", "Chicken cutlets", 120),
        "minced_turkey": ("Котлеты из индейки", "Turkey cutlets", 120),
        "minced_fish": ("Рыбные котлеты", "Fish cutlets", 120),
    }
    method_words = {
        "fry": ("", "", "", 20),
        "bake": ("в духовке", "Oven-baked ", "baked ", 35),
        "steam": ("на пару", "Steamed ", "steamed ", 30),
    }
    garn_keys = ["mashed", "buckwheat", "stewed_veg", "pasta"]
    out = []
    for fk, (name_ru, name_en, grams) in kinds.items():
        for mk, (word_ru, word_en, _w2, minutes) in method_words.items():
            for gi, gk in enumerate(garn_keys):
                garn = GARNISH[gk]
                ru = f"{name_ru} {word_ru} с {garn['ins']}".replace("  ", " ")
                en = f"{word_en}{name_en} with {garn['en']}"
                ings = ([(fk, grams * 2), ("egg", 60), ("onion", 40),
                         ("bread", 30)] + garnish_ings(garn, 2) +
                        [("salt", 2), ("pepper", 1)])
                if mk == "fry":
                    ings.append(("vegetable_oil", 20))
                gs_ru = garnish_ru_step(garn)
                gs_en = garnish_en_step(garn)
                if mk == "fry":
                    sru = ["Фарш смешайте с яйцом, мелко нарезанным луком, "
                           "размоченным хлебом, солью и перцем.",
                           "Сформируйте котлеты и обжарьте по 4–5 минут с "
                           "каждой стороны, затем 5 минут под крышкой."]
                    sen = ["Mix the ground meat with the egg, chopped onion, "
                           "soaked bread, salt and pepper.",
                           "Shape the cutlets and fry for 4–5 minutes per "
                           "side, then 5 minutes covered."]
                elif mk == "bake":
                    sru = ["Фарш смешайте с яйцом, луком, хлебом, солью "
                           "и перцем.",
                           "Выложите котлеты на противень и запекайте "
                           "25–30 минут при 180 °C."]
                    sen = ["Mix the ground meat with the egg, onion, bread, "
                           "salt and pepper.",
                           "Place the cutlets on a tray and bake at 180 °C "
                           "for 25–30 minutes."]
                else:
                    sru = ["Фарш смешайте с яйцом, луком, солью и перцем.",
                           "Готовьте котлеты на пару 20–25 минут."]
                    sen = ["Mix the ground meat with the egg, onion, salt "
                           "and pepper.",
                           "Steam the cutlets for 20–25 minutes."]
                sru.append(gs_ru)
                sen.append(gs_en)
                sru.append("Подавайте горячими, посыпав зеленью.")
                sen.append("Serve hot, sprinkled with herbs.")
                out.append(draft("main", ru, en, minutes, 2, ings,
                                 sru, sen, family=fk))
    return out


def garnish_ru_step(garn):
    steps = {
        "boil": f"Отварите {garn.get('raw_ru', garn['nom'])} до готовности.",
        "pasta": "Отварите макароны до аль денте и откиньте.",
        "mash": "Картофель отварите и разомните с молоком и маслом.",
        "bake_potato": "Картофель запеките дольками в духовке вместе с "
                       "котлетами.",
        "stew_veg": "Овощи нарежьте и потушите 15 минут.",
        "fresh": "Свежие овощи нарежьте для подачи.",
    }
    return steps[garn["cook"]]


def garnish_en_step(garn):
    steps = {
        "boil": f"Cook the {garn['en']} until tender.",
        "pasta": "Boil the pasta until al dente and drain.",
        "mash": "Boil the potatoes and mash with milk and butter.",
        "bake_potato": "Roast the potato wedges in the oven together with "
                       "the cutlets.",
        "stew_veg": "Dice the vegetables and simmer for 15 minutes.",
        "fresh": "Slice the fresh vegetables for serving.",
    }
    return steps[garn["cook"]]


def specials():
    """Фиксированные блюда домашней кухни."""
    out = []
    items = [
        ("Плов с курицей", "Chicken plov (pilaf)", 60,
         [("chicken_thigh", 400), ("rice", 300), ("carrot", 150),
          ("onion", 100), ("garlic", 15), ("vegetable_oil", 40),
          ("spices", 3), ("salt", 3)],
         ["Курицу обжарьте в казане до румяности, добавьте лук и морковь "
          "соломкой.",
          "Всыпьте промытый рис, залейте кипятком на 1,5 см выше риса, "
          "воткните зубчики чеснока.",
          "Готовьте под крышкой на слабом огне 25–30 минут, не помешивая."],
         ["Fry the chicken in a heavy pot until golden; add the onion and "
          "carrot cut into strips.",
          "Stir in the rinsed rice, pour boiling water 1.5 cm above the "
          "rice and tuck in the garlic cloves.",
          "Cook, covered, over low heat for 25–30 minutes without "
          "stirring."]),
        ("Плов с говядиной", "Beef plov (pilaf)", 90,
         [("beef", 400), ("rice", 300), ("carrot", 150), ("onion", 100),
          ("garlic", 15), ("vegetable_oil", 40), ("spices", 3),
          ("salt", 3)],
         ["Говядину нарежьте кубиками и обжарьте 10 минут, добавьте лук "
          "и морковь.",
          "Всыпьте рис, залейте кипятком и воткните чеснок.",
          "Тушите под крышкой 40–50 минут на слабом огне."],
         ["Dice the beef and fry for 10 minutes; add the onion and carrot.",
          "Stir in the rice, pour in boiling water and tuck in the garlic.",
          "Simmer, covered, over low heat for 40–50 minutes."]),
        ("Гуляш из говядины с подливой", "Beef goulash with gravy", 75,
         [("beef", 400), ("onion", 100), ("carrot", 80),
          ("tomato_paste", 40), ("sour_cream", 60), ("flour", 15),
          ("vegetable_oil", 20)],
         ["Говядину нарежьте кубиками и обжарьте до корочки.",
          "Добавьте лук, морковь, томатную пасту и муку, обжарьте 3 минуты.",
          "Влейте 300 мл воды и тушите 45–60 минут до мягкости, в конце "
          "вмешайте сметану."],
         ["Dice the beef and fry until browned.",
          "Add the onion, carrot, tomato paste and flour; fry for 3 minutes.",
          "Pour in 300 ml of water and simmer for 45–60 minutes; stir in "
          "the sour cream at the end."]),
        ("Бефстроганов", "Beef stroganoff", 60,
         [("beef", 400), ("onion", 100), ("mushroom", 150),
          ("sour_cream", 100), ("mustard", 10), ("vegetable_oil", 20)],
         ["Говядину нарежьте тонкой соломкой и обжарьте порциями 3–4 минуты.",
          "Отдельно обжарьте лук и грибы.",
          "Соедините, добавьте сметану с горчицей и прогрейте 5 минут "
          "на слабом огне."],
         ["Slice the beef into thin strips and fry in batches for 3–4 "
          "minutes.",
          "Separately fry the onion and mushrooms.",
          "Combine, add the sour cream with mustard and heat through for "
          "5 minutes over low heat."]),
        ("Ленивые голубцы", "Lazy cabbage rolls", 60,
         [("minced_beef", 350), ("cabbage", 250), ("rice", 80),
          ("onion", 60), ("tomato_paste", 40), ("sour_cream", 40)],
         ["Капусту нашинкуйте и помните с солью.",
          "Смешайте фарш, капусту, отваренный рис и лук; сформируйте "
          "котлеты.",
          "Обжарьте, затем залейте соусом из томатной пасты и сметаны и "
          "тушите 25 минут."],
         ["Shred the cabbage and crush it with salt.",
          "Mix the ground meat, cabbage, cooked rice and onion; shape "
          "cutlets.",
          "Fry, then cover with a tomato-and-sour-cream sauce and simmer "
          "for 25 minutes."]),
        ("Фаршированные перцы", "Stuffed bell peppers", 70,
         [("bell_pepper", 500), ("minced_beef", 300), ("rice", 80),
          ("onion", 60), ("carrot", 60), ("tomato_paste", 30),
          ("sour_cream", 40)],
         ["Перцы очистите от семян.",
          "Смешайте фарш с полуготовым рисом, луком и морковью, нафаршируйте "
          "перцы.",
          "Поставьте в кастрюлю, залейте соусом с водой и тушите 35–40 "
          "минут."],
         ["Core the bell peppers.",
          "Mix the ground meat with half-cooked rice, onion and carrot and "
          "stuff the peppers.",
          "Place in a pot, cover with the sauce thinned with water and "
          "simmer for 35–40 minutes."]),
        ("Фаршированные кабачки", "Stuffed zucchini", 60,
         [("zucchini", 400), ("minced_chicken", 250), ("rice", 60),
          ("onion", 50), ("cheese", 40), ("tomato_paste", 30)],
         ["Кабачки разрежьте вдоль и ложкой выньте мякоть.",
          "Смешайте фарш с рисом и луком, наполните лодочки, посыпьте сыром.",
          "Запекайте 30–35 минут при 180 °C."],
         ["Halve the zucchini and scoop out the flesh.",
          "Mix the ground chicken with rice and onion, fill the boats and "
          "sprinkle with cheese.",
          "Bake at 180 °C for 30–35 minutes."]),
        ("Куриная печень в сметане", "Chicken liver in sour cream", 30,
         [("chicken_liver", 350), ("onion", 100), ("sour_cream", 100),
          ("vegetable_oil", 15)],
         ["Печень промойте и обсушите.",
          "Обжарьте лук, добавьте печень и жарьте 5–6 минут.",
          "Влейте сметану, посолите и тушите 8–10 минут."],
         ["Rinse and dry the liver.",
          "Fry the onion, add the liver and cook for 5–6 minutes.",
          "Pour in the sour cream, season and simmer for 8–10 minutes."]),
        ("Тушёная капуста с курицей", "Braised cabbage with chicken", 50,
         [("chicken_thigh", 300), ("cabbage", 400), ("onion", 60),
          ("carrot", 60), ("tomato_paste", 40), ("vegetable_oil", 20)],
         ["Курицу обжарьте кусочками до румяности.",
          "Добавьте лук, морковь и нашинкованную капусту.",
          "Влейте томатную пасту с полстаканом воды и тушите 25–30 минут."],
         ["Fry the chicken pieces until golden.",
          "Add the onion, carrot and shredded cabbage.",
          "Stir in the tomato paste with half a cup of water and simmer "
          "for 25–30 minutes."]),
        ("Тушёный картофель с мясом", "Beef and potato stew", 70,
         [("beef", 350), ("potato", 400), ("carrot", 80), ("onion", 80),
          ("tomato_paste", 30), ("bay_leaf", 1)],
         ["Мясо обжарьте с луком, залейте водой и тушите 30 минут.",
          "Добавьте картофель и морковь, тушите ещё 25–30 минут до "
          "мягкости."],
         ["Fry the meat with the onion, add water and simmer for 30 minutes.",
          "Add the potatoes and carrot and simmer for another 25–30 minutes "
          "until tender."]),
        ("Курица, запечённая с овощами", "Oven-baked chicken with "
         "vegetables", 55,
         [("chicken_thigh", 450), ("potato", 300), ("carrot", 100),
          ("bell_pepper", 100), ("onion", 80), ("olive_oil", 25),
          ("spices", 3)],
         ["Овощи нарежьте крупно, выложите в форму, посолите и полейте "
          "маслом.",
          "Сверху разложите курицу, приправьте.",
          "Запекайте 40–45 минут при 190 °C."],
         ["Cut the vegetables roughly, place in a baking dish, season and "
          "drizzle with oil.",
          "Arrange the chicken on top and season.",
          "Bake at 190 °C for 40–45 minutes."]),
        ("Картофельная запеканка с фаршем", "Potato and mince casserole", 70,
         [("potato", 500), ("minced_beef", 300), ("onion", 80),
          ("cheese", 50), ("milk", 60), ("butter", 15)],
         ["Картофель отварите и сделайте пюре с молоком и маслом.",
          "Фарш обжарьте с луком до готовности.",
          "В форме чередуйте слои пюре и фарша, посыпьте сыром и запекайте "
          "25 минут при 180 °C."],
         ["Boil the potatoes and mash with milk and butter.",
          "Fry the ground beef with the onion until cooked.",
          "Layer the mash and the mince in a dish, top with cheese and bake "
          "at 180 °C for 25 minutes."]),
        ("Макароны по-флотски с говядиной", "Navy-style pasta with beef", 35,
         [("pasta", 250), ("minced_beef", 300), ("onion", 100),
          ("carrot", 60), ("vegetable_oil", 20)],
         ["Отварите макароны до аль денте.",
          "Фарш обжарьте с луком и морковью 10 минут, добавьте томатную "
          "пасту при желании.",
          "Соедините с макаронами и прогрейте 3 минуты."],
         ["Boil the pasta until al dente.",
          "Fry the ground beef with the onion and carrot for 10 minutes.",
          "Fold in the pasta and heat through for 3 minutes."]),
        ("Паста в сливочном соусе с курицей", "Creamy chicken pasta", 35,
         [("pasta", 180), ("chicken_breast", 250), ("cream", 120),
          ("onion", 60), ("garlic", 6), ("cheese", 40),
          ("olive_oil", 15)],
         ["Курицу нарежьте полосками и обжарьте 6–7 минут.",
          "Добавьте лук и чеснок, влейте сливки, прогрейте 3 минуты.",
          "Соедините с макаронами, посыпьте сыром."],
         ["Slice the chicken into strips and fry for 6–7 minutes.",
          "Add the onion and garlic, pour in the cream and heat for 3 "
          "minutes.",
          "Fold in the pasta and sprinkle with cheese."]),
        ("Рыба в томатном соусе с овощами", "Fish in tomato sauce with "
         "vegetables", 40,
         [("pollock", 400), ("carrot", 100), ("onion", 80),
          ("tomato_paste", 50), ("vegetable_oil", 20)],
         ["Морковь натрите, лук нарежьте, обжарьте вместе 5 минут.",
          "Добавьте томатную пасту и полстакана воды — это подушка из "
          "овощей.",
          "Выложите куски рыбы на овощи и тушите под крышкой 20 минут."],
         ["Grate the carrot, chop the onion and fry together for 5 minutes.",
          "Stir in the tomato paste and half a cup of water to make the "
          "vegetable bed.",
          "Lay the fish pieces on top and simmer, covered, for 20 minutes."]),
        ("Креветки в чесночном масле", "Garlic butter shrimp", 15,
         [("shrimp", 400), ("butter", 30), ("garlic", 12), ("lemon", 30),
          ("greens", 10)],
         ["Растопите масло с чесноком на сковороде.",
          "Добавьте креветки и жарьте 3–4 минуты, помешивая.",
          "Сбрызните лимонным соком и посыпьте зеленью."],
         ["Melt the butter with the garlic in a pan.",
          "Add the shrimp and fry for 3–4 minutes, stirring.",
          "Squeeze over the lemon and sprinkle with herbs."]),
        ("Тофу в соевом соусе с овощами", "Tofu in soy sauce with "
         "vegetables", 30,
         [("tofu", 300), ("bell_pepper", 100), ("zucchini", 100),
          ("soy_sauce", 40), ("honey", 15), ("garlic", 8),
          ("sesame_oil_placeholder", 0)],
         ["Тофу нарежьте кубиками и обжарьте до румяности.",
          "Добавьте овощи и жарьте 5 минут.",
          "Влейте соус из соевого соуса, мёда и чеснока, прогрейте 2 минуты."],
         ["Dice the tofu and fry until golden.",
          "Add the vegetables and fry for 5 minutes.",
          "Pour in the soy-honey-garlic sauce and heat for 2 minutes."]),
        ("Нут, тушённый в томате", "Chickpeas simmered in tomato sauce", 35,
         [("chickpeas", 250), ("tomato_paste", 50), ("onion", 80),
          ("carrot", 60), ("spices", 3), ("olive_oil", 15)],
         ["Лук и морковь обжарьте, добавьте томатную пасту.",
          "Всыпьте отварной нут и полстакана воды, тушите 15 минут.",
          "Приправьте паприкой и зирой."],
         ["Fry the onion and carrot, stir in the tomato paste.",
          "Add the cooked chickpeas and half a cup of water, simmer for "
          "15 minutes.",
          "Season with paprika and cumin."]),
        ("Чечевица с овощами по-восточному", "Oriental-style lentils with "
         "vegetables", 35,
         [("lentils", 250), ("carrot", 80), ("onion", 80), ("tomato", 100),
          ("spices", 3), ("olive_oil", 15)],
         ["Лук, морковь обжарьте, добавьте помидоры кубиками.",
          "Всыпьте чечевицу, залейте водой на 2 см выше, варите 20 минут.",
          "Приправьте зирой и куркумой."],
         ["Fry the onion and carrot, add the diced tomatoes.",
          "Stir in the lentils, cover with water 2 cm above and cook for "
          "20 minutes.",
          "Season with cumin and turmeric."]),
    ]
    for ru, en, minutes, ings, sru, sen in items:
        ings = [(k, g) for k, g in ings if g > 0]
        ings = [(k if k != "sesame_oil_placeholder" else "olive_oil", g)
                for k, g in ings]
        ings += [("salt", 2), ("pepper", 1)]
        # плов — большая кастрюля на 4 порции
        servings = 4 if ru.startswith("Плов") else 2
        out.append(draft("main", ru, en, minutes, servings, ings, sru, sen))
    return out


def pasta_dishes():
    """Паста: 14 соусов/комбинаций."""
    out = []
    items = [
        ("Паста болоньезе", "Bolognese pasta",
         [("minced_beef", 300), ("tomato_paste", 60), ("tomato", 150),
          ("onion", 80), ("carrot", 60), ("olive_oil", 20)], False),
        ("Паста в сливочном соусе с грибами", "Creamy mushroom pasta",
         [("mushroom", 250), ("cream", 150), ("onion", 60),
          ("butter", 20)], False),
        ("Сырная паста", "Cheese pasta",
         [("cheese", 80), ("cream", 120), ("butter", 20),
          ("garlic", 4)], False),
        ("Паста с тунцом и томатами", "Tuna and tomato pasta",
         [("tuna_can", 150), ("tomato", 200), ("garlic", 6),
          ("olive_oil", 20)], False),
        ("Паста с креветками в чесночном масле", "Garlic shrimp pasta",
         [("shrimp", 250), ("butter", 30), ("garlic", 12), ("lemon", 30)],
         False),
        ("Овощная паста", "Vegetable pasta",
         [("zucchini", 150), ("bell_pepper", 100), ("tomato", 200),
          ("onion", 60), ("olive_oil", 25), ("garlic", 6)], True),
        ("Паста с чечевицей по-итальянски", "Lentil ragù pasta",
         [("lentils", 200), ("tomato_paste", 60), ("carrot", 60),
          ("onion", 60), ("olive_oil", 20)], True),
        ("Паста со шпинатом и тофу", "Pasta with spinach and tofu",
         [("tofu", 200), ("spinach", 150), ("cream", 100),
          ("garlic", 6)], False),
        ("Паста карбонара-стайл", "Carbonara-style pasta",
         [("egg", 120), ("cheese", 60), ("garlic", 4), ("butter", 15)],
         False),
        ("Паста песто-стайл", "Pesto-style pasta",
         [("walnut", 40), ("olive_oil", 40), ("greens", 30),
          ("cheese", 40), ("garlic", 4)], False),
        ("Паста с лососем и сливками", "Salmon cream pasta",
         [("salmon", 250), ("cream", 150), ("onion", 50),
          ("butter", 20)], False),
        ("Паста с курицей и томатами", "Chicken and tomato pasta",
         [("chicken_breast", 250), ("tomato", 200), ("onion", 60),
          ("olive_oil", 20)], False),
        ("Паста с курицей в сливках", "Chicken pasta in cream sauce",
         [("chicken_breast", 250), ("cream", 150), ("cheese", 40),
          ("garlic", 6)], False),
        ("Макароны с яйцом и зеленью", "Pasta with egg and herbs",
         [("egg", 120), ("greens", 20), ("butter", 20),
          ("cheese", 30)], False),
    ]
    for ru, en, extra, vegan_ok in items:
        ings = ([("pasta", 200)] + extra +
                [("salt", 2), ("pepper", 1)])
        sru = ["Отварите макароны в подсоленной воде до аль денте, откиньте, "
               "сохранив полстакана воды от варки.",
               "Приготовьте соус: обжарьте основу, добавьте жидкие "
               "ингредиенты и прогрейте 3–5 минут.",
               "Соедините пасту с соусом, при необходимости подлейте воду "
               "от варки, прогрейте 1–2 минуты и подавайте."]
        sen = ["Boil the pasta in salted water until al dente; drain, "
               "reserving half a cup of the cooking water.",
               "Make the sauce: fry the base, add the liquid ingredients "
               "and heat for 3–5 minutes.",
               "Toss the pasta with the sauce, loosen with the reserved "
               "water if needed and serve."]
        out.append(draft("main", ru, en, 30, 2, ings, sru, sen))
    return out


def build_main(garn_per=GARN_PER):
    return (generic_mains(garn_per) + sauced_mains() + cutlets() +
            specials() + pasta_dishes())
