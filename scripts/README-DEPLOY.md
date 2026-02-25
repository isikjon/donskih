# Деплой на сервер

Среда Cursor не имеет доступа по SSH к твоему серверу, поэтому деплой нужно запускать **со своего компьютера** (где настроен доступ к `185.23.35.66`).

## Одной командой

Из корня проекта (на своём Mac):

```bash
cd /Users/shamsiddintadjiddinov40gmail.com/Desktop/donskih
make deploy
```

Скрипт:
1. Соберёт веб (`flutter build web`), если ещё не собран.
2. Загрузит бэкенд в `/opt/donskih-api/` (без перезаписи `.env`).
3. Загрузит `build/web/` в `/var/www/donskih-admin/`.
4. Добавит в `.env` на сервере `ADMIN_SECRET_KEY` (если его ещё нет) и выведет ключ в конец.
5. Выполнит миграции и перезапустит API (`docker compose down && docker compose up -d`).

## Если нужен свой хост или пользователь

```bash
DEPLOY_SERVER=185.23.35.66 DEPLOY_SSH_USER=root make deploy
```

Или задать свой ключ админки (чтобы не генерировался случайный):

```bash
ADMIN_SECRET_KEY=мой_секретный_ключ make deploy
```

## После деплоя

- **API:** проверка — `curl -s https://donskih-cdn.ru/api/v1/health`
- **Админка:** открыть в браузере `https://donskih-cdn.ru/admin` (если nginx отдаёт `/var/www/donskih-admin` по пути `/admin`).

Если nginx ещё не настроен для админки, добавь в конфиг (пример):

```nginx
location /admin {
    alias /var/www/donskih-admin;
    try_files $uri $uri/ /admin/index.html;
}
```

И перезагрузи nginx: `sudo nginx -s reload`.
