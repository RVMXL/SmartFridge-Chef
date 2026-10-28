#!/usr/bin/env python3
"""Обогащение assets/data/recipes.json флагами религиозных диет (v0.4.3).

Добавляет в flags каждого рецепта 5 булевых полей (идемпотентно —
пересчитываются с нуля при каждом запуске):

  has_pork      — свинина и производные (бекон/сало/ветчина/салями...)
  has_alcohol   — алкоголь (вино/пиво/коньяк...; в базе пока 0 рецептов)
  has_beef      — говядина/телятина (включая говяжий фарш)
  has_shellfish — морепродукты без плавников и чешуи (креветки, кальмары...)
  has_dairy     — молочные продукты (в т.ч. кладовое сливочное масло)

Использование фильтрами планера:
  halal  → исключить has_pork || has_alcohol
  kosher → исключить has_pork || has_alcohol || has_shellfish
           || (has_meat && has_dairy)          — Mixing meat and dairy
  hindu  → исключить has_beef

Система координат совпадает с scripts/fix_recipe_allergens.py: тот же
компактный JSON (separators=(',',':')), та же защита от регрессий —
после патча печатаются нарушения, выход с кодом 1 при проблемах.

ВАЖНО (осознанные решения):
  - peanut_butter НЕ молочное (арахисовая паста), margarine тоже;
  - crab_sticks (крабовые палочки) НЕ shellfish — это сурими из рыбы;
  - желатина в базе нет; при появлении ключа gelatin скрипт сообщит
    о нём в разделе «подозрительные ключи» (добавить руками в PORK_KEYS
    либо завести отдельный флаг — решит автор);
  - рыбные ключи в has_meat не попадают (рыба парве для кошера,
    халяль её разрешает целиком).

Запуск:  python3 scripts/enrich_recipe_diet_flags.py
"""
import json
import re
import sys

PATH = '/home/z/my-project/smart_fridge_chef/assets/data/recipes.json'

# --- ключи-триггеры (надмножества того, что реально есть в базе) ---------
PORK_KEYS = {
    'pork', 'bacon', 'lard', 'ham', 'salami', 'prosciutto', 'chorizo',
    'pancetta', 'jamon', 'speck', 'gelatin',  # желатин чаще свиной
}
ALCOHOL_KEYS = {
    'wine', 'white_wine', 'red_wine', 'beer', 'cognac', 'rum', 'brandy',
    'vodka', 'champagne', 'whiskey', 'liquor', 'sake', 'tequila',
    'mulled_wine',
}
BEEF_KEYS = {'beef', 'minced_beef', 'veal'}
# крабовые палочки сознательно НЕ здесь (сурими = белая рыба)
SHELLFISH_KEYS = {
    'shrimp', 'prawns', 'squid', 'crab', 'mussels', 'oysters', 'octopus',
    'scallops', 'lobster', 'clams', 'crayfish',
}
DAIRY_KEYS = {
    'milk', 'kefir', 'cream', 'sour_cream', 'butter', 'cheese',
    'cottage_cheese', 'yogurt', 'condensed_milk', 'ryazhenka', 'varenets',
}

# Сеть безопасности: маски «подозрительных» имён, которые не попали ни в
# один набор выше. Скрипт не флагает их сам, но кричит в stdout.
SUSPICIOUS_RX = re.compile(
    r'pork|bacon|lard|ham|salami|gelatin|wine|beer|cognac|rum|vodka|'
    r'alcohol|beef|veal|shrimp|crab|mussel|squid|oyster|lobster|milk|'
    r'cheese|cream|butter|kefir|yogurt|tvorog|smetana',
    re.IGNORECASE,
)


def recipe_keys(r):
    return {ing['key'] for ing in r.get('ingredients', [])}


