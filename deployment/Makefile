SHELL := /usr/bin/env bash
.SHELLFLAGS := -o pipefail -c

.PHONY: setup-install-pre-requisites setup-k3s-cluster-init setup-verify setup-k3s-cluster-remote help

setup-install-pre-requisites: ## Install host tools, Docker, K3s, and Helm locally by default
	bash scripts/installation_utils/install_os_tools_and_software.sh

setup-k3s-cluster-init: ## Initialize the first K3s server on this machine
	bash scripts/installation_utils/setup_kubernetes_cluster.sh k3s server --cluster-init

setup-k3s-cluster-remote: ## Install prerequisites, initialize the first server, and join the rest over SSH
	bash scripts/installation_utils/setup_k3s_cluster.sh $(NODES)

setup-verify: ## Check local Docker, Docker Compose, and K3s access without sudo
	bash scripts/installation_utils/verify_docker.sh
	bash scripts/installation_utils/verify_k3s.sh

# ======================================================================================================================================================

.PHONY: certs certs-root certs-nifi certs-nginx certs-opensearch certs-opensearch-nodes

certs: certs-root ## Generate the root CA and NiFi and NGINX certificates
	$(MAKE) certs-nifi certs-nginx

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

.PHONY: helm-values-nifi helm-values-nginx helm-values-opensearch helm-values-opensearch-dashboards

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
