# -*- coding: utf-8 -*-
"""Салаты, перекусы и десерты."""

from helpers import draft


# Подготовка ингредиентов, требующих готовки, — конкретно, с временем
# и способом (fix v0.6.11: «Отварите добавку, если требуется» не называл
# ни ингредиент, ни способ — пользователь ждал «отварите картошку»).
SALAD_PREP = {
    "potato": ("Картофель отварите в подсоленной воде 20–25 минут до "
               "мягкости, остудите и нарежьте кубиками.",
               "Boil the potatoes in salted water for 20–25 minutes until "
               "soft; cool and dice."),
    "beetroot": ("Свёклу отварите 40–50 минут до мягкости (быстрее — "
                 "в микроволновке), остудите и нарежьте кубиками.",
                 "Boil the beetroot for 40–50 minutes until soft (faster "
                 "in the microwave); cool and dice."),
    "egg": ("Яйца отварите вкрутую 9–10 минут, остудите в холодной воде, "
            "очистите и нарежьте.",
            "Hard-boil the eggs for 9–10 minutes, cool in cold water, peel "
            "and chop."),
    "chicken_breast": ("Курицу отварите в подсоленной воде 12–15 минут до "
                       "готовности, остудите и нарежьте кубиками.",
                       "Poach the chicken in salted water for 12–15 minutes "
                       "until cooked; cool and dice."),
    "beans": ("Фасоль отварите до готовности 40–50 минут (или возьмите "
              "консервированную и промойте).",
              "Cook the beans until tender, 40–50 minutes, or use canned "
              "beans, rinsed."),
    "chickpeas": ("Нут замочите заранее и отварите 50–60 минут до мягкости "
                  "(или возьмите консервированный и промойте).",
                  "Soak the chickpeas in advance and boil until soft, "
                  "50–60 minutes, or use canned, rinsed."),
    "shrimp": ("Креветки опустите в кипящую подсоленную воду на 3–4 минуты, "
               "остудите и очистите.",
               "Drop the shrimp into boiling salted water for 3–4 minutes; "
               "cool and peel."),
    "tuna_can": ("Тунец достаньте из банки, слейте жидкость и разберите "
                 "на кусочки.",
                 "Drain the canned tuna and flake it into pieces."),
    "walnut": ("Грецкие орехи подсушите на сухой сковороде 2–3 минуты и "
               "крупно порубите.",
               "Toast the walnuts in a dry pan for 2–3 minutes and chop "
               "coarsely."),
}

# Нарезка свежей базы салата (после prep-шагов)
SALAD_CUT = {
    "ct": ("Помидоры и огурцы нарежьте крупными кубиками.",
           "Dice the tomatoes and the cucumber."),
    "cabbage": ("Капусту тонко нашинкуйте, морковь натрите на крупной "
                "тёрке.",
                "Shred the cabbage thinly; grate the carrot coarsely."),
    "carrot": ("Морковь натрите на крупной тёрке.",
               "Grate the carrot coarsely."),
    "greens": ("Листья салата порвите руками, огурец нарежьте "
               "полукружиями.",
               "Tear the lettuce leaves by hand; slice the cucumber."),
    "potato": ("Солёные огурцы нарежьте кубиками.",
               "Dice the pickles."),
    "beet": None,  # свёкла уже нарезана в prep-шаге
}

# Заправка по типу салата — совпадает с логикой состава (ниже)
DRESSING = {
    "sour_cream": ("Смешайте всё в салатнике со сметаной, посолите и "
                   "поперчите.",
                   "Toss everything in a bowl with the sour cream; season "
                   "with salt and pepper."),
    "mayo": ("Смешайте всё в салатнике с майонезом, посолите и поперчите.",
             "Toss everything in a bowl with the mayonnaise; season with "
             "salt and pepper."),
    "oil": ("Смешайте всё в салатнике, заправьте оливковым маслом, "
            "посолите и поперчите.",
            "Toss everything in a bowl, dress with olive oil and season "
            "with salt and pepper."),
}


