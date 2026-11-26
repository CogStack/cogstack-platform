# Kubernetes configuration

.PHONY: k3s-load-auth-all k3s-load-auth-nifi k3s-load-auth-opensearch k3s-load-auth-opensearch-dashboards

k3s-load-auth-all: ## Load the NiFi, Dashboards, and OpenSearch auth Secrets
	$(MAKE) k3s-load-auth-nifi
	$(MAKE) k3s-load-auth-opensearch-dashboards
	$(MAKE) k3s-load-auth-opensearch

# Uses env/authentication.env. Set NIFI_AUTH_FILE to choose another auth file.
k3s-load-auth-nifi: ## Load the NiFi flow encryption key and NGINX login Secret
	@bash scripts/security/load_nifi_auth.sh

# Both targets use env/authentication.env unless OPENSEARCH_AUTH_FILE is set.
k3s-load-auth-opensearch: ## Load the bootstrap policy and users before installing OpenSearch
k3s-load-auth-opensearch-dashboards: ## Load the OpenSearch Dashboards auth Secret

k3s-load-auth-opensearch k3s-load-auth-opensearch-dashboards:
	@bash scripts/security/load_opensearch_auth.sh $(@:k3s-load-auth-%=%)

.PHONY: k3s-delete-auth-all k3s-delete-auth-nifi k3s-delete-auth-opensearch k3s-delete-auth-opensearch-dashboards

k3s-delete-auth-all: k3s-delete-auth-nifi k3s-delete-auth-opensearch k3s-delete-auth-opensearch-dashboards ## Delete the NiFi, OpenSearch, and Dashboards auth Secrets
k3s-delete-auth-nifi: ## Delete the NiFi login and flow encryption key Secret
k3s-delete-auth-opensearch: ## Delete the OpenSearch security bootstrap Secret
k3s-delete-auth-opensearch-dashboards: ## Delete the OpenSearch Dashboards auth Secret

k3s-delete-auth-nifi k3s-delete-auth-opensearch k3s-delete-auth-opensearch-dashboards:
	@set -e; \
	. ./env/general.env; \
	namespace="$${KUBE_NAMESPACE:?Set KUBE_NAMESPACE in env/general.env}"; \
	case "$(@:k3s-delete-auth-%=%)" in \
		nifi) secret=nifi-auth;; \
		opensearch) secret=opensearch-security-bootstrap;; \
		opensearch-dashboards) secret=dashboards-auth;; \
	esac; \
	kubectl -n "$$namespace" delete secret "$$secret" --ignore-not-found

.PHONY: k3s-load-env-all k3s-load-env-nginx k3s-load-env-opensearch

k3s-load-env-all: k3s-load-env-nginx k3s-load-env-opensearch ## Load all runtime environment ConfigMaps
k3s-load-env-nginx: ## Load the NGINX runtime settings into the nginx-env ConfigMap
k3s-load-env-opensearch: ## Load the OpenSearch log level into the opensearch-env ConfigMap

k3s-load-env-nginx k3s-load-env-opensearch:
	@set -eo pipefail; \
	. ./env/general.env; \
	namespace="$${KUBE_NAMESPACE:?Set KUBE_NAMESPACE in env/general.env}"; \
	service=$(@:k3s-load-env-%=%); \
	env_file="./env/$$service.env"; \
	if [[ "$$service" == opensearch || -f "$$env_file" ]]; then . "$$env_file"; fi; \
	args=(); \
	case "$$service" in \
		nginx) args+=("--from-literal=NGINX_NIFI_SERVER_NAME=$${NGINX_NIFI_SERVER_NAME:-_}");; \
		opensearch) args+=("--from-literal=OPENSEARCH_LOG_LEVEL=$${OPENSEARCH_LOG_LEVEL:-INFO}");; \
	esac; \
	kubectl -n "$$namespace" create configmap "$$service-env" "$${args[@]}" --dry-run=client -o yaml | \
		kubectl -n "$$namespace" apply --server-side --field-manager=cogstack-env -f -

.PHONY: k3s-bootstrap-opensearch k3s-prepare-all

k3s-bootstrap-opensearch: k3s-load-auth-opensearch ## Alias for k3s-load-auth-opensearch

k3s-prepare-all: ## Render Helm values and load TLS, runtime, and auth resources
	$(MAKE) helm-values-all
	$(MAKE) k3s-load-certs-all
	$(MAKE) k3s-load-env-all
	$(MAKE) k3s-load-auth-all
