#!/usr/bin/env python3
"""Калибровка запрещённых списков столов Певзнера по базе recipes.json.

Для каждого стола печатает: сколько рецептов остаётся после жёсткого
фильтра и какие рецепты-примеры исключаются. Цель: у каждого стола
остаток >= 60 рецептов (недельному планеру нужен запас), иначе список
запретов сужается. Ключи, не встречающиеся в базе, сигнализируются.
"""
import json
import sys

RECIPE = '/home/z/my-project/smart_fridge_chef/assets/data/recipes.json'

# Черновик списков (v1) — переносится в medical_diet.dart после калибровки.
TABLES = {
    1: 'pork cabbage mushroom beans split_peas lentils chickpeas mayo '
       'chocolate pearl_barley barley_cooked pickles',
    2: 'pork cabbage mushroom beans split_peas lentils chickpeas mayo '
       'pickles pearl_barley barley_cooked',
    3: 'rice semolina chocolate',
    4: 'milk cream cheese mayo pork mushroom beans split_peas lentils '
       'chickpeas cabbage onion garlic spinach beetroot bell_pepper greens '
       'bread pickles vinegar soy_sauce almond walnut peanut_butter '
       'chocolate honey jam raisins olives avocado herbs_dried spices '
       'pepper bay_leaf cinnamon mustard cucumber tomato lettuce',
    5: 'pork chicken_liver beans split_peas lentils chickpeas mushroom '
       'pickles vinegar garlic chocolate mayo spinach cream',
    6: 'pork beef minced_beef chicken_liver mushroom beans split_peas '
       'lentils chickpeas chocolate shrimp squid',
    7: 'pickles mushroom chocolate cheese beans split_peas lentils '
       'chickpeas garlic mayo',
    8: 'sugar jam honey chocolate mayo pasta pork cream banana raisins '
       'peanut_butter',
    9: 'sugar jam honey chocolate banana raisins',
    10: 'pickles chocolate garlic mustard pork chicken_liver mayo beans '
        'split_peas lentils chickpeas',
    11: '',
    12: 'garlic pepper mustard chocolate spices',
    13: 'pork cream mayo beans split_peas lentils chickpeas cabbage '
        'mushroom bread cheese spices pepper garlic mustard pickles '
        'chocolate berries cherry plum',
    14: 'milk cheese cottage_cheese sour_cream cream yogurt kefir butter '
        'potato carrot beetroot cabbage cucumber pumpkin zucchini spinach '
        'lettuce greens tomato bell_pepper onion garlic avocado apple pear '
        'banana orange lemon berries cherry plum jam honey mushroom beans '
        'split_peas lentils chickpeas broccoli cauliflower celery olives '
        'pickles',
    15: '',
}

with open(RECIPE, encoding='utf-8') as f:
    data = json.load(f)
recipes = data['recipes'] if isinstance(data, dict) else data

known = set()
ru = {}
for r in recipes:
    for i in r['ingredients']:
        known.add(i['key'])
        ru[i['key']] = i['ru']

print(f'Рецептов в базе: {len(recipes)}, уникальных ключей: {len(known)}\n')

bad = False
for n in range(1, 16):
    forb = set(TABLES[n].split())
    unknown = forb - known
    if unknown:
        print(f'!! стол {n}: ключей нет в базе: {sorted(unknown)}')
        bad = True
        forb -= unknown
    kept = [r for r in recipes
            if not any(i['key'] in forb for i in r['ingredients'])]
    excl = len(recipes) - len(kept)
    examples = [r['title']['ru'] for r in recipes
                if any(i['key'] in forb for i in r['ingredients'])][:3]
    flag = 'OK ' if len(kept) >= 60 else ('!!! МАЛО' if n not in (11, 15)
                                          else '(без запретов)')
    print(f'стол {n:2}: осталось {len(kept):3}/541 (исключено {excl:3}) '
          f'{flag}  примеры: {"; ".join(examples) or "-"}')

sys.exit(1 if bad else 0)
