#!/usr/bin/env python3
"""VER-1 (аудит 2026-10-28): версия одна — из pubspec.yaml.

Проверяет, что kAppVersion в lib/core/constants.dart совпадает с версией
до «+» в pubspec.yaml. Раньше три версии жили одновременно (UA «0.4»,
kAppVersion «0.5.9», pubspec 0.5.10) — CHANGELOG v0.5.8 фиксировал тот же
класс бага. Запускается локально и шагом CI; падение ломает сборку.
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

pubspec = (ROOT / 'pubspec.yaml').read_text()
m = re.search(r'^version:\s*(\d+\.\d+\.\d+)\+\d+\s*$', pubspec, re.M)
if not m:
    print('FAIL: не нашёл version: x.y.z+N в pubspec.yaml')
    sys.exit(1)
expected = m.group(1)

constants = (ROOT / 'lib/core/constants.dart').read_text()
m2 = re.search(r"kAppVersion\s*=\s*'([^']+)'", constants)
if not m2:
    print('FAIL: не нашёл kAppVersion в lib/core/constants.dart')
    sys.exit(1)
actual = m2.group(1)

if actual != expected:
    print(f'FAIL: kAppVersion = {actual}, pubspec = {expected}. '
          f'Синхронизируй lib/core/constants.dart с pubspec.yaml.')
    sys.exit(1)
print(f'OK: версия синхронна — {expected}')
