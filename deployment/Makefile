SHELL := /usr/bin/env bash
.SHELLFLAGS := -o pipefail -c

.PHONY: setup-install-pre-requisites setup-k3s-cluster-init setup-verify setup-k3s-cluster-remote setup-k3s-namespace help

setup-install-pre-requisites: ## Install host tools, Docker, K3s, and Helm locally by default
	bash scripts/installation_utils/install_os_tools_and_software.sh

setup-k3s-cluster-init: ## Initialize the first K3s server on this machine
	bash scripts/installation_utils/setup_kubernetes_cluster.sh k3s server --cluster-init

setup-k3s-cluster-remote: ## Install prerequisites, initialize the first server, and join the rest over SSH
	bash scripts/installation_utils/setup_k3s_cluster.sh $(NODES)

setup-k3s-namespace: ## Create the namespace configured in env/general.env
	@set -eo pipefail; \
	. ./env/general.env; \
	kubectl create namespace "$${KUBE_NAMESPACE:?Set KUBE_NAMESPACE in env/general.env}" --dry-run=client -o yaml | \
		kubectl apply --server-side --field-manager=cogstack-namespace -f -

setup-verify: ## Check local Docker, Docker Compose, and K3s access without sudo
	bash scripts/installation_utils/verify_docker.sh
	bash scripts/installation_utils/verify_k3s.sh

# ======================================================================================================================================================

.PHONY: certs certs-all certs-root certs-nifi certs-nginx certs-opensearch certs-opensearch-nodes delete-certs-all

load_certificates_env = set -e; set -a; if [ -f ./env/certificates.env ]; then . ./env/certificates.env; fi; set +a

certs: certs-root ## Generate the root CA and NiFi and NGINX certificates
	$(MAKE) certs-nifi certs-nginx

certs-all: ## Generate the root CA and NiFi, NGINX, OpenSearch, and Dashboards certificates
	@set -e; \
	. ./env/general.env; \
	namespace="$${KUBE_NAMESPACE:?Set KUBE_NAMESPACE in env/general.env}"; \
	export CLUSTER_DOMAIN; \
	$(MAKE) certs KUBE_NAMESPACE="$$namespace"; \
	$(MAKE) certs-opensearch KUBE_NAMESPACE="$$namespace"
	@$(load_certificates_env); \
	OPENSEARCH_DASHBOARDS_DNS_NAMES="$${OPENSEARCH_DASHBOARDS_DNS_NAMES:-localhost}" \
		bash scripts/security/create_opensearch_client_admin_certs.sh --dashboards-only

certs-root: ## Generate the root CA bundle
	@$(load_certificates_env); \
	bash scripts/security/create_root_ca_cert.sh

certs-nifi: ## Generate the NiFi certificate and stores with the existing CA
	bash scripts/security/create_nifi_certs.sh

certs-nginx: ## Generate the NGINX certificate with the existing CA
	@$(load_certificates_env); \
	bash scripts/security/create_nginx_certs.sh

certs-opensearch: ## Generate the shared OpenSearch node and admin client certificates
	@$(load_certificates_env); \
	service=opensearch-cluster-master; \
	service_dns="$$service.$${KUBE_NAMESPACE:-search}.svc"; \
	$(MAKE) certs-opensearch-nodes NODES=opensearch-shared \
		OPENSEARCH_NODE_DNS_NAMES="$${OPENSEARCH_NODE_DNS_NAMES:-localhost,$$service,$$service_dns,$$service_dns.$${CLUSTER_DOMAIN:-cluster.local}}"
	@$(load_certificates_env); \
	bash scripts/security/create_opensearch_client_admin_certs.sh --admin-only

certs-opensearch-nodes: ## Generate OpenSearch node certificates for NODES="node1 node2 ..."
	@$(load_certificates_env); \
	read -r -a nodes <<< "$$NODES"; \
	bash scripts/security/create_opensearch_node_cert.sh "$${nodes[@]}"