def salad_steps(base_key, add_key):
    """Шаги салата по фактическому составу (ru, en).

    Порядок: подготовка требующих готовки ингредиентов -> нарезка
    свежих -> сборка с заправкой, соответствующей составу.
    """
    sru, sen = [], []
    # ключ базы в bases не совпадает с ключом ингредиента (beet -> beetroot)
    base_prep = {"potato": "potato", "beet": "beetroot"}.get(base_key)
    for key in ([base_prep] if base_prep else []) + [add_key]:
        if key in SALAD_PREP:
            ru, en = SALAD_PREP[key]
            sru.append(ru)
            sen.append(en)
    if base_key == "ct" and add_key == "none":
        # Греческий салат: сыр и оливки заменяют заправку-майонез
        sru.append("Помидоры и огурцы нарежьте крупными кубиками, сыр — "
                   "такими же кубиками, оливки оставьте целыми.")
        sen.append("Dice the tomatoes, cucumber and cheese; leave the "
                   "olives whole.")
    else:
        cut = SALAD_CUT[base_key]
        if base_key == "carrot" and add_key == "apple":
            cut = ("Морковь натрите на крупной тёрке, яблоко нарежьте "
                   "соломкой.",
                   "Grate the carrot coarsely; slice the apple into "
                   "strips.")
        if cut:
            sru.append(cut[0])
            sen.append(cut[1])
        if add_key == "cheese":
            sru.append("Сыр нарежьте кубиками.")
            sen.append("Dice the cheese.")
    if base_key == "beet":
        dressing = "sour_cream"
    elif base_key == "potato" or (base_key == "ct" and add_key == "egg"):
        dressing = "mayo"
    else:
        dressing = "oil"
    sru.append(DRESSING[dressing][0])
    sen.append(DRESSING[dressing][1])
    return sru, sen


def salads():
    """Салаты: база x добавка (с whitelist по базе)."""
    bases = {
        "ct": ("Салат из помидоров и огурцов", "Tomato and cucumber salad",
               [("tomato", 200), ("cucumber", 200)],
               ["none", "egg", "cheese", "chicken_breast", "tuna_can",
                "chickpeas", "beans", "shrimp"]),
        "cabbage": ("Салат из свежей капусты", "Fresh cabbage salad",
                    [("cabbage", 250), ("carrot", 60)],
                    ["none", "egg", "cheese", "chicken_breast", "tuna_can",
                     "chickpeas", "beans"]),
        "beet": ("Салат из свёклы", "Beetroot salad",
                 [("beetroot", 200)],
                 ["none", "egg", "cheese", "beans", "walnut"]),
        "carrot": ("Морковный салат", "Carrot salad",
                   [("carrot", 200)],
                   ["none", "apple", "cheese", "chickpeas"]),
        "greens": ("Зелёный салат", "Green salad",
                   [("lettuce", 150), ("cucumber", 150)],
                   ["none", "egg", "cheese", "chicken_breast", "tuna_can",
                    "shrimp", "chickpeas"]),
        "potato": ("Картофельный салат", "Potato salad",
                   [("potato", 250), ("pickles", 60)],
                   ["none", "egg", "beans"]),
    }
    adds = {
        "none": ("", "", []),
        "egg": ("с яйцом", "with egg", [("egg", 100)]),
        "cheese": ("с сыром", "with cheese", [("cheese", 60)]),
        "chicken_breast": ("с курицей", "with chicken",
                           [("chicken_breast", 120)]),
        "tuna_can": ("с тунцом", "with tuna", [("tuna_can", 80)]),
        "chickpeas": ("с нутом", "with chickpeas", [("chickpeas", 100)]),
        "beans": ("с фасолью", "with beans", [("beans", 100)]),
        "shrimp": ("с креветками", "with shrimp", [("shrimp", 100)]),
        "apple": ("с яблоком", "with apple", [("apple", 80)]),
        "walnut": ("с грецкими орехами", "with walnuts", [("walnut", 30)]),
        "pickles": ("с солёными огурцами", "with pickles", [("pickles", 60)]),
    }
    # Реалистичное время: варка картофеля/свёклы/бобовых требует минут
    ADD_MINUTES = {
        "none": 15, "cheese": 15, "walnut": 20, "apple": 15,
        "pickles": 15, "tuna_can": 15, "egg": 20, "shrimp": 20,
        "chicken_breast": 25, "beans": 55, "chickpeas": 60,
    }
    out = []
    for base_key, (base_ru, base_en, base_ings, allowed) in bases.items():
        for add_key in allowed:
            add_ru, add_en, add_ings = adds[add_key]
            ings = list(base_ings) + add_ings
            # заправка по типу салата
            if base_key in ("potato", "beet") or add_key == "egg" and \
                    base_key == "ct":
                ings += [("sour_cream", 40) if base_key == "beet"
                         else ("mayo", 25)]
            elif base_key == "ct" and add_key == "none":
                ings = [("tomato", 200), ("cucumber", 200), ("cheese", 60),
                        ("olives", 30)]
                base_ru, base_en = "Греческий салат", "Greek salad"
            ings += [("olive_oil", 18), ("salt", 1), ("pepper", 1)]
            ru = f"{base_ru} {add_ru}".replace("  ", " ").strip()
            en = f"{base_en} {add_en}".replace("  ", " ").strip()
            sru, sen = salad_steps(base_key, add_key)
            family = add_ings[0][0] if add_ings else base_ings[0][0]
            if base_key == "beet":
                minutes = 60
            elif base_key == "potato":
                minutes = 35
            else:
                minutes = ADD_MINUTES[add_key]
            out.append(draft("salad", ru, en, minutes, 2, ings, sru, sen,
                             family=family))
    return out


