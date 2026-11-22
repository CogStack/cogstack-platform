SHELL := /usr/bin/env bash
.SHELLFLAGS := -o pipefail -c

DC_START_CMD := up -d
DC_STOP_CMD := stop
define WITH_ENV
source ./export_env_vars.sh || exit $$?;
endef

help: ## List available targets with descriptions
	@echo "Available targets:"
	@awk '\
	function default_desc(target) { \
		if (target ~ /^start-/) return "Start a service or service group"; \
		if (target ~ /^stop-/) return "Stop a service or service group"; \
		if (target ~ /^delete-/) return "Delete related containers/images/volumes"; \
		if (target == "load-env") return "Load variables from export_env_vars.sh"; \
		if (target == "show-env") return "Print current environment variables"; \
		return "(no description)"; \
	} \
	/^[a-zA-Z0-9][a-zA-Z0-9_-]*:/ { \
		raw=$$0; \
		target=raw; \
		sub(/:.*/, "", target); \
		if (!(target in seen)) { \
			seen[target]=1; \
		} \
		if (index(raw, "##") > 0) { \
			description=raw; \
			sub(/^.*##[[:space:]]*/, "", description); \
			desc[target]=description; \
		} \
	} \
	END { \
		for (target in seen) { \
			description=desc[target]; \
			if (description == "") description=default_desc(target); \
			print target "\t" description; \
		} \
	} \
	' $(MAKEFILE_LIST) | sort | awk -F '\t' '{printf "  %-28s %s\n", $$1, $$2}'

load-env: ## Load variables from export_env_vars.sh in a subshell
	$(WITH_ENV) echo "Environment variables loaded."

show-env: ## Print sorted environment variables after loading export_env_vars.sh
	${WITH_ENV} >/dev/null 2>&1; printenv | sort

check-config: ## Validate the NiFi dev Compose file
	@$(WITH_ENV) docker compose -f docker-compose.dev.yml config --quiet

start-nifi-dev: ## Start NiFi and NiFi nginx (docker-compose.dev.yml)
	$(WITH_ENV) docker compose -f docker-compose.dev.yml $(DC_START_CMD) nifi nifi-nginx

start-nifi-dev-build: ## Build and start NiFi dev services
	$(WITH_ENV) docker compose -f docker-compose.dev.yml up -d --build nifi nifi-nginx

build-nifi-image: ## Build the local NiFi image without starting services
	$(WITH_ENV) docker build \
		--build-arg NIFI_VERSION="$${NIFI_VERSION:-2.12.0}" \
		--build-arg NIFI_BASE_IMAGE="$${NIFI_BASE_IMAGE}" \
		--build-arg NIFI_UID="$${COGSTACK_LOCAL_UID:-1000}" \
		--build-arg NIFI_GID="$${COGSTACK_LOCAL_GID:-1000}" \
		--tag "$${NIFI_LOCAL_DOCKER_IMAGE:-cogstack/cogstack-nifi:local}" \
		--file ../Dockerfile \
		..

start-jupyter:
	$(WITH_ENV) docker compose -f ../../jupyter-hub/docker/docker-compose.base.yml -f ../../jupyter-hub/docker/docker-compose.prod.yml $(DC_START_CMD) cogstack-jupyter-hub

stop-nifi-dev: ## Stop NiFi and NiFi nginx (docker-compose.dev.yml)
	$(WITH_ENV) docker compose -f docker-compose.dev.yml $(DC_STOP_CMD) nifi nifi-nginx

delete-nifi-dev-containers: ## Remove NiFi containers from docker-compose.dev.yml
	$(WITH_ENV) docker compose -f docker-compose.dev.yml rm -f -s nifi nifi-nginx

delete-nifi-dev-images: ## Delete NiFi images referenced in docker-compose.dev.yml
	$(WITH_ENV) images="$$(docker compose -f docker-compose.dev.yml config --images nifi nifi-nginx  | sort -u)"; \
	if [ -n "$$images" ]; then \
		docker image rm -f $$images; \
	else \
		echo "No NiFi images found in docker-compose.dev.yml"; \
	fi

delete-jupyter: ## Remove Jupyter container
	$(WITH_ENV) docker compose -f ../../jupyter-hub/docker/docker-compose.base.yml -f ../../jupyter-hub/docker/docker-compose.prod.yml rm -f -s cogstack-jupyter-hub

make-delete-jupyter: delete-jupyter ## Alias for delete-jupyter

stop-jupyter:
	$(WITH_ENV) docker compose -f ../../jupyter-hub/docker/docker-compose.base.yml -f ../../jupyter-hub/docker/docker-compose.yml $(DC_STOP_CMD) cogstack-jupyter-hub

.PHONY: help load-env show-env check-config start-nifi-dev start-nifi-dev-build build-nifi-image start-jupyter stop-nifi-dev delete-nifi-dev-containers delete-nifi-dev-images delete-jupyter make-delete-jupyter stop-jupyter