delete-certs-all: ## Delete generated local TLS certificates, keys, and stores
	@set -e; \
	certs="$${SECURITY_DIR:-security}/certificates"; \
	if [ -L "$$certs" ]; then printf 'Certificate directory is a symlink: %s\n' "$$certs" >&2; exit 1; fi; \
	[ -d "$$certs" ] || exit 0; \
	CDPATH= cd -- "$$certs"; \
	find -P . -maxdepth 2 \( -type f -o -type l \) \
		\( -path './root/*' -o -path './nifi/*' -o -path './nginx/*' -o -path './opensearch/*' \) \
		\( -name '*.crt' -o -name '*.pem' -o -name '*.key' -o -name '*.csr' -o -name '*.p12' -o -name '*.jks' \) -delete

# ======================================================================================================================================================

.PHONY: k3s-load-certs k3s-load-certs-all k3s-load-certs-root-ca k3s-load-certs-nifi k3s-load-certs-nginx k3s-load-certs-opensearch

k3s-load-certs: k3s-load-certs-all ## Alias for k3s-load-certs-all
k3s-load-certs-all: ## Load all TLS Secrets for NiFi, NGINX and OpenSearch
k3s-load-certs-root-ca: ## Load the public CA and NiFi truststore into cogstack-root-ca
k3s-load-certs-nifi: ## Load the NiFi keystore into nifi-tls
k3s-load-certs-nginx: ## Load the NGINX certificate and key into nginx-tls
k3s-load-certs-opensearch: ## Load the shared node certificate into opensearch-node-tls

k3s-load-certs-all k3s-load-certs-root-ca k3s-load-certs-nifi k3s-load-certs-nginx k3s-load-certs-opensearch:
	@set -eo pipefail; \
	. ./env/general.env; \
	namespace="$${KUBE_NAMESPACE:?Set KUBE_NAMESPACE in env/general.env}"; \
	certs="$${SECURITY_DIR:-security}/certificates"; \
	services=$(@:k3s-load-certs-%=%); \
	if [ "$$services" = all ]; then services="root-ca nifi nginx opensearch"; fi; \
	manifests=(); \
	for service in $$services; do \
		case "$$service" in \
			root-ca) secret=(generic cogstack-root-ca \
				--from-file="ca.crt=$$certs/root/root-ca.pem" \
				--from-file="truststore.jks=$$certs/nifi/nifi-truststore.jks");; \
			nifi) secret=(generic nifi-tls \
				--from-file="nifi-keystore.jks=$$certs/nifi/nifi-keystore.jks");; \
			nginx) secret=(tls nginx-tls \
				--cert="$$certs/nginx/tls.crt" --key="$$certs/nginx/tls.key");; \
			opensearch) secret=(generic opensearch-node-tls \
				--from-file="node.crt=$$certs/opensearch/opensearch-shared.crt" \
				--from-file="node.key=$$certs/opensearch/opensearch-shared.key" \
				--from-file="ca.crt=$$certs/opensearch/elastic-stack-ca.crt.pem");; \
		esac; \
		manifest=$$(kubectl -n "$$namespace" create secret "$${secret[@]}" --dry-run=client -o yaml); \
		manifests+=("$$manifest"); \
	done; \
	printf -- '---\n%s\n' "$${manifests[@]}" | \
		kubectl -n "$$namespace" apply --server-side --field-manager=cogstack-certificates -f -

.PHONY: k3s-load-auth-nifi k3s-load-auth-opensearch k3s-load-auth-opensearch-dashboards

# Uses env/authentication.env. Set NIFI_AUTH_FILE to choose another auth file.
k3s-load-auth-nifi: ## Prompt for missing credentials and load the NiFi auth Secret
	@bash scripts/security/load_nifi_auth.sh

# Both targets use env/authentication.env unless OPENSEARCH_AUTH_FILE is set.
k3s-load-auth-opensearch: ## Load configured users into a fresh OpenSearch cluster
k3s-load-auth-opensearch-dashboards: ## Load the OpenSearch Dashboards auth Secret

k3s-load-auth-opensearch k3s-load-auth-opensearch-dashboards:
	@bash scripts/security/load_opensearch_auth.sh $(@:k3s-load-auth-%=%)