def snacks():
    out = []
    items = [
        ("Творог с ягодами", "Cottage cheese with berries",
         [("cottage_cheese", 120), ("berries", 80), ("honey", 10)], 5,
         ["Ягоды промойте, крупные разрежьте пополам.",
          "Смешайте творог с ягодами, полейте мёдом."],
         ["Rinse the berries; halve the large ones.",
          "Fold the berries into the cottage cheese and drizzle with "
          "honey."]),
        ("Йогурт с бананом и орехами", "Yogurt with banana and nuts",
         [("yogurt", 150), ("banana", 80), ("walnut", 15)], 5,
         ["Банан нарежьте кружочками, орехи крупно порубите.",
          "Смешайте с йогуртом."],
         ["Slice the banana; chop the nuts coarsely.",
          "Fold into the yogurt."]),
        ("Яблоко с арахисовой пастой", "Apple with peanut butter",
         [("apple", 150), ("peanut_butter", 20)], 5,
         ["Яблоко нарежьте дольками.",
          "Подавайте дольки с арахисовой пастой для макания."],
         ["Cut the apple into wedges.",
          "Serve the wedges with peanut butter for dipping."]),
        ("Тост с авокадо", "Avocado toast",
         [("bread", 70), ("avocado", 60), ("lemon", 5), ("salt", 1)], 7,
         ["Хлеб подрумяньте в тостере или на сухой сковороде.",
          "Авокадо разомните вилкой с лимонным соком и солью, намажьте "
          "на тост."],
         ["Toast the bread in a toaster or a dry pan.",
          "Mash the avocado with the lemon juice and salt; spread on the "
          "toast."]),
        ("Яйца с овощной нарезкой", "Boiled eggs with vegetable sticks",
         [("egg", 120), ("cucumber", 80), ("carrot", 80)], 12,
         ["Яйца отварите вкрутую 9–10 минут, остудите в холодной воде "
          "и очистите.",
          "Огурец и морковь нарежьте длинными брусочками, подавайте "
          "с яйцами."],
         ["Hard-boil the eggs for 9–10 minutes; cool in cold water and "
          "peel.",
          "Cut the cucumber and carrot into long sticks and serve with "
          "the eggs."]),
        ("Хумус с морковью", "Hummus with carrot sticks",
         [("chickpeas", 120), ("olive_oil", 15), ("lemon", 20),
          ("garlic", 4), ("carrot", 100)], 15,
         ["Нут замочите заранее и отварите 50–60 минут до мягкости (или "
          "возьмите консервированный и промойте).",
          "Пробейте блендером нут с чесноком, лимонным соком и маслом, "
          "подливая 2–3 ст. л. холодной воды до кремовой текстуры.",
          "Морковь нарежьте брусочками и подавайте с хумусом."],
         ["Soak the chickpeas in advance and boil until soft, 50–60 "
          "minutes, or use canned, rinsed.",
          "Blend the chickpeas with the garlic, lemon juice and oil, "
          "adding 2–3 tbsp of cold water until creamy.",
          "Cut the carrot into sticks and serve with the hummus."]),
        ("Ореховая смесь с сухофруктами", "Nut and raisin mix",
         [("walnut", 20), ("almond", 20), ("raisins", 25)], 2,
         ["Орехи по желанию подсушите на сухой сковороде 2–3 минуты "
          "и остудите.",
          "Смешайте с изюмом и расфасуйте порциями."],
         ["Optionally toast the nuts in a dry pan for 2–3 minutes and "
          "cool.",
          "Mix with the raisins and divide into portions."]),
        ("Банан с шоколадом", "Banana with chocolate",
         [("banana", 120), ("chocolate", 20)], 5,
         ["Шоколад растопите на водяной бане или в микроволновке — "
          "по 20 секунд, помешивая.",
          "Банан нарежьте кружочками и полейте шоколадом."],
         ["Melt the chocolate over a water bath or in the microwave in "
          "20-second bursts, stirring.",
          "Slice the banana and drizzle with the chocolate."]),
        ("Ягоды со сливками", "Berries with cream",
         [("berries", 120), ("cream", 60)], 5,
         ["Ягоды промойте и обсушите.",
          "Сливки взбейте до мягких пиков и подавайте с ягодами."],
         ["Rinse the berries and pat dry.",
          "Whip the cream to soft peaks and serve with the berries."]),
        ("Ягодный смузи", "Berry smoothie",
         [("berries", 100), ("banana", 60), ("milk", 150)], 5,
         ["Ягоды, банан и молоко пробейте блендером до однородности.",
          "Разлейте по стаканам и подавайте сразу."],
         ["Blend the berries, banana and milk until smooth.",
          "Pour into glasses and serve right away."]),
        ("Банановый смузи с овсянкой", "Banana oat smoothie",
         [("banana", 100), ("oat_flakes", 20), ("milk", 150),
          ("honey", 10)], 5,
         ["Овсяные хлопья залейте молоком и оставьте на 5 минут.",
          "Добавьте банан и мёд, пробейте блендером до однородности."],
         ["Cover the oats with the milk and let sit for 5 minutes.",
          "Add the banana and honey and blend until smooth."]),
        ("Морковные палочки с йогуртовым соусом",
         "Carrot sticks with yogurt dip",
         [("carrot", 120), ("yogurt", 80), ("garlic", 3),
          ("greens", 5)], 8,
         ["Морковь нарежьте брусочками.",
          "Йогурт смешайте с тёртым чесноком, рубленой зеленью и щепоткой "
          "соли — подавайте как соус."],
         ["Cut the carrot into sticks.",
          "Stir the grated garlic, chopped herbs and a pinch of salt into "
          "the yogurt and serve as a dip."]),
        ("Груша с сыром", "Pear with cheese",
         [("pear", 150), ("cheese", 40)], 5,
         ["Грушу нарежьте ломтиками, сыр — тонкими пластинками.",
          "Подавайте вместе."],
         ["Slice the pear; cut the cheese into thin slices.",
          "Serve together."]),
        ("Кефир с ягодами", "Kefir with berries",
         [("kefir", 250), ("berries", 60)], 3,
         ["Ягоды промойте и слегка разомните ложкой.",
          "Добавьте в кефир и перемешайте."],
         ["Rinse the berries and crush them lightly with a spoon.",
          "Stir into the kefir."]),
    ]
    for ru, en, ings, minutes, sru, sen in items:
        out.append(draft("snack", ru, en, minutes, 1, ings, sru, sen))
    return out


