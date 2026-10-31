# -*- coding: utf-8 -*-
"""Супы (4 базовых бульона) и самостоятельные гарниры."""

from helpers import draft


def soups():
    out = []
    base_aromatic = [("carrot", 60), ("onion", 50), ("salt", 2),
                     ("bay_leaf", 1), ("pepper", 1)]

    chicken_base = [("chicken_thigh", 450), ("potato", 250),
                    ("water", 0)] + base_aromatic

    def chicken(title_ru, title_en, extra, minutes=50, family="chicken_thigh",
                drop_potato=False):
        ings = list(chicken_base)
        if drop_potato:
            ings = [i for i in ings if i[0] != "potato"]
        ings += extra
        sru = ["Курицу залейте 1,5 л воды, доведите до кипения, снимите пену "
               "и варите 25 минут.",
               "Добавьте нарезанные картофель, морковь и лук, варите 10 минут."]
        sen = ["Cover the chicken with 1.5 L of water, bring to a boil, "
               "skim and cook for 25 minutes.",
               "Add the chopped potatoes, carrot and onion and cook for "
               "10 minutes."]
        es_ru, es_en = extra_steps(extra)
        sru.extend(es_ru)
        sen.extend(es_en)
        sru.append("Дайте супу настояться под крышкой 10 минут и подавайте.")
        sen.append("Let the soup rest, covered, for 10 minutes and serve.")
        out.append(draft("soup", title_ru, title_en, minutes, 4, ings,
                         sru, sen, family=family))

    # (fix v0.6.11: шаги добавок строятся по ВСЕМ ключам добавки —
    # раньше у «фрикадельки + вермишель» вермишель терялась)
    EXTRA_STEPS = {
        "pasta": ("Всыпьте вермишель и варите ещё 5–7 минут.",
                  "Stir in the noodles and cook for another 5–7 minutes."),
        "rice": ("Всыпьте промытый рис и варите 15 минут.",
                 "Stir in the rinsed rice and cook for 15 minutes."),
        "buckwheat": ("Всыпьте промытую гречку и варите 15 минут.",
                      "Stir in the rinsed buckwheat and cook for 15 "
                      "minutes."),
        "millet": ("Всыпьте промытое пшено и варите 15 минут.",
                   "Stir in the rinsed millet and cook for 15 minutes."),
        "split_peas": ("Горох замочите заранее и варите с курицей 30 минут.",
                       "Soak the peas in advance and cook with the chicken "
                       "for 30 minutes."),
        "corn": ("Добавьте кукурузу и варите 5 минут.",
                 "Add the corn and cook for 5 minutes."),
        "mushroom": ("Обжарьте грибы и добавьте в суп за 10 минут до "
                     "готовности.",
                     "Fry the mushrooms and add them 10 minutes before the "
                     "soup is done."),
        "minced_chicken": ("Сформируйте фрикадельки из фарша и опустите в "
                           "кипящий бульон, варите 10 минут.",
                           "Shape meatballs from the ground chicken and "
                           "drop them into the boiling broth; cook for "
                           "10 minutes."),
    }
    FALLBACK_STEP = ("Поварите всё вместе в кастрюле ещё 5 минут на слабом "
                     "огне.",
                     "Simmer everything together in the pot for another 5 "
                     "minutes over low heat.")

    def extra_steps(extra):
        pairs = [EXTRA_STEPS.get(key, FALLBACK_STEP)
                 for key, _ in extra] if extra else [FALLBACK_STEP]
        return [p[0] for p in pairs], [p[1] for p in pairs]

    chicken("Куриная лапша", "Chicken noodle soup", [("pasta", 80)],
            drop_potato=True)
    chicken("Куриный суп с рисом", "Chicken rice soup", [("rice", 70)])
    chicken("Куриный суп с гречкой", "Chicken buckwheat soup",
            [("buckwheat", 70)])
    chicken("Куриный суп с овощами", "Chicken vegetable soup",
            [("zucchini", 100), ("bell_pepper", 60)])
    chicken("Суп с куриными фрикадельками и вермишелью",
            "Chicken meatball and noodle soup",
            [("minced_chicken", 300), ("pasta", 60)], family="minced_chicken")
    chicken("Куриный суп с пшеном", "Chicken millet soup", [("millet", 70)])
    chicken("Куриный суп с кукурузой", "Chicken corn soup", [("corn", 150)])
    chicken("Грибной суп с курицей", "Chicken and mushroom soup",
            [("mushroom", 200)])
    chicken("Гороховый суп с курицей", "Chicken and split pea soup",
            [("split_peas", 120)], minutes=70)

    # ---------- говяжьи ----------
    # (fix v0.6.11: раньше всем говяжьим супам печаталась одна фраза
    # «Борщ и щи подавайте со сметаной», а добавки (свёкла, перловка,
    # чечевица, лапша) не упоминались вовсе)
    beef_aromatic = [("carrot", 60), ("onion", 60), ("salt", 2),
                     ("bay_leaf", 1), ("pepper", 1), ("water", 0)]
    beef = [
        ("Борщ с говядиной", "Beef borscht",
         [("beetroot", 200), ("cabbage", 200), ("potato", 200),
          ("tomato_paste", 30), ("sour_cream", 60), ("vinegar", 5)], 80,
         "Свёклу натрите на крупной тёрке и потушите с томатной пастой "
         "и уксусом 5–7 минут, добавьте в борщ вместе с капустой "
         "и картофелем.",
         "Grate the beetroot and simmer with the tomato paste and vinegar "
         "for 5–7 minutes; add to the borscht with the cabbage and "
         "potatoes.",
         "Варите ещё 15–20 минут, посолите по вкусу.",
         "Cook for another 15–20 minutes and season to taste.",
         "Дайте настояться 10 минут и подавайте со сметаной.",
         "Rest for 10 minutes and serve with sour cream."),
        ("Щи из свежей капусты", "Fresh cabbage soup (shchi)",
         [("cabbage", 300), ("potato", 200), ("tomato_paste", 20)], 70,
         "Капусту нашинкуйте и добавьте в бульон вместе с картофелем.",
         "Shred the cabbage and add it to the broth with the potatoes.",
         "Варите ещё 15–20 минут, посолите по вкусу.",
         "Cook for another 15–20 minutes and season to taste.",
         "Дайте настояться 10 минут и подавайте со сметаной.",
         "Rest for 10 minutes and serve with sour cream."),
        ("Рассольник", "Rassolnik (pickle soup)",
         [("pickles", 150), ("pearl_barley", 80), ("potato", 200)], 75,
         "Перловку промойте (лучше замочить заранее на 1–2 часа) и "
         "добавьте в бульон вместе с картофелем и огурцами.",
         "Rinse the pearl barley (ideally soaked for 1–2 hours in advance) "
         "and add it to the broth with the potatoes and pickles.",
         "Варите ещё 25–30 минут до мягкости перловки, посолите по вкусу.",
         "Cook for another 25–30 minutes until the barley is tender and "
         "season to taste.",
         "Дайте настояться 10 минут и подавайте.",
         "Rest for 10 minutes and serve."),
        ("Чечевичный суп с говядиной", "Beef and lentil soup",
         [("lentils", 150), ("tomato_paste", 30), ("carrot", 80)], 60,
         "Промойте чечевицу и добавьте в суп вместе с томатной пастой "
         "и морковью.",
         "Rinse the lentils and add them to the soup with the tomato "
         "paste and carrot.",
         "Варите ещё 20–25 минут до мягкости чечевицы, посолите по вкусу.",
         "Cook for another 20–25 minutes until the lentils are tender and "
         "season to taste.",
         "Дайте настояться 10 минут и подавайте.",
         "Rest for 10 minutes and serve."),
        ("Суп с говядиной и овощами", "Beef and vegetable soup",
         [("potato", 200), ("celery", 60), ("tomato", 100),
          ("bell_pepper", 60)], 70,
         "Добавьте нарезанные картофель, сельдерей, помидоры и перец.",
         "Add the chopped potatoes, celery, tomatoes and bell pepper.",
         "Варите ещё 15–20 минут, посолите по вкусу.",
         "Cook for another 15–20 minutes and season to taste.",
         "Дайте настояться 10 минут и подавайте.",
         "Rest for 10 minutes and serve."),
        ("Лапша с говядиной", "Beef noodle soup",
         [("pasta", 80), ("carrot", 60)], 60,
         "Добавьте нарезанную морковь.",
         "Add the sliced carrot.",
         "Варите 10 минут, затем всыпьте лапшу и варите ещё 5–7 минут, "
         "посолите по вкусу.",
         "Cook for 10 minutes, then stir in the noodles and cook for "
         "another 5–7 minutes; season to taste.",
         "Дайте настояться 10 минут и подавайте.",
         "Rest for 10 minutes and serve."),
    ]
    for ru, en, extra, minutes, add_ru, add_en, cook_ru, cook_en, \
            end_ru, end_en in beef:
        ings = [("beef", 400)] + beef_aromatic + extra
        sru = ["Говядину залейте 1,5–2 л воды, снимите пену и варите 40–50 "
               "минут до мягкости.",
               "Достаньте, нарежьте и верните в бульон.",
               add_ru, cook_ru, end_ru]
        sen = ["Cover the beef with 1.5–2 L of water, skim and cook for "
               "40–50 minutes until tender.",
               "Take it out, slice and return to the broth.",
               add_en, cook_en, end_en]
        out.append(draft("soup", ru, en, minutes, 4, ings, sru, sen))

    # ---------- вегетарианские ----------
    veg = [
        ("Грибной суп", "Mushroom soup",
         [("mushroom", 300), ("potato", 250), ("sour_cream", 40)],
         40, False),
        ("Грибной крем-суп", "Creamy mushroom soup",
         [("mushroom", 300), ("potato", 150), ("cream", 100),
          ("onion", 60)], 40, True),
        ("Тыквенный крем-суп", "Creamy pumpkin soup",
         [("pumpkin", 400), ("carrot", 60), ("cream", 100), ("onion", 50)],
         35, True),
        ("Кукурузный крем-суп", "Creamy corn soup",
         [("corn", 250), ("potato", 150), ("cream", 80)], 35, True),
        ("Крем-суп из брокколи с сыром", "Broccoli cheese soup",
         [("broccoli", 300), ("cream", 80), ("cheese", 40), ("onion", 50)],
         35, True),
        ("Крем-суп из цветной капусты", "Cauliflower soup",
         [("cauliflower", 300), ("cream", 80), ("onion", 50)], 35, True),
        ("Томатный суп с базиликом", "Tomato basil soup",
         [("tomato", 500), ("potato", 150), ("onion", 60), ("cream", 100),
          ("herbs_dried", 2)], 35, True),
        ("Кабачковый крем-суп", "Zucchini soup",
         [("zucchini", 500), ("potato", 150), ("cream", 80),
          ("garlic", 6), ("onion", 50)],
         35, True),
        ("Гороховый постный суп", "Vegan split pea soup",
         [("split_peas", 200), ("carrot", 80), ("onion", 60),
          ("bay_leaf", 1)], 60, False),
        ("Чечевичный постный суп", "Vegan lentil soup",
         [("lentils", 200), ("carrot", 80), ("tomato_paste", 30),
          ("onion", 60)], 45, False),
        ("Фасолевый постный суп", "Vegan bean soup",
         [("beans", 180), ("tomato", 100), ("potato", 150),
          ("carrot", 60)], 60, False),
        ("Зелёные щи с яйцом", "Green sorrel soup with egg",
         [("greens", 100), ("potato", 200), ("egg", 120),
          ("sour_cream", 40)], 35, False),
        ("Овощной суп", "Vegetable soup",
         [("potato", 250), ("cabbage", 200), ("carrot", 60),
          ("tomato", 150), ("zucchini", 100), ("vegetable_oil", 20)],
         40, False),
        ("Гречневый постный суп с грибами", "Vegan buckwheat and mushroom "
         "soup", [("buckwheat", 80), ("potato", 150), ("mushroom", 100),
                  ("carrot", 60)], 40, False),
    ]
    # (fix v0.6.11: у гороха и фасоли «варите 20–25 минут» — физически
    # несвариваемо; у чечевицы и гречки крупа не называлась вовсе)
    VEG_STEPS = {
        "Гороховый постный суп": (
            ["Горох промойте и замочите на 2–3 часа (колотый можно "
             "не замачивать).",
             "Залейте 1,5 л воды, доведите до кипения и варите 40–50 минут "
             "до мягкости.",
             "Добавьте нарезанные морковь и лук с лавровым листом, варите "
             "ещё 10–15 минут, посолите.",
             "Поварите ещё 3–5 минут на слабом огне и подавайте."],
            ["Rinse the split peas and soak for 2–3 hours (split peas can "
             "skip soaking).",
             "Cover with 1.5 L of water, bring to a boil and cook for "
             "40–50 minutes until soft.",
             "Add the chopped carrot and onion with the bay leaf and cook "
             "for another 10–15 minutes; season with salt.",
             "Simmer for another 3–5 minutes over low heat and serve."]),
        "Фасолевый постный суп": (
            ["Фасоль замочите на ночь и отварите 40–50 минут до мягкости "
             "(консервированную просто промойте и добавьте за 10 минут "
             "до конца).",
             "Добавьте нарезанные картофель, морковь и помидоры, варите "
             "15–20 минут, посолите.",
             "Поварите ещё 3–5 минут на слабом огне и подавайте."],
            ["Soak the beans overnight and cook for 40–50 minutes until "
             "tender (canned beans: just rinse and add 10 minutes before "
             "the end).",
             "Add the chopped potatoes, carrot and tomatoes and cook for "
             "15–20 minutes; season with salt.",
             "Simmer for another 3–5 minutes over low heat and serve."]),
        "Чечевичный постный суп": (
            ["Чечевицу промойте, залейте 1,2–1,5 л воды и варите 10 минут.",
             "Добавьте нарезанные лук и морковь с томатной пастой, варите "
             "ещё 15–20 минут до мягкости, посолите.",
             "Дайте настояться 5 минут и подавайте."],
            ["Rinse the lentils, cover with 1.2–1.5 L of water and cook "
             "for 10 minutes.",
             "Add the chopped onion and carrot with the tomato paste and "
             "cook for another 15–20 minutes until tender; season with "
             "salt.",
             "Let rest for 5 minutes and serve."]),
        "Гречневый постный суп с грибами": (
            ["Картофель нарежьте и залейте 1–1,2 л воды, варите 10 минут.",
             "Грибы с луком и морковью нарежьте и добавьте вместе с "
             "промытой гречкой, варите ещё 15 минут, посолите.",
             "Поварите ещё 3–5 минут на слабом огне и подавайте."],
            ["Chop the potatoes, cover with 1–1.2 L of water and cook for "
             "10 minutes.",
             "Chop the mushrooms, onion and carrot and add them with the "
             "rinsed buckwheat; cook for another 15 minutes and season "
             "with salt.",
             "Simmer for another 3–5 minutes over low heat and serve."]),
    }
    for ru, en, ings, minutes, is_cream in veg:
        if ru in VEG_STEPS:
            sru, sen = VEG_STEPS[ru]
            out.append(draft("soup", ru, en, minutes, 4, ings + [("salt", 2)],
                             sru, sen))
            continue
        sru = ["Овощи нарежьте и залейте 1–1,2 л воды.",
               "Варите 20–25 минут до мягкости, посолите."]
        sen = ["Chop the vegetables and cover with 1–1.2 L of water.",
               "Cook for 20–25 minutes until soft; season with salt."]
        if is_cream:
            sru.append("Добавьте сливки и пробейте блендером до однородного "
                       "пюре.")
            sen.append("Add the cream and blend until smooth.")
        else:
            sru.append("Поварите ещё 3–5 минут в кастрюле на слабом огне "
                       "и подавайте.")
            sen.append("Simmer in the pot for another 3–5 minutes over low "
                       "heat and serve.")
        out.append(draft("soup", ru, en, minutes, 4, ings + [("salt", 2)],
                         sru, sen))

    # ---------- рыбные ----------
    fish = [
        ("Уха из лосося", "Salmon ukha",
         [("salmon", 350), ("potato", 250), ("carrot", 60), ("onion", 50)],
         40),
        ("Уха из минтая", "Pollock ukha",
         [("pollock", 400), ("potato", 250), ("millet", 50),
          ("carrot", 60)], 40),
        ("Лососевый крем-суп", "Creamy salmon soup",
         [("salmon", 300), ("cream", 120), ("potato", 150), ("onion", 50)],
         35),
        ("Рыбный суп с треской и овощами", "Cod and vegetable soup",
         [("cod", 350), ("potato", 200), ("tomato", 100), ("carrot", 60)],
         35),
        ("Тайский суп с креветками", "Thai-style shrimp soup",
         [("shrimp", 250), ("mushroom", 150), ("tomato", 100),
          ("lemon", 40), ("soy_sauce", 20), ("garlic", 6)], 30),
    ]
    # (fix v0.6.11: креветки варятся 3–4 минуты, а не 10–12;
    # пшено в ухе из минтая не упоминалось)
    FISH_STEPS = {
        "Уха из минтая": (
            ["Овощи залейте 1–1,2 л воды и варите 15 минут.",
             "Всыпьте промытое пшено и варите 10 минут.",
             "Добавьте минтая и варите ещё 10–12 минут.",
             "Посолите, приправьте и дайте настояться 5 минут."],
            ["Cover the vegetables with 1–1.2 L of water and cook for "
             "15 minutes.",
             "Stir in the rinsed millet and cook for 10 minutes.",
             "Add the pollock and cook for another 10–12 minutes.",
             "Season, add salt and let rest for 5 minutes."]),
        "Тайский суп с креветками": (
            ["Овощи с грибами залейте 1 л воды и варите 10 минут.",
             "Добавьте креветки и соевый соус, варите 3–4 минуты — "
             "креветки готовятся очень быстро.",
             "Снимите с огня, добавьте лимонный сок, посолите и дайте "
             "настояться 5 минут."],
            ["Cover the vegetables and mushrooms with 1 L of water and "
             "cook for 10 minutes.",
             "Add the shrimp and soy sauce and cook for 3–4 minutes — "
             "shrimp cook very quickly.",
             "Remove from the heat, add the lemon juice, season with salt "
             "and let rest for 5 minutes."]),
    }
    for ru, en, ings, minutes in fish:
        if ru in FISH_STEPS:
            sru, sen = FISH_STEPS[ru]
            out.append(draft("soup", ru, en, minutes, 4,
                             ings + [("salt", 2), ("bay_leaf", 1)], sru, sen))
            continue
        sru = ["Овощи залейте 1–1,2 л воды и варите 15 минут.",
               "Добавьте рыбу и варите ещё 10–12 минут.",
               "Посолите, приправьте и дайте настояться 5 минут."]
        sen = ["Cover the vegetables with 1–1.2 L of water and cook for "
               "15 minutes.",
               "Add the fish and cook for another 10–12 minutes.",
               "Season, add salt and let rest for 5 minutes."]
        out.append(draft("soup", ru, en, minutes, 4,
                         ings + [("salt", 2), ("bay_leaf", 1)], sru, sen))
    return out


