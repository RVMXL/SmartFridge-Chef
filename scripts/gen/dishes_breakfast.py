# -*- coding: utf-8 -*-
"""Завтраки: каши, омлеты, творожное, блины, тосты и смузи."""

from helpers import draft


def porridges():
    """Каши: 6 баз x 12 добавок."""
    bases = [
        ("Овсянка на молоке", "Oatmeal with milk", "milk porridge",
         [("oat_flakes", 50), ("milk", 200), ("butter", 5), ("sugar", 5)],
         15,
         "Вскипятите молоко, всыпьте хлопья и варите 5–7 минут, помешивая.",
         "Bring the milk to a boil, stir in the oats and cook for 5–7 "
         "minutes, stirring."),
        ("Овсянка на воде", "Oatmeal with water", "water porridge",
         [("oat_flakes", 55), ("butter", 5), ("sugar", 5)],
         15,
         "Вскипятите воду, всыпьте хлопья и варите 5–7 минут, помешивая.",
         "Bring the water to a boil, stir in the oats and cook for 5–7 "
         "minutes, stirring."),
        ("Манная каша", "Semolina porridge", "semolina porridge",
         [("semolina", 40), ("milk", 250), ("sugar", 8), ("butter", 5)],
         20,
         "Вскипятите молоко, тонкой струйкой всыпьте манку, помешивая, и "
         "варите 4–5 минут. Дайте настояться под крышкой.",
         "Bring the milk to a boil, whisk in the semolina in a thin stream "
         "and cook for 4–5 minutes. Let it rest, covered."),
        ("Пшённая каша", "Millet porridge", "millet porridge",
         [("millet", 50), ("milk", 150), ("sugar", 8), ("butter", 5)],
         30,
         "Промойте пшено, залейте молоком с водой и варите на слабом огне "
         "20–25 минут под крышкой.",
         "Rinse the millet, cover with milk and water and simmer, covered, "
         "for 20–25 minutes."),
        ("Рисовая каша", "Rice porridge", "rice porridge",
         [("rice", 60), ("milk", 200), ("sugar", 5), ("butter", 5)],
         30,
         "Промойте рис, залейте молоком с водой и варите на слабом огне "
         "20–25 минут до мягкости.",
         "Rinse the rice, cover with milk and water and simmer for 20–25 "
         "minutes until soft."),
        ("Гречка с молоком", "Buckwheat with milk", "buckwheat with milk",
         [("buckwheat", 60), ("milk", 200), ("butter", 5)],
         20,
         "Отварите гречку в подсоленной воде до готовности.",
         "Cook the buckwheat in salted water until tender."),
    ]
    addins = [
        ("с бананом и мёдом", "with banana and honey",
         [("banana", 80), ("honey", 15)]),
        ("с яблоком и корицей", "with apple and cinnamon",
         [("apple", 100), ("cinnamon", 1)]),
        ("с ягодами и мёдом", "with berries and honey",
         [("berries", 80), ("honey", 15)]),
        ("с грушей и мёдом", "with pear and honey",
         [("pear", 100), ("honey", 15)]),
        ("с изюмом и орехами", "with raisins and walnuts",
         [("raisins", 25), ("walnut", 15)]),
        ("с вареньем", "with jam", [("jam", 30)]),
        ("с шоколадом", "with chocolate", [("chocolate", 20)]),
        ("с миндалём и мёдом", "with almonds and honey",
         [("almond", 20), ("honey", 15)]),
        ("со сливой", "with plums", [("plum", 100)]),
        ("с вишней", "with cherries", [("cherry", 100)]),
        ("с апельсином и мёдом", "with orange and honey",
         [("orange", 100), ("honey", 15)]),
        ("с тыквой и мёдом", "with pumpkin and honey",
         [("pumpkin", 100), ("honey", 15)]),
    ]
    out = []
    for base_ru, base_en, base_en_short, base_ings, minutes, step_ru, step_en \
            in bases:
        for add_ru, add_en, add_ings in addins:
            if "мёдом" in add_ru and "воде" in base_ru and \
                    add_ru == "с апельсином и мёдом":
                pass  # веганские варианты не выбрасываем — флаги сами решат
            ings = base_ings + add_ings + [("salt", 1)]
            ru = f"{base_ru} {add_ru}"
            en = f"{base_en} {add_en}"
            fruit = add_ings[0][0]
            steps_ru = [step_ru,
                        "Готовую кашу разложите по тарелкам.",
                        f"Добавьте топпинг и подавайте тёплой."]
            steps_en = [step_en,
                        "Divide the porridge between bowls.",
                        "Top with the add-ins and serve warm."]
            out.append(draft("breakfast", ru, en, minutes, 1, ings,
                             steps_ru, steps_en, family=fruit))
    return out


