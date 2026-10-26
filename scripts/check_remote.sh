#!/usr/bin/env bash
# Правило №1: перед любой работой сверить локальный HEAD с origin/main.
# Remote может уйти вперёд после сброса песочницы (кейс 8c84566 «Create codeql.yml»).
set -e
cd "$(dirname "$0")/.."
echo "=== check_remote: $(date -u +%Y-%m-%dT%H:%M:%SZ) ==="
git fetch origin --prune 2>&1
LOCAL=$(git rev-parse HEAD)
REMOTE=$(git rev-parse origin/main)
echo "local  HEAD: $LOCAL"
echo "origin/main: $REMOTE"
if [ "$LOCAL" = "$REMOTE" ]; then
  echo "RESULT: OK — локальный HEAD совпадает с origin/main"
  exit 0
fi
BEHIND=$(git rev-list --count HEAD..origin/main)
AHEAD=$(git rev-list --count origin/main..HEAD)
echo "RESULT: DIVERGED — local behind=$BEHIND ahead=$AHEAD"
exit 1