def sides():
    """Самостоятельные гарниры (категория side — используются как обед/ужин)."""
    out = []
    items = [
        ("Гречка с грибами и луком", "Buckwheat with mushrooms and onion",
         [("buckwheat", 80), ("mushroom", 150), ("onion", 60),
          ("vegetable_oil", 15)],
         [("Гречку прокалите на сухой сковороде 2 минуты.",
           "Toast the buckwheat in a dry pan for 2 minutes."),
          ("Залейте водой 1:2, варите под крышкой 15 минут.",
           "Add water 1:2 and cook, covered, for 15 minutes."),
          ("Грибы с луком обжарьте и смешайте с гречкой.",
           "Fry the mushrooms with the onion and fold into the buckwheat.")]),
        ("Рис с овощами", "Rice with vegetables",
         [("rice", 80), ("carrot", 60), ("green_peas", 60), ("corn", 60),
          ("vegetable_oil", 15)],
         [("Рис обжарьте с маслом 2 минуты, залейте водой 1:2.",
           "Fry the rice in oil for 2 minutes, add water 1:2."),
          ("Добавьте овощи, накройте крышкой и готовьте 15 минут.",
           "Add the vegetables, cover and cook for 15 minutes.")]),
        ("Картофельное пюре с чесноком", "Garlic mashed potatoes",
         [("potato", 300), ("milk", 80), ("butter", 20), ("garlic", 8)],
         [("Картофель отварите в подсоленной воде до мягкости.",
           "Boil the potatoes in salted water until soft."),
          ("Разомните с горячим молоком и маслом, вмешайте чеснок.",
           "Mash with hot milk and butter, stir in the garlic.")]),
        ("Запечённые дольки картофеля", "Roasted potato wedges",
         [("potato", 350), ("olive_oil", 20), ("spices", 3), ("garlic", 6)],
         [("Картофель нарежьте дольками и смешайте с маслом и специями.",
           "Cut the potatoes into wedges and toss with oil and spices."),
          ("Запекайте 35 минут при 200 °C, перевернув один раз.",
           "Roast at 200 °C for 35 minutes, turning once.")]),
        ("Тушёная капуста", "Braised cabbage",
         [("cabbage", 400), ("onion", 60), ("carrot", 60),
          ("tomato_paste", 30), ("vegetable_oil", 15)],
         [("Капусту нашинкуйте, лук и морковь обжарьте.",
           "Shred the cabbage; fry the onion and carrot."),
          ("Сложите всё в сотейник, добавьте томатную пасту и полстакана "
           "воды, тушите 25 минут.",
           "Combine in a pot, add the tomato paste and half a cup of water, "
           "simmer for 25 minutes.")]),
        ("Булгур с овощами", "Bulgur with vegetables",
         [("bulgur_cooked", 0)],  # заглушка — заменяется ниже
         []),
        ("Перловка с грибами", "Pearl barley with mushrooms",
         [("pearl_barley", 80), ("mushroom", 150), ("onion", 60),
          ("butter", 15)],
         [("Перловку замочите на час и отварите 30 минут.",
           "Soak the barley for an hour and cook for 30 minutes."),
          ("Грибы с луком обжарьте в масле и смешайте с крупой.",
           "Fry the mushrooms with the onion in butter and fold into the "
           "barley.")]),
        ("Овощное рагу", "Vegetable stew",
         [("potato", 200), ("zucchini", 150), ("cabbage", 150),
          ("carrot", 60), ("tomato", 100), ("vegetable_oil", 15)],
         [("Овощи нарежьте крупными кубиками.",
           "Cut the vegetables into large cubes."),
          ("Слоями сложите в сотейник с маслом и небольшим количеством "
           "воды, тушите 30 минут под крышкой.",
           "Layer in a pot with oil and a splash of water, simmer, "
           "covered, for 30 minutes.")]),
        ("Кабачки тушёные с помидорами", "Zucchini simmered with tomatoes",
         [("zucchini", 300), ("tomato", 150), ("garlic", 6),
          ("olive_oil", 15), ("greens", 10)],
         [("Кабачки нарежьте полукружиями и обжарьте 5 минут.",
           "Slice the zucchini and fry for 5 minutes."),
          ("Добавьте помидоры и чеснок, тушите 15 минут.",
           "Add the tomatoes and garlic and simmer for 15 minutes.")]),
        ("Фасоль тушёная в томате", "Beans simmered in tomato sauce",
         [("beans", 200), ("tomato_paste", 40), ("onion", 60),
          ("carrot", 60), ("vegetable_oil", 15)],
         [("Фасоль замочите на ночь и отварите до готовности.",
           "Soak the beans overnight and cook until tender."),
          ("Обжарьте лук с морковью, добавьте томатную пасту и фасоль, "
           "тушите 10 минут.",
           "Fry the onion and carrot, add the tomato paste and beans and "
           "simmer for 10 minutes.")]),
    ]
    for ru, en, ings, steps in items:
        if ru == "Булгур с овощами":
            ings = [("bulgur_cooked", 0)]
            ings = [("bulgur_cooked", 300), ("carrot", 60),
                    ("bell_pepper", 60), ("onion", 50),
                    ("olive_oil", 15)]
            steps = [("Крупу залейте кипятком 1:1,5 и дайте настояться "
                      "20 минут.",
                      "Cover the bulgur with boiling water 1:1.5 and let "
                      "sit for 20 minutes."),
                     ("Овощи обжарьте и смешайте с булгуром.",
                      "Fry the vegetables and fold into the bulgur.")]
        sru = [s[0] for s in steps]
        sen = [s[1] for s in steps]
        out.append(draft("side", ru, en, 35, 2,
                         ings + [("salt", 2)], sru, sen))
    return out


def build_soup_side():
    return soups() + sides()
