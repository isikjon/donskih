#!/usr/bin/env bash
# Обновление на сервере через git (запускать НА СЕРВЕРЕ после setup-git-on-server.sh).
# Можно положить в /opt/donskih/ и вызывать: /opt/donskih/server-update.sh

set -e
cd /opt/donskih
git pull origin main || git pull origin master
cd /opt/donskih-api
docker compose up -d --build
echo "Готово."
