#!/usr/bin/env bash
# check_remote.sh — ДВА НЕИЗБЫТОЧНЫХ ПРАВИЛА перед любой работой.
#
# ПРАВИЛО №1: сверка локального HEAD с origin/main (ПЕРЕД работой).
#   Remote может уйти вперёд после сброса песочницы
#   (реальный кейс: 8c84566 «Create codeql.yml» — обнаружен лишь по отказу push).
#
# ПРАВИЛО №2: коммиты ТОЛЬКО от владельца репо (rvmxl), не от системного
#   пользователя контейнера (z / Z User). Гард проверяет git config и
#   чинит на месте; при неверной идентичности в уже существующих коммитах —
#   см. rewrite через git filter-branch (кейс 2026-10-28, 5 коммитов).
#
# Запуск: bash scripts/check_remote.sh   (из любой директории)
set -u

EXPECTED_NAME="rvmxl"
EXPECTED_EMAIL="rvmxl@users.noreply.github.com"

# --- найти корень репо независимо от CWD ---
if [ -d "/home/z/my-project/smart_fridge_chef/.git" ]; then
    PROJECT="/home/z/my-project/smart_fridge_chef"
elif [ -d "$(pwd)/.git" ] && [ -f "$(pwd)/pubspec.yaml" ]; then
    PROJECT="$(pwd)"
else
    echo "НЕТ РЕПО — сначала восстанови из бэкапа:"
    echo "  tar -xf /home/sync/smart-fridge-repo.tar -C /home/z/my-project"
    echo "затем перезапусти эту проверку (remote мог уйти вперёд тарбола!)"
    exit 2
fi
cd "$PROJECT"

# --- ПРАВИЛО №2: идентичность коммитов (авточинка) ---
LOCAL_NAME=$(git config user.name  || true)
LOCAL_EMAIL=$(git config user.email || true)
if [ "$LOCAL_NAME" != "$EXPECTED_NAME" ] || [ "$LOCAL_EMAIL" != "$EXPECTED_EMAIL" ]; then
    echo "ПРАВИЛО №2: identity неверна («$LOCAL_NAME» <$LOCAL_EMAIL>) —"
    git config user.name  "$EXPECTED_NAME"
    git config user.email "$EXPECTED_EMAIL"
    echo "  исправлено на $EXPECTED_NAME <$EXPECTED_EMAIL> (local git config)"
fi

# --- ПРАВИЛО №1: сверка с remote ---
git fetch origin --tags --prune >/dev/null 2>&1 || { echo "FETCH FAILED — проверь сеть/токен"; exit 2; }

AHEAD=$(git rev-list --count origin/main..HEAD)
BEHIND=$(git rev-list --count HEAD..origin/main)
DIRTY=$(git status --porcelain | wc -l)

echo "local  HEAD : $(git log -1 --format='%h %an: %s' | head -c 100)"
echo "origin/main : $(git log -1 --format='%h %an: %s' origin/main | head -c 100)"
echo "расхождение : вперёд на $AHEAD, отстаём на $BEHIND; незакоммиченных файлов: $DIRTY"

if   [ "$BEHIND" -gt 0 ] && [ "$AHEAD" -eq 0 ]; then
    echo "==> remote вперёд: git pull --rebase ПЕРЕД работой"; exit 1
elif [ "$AHEAD" -gt 0 ] && [ "$BEHIND" -gt 0 ]; then
    echo "==> ветки разошлись: git pull --rebase, реши конфликты, потом работай"; exit 1
elif [ "$AHEAD" -gt 0 ]; then
    echo "==> есть незапушенные коммиты: git push origin main"; exit 0
elif [ "$DIRTY" -gt 0 ]; then
    echo "==> дерево грязное: закоммить/убери изменения перед новой задачей"; exit 1
else
    echo "OK: синхронизировано, identity верна — можно работать"
    exit 0
fi
