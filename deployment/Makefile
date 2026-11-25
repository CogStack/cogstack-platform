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

.PHONY: certs certs-all certs-root certs-nifi certs-nginx certs-opensearch certs-opensearch-nodes

certs: certs-root ## Generate the root CA and NiFi and NGINX certificates
	$(MAKE) certs-nifi certs-nginx

certs-all: ## Generate the root CA and NiFi, NGINX, OpenSearch, and Dashboards certificates
	@set -e; \
	. ./env/general.env; \
	namespace="$${KUBE_NAMESPACE:?Set KUBE_NAMESPACE in env/general.env}"; \
	export CLUSTER_DOMAIN; \
	$(MAKE) certs KUBE_NAMESPACE="$$namespace"; \
	$(MAKE) certs-opensearch KUBE_NAMESPACE="$$namespace"
	OPENSEARCH_DASHBOARDS_DNS_NAMES="$${OPENSEARCH_DASHBOARDS_DNS_NAMES:-localhost}" \
		bash scripts/security/create_opensearch_client_admin_certs.sh --dashboards-only

certs-root: ## Generate the root CA bundle
	bash scripts/security/create_root_ca_cert.sh

certs-nifi: ## Generate the NiFi certificate and stores with the existing CA
	bash scripts/security/create_nifi_certs.sh

certs-nginx: ## Generate the NGINX certificate with the existing CA
	bash scripts/security/create_nginx_certs.sh

certs-opensearch: ## Generate the shared OpenSearch node and admin client certificates
	@service=opensearch-cluster-master; \
	service_dns="$$service.$${KUBE_NAMESPACE:-search}.svc"; \
	$(MAKE) certs-opensearch-nodes NODES=opensearch-shared \
		OPENSEARCH_NODE_DNS_NAMES="$${OPENSEARCH_NODE_DNS_NAMES:-localhost,$$service,$$service_dns,$$service_dns.$${CLUSTER_DOMAIN:-cluster.local}}"
	bash scripts/security/create_opensearch_client_admin_certs.sh --admin-only

certs-opensearch-nodes: ## Generate OpenSearch node certificates for NODES="node1 node2 ..."
	@read -r -a nodes <<< "$$NODES"; \
	bash scripts/security/create_opensearch_node_cert.sh "$${nodes[@]}"

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

help: ## Show deployment commands
	@printf '%s\n' 'Deployment commands'
	@awk -F ':.*## ' 'NF == 2 && $$1 ~ /^[[:alnum:]_-]+$$/ { printf "  %-30s %s\n", $$1, $$2 }' "$(lastword $(MAKEFILE_LIST))"
	@printf '\n%s\n  %s\n' 'Remote setup example' \
		'make setup-k3s-cluster-remote NODES="admin@server1 admin@server2 admin@server3"'