.PHONY: k3s-load-env-all k3s-load-env-nifi k3s-load-env-nginx k3s-load-env-opensearch

k3s-load-env-all: k3s-load-env-nifi k3s-load-env-nginx k3s-load-env-opensearch ## Load all runtime environment ConfigMaps
k3s-load-env-nifi: ## Load the NiFi proxy hosts into the nifi-env ConfigMap
k3s-load-env-nginx: ## Load the NGINX runtime settings into the nginx-env ConfigMap
k3s-load-env-opensearch: ## Load the OpenSearch log level into the opensearch-env ConfigMap

k3s-load-env-nifi k3s-load-env-nginx k3s-load-env-opensearch:
	@set -eo pipefail; \
	. ./env/general.env; \
	namespace="$${KUBE_NAMESPACE:?Set KUBE_NAMESPACE in env/general.env}"; \
	service=$(@:k3s-load-env-%=%); \
	env_file="./env/$$service.env"; \
	if [[ "$$service" != nginx || -f "$$env_file" ]]; then . "$$env_file"; fi; \
	args=(); \
	case "$$service" in \
		nifi) args+=("--from-literal=NIFI_WEB_PROXY_HOST=$${NIFI_WEB_PROXY_HOST-}");; \
		nginx) \
			for name in NGINX_NIFI_SERVER_NAME NGINX_PROXY_CONTEXT_PATH NGINX_PROXY_SCHEME; do \
				if [[ -n $${!name+x} ]]; then args+=("--from-literal=$$name=$${!name}"); fi; \
			done;; \
		opensearch) args+=("--from-literal=OPENSEARCH_LOG_LEVEL=$${OPENSEARCH_LOG_LEVEL:-INFO}");; \
	esac; \
	kubectl -n "$$namespace" create configmap "$$service-env" "$${args[@]}" --dry-run=client -o yaml | \
		kubectl -n "$$namespace" apply --server-side --field-manager=cogstack-env -f -

# ======================================================================================================================================================

.PHONY: helm-values-all helm-values-nifi helm-values-nginx helm-values-opensearch helm-values-opensearch-dashboards

helm-values-all: helm-values-nifi helm-values-nginx helm-values-opensearch helm-values-opensearch-dashboards ## Render all four charts' environment-based values
helm-values-nifi: ## Render NiFi values.yaml from env/nifi.env
helm-values-nginx: ## Render NGINX values.yaml from env/nifi.env and optional env/nginx.env
helm-values-opensearch: ## Render OpenSearch values.yaml from env/opensearch.env
helm-values-opensearch-dashboards: ## Render OpenSearch Dashboards values.yaml from env/opensearch-dashboards.env

