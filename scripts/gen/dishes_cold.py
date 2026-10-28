# -*- coding: utf-8 -*-
"""Салаты, перекусы и десерты."""

from helpers import draft


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
            sru = ["Овощи нарежьте, крупные ингредиенты — кубиками.",
                   "Отварите добавку, если требуется (яйцо, курица, овощи).",
                   "Смешайте всё в салатнике, заправьте маслом или сметаной, "
                   "посолите и поперчите."]
            sen = ["Chop the vegetables; dice the larger ingredients.",
                   "Cook the add-in if needed (egg, chicken, vegetables).",
                   "Toss everything in a bowl, dress with oil or sour cream, "
                   "season with salt and pepper."]
            family = add_ings[0][0] if add_ings else base_ings[0][0]
            minutes = 15 if add_key in ("none", "cheese", "walnut",
                                        "apple", "pickles") else 25
            out.append(draft("salad", ru, en, minutes, 2, ings, sru, sen,
                             family=family))
    return out


def snacks():
    out = []
    items = [
        ("Творог с ягодами", "Cottage cheese with berries",
         [("cottage_cheese", 120), ("berries", 80), ("honey", 10)], 5),
        ("Йогурт с бананом и орехами", "Yogurt with banana and nuts",
         [("yogurt", 150), ("banana", 80), ("walnut", 15)], 5),
        ("Яблоко с арахисовой пастой", "Apple with peanut butter",
         [("apple", 150), ("peanut_butter", 20)], 5),
        ("Тост с авокадо", "Avocado toast",
         [("bread", 70), ("avocado", 60), ("lemon", 5), ("salt", 1)], 7),
        ("Яйца с овощной нарезкой", "Boiled eggs with vegetable sticks",
         [("egg", 120), ("cucumber", 80), ("carrot", 80)], 12),
        ("Хумус с морковью", "Hummus with carrot sticks",
         [("chickpeas", 120), ("olive_oil", 15), ("lemon", 20),
          ("garlic", 4), ("carrot", 100)], 15),
        ("Ореховая смесь с сухофруктами", "Nut and raisin mix",
         [("walnut", 20), ("almond", 20), ("raisins", 25)], 2),
        ("Банан с шоколадом", "Banana with chocolate",
         [("banana", 120), ("chocolate", 20)], 5),
        ("Ягоды со сливками", "Berries with cream",
         [("berries", 120), ("cream", 60)], 5),
        ("Ягодный смузи", "Berry smoothie",
         [("berries", 100), ("banana", 60), ("milk", 150)], 5),
        ("Банановый смузи с овсянкой", "Banana oat smoothie",
         [("banana", 100), ("oat_flakes", 20), ("milk", 150),
          ("honey", 10)], 5),
        ("Морковные палочки с йогуртовым соусом",
         "Carrot sticks with yogurt dip",
         [("carrot", 120), ("yogurt", 80), ("garlic", 3),
          ("greens", 5)], 8),
        ("Груша с сыром", "Pear with cheese",
         [("pear", 150), ("cheese", 40)], 5),
        ("Кефир с ягодами", "Kefir with berries",
         [("kefir", 250), ("berries", 60)], 3),
    ]
    for ru, en, ings, minutes in items:
        out.append(draft(
            "snack", ru, en, minutes, 1, ings,
            ["Подготовьте ингредиенты: промойте, нарежьте или смешайте.",
             "Подавайте сразу или упакуйте с собой."],
            ["Prep the ingredients: rinse, slice or mix.",
             "Serve right away or pack for later."]))
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