def egg_dishes():
    """Омлеты, яичница, шакшука."""
    fillings = [
        ("с сыром", "with cheese", [("cheese", 30)]),
        ("с помидорами", "with tomatoes", [("tomato", 60)]),
        ("с шампиньонами", "with mushrooms", [("mushroom", 60)]),
        ("с зеленью", "with fresh herbs", [("greens", 15)]),
        ("со шпинатом", "with spinach", [("spinach", 60)]),
        ("с болгарским перцем", "with bell pepper", [("bell_pepper", 60)]),
        ("с сыром и помидорами", "with cheese and tomatoes",
         [("cheese", 30), ("tomato", 60)]),
        ("овощной", "vegetable omelette",
         [("zucchini", 60), ("bell_pepper", 40)]),
        ("с кукурузой", "with corn", [("corn", 50)]),
        ("с зелёным горошком", "with green peas", [("green_peas", 50)]),
        ("с творогом", "with cottage cheese", [("cottage_cheese", 50)]),
    ]
    out = []
    for add_ru, add_en, add_ings in fillings:
        ings = [("egg", 120), ("milk", 40), ("butter", 5)] + add_ings
        ings += [("salt", 1), ("pepper", 1)]
        filling = add_ings[0][0]
        out.append(draft(
            "breakfast", f"Омлет {add_ru}", f"Omelette {add_en}", 15, 1,
            ings,
            ["Яйца взбейте с молоком, солью и перцем.",
             "Начинку обжарьте на сливочном масле 2–3 минуты.",
             "Влейте яичную смесь и готовьте под крышкой на слабом огне "
             "5–7 минут до схватывания."],
            ["Whisk the eggs with milk, salt and pepper.",
             "Sauté the filling in butter for 2–3 minutes.",
             "Pour in the egg mixture and cook, covered, over low heat for "
             "5–7 minutes until set."],
            family=filling))
    out.append(draft(
        "breakfast", "Яичница с помидорами", "Fried eggs with tomatoes",
        12, 1,
        [("egg", 120), ("tomato", 80), ("butter", 5), ("salt", 1)],
        ["Помидоры нарежьте кружочками.",
         "Яйца разбейте на разогретую сковороду с маслом.",
         "Добавьте помидоры, посолите и жарьте 3–4 минуты до готовности "
         "белка."],
        ["Slice the tomatoes.",
         "Crack the eggs into a heated, buttered pan.",
         "Add the tomatoes, season with salt and fry for 3–4 minutes until "
         "the whites are set."]))
    out.append(draft(
        "breakfast", "Шакшука", "Shakshuka", 25, 2,
        [("egg", 240), ("tomato", 240), ("bell_pepper", 80), ("onion", 60),
         ("olive_oil", 15), ("garlic", 6), ("spices", 2), ("salt", 2)],
        ["Лук, перец и чеснок обжарьте в масле 5 минут.",
         "Добавьте нарезанные помидоры и специи, тушите 10 минут до "
         "загустения.",
         "Сделайте в соусе лунки, разбейте в них яйца.",
         "Накройте крышкой и готовьте 5–7 минут, пока белок не схватится."],
        ["Fry the onion, pepper and garlic in oil for 5 minutes.",
         "Add the chopped tomatoes and spices, simmer for 10 minutes until "
         "thickened.",
         "Make wells in the sauce and crack the eggs into them.",
         "Cover and cook for 5–7 minutes until the whites are set."]))
    return out


