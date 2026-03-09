#!/usr/bin/env bash
# Настройка Git на сервере для деплоя через git pull.
# Запускать НА СЕРВЕРЕ (или через: ssh donskih 'bash -s' < scripts/setup-git-on-server.sh)
#
# Что делает:
# 1. Сохраняет .env из текущего /opt/donskih-api
# 2. Клонирует репо в /opt/donskih (если ещё нет) или делает git pull
# 3. Подкладывает .env в backend
# 4. Заменяет /opt/donskih-api на симлинк на /opt/donskih/backend
# 5. Запускает docker compose из /opt/donskih-api (т.е. из backend)

set -e
REPO_URL="${REPO_URL:-https://github.com/isikjon/donskih.git}"
OPT_DONSKIH="/opt/donskih"
OPT_API="/opt/donskih-api"
ENV_BACKUP="/tmp/donskih-api.env.bak"

echo "=== 1. Сохраняем .env ==="
if [[ -f "$OPT_API/.env" ]]; then
  cp "$OPT_API/.env" "$ENV_BACKUP"
  echo "Сохранено в $ENV_BACKUP"
else
  echo ".env не найден, пропускаем"
fi

echo "=== 2. Клонируем или обновляем репозиторий ==="
if [[ -d "$OPT_DONSKIH/.git" ]]; then
  cd "$OPT_DONSKIH"
  git fetch origin
  git pull origin main || git pull origin master || true
  echo "Репозиторий обновлён"
else
  cd /opt
  if [[ -d "$OPT_DONSKIH" ]]; then
    echo "Папка $OPT_DONSKIH есть, но не репо — переименуем в .bak и клонируем заново"
    mv "$OPT_DONSKIH" "${OPT_DONSKIH}.bak"
  fi
  git clone "$REPO_URL" donskih
  echo "Клонировано в $OPT_DONSKIH"
fi

echo "=== 3. Восстанавливаем .env в backend ==="
if [[ -f "$ENV_BACKUP" ]]; then
  cp "$ENV_BACKUP" "$OPT_DONSKIH/backend/.env"
  echo ".env скопирован в $OPT_DONSKIH/backend/"
fi

echo "=== 4. Симлинк /opt/donskih-api -> backend ==="
if [[ -L "$OPT_API" ]]; then
  rm -f "$OPT_API"
elif [[ -d "$OPT_API" ]]; then
  echo "Старую папку $OPT_API переименуем в ${OPT_API}.old"
  rm -rf "${OPT_API}.old"
  mv "$OPT_API" "${OPT_API}.old"
fi
ln -sfn "$OPT_DONSKIH/backend" "$OPT_API"
echo "Создан симлинк: $OPT_API -> $OPT_DONSKIH/backend"

echo "=== 5. Запуск контейнеров ==="
cd "$OPT_API"
docker compose up -d --build

echo ""
echo "Готово. Дальше для обновления на сервере:"
echo "  cd /opt/donskih && git pull origin main && cd /opt/donskih-api && docker compose up -d --build"
echo ""
echo "Если репозиторий приватный — настрой на сервере SSH ключ или HTTPS токен для git."