helm-values-nifi helm-values-nginx helm-values-opensearch helm-values-opensearch-dashboards:
	@set -e; \
	service=$(@:helm-values-%=%); \
	env_file="./env/$$service.env"; \
	set -a; \
	if [ "$$service" = nginx ]; then \
		: "$${NGINX_DOCKER_CPU_MIN:=1}" "$${NGINX_DOCKER_CPU_MAX:=1}" "$${NGINX_DOCKER_RAM:=512M}"; \
		if [ -f "$$env_file" ] && [ -f ./env/nifi.env ]; then . ./env/nifi.env; fi; \
		[ -f "$$env_file" ] || env_file=./env/nifi.env; \
	fi; \
	. "$$env_file"; \
	set +a; \
	case "$$service" in \
		nifi) node_setting=NIFI_K3S_WHITELIST; export NIFI_K3S_ALLOWED_NODES='[]';; \
		opensearch) node_setting=OPENSEARCH_K3S_BLACKLIST; export OPENSEARCH_K3S_NODE_AFFINITY='{}';; \
		*) node_setting=;; \
	esac; \
	if [ -n "$$node_setting" ]; then \
		node_list="$${!node_setting}"; \
		IFS=$$' ,\t' read -r -a nodes <<< "$${node_list//$$'\n'/ }"; \
		if (( $${#nodes[@]} )); then \
			node_label='[a-z0-9]([a-z0-9-]*[a-z0-9])?'; \
			for node in "$${nodes[@]}"; do \
				if [[ $${#node} -gt 253 || ! "$$node" =~ ^$$node_label([.]$$node_label)*$$ ]]; then \
					printf 'Invalid Kubernetes node name in %s: %s\n' "$$node_setting" "$$node" >&2; \
					exit 1; \
				fi; \
			done; \
			if [ "$$service" = nifi ]; then \
				printf -v names '"%s",' "$${nodes[@]}"; \
				NIFI_K3S_ALLOWED_NODES="[$${names%,}]"; \
			else \
				printf -v fields '{key: metadata.name, operator: NotIn, values: ["%s"]},' "$${nodes[@]}"; \
				OPENSEARCH_K3S_NODE_AFFINITY="{requiredDuringSchedulingIgnoredDuringExecution: {nodeSelectorTerms: [{matchFields: [$${fields%,}]}]}}"; \
			fi; \
		fi; \
	fi; \
	chart="charts/$$service"; \
	template="$$chart/values.env.yaml"; \
	variables=$$(envsubst --variables "$$(cat "$$template")"); \
	for name in $$variables; do \
		value="$${!name:?Set $$name in $$env_file before rendering}"; \
		if [[ "$$name" == *_DOCKER_RAM && "$$value" =~ ^([0-9]+([.][0-9]+)?)([kmgtp])[bB]?$$ ]]; then \
			unit=$$(printf '%s' "$${BASH_REMATCH[3]}" | tr kmgtp KMGTP); \
			export "$$name=$${BASH_REMATCH[1]}$${unit}i"; \
		fi; \
	done; \
	tmp=$$(mktemp -d "$$chart/.values.XXXXXX"); \
	trap 'rm -rf -- "$$tmp"' EXIT; \
	envsubst < "$$template" > "$$tmp/values.yaml"; \
	mv -- "$$tmp/values.yaml" "$$chart/values.yaml"

# ======================================================================================================================================================

.PHONY: helm-install helm-install-nifi helm-install-nginx helm-install-nifi-stack
.PHONY: helm-install-opensearch helm-install-opensearch-dashboards helm-install-opensearch-stack k3s-bootstrap-opensearch

# Set KUBE_NAMESPACE in deployment/env/general.env and create the namespace
# and required Secrets and ConfigMaps. Run these from the repository root.
#   make -C deployment helm-install-nifi HELM_TIMEOUT=15m
#   make -C deployment helm-install-nginx
#   make -C deployment helm-install-nifi-stack
# Load dashboards-auth first to share its service account password with bootstrap.
#   make -C deployment k3s-load-auth-opensearch-dashboards
#   make -C deployment helm-install-opensearch
#   make -C deployment k3s-load-auth-opensearch
#   make -C deployment helm-install-opensearch-dashboards HELM_VALUES=/path/to/dashboards-values.yaml
# The stack initializes Security on first install. Set BOOTSTRAP_OPENSEARCH_SECURITY=0 to skip bootstrap.
#   make -C deployment helm-install-opensearch-stack HELM_VALUES=/path/to/dashboards-values.yaml
# The stack target uses HELM_VALUES for Dashboards.
# HELM_VALUES accepts an absolute path, a path relative to deployment/, or - for stdin.
# HELM_TIMEOUT defaults to 10m.
helm-install: ## Install or upgrade CHART with optional HELM_VALUES and HELM_TIMEOUT
	@set -e; \
	. ./env/general.env; \
	namespace="$${KUBE_NAMESPACE:?Set KUBE_NAMESPACE in env/general.env}"; \
	chart="charts/$${CHART:?Set CHART to a directory under deployment/charts}"; \
	release="$$CHART"; \
	args=(); \
	case "$$CHART" in \
		nifi|nginx) release="cogstack-$$CHART";; \
		opensearch|opensearch-dashboards) \
			helm repo add opensearch https://opensearch-project.github.io/helm-charts/; \
			helm dependency build "$$chart";; \
	esac; \
	if [ "$$CHART" = opensearch ]; then \
		args+=(--set-file "opensearch.config.opensearch\\.yml=$$chart/config/opensearch.yml"); \
	fi; \
	if [ -n "$${HELM_VALUES:-}" ]; then args+=(-f "$$HELM_VALUES"); fi; \
	helm upgrade --install "$$release" "$$chart" -n "$$namespace" \
		--wait --timeout "$${HELM_TIMEOUT:-10m}" "$${args[@]}"

helm-install-nifi: k3s-load-env-nifi ## Load the NiFi environment, then install or upgrade NiFi
	$(MAKE) helm-install CHART=nifi

helm-install-nginx: k3s-load-env-nginx ## Load the NGINX environment, then install or upgrade NGINX
	$(MAKE) helm-install CHART=nginx

helm-install-nifi-stack: helm-install-nifi ## Load the runtime environment and install or upgrade NiFi and NGINX
	$(MAKE) helm-install-nginx

helm-install-opensearch: k3s-load-env-opensearch ## Load the OpenSearch environment, then install or upgrade OpenSearch
	$(MAKE) helm-install CHART=opensearch

helm-install-opensearch-dashboards: ## Install or upgrade OpenSearch Dashboards
	$(MAKE) helm-install CHART=opensearch-dashboards

k3s-bootstrap-opensearch: k3s-load-auth-opensearch ## Alias for k3s-load-auth-opensearch

helm-install-opensearch-stack: ## Install OpenSearch and then Dashboards
	$(MAKE) helm-install-opensearch HELM_VALUES=
	@if [ "$${BOOTSTRAP_OPENSEARCH_SECURITY:-1}" = 1 ]; then $(MAKE) k3s-bootstrap-opensearch; fi
	$(MAKE) helm-install-opensearch-dashboards

# ======================================================================================================================================================

.PHONY: helm-uninstall-nifi helm-uninstall-nginx helm-uninstall-nifi-stack
.PHONY: helm-uninstall-opensearch helm-uninstall-opensearch-dashboards helm-uninstall-opensearch-stack

# Reinstall in the same namespace with the same StatefulSet names to reuse the retained PVCs.
helm-uninstall-nifi: ## Uninstall NiFi and retain its PVCs
helm-uninstall-nginx: ## Uninstall NGINX
helm-uninstall-opensearch: ## Uninstall OpenSearch and retain its PVCs
helm-uninstall-opensearch-dashboards: ## Uninstall OpenSearch Dashboards

helm-uninstall-nifi helm-uninstall-nginx helm-uninstall-opensearch helm-uninstall-opensearch-dashboards:
	@set -e; \
	. ./env/general.env; \
	namespace="$${KUBE_NAMESPACE:?Set KUBE_NAMESPACE in env/general.env}"; \
	release=$(@:helm-uninstall-%=%); \
	case "$$release" in nifi|nginx) release="cogstack-$$release";; esac; \
	helm uninstall "$$release" -n "$$namespace" --ignore-not-found \
		--cascade foreground --wait --timeout "$${HELM_TIMEOUT:-10m}"

helm-uninstall-nifi-stack: helm-uninstall-nginx ## Uninstall NGINX, then NiFi, and retain PVCs
	$(MAKE) helm-uninstall-nifi

helm-uninstall-opensearch-stack: helm-uninstall-opensearch-dashboards ## Uninstall Dashboards, then OpenSearch, and retain PVCs
	$(MAKE) helm-uninstall-opensearch

# ======================================================================================================================================================

help: ## Show deployment commands
	@printf '%s\n' 'Deployment commands'
	@awk -F ':.*## ' 'NF == 2 && $$1 ~ /^[[:alnum:]_-]+$$/ { printf "  %-30s %s\n", $$1, $$2 }' "$(lastword $(MAKEFILE_LIST))"
	@printf '\n%s\n  %s\n' 'Remote setup example' \
		'make setup-k3s-cluster-remote NODES="admin@server1 admin@server2 admin@server3"'
