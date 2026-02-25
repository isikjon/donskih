.PHONY: run test lint migrate build up down logs

build:
	docker compose build

up:
	docker compose up -d

down:
	docker compose down

logs:
	docker compose logs -f api

run:
	docker compose up --build

migrate:
	docker compose exec api alembic upgrade head

migration:
	docker compose exec api alembic revision --autogenerate -m "$(msg)"

test:
	docker compose exec api pytest tests/ -v

lint:
	docker compose exec api python -m py_compile app/main.py

shell:
	docker compose exec api python -c "import app; print('OK')"

health:
	curl -s http://localhost:8000/health | python3 -m json.tool