def desserts():
    out = []
    items = [
        ("Запечённое яблоко с мёдом и корицей", "Baked apple with honey "
         "and cinnamon", 30,
         [("apple", 200), ("honey", 20), ("cinnamon", 2), ("walnut", 15)],
         ["Вырежьте сердцевину яблок, не прорезая до дна.",
          "Вложите мёд, корицу и орехи.",
          "Запекайте 20–25 минут при 180 °C."],
         ["Core the apples without cutting through the bottom.",
          "Fill with honey, cinnamon and nuts.",
          "Bake at 180 °C for 20–25 minutes."]),
        ("Шарлотка с яблоками", "Apple charlotte", 50,
         [("apple", 300), ("flour", 120), ("egg", 150), ("sugar", 100),
          ("butter", 10)],
         ["Яйца взбейте с сахаром добела, всыпьте муку.",
          "Яблоки нарежьте дольками и выложите в смазанную форму.",
          "Залейте тестом и запекайте 35–40 минут при 180 °C."],
         ["Whisk the eggs with sugar until pale; stir in the flour.",
          "Slice the apples and place in a greased dish.",
          "Pour over the batter and bake at 180 °C for 35–40 minutes."]),
        ("Творожный десерт с какао", "Cocoa cottage cheese dessert", 10,
         [("cottage_cheese", 130), ("cocoa_repl", 0), ("sugar", 15),
          ("sour_cream", 30)],
         ["Творог взбейте со сметаной и сахаром.",
          "Добавьте какао по вкусу и перемешайте.",
          "Охладите 10 минут и подавайте."],
         ["Blend the cottage cheese with sour cream and sugar.",
          "Add cocoa to taste and mix.",
          "Chill for 10 minutes and serve."]),
        ("Ягоды со взбитыми сливками", "Berries with whipped cream", 10,
         [("berries", 150), ("cream", 80), ("sugar", 10)],
         ["Сливки взбейте с сахаром до мягких пиков.",
          "Разложите ягоды по креманкам и покройте сливками."],
         ["Whip the cream with sugar to soft peaks.",
          "Divide the berries between glasses and top with the cream."]),
        ("Овсяное печенье с бананом", "Banana oat cookies", 25,
         [("oat_flakes", 100), ("banana", 150), ("raisins", 30),
          ("honey", 20)],
         ["Банан разомните, смешайте с хлопьями, изюмом и мёдом.",
          "Выложите лепёшки на противень с пергаментом.",
          "Запекайте 15–18 минут при 180 °C."],
         ["Mash the banana, mix with oats, raisins and honey.",
          "Drop spoonfuls onto a lined baking tray.",
          "Bake at 180 °C for 15–18 minutes."]),
        ("Шоколадный мусс", "Chocolate mousse", 25,
         [("cream", 150), ("chocolate", 80), ("egg", 60), ("sugar", 20)],
         ["Шоколад растопите на водяной бане, слегка остудите.",
          "Вмешайте желтки, затем взбитые с сахаром белки.",
          "Сливки взбейте и аккуратно соедините с шоколадной массой. "
          "Охладите 1–2 часа."],
         ["Melt the chocolate over a water bath; cool slightly.",
          "Stir in the yolks, then the whites whipped with sugar.",
          "Whip the cream and fold into the chocolate. Chill for 1–2 "
          "hours."]),
        ("Груша, запечённая с мёдом и орехами", "Baked pear with honey and "
         "nuts", 30,
         [("pear", 200), ("honey", 20), ("walnut", 20), ("cinnamon", 1)],
         ["Груши разрежьте пополам, удалите сердцевину.",
          "Смажьте мёдом, посыпьте орехами и корицей.",
          "Запекайте 20 минут при 180 °C."],
         ["Halve the pears and core them.",
          "Brush with honey, sprinkle with nuts and cinnamon.",
          "Bake at 180 °C for 20 minutes."]),
        ("Бананово-ягодный сорбет", "Banana berry sorbet", 10,
         [("banana", 150), ("berries", 100), ("honey", 15)],
         ["Замороженный банан с ягодами пробейте блендером до кремовой "
          "текстуры.",
          "Добавьте мёд и подавайте сразу."],
         ["Blend frozen banana with berries until creamy.",
          "Stir in the honey and serve right away."]),
        ("Творожный пудинг с желатином", "Cottage cheese pudding", 20,
         [("cottage_cheese", 130), ("yogurt", 80), ("sugar", 15),
          ("gelatin_repl", 0)],
         ["Творог взбейте с йогуртом и сахаром.",
          "Растворите желатин по инструкции и вмешайте в массу.",
          "Разлейте по формочкам и охладите 2 часа."],
         ["Blend the cottage cheese with yogurt and sugar.",
          "Dissolve gelatin according to the package and fold in.",
          "Divide into molds and chill for 2 hours."]),
        ("Запечённая тыква с мёдом", "Baked pumpkin with honey", 35,
         [("pumpkin", 250), ("honey", 25), ("cinnamon", 2),
          ("butter", 10)],
         ["Тыкву нарежьте ломтиками, выложите в форму.",
          "Полейте мёдом, посыпьте корицей, добавьте кусочек масла.",
          "Запекайте 25–30 минут при 190 °C."],
         ["Slice the pumpkin and place in a dish.",
          "Drizzle with honey, sprinkle with cinnamon, dot with butter.",
          "Bake at 190 °C for 25–30 minutes."]),
    ]
    for ru, en, minutes, ings, sru, sen in items:
        ings = [(k, g) for k, g in ings if g > 0]
        if ru.startswith("Творожный десерт"):
            ings.append(("chocolate", 10))
        servings = 6 if ru.startswith("Шарлотка") else (
            3 if ru.startswith("Шоколадный мусс") else (
            4 if ru.startswith("Овсяное печенье") else 1))
        out.append(draft("dessert", ru, en, minutes, servings, ings,
                         sru, sen))
    return out


def build_cold():
    return salads() + snacks() + desserts()