def curd_dishes():
    """Сырники, запеканки, творожные миски."""
    out = []
    syr_adds = [
        ("Классические сырники", "Classic syrniki", []),
        ("Сырники с изюмом", "Syrniki with raisins", [("raisins", 20)]),
        ("Сырники с бананом", "Syrniki with banana", [("banana", 60)]),
        ("Сырники с яблоком", "Syrniki with apple", [("apple", 60)]),
    ]
    for ru, en, extra in syr_adds:
        ings = ([("cottage_cheese", 120), ("egg", 30), ("flour", 25),
                 ("sugar", 10), ("sour_cream", 20), ("salt", 1)] + extra)
        extra_ru = f" с {extra[0][0] and ''}" if False else ""
        out.append(draft(
            "breakfast", ru, en, 20, 1, ings,
            ["Творог разомните вилкой, смешайте с яйцом, сахаром и мукой.",
             "Сформируйте сырники и обваляйте в муке.",
             "Обжарьте на сливочном масле по 2–3 минуты с каждой стороны "
             "до золотистой корочки.",
             "Подавайте со сметаной."],
            ["Mash the cottage cheese with a fork, mix with the egg, sugar "
             "and flour.",
             "Shape the syrniki and coat in flour.",
             "Fry in butter for 2–3 minutes per side until golden.",
             "Serve with sour cream."]))
    cas_adds = [
        ("Творожная запеканка", "Cottage cheese casserole", []),
        ("Творожная запеканка с яблоком", "Cottage cheese casserole "
         "with apple", [("apple", 80)]),
        ("Творожная запеканка с тыквой", "Cottage cheese casserole "
         "with pumpkin", [("pumpkin", 80)]),
        ("Творожная запеканка с изюмом", "Cottage cheese casserole "
         "with raisins", [("raisins", 25)]),
    ]
    for ru, en, extra in cas_adds:
        ings = ([("cottage_cheese", 130), ("egg", 30), ("semolina", 15),
                 ("sugar", 10), ("sour_cream", 15)] + extra)
        out.append(draft(
            "breakfast", ru, en, 40, 1, ings,
            ["Творог смешайте с яйцом, манкой и сахаром, добавьте добавку.",
             "Выложите массу в смазанную форму.",
             "Запекайте 30–35 минут при 180 °C до румяной верхушки.",
             "Дайте остыть 5 минут и нарежьте порционно."],
            ["Mix the cottage cheese with the egg, semolina and sugar; add "
             "the add-ins.",
             "Transfer to a greased baking dish.",
             "Bake at 180 °C for 30–35 minutes until golden on top.",
             "Rest for 5 minutes and slice."]))
    bowls = [
        ("Творог с ягодами и йогуртом", "Cottage cheese with berries and "
         "yogurt", [("berries", 80), ("yogurt", 60)]),
        ("Творог с бананом, мёдом и орехами", "Cottage cheese with banana, "
         "honey and walnuts", [("banana", 80), ("honey", 15),
                               ("walnut", 10)]),
    ]
    for ru, en, extra in bowls:
        ings = [("cottage_cheese", 130)] + extra
        out.append(draft(
            "breakfast", ru, en, 5, 1, ings,
            ["Творог выложите в миску и слегка разомните вилкой.",
             "Добавьте топпинги и перемешайте."],
            ["Place the cottage cheese in a bowl and lightly mash.",
             "Add the toppings and mix."]))
    return out


