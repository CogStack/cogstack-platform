PROJECT = cogstack-jupyter-hub
CONTAINER_NAME = $(PROJECT)
CONTAINER_NAME_DEV= $(PROJECT)-dev
COMPOSE_BASE = docker-compose.base.yml
SHELL := /usr/bin/env bash
.SHELLFLAGS := -o pipefail -c

DC_START_CMD := up -d
DC_STOP_CMD := stop
DC_DOWN_CMD := down

define WITH_ENV
set -a && source ../export_env_vars.sh;
endef

.PHONY: up down restart build logs cert-check health-check


# utility commands

load-env:
	$(WITH_ENV) echo "Environment variables loaded."

show-env:
	${WITH_ENV} >/dev/null 2>&1; printenv | grep -E "^(JUPYTER)" | sort

logs-dev:
	docker logs -f --tail 10000 ${CONTAINER_NAME_DEV}

logs:
	docker logs -f --tail 10000 $(CONTAINER_NAME)

health-check:
	${WITH_ENV} curl -k -v https://localhost:${JUPYTERHUB_INTERNAL_PORT}/

# start services

start-dev:
	$(WITH_ENV) docker compose -f docker-compose.dev.yml $(DC_START_CMD)

start-dev-build:
	$(WITH_ENV) docker compose -f docker-compose.dev.yml ${DC_START_CMD} --build

start:
	$(WITH_ENV) docker compose -f $(COMPOSE_BASE) -f docker-compose.yml $(DC_START_CMD)

start-prod:
	$(WITH_ENV) docker compose -f $(COMPOSE_BASE) -f docker-compose.prod.yml $(DC_START_CMD)

stop-all:
	$(WITH_ENV) docker compose -f $(COMPOSE_BASE) -f docker-compose.dev.yml -f docker-compose.local.yml -f docker-compose.prod.yml docker-compose.yml  ${DC_DOWN_CMD}
