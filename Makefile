# Деплой бэкенда и веб-админки на сервер.
# Запускай с машины, с которой есть SSH до root@185.23.35.66:
#   make deploy
# Или с своим хостом/ключом:
#   DEPLOY_SERVER=185.23.35.66 DEPLOY_SSH_USER=root make deploy
.PHONY: deploy build-web

build-web:
	flutter build web --base-href /admin/

deploy: build-web
	./scripts/deploy.sh
