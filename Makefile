.PHONY: up down restart logs

COMPOSE=docker compose -f docker-compose.yml -f compose-grandine.yml

up:
	$(COMPOSE) up -d

down:
	$(COMPOSE) down

restart: down up

logs:
	$(COMPOSE) logs -f