def pancakes_toasts():
    """Блины, оладьи, тосты, мюсли-боулы."""
    out = []
    items = [
        ("Блины на кефире", "Kefir pancakes",
         [("flour", 60), ("egg", 30), ("kefir", 120), ("sugar", 10),
          ("salt", 1), ("vegetable_oil", 10)],
         30, 1,
         ["Взбейте яйцо с сахаром и солью, влейте кефир.",
          "Всыпьте муку и замесите жидкое тесто без комков.",
          "Выпекайте тонкие блины на разогретой сковороде по 1–2 минуты "
          "с каждой стороны.",
          "Подавайте с вареньем или сметаной."],
         ["Whisk the egg with sugar and salt, pour in the kefir.",
          "Stir in the flour until smooth.",
          "Cook thin pancakes on a hot pan, 1–2 minutes per side.",
          "Serve with jam or sour cream."]),
        ("Блины на молоке", "Milk pancakes",
         [("flour", 60), ("egg", 30), ("milk", 120), ("sugar", 10),
          ("salt", 1), ("vegetable_oil", 10)],
         30, 1,
         ["Взбейте яйцо с сахаром, влейте молоко.",
          "Всыпьте муку и размешайте до однородности.",
          "Жарьте блины на смазанной сковороде с двух сторон.",
          "Подавайте с любимой начинкой."],
         ["Whisk the egg with sugar, pour in the milk.",
          "Stir in the flour until smooth.",
          "Cook the pancakes on a greased pan on both sides.",
          "Serve with your favourite filling."]),
        ("Оладьи на кефире", "Kefir fritters",
         [("flour", 50), ("kefir", 100), ("egg", 30), ("sugar", 10),
          ("baking_powder", 2), ("vegetable_oil", 10)],
         25, 1,
         ["Смешайте кефир с яйцом, сахаром и разрыхлителем.",
          "Всыпьте муку — тесто должно быть густым.",
          "Выкладывайте ложкой на разогретую сковороду и жарьте по 2 минуты "
          "с каждой стороны под крышкой."],
         ["Mix the kefir with the egg, sugar and baking powder.",
          "Stir in the flour — the batter should be thick.",
          "Drop spoonfuls onto a hot pan and fry 2 minutes per side, "
          "covered."]),
        ("Оладьи с яблоком", "Apple fritters",
         [("flour", 50), ("apple", 70), ("kefir", 100), ("egg", 30),
          ("sugar", 10), ("cinnamon", 1), ("baking_powder", 2),
          ("vegetable_oil", 10)],
         25, 1,
         ["Яблоко натрите на тёрке.",
          "Смешайте все ингредиенты в густое тесто.",
          "Жарьте оладьи по 2 минуты с каждой стороны."],
         ["Grate the apple.",
          "Mix everything into a thick batter.",
          "Fry the fritters for 2 minutes per side."]),
        ("Банановые панкейки", "Banana pancakes",
         [("banana", 80), ("egg", 60), ("oat_flakes", 30), ("flour", 20),
          ("baking_powder", 2), ("vegetable_oil", 5)],
         20, 1,
         ["Банан разомните вилкой в пюре.",
          "Смешайте с яйцом, хлопьями и мукой; дайте постоять 5 минут.",
          "Обжаривайте маленькие панкейки на разогретой сковороде с маслом "
          "по 1–2 минуты с каждой стороны."],
         ["Mash the banana with a fork.",
          "Mix with the egg, oats and flour; let rest for 5 minutes.",
          "Fry small pancakes in a lightly oiled pan for 1–2 minutes "
          "per side."]),
        ("Оладьи из кабачков", "Zucchini fritters",
         [("zucchini", 120), ("egg", 60), ("flour", 30), ("garlic", 4),
          ("salt", 2), ("vegetable_oil", 10)],
         25, 1,
         ["Кабачок натрите и отожмите лишний сок.",
          "Смешайте с яйцами, мукой, чесноком и солью.",
          "Жарьте оладьи по 2–3 минуты с каждой стороны до румяности."],
         ["Grate the zucchini and squeeze out the excess juice.",
          "Mix with the eggs, flour, garlic and salt.",
          "Fry the fritters for 2–3 minutes per side until golden."]),
    ]
    for ru, en, ings, minutes, servings, sru, sen in items:
        out.append(draft("breakfast", ru, en, minutes, servings, ings,
                         sru, sen))
    toasts = [
        ("Тост с сыром и помидором", "Toast with cheese and tomato",
         [("bread", 70), ("cheese", 30), ("tomato", 40), ("butter", 5)]),
        ("Тост с творогом и зеленью", "Toast with cottage cheese and herbs",
         [("bread", 70), ("cottage_cheese", 60), ("greens", 10),
          ("salt", 1)]),
        ("Тост с арахисовой пастой и бананом", "Toast with peanut butter "
         "and banana", [("bread", 70), ("peanut_butter", 20),
                        ("banana", 60)]),
        ("Тост с авокадо и яйцом", "Toast with avocado and egg",
         [("bread", 70), ("avocado", 50), ("egg", 60), ("lemon", 5),
          ("salt", 1)]),
        ("Тост с тунцом", "Toast with tuna",
         [("bread", 70), ("tuna_can", 50), ("mayo", 10), ("salt", 1)]),
    ]
    for ru, en, ings in toasts:
        out.append(draft(
            "breakfast", ru, en, 10, 1, ings,
            ["Хлеб подсушите в тостере или на сухой сковороде.",
             "Намажьте начинкой и подавайте сразу."],
            ["Toast the bread in a toaster or dry pan.",
             "Spread with the topping and serve right away."]))
    bowls = [
        ("Мюсли с йогуртом и бананом", "Muesli with yogurt and banana",
         [("oat_flakes", 40), ("yogurt", 150), ("banana", 60),
          ("walnut", 15), ("honey", 15)]),
        ("Смузи-боул с ягодами", "Berry smoothie bowl",
         [("berries", 80), ("banana", 80), ("oat_flakes", 25),
          ("milk", 100)]),
    ]
    for ru, en, ings in bowls:
        out.append(draft(
            "breakfast", ru, en, 8, 1, ings,
            ["Сложите ингредиенты в блендер и пробейте до однородности.",
             "Перелейте в миску и украсьте фруктами или орехами."],
            ["Blend everything until smooth.",
             "Pour into a bowl and top with fruit or nuts."]))
    return out


def build_breakfast():
    return (porridges() + egg_dishes() + curd_dishes() + pancakes_toasts())