def main():
    with open(PATH, encoding='utf-8') as f:
        data = json.load(f)
    recipes = data['recipes']

    counted = set(PORK_KEYS | ALCOHOL_KEYS | BEEF_KEYS | SHELLFISH_KEYS
                  | DAIRY_KEYS)

    stats = {'has_pork': 0, 'has_alcohol': 0, 'has_beef': 0,
             'has_shellfish': 0, 'has_dairy': 0}
    kosher_extra = 0   # meat∧dairy без прочих триггеров
    diet_counts = {'halal': 0, 'kosher': 0, 'hindu': 0}

    for r in recipes:
        keys = recipe_keys(r)
        flags = r.setdefault('flags', {})
        pork = bool(keys & PORK_KEYS)
        alcohol = bool(keys & ALCOHOL_KEYS)
        beef = bool(keys & BEEF_KEYS)
        shellfish = bool(keys & SHELLFISH_KEYS)
        dairy = bool(keys & DAIRY_KEYS)
        flags['has_pork'] = pork
        flags['has_alcohol'] = alcohol
        flags['has_beef'] = beef
        flags['has_shellfish'] = shellfish
        flags['has_dairy'] = dairy

        stats['has_pork'] += pork
        stats['has_alcohol'] += alcohol
        stats['has_beef'] += beef
        stats['has_shellfish'] += shellfish
        stats['has_dairy'] += dairy

        halal = pork or alcohol
        kosher = pork or alcohol or shellfish or \
            (flags.get('has_meat') and dairy)
        hindu = beef
        diet_counts['halal'] += halal
        diet_counts['kosher'] += kosher
        diet_counts['hindu'] += hindu
        if kosher and not (pork or alcohol or shellfish):
            kosher_extra += 1

    # --- сеть безопасности: подозрительные ключи вне известных наборов ----
    suspicious = {}
    for r in recipes:
        for k in recipe_keys(r):
            if k in counted:
                continue
            if SUSPICIOUS_RX.search(k):
                suspicious.setdefault(k, 0)
                suspicious[k] += 1

    with open(PATH, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, separators=(',', ':'))
    f_count = data.get('count')
    assert f_count == len(recipes), 'count рассинхронизировался'

    print(f'Рецептов: {len(recipes)} (count={f_count})')
    print('\nФлаги:')
    for k, v in stats.items():
        print(f'  {k:14s}: {v}')
    print('\nИсключается по диетам:')
    for k, v in diet_counts.items():
        print(f'  {k:8s}: {v} ({100.0 * v / len(recipes):.1f}%)')
    print(f'  (кошер: {kosher_extra} рецептов только из-за мясо+молоко)')

    if suspicious:
        print('\n!! ПОДОЗРИТЕЛЬНЫЕ ключи вне известных наборов '
              '(проверить руками):')
        for k, c in sorted(suspicious.items()):
            print(f'  {k}: {c} рецептов')
    else:
        print('\nПодозрительных ключей вне наборов: нет')

    # --- самопроверки (нужны до Dart-инварианта) --------------------------
    problems = []
    for r in recipes:
        keys = recipe_keys(r)
        fl = r['flags']
        if fl.get('has_pork') and not fl.get('has_meat'):
            problems.append(f"{r['id']}: has_pork без has_meat")
        if fl.get('has_beef') and not fl.get('has_meat'):
            problems.append(f"{r['id']}: has_beef без has_meat")
        if fl.get('has_dairy'):
            allerg = set(r.get('allergens', []))
            if 'milk' not in allerg:
                problems.append(f"{r['id']}: has_dairy без аллергена milk")
        if fl.get('has_shellfish'):
            allerg = set(r.get('allergens', []))
            if 'shellfish' not in allerg:
                problems.append(
                    f"{r['id']}: has_shellfish без аллергена shellfish")
    if problems:
        print(f'\n!! НАРУШЕНИЯ согласованности ({len(problems)}):')
        for p in problems:
            print(f'  {p}')
        sys.exit(1)
    print('\nСогласованность флагов с has_meat/аллергенами: OK')


if __name__ == '__main__':
    main()
