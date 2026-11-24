SHELL := /usr/bin/env bash
.SHELLFLAGS := -o pipefail -c

DC_START_CMD := up -d
DC_STOP_CMD := stop
COMPOSE_DEV := docker compose -f docker-compose.base.yml -f docker-compose.dev.yml
COMPOSE_PROD := docker compose -f docker-compose.base.yml -f docker-compose.prod.yml
DEV_CERT_ENV := $(abspath ../../../deployment/env/cert_auth_settings_dev.env)

define WITH_ENV
source ./export_env_vars.sh || exit $$?;
endef

define WITH_DEV_CERTS
$(WITH_ENV) \
cert_dir=../../../deployment/security/certificates; \
dev_certs=(); \
if [[ -f "$(DEV_CERT_ENV)" ]]; then \
	set -a; source "$(DEV_CERT_ENV)" || exit $$?; set +a; \
	: "$${SECURITY_DIR:?Set SECURITY_DIR in the dev settings file}"; \
	cert_dir="$$SECURITY_DIR/certificates"; \
	dev_certs=(-f docker-compose.dev-tls.yml); \
fi;
endef

define CHECK_TLS_FILES
for cert in root/root-ca.pem nifi/nifi-keystore.jks nifi/nifi-truststore.jks nginx/tls.crt nginx/tls.key; do \
	file="$$cert_dir/$$cert"; \
	if [ ! -f "$$file" ] || [ ! -r "$$file" ] || [ ! -s "$$file" ]; then \
		printf 'TLS file missing, empty, or unreadable: %s\n' "$$file" >&2; exit 1; \
	fi; \
done;
endef

define WITH_DEV_START
$(WITH_DEV_CERTS) \
if [[ -n "$${NIFI_DEV_OPENBAO_ADDR:-}" ]]; then \
	source ./openbao_dev.sh && nifi_openbao_dev load || exit $$?; \
	unset BAO_TOKEN; \
fi; \
if (( $${#dev_certs[@]} )); then \
	: "$${KEYSTORE_PASSWORD:?Set KEYSTORE_PASSWORD}" "$${TRUSTSTORE_PASSWORD:?Set TRUSTSTORE_PASSWORD}"; \
fi; \
$(CHECK_TLS_FILES)
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

check-config: ## Validate the default, dev and prod Compose configurations
	@$(WITH_ENV) docker compose config --quiet && $(COMPOSE_PROD) config --quiet
	@$(WITH_DEV_CERTS) $(COMPOSE_DEV) "$${dev_certs[@]}" config --quiet

check-tls: ## Check the TLS files required by NiFi and NGINX
	@cert_dir=../../../deployment/security/certificates; $(CHECK_TLS_FILES)

start-nifi: check-tls ## Start the default NiFi and NGINX stack
	$(WITH_ENV) docker compose $(DC_START_CMD)

setup-nifi-dev-tls: ## Generate or validate the local dev certificates using cert_auth_settings_dev.env
	@./setup_dev_tls.sh "$(DEV_CERT_ENV)"

seed-nifi-dev-openbao: ## Store the current demo credentials in a fresh OpenBao dev instance
	@source ./openbao_dev.sh && nifi_openbao_dev seed "$(DEV_CERT_ENV)"

start-nifi-dev: ## Start NiFi and NGINX with local builds
	$(WITH_DEV_START) $(COMPOSE_DEV) "$${dev_certs[@]}" $(DC_START_CMD) nifi nifi-nginx

start-nifi-dev-build: ## Build and start NiFi dev services
	$(WITH_DEV_START) $(COMPOSE_DEV) "$${dev_certs[@]}" up -d --build nifi nifi-nginx

start-nifi-prod: check-tls ## Start the published NiFi and NGINX images on cogstack-net
	$(WITH_ENV) $(COMPOSE_PROD) $(DC_START_CMD)

build-nifi-image: ## Build the local NiFi image without starting services
	$(WITH_ENV) docker build \
		--build-arg NIFI_VERSION="$${NIFI_VERSION:-2.12.0}" \
		--build-arg NIFI_BASE_IMAGE \
		--build-arg NIFI_UID="$${COGSTACK_LOCAL_UID:-1000}" \
		--build-arg NIFI_GID="$${COGSTACK_LOCAL_GID:-1000}" \
		--tag "$${NIFI_LOCAL_DOCKER_IMAGE:-cogstacksystems/nifi:local}" \
		--file ../Dockerfile \
		..

stop-nifi-dev: ## Stop the NiFi dev services
	$(WITH_ENV) $(COMPOSE_DEV) $(DC_STOP_CMD) nifi nifi-nginx

stop-nifi-prod: ## Stop the NiFi prod services
	$(WITH_ENV) $(COMPOSE_PROD) $(DC_STOP_CMD)

delete-nifi: delete-nifi-dev-containers ## Stop and remove the NiFi and NGINX containers

delete-nifi-dev-containers: ## Remove the NiFi dev containers
	$(WITH_ENV) $(COMPOSE_DEV) rm -f -s nifi nifi-nginx

delete-nifi-dev-volumes: delete-nifi-dev-containers ## Remove the NiFi and NGINX containers and delete NiFi dev volume data
	@$(WITH_ENV) volumes="$$($(COMPOSE_DEV) config --format json | \
		jq -r '.volumes[]? | select(.external != true) | .name')" || exit $$?; \
	if [ -n "$$volumes" ]; then docker volume rm -f $$volumes; fi

delete-nifi-dev-images: ## Delete the NiFi dev images
	$(WITH_ENV) images="$$($(COMPOSE_DEV) config --images nifi nifi-nginx | sort -u)" || exit $$?; \
	if [ -n "$$images" ]; then \
		docker image rm -f $$images; \
	else \
		echo "No NiFi dev images found."; \
	fi

.PHONY: help load-env show-env check-config check-tls start-nifi setup-nifi-dev-tls seed-nifi-dev-openbao start-nifi-dev start-nifi-dev-build start-nifi-prod build-nifi-image stop-nifi-dev stop-nifi-prod delete-nifi delete-nifi-dev-containers delete-nifi-dev-volumes delete-nifi-dev-images
