OPENBAO_HOST_PORT ?= 8201
OPENBAO_TLS_DIR ?= $(CURDIR)/local-server/tls

.PHONY: start-openbao start-openbao-dev

start-openbao: ## Start the persistent OpenBao server
	OPENBAO_HOST_PORT="$(OPENBAO_HOST_PORT)" OPENBAO_TLS_DIR="$(OPENBAO_TLS_DIR)" \
		docker compose --project-name openbao-server --env-file env/openbao.env \
		-f docker/docker-compose.base.yml -f docker/docker-compose.server.yml up -d

start-openbao-dev: ## Start the in-memory OpenBao server
	docker compose -f docker/docker-compose.yml up -d
