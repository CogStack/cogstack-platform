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
.PHONY: k3s-load-certs-opensearch-dashboards

k3s-load-certs: k3s-load-certs-all ## Alias for k3s-load-certs-all
k3s-load-certs-all: ## Load NiFi, NGINX, and OpenSearch node TLS Secrets
k3s-load-certs-root-ca: ## Load the public CA and NiFi truststore into cogstack-root-ca
k3s-load-certs-nifi: ## Load the NiFi keystore into nifi-tls
k3s-load-certs-nginx: ## Load the NGINX certificate and key into nginx-tls
k3s-load-certs-opensearch: ## Load the shared node certificate into opensearch-node-tls
k3s-load-certs-opensearch-dashboards: ## Load the browser-facing certificate into dashboards-tls

k3s-load-certs-all k3s-load-certs-root-ca k3s-load-certs-nifi k3s-load-certs-nginx k3s-load-certs-opensearch k3s-load-certs-opensearch-dashboards:
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
		opensearch-dashboards) secret=(tls dashboards-tls \
			--cert="$$certs/opensearch/es_kibana_client.pem" --key="$$certs/opensearch/es_kibana_client.key");; \
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
	if [[ "$$service" == opensearch || -f "$$env_file" ]]; then . "$$env_file"; fi; \
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

.PHONY: k3s-install-nifi k3s-install-nginx k3s-install-ocr-service k3s-install-nifi-stack
.PHONY: k3s-uninstall-nifi k3s-uninstall-nginx k3s-uninstall-ocr-service k3s-uninstall-nifi-stack
.PHONY: k3s-install-opensearch k3s-install-opensearch-dashboards k3s-install-opensearch-stack k3s-bootstrap-opensearch
.PHONY: k3s-uninstall-opensearch k3s-uninstall-opensearch-dashboards k3s-uninstall-opensearch-stack

# Install static manifests in the namespace from env/general.env.
k3s-install-nifi: k3s-load-env-nifi ## Apply the NiFi manifest and wait for readiness
k3s-install-nginx: k3s-load-env-nginx ## Apply the NGINX manifest and wait for readiness
k3s-install-ocr-service: ## Apply the OCR Service manifest and wait for readiness
k3s-install-opensearch: k3s-load-env-opensearch ## Apply the OpenSearch manifest and wait for readiness
k3s-install-opensearch-dashboards: ## Apply the Dashboards manifest and wait for readiness

k3s-install-nifi k3s-install-nginx k3s-install-ocr-service k3s-install-opensearch k3s-install-opensearch-dashboards:
	@set -e; \
	. ./env/general.env; \
	namespace="$${KUBE_NAMESPACE:?Set KUBE_NAMESPACE in env/general.env}"; \
	service=$(@:k3s-install-%=%); \
	case "$$service" in \
		nifi) workload=statefulset/cogstack-nifi;; \
		nginx) workload=deployment/cogstack-nginx;; \
		ocr-service) workload=deployment/ocr-service;; \
		opensearch) workload=statefulset/opensearch-cluster-master;; \
		opensearch-dashboards) workload=deployment/opensearch-dashboards;; \
	esac; \
	kubectl -n "$$namespace" apply -f "charts/$$service/rendered.yaml"; \
	kubectl -n "$$namespace" rollout status "$$workload" --timeout="$${K3S_TIMEOUT:-10m}"

k3s-install-nifi-stack: k3s-install-nifi ## Install NiFi and then NGINX from their manifests
	$(MAKE) k3s-install-nginx

k3s-bootstrap-opensearch: k3s-load-auth-opensearch ## Initialize OpenSearch Security

k3s-install-opensearch-stack: k3s-install-opensearch ## Install OpenSearch and then Dashboards from their manifests
	@if [ "$${BOOTSTRAP_OPENSEARCH_SECURITY:-1}" = 1 ]; then $(MAKE) k3s-bootstrap-opensearch; fi
	$(MAKE) k3s-install-opensearch-dashboards

k3s-uninstall-nifi: ## Delete the NiFi workloads and retain their PVCs
k3s-uninstall-nginx: ## Delete the NGINX workloads
k3s-uninstall-ocr-service: ## Delete the OCR Service workloads
k3s-uninstall-opensearch: ## Delete the OpenSearch workloads and retain their PVCs
k3s-uninstall-opensearch-dashboards: ## Delete the Dashboards workloads

k3s-uninstall-nifi k3s-uninstall-nginx k3s-uninstall-ocr-service k3s-uninstall-opensearch k3s-uninstall-opensearch-dashboards:
	@set -e; \
	. ./env/general.env; \
	namespace="$${KUBE_NAMESPACE:?Set KUBE_NAMESPACE in env/general.env}"; \
	service=$(@:k3s-uninstall-%=%); \
	kubectl -n "$$namespace" delete -f "charts/$$service/rendered.yaml" \
		--ignore-not-found --cascade=foreground --wait --timeout="$${K3S_TIMEOUT:-10m}"

k3s-uninstall-nifi-stack: k3s-uninstall-nginx ## Uninstall NGINX, then NiFi, and retain PVCs
	$(MAKE) k3s-uninstall-nifi

k3s-uninstall-opensearch-stack: k3s-uninstall-opensearch-dashboards ## Uninstall Dashboards, then OpenSearch, and retain PVCs
	$(MAKE) k3s-uninstall-opensearch

# ======================================================================================================================================================

.PHONY: helm-install

helm-install: ## Install or upgrade CHART with optional HELM_VALUES and HELM_TIMEOUT
	@set -e; \
	. ./env/general.env; \
	namespace="$${KUBE_NAMESPACE:?Set KUBE_NAMESPACE in env/general.env}"; \
	chart="charts/$${CHART:?Set CHART to a directory under deployment/charts}"; \
	release="$$CHART"; \
	args=(); \
	if [ -n "$${HELM_VALUES:-}" ]; then args+=(-f "$$HELM_VALUES"); fi; \
	helm upgrade --install "$$release" "$$chart" -n "$$namespace" \
		--wait --timeout "$${HELM_TIMEOUT:-10m}" "$${args[@]}"

# ======================================================================================================================================================

help: ## Show deployment commands
	@printf '%s\n' 'Deployment commands'
	@awk -F ':.*## ' 'NF == 2 && $$1 ~ /^[[:alnum:]_-]+$$/ { printf "  %-30s %s\n", $$1, $$2 }' "$(lastword $(MAKEFILE_LIST))"
	@printf '\n%s\n  %s\n' 'Remote setup example' \
		'make setup-k3s-cluster-remote NODES="admin@server1 admin@server2 admin@server3"'
