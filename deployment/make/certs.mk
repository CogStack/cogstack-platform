# Certificates

.PHONY: certs-all certs-k3s certs-root certs-nifi certs-nginx certs-opensearch certs-opensearch-shared certs-opensearch-nodes delete-certs-all

load_certificates_env = set -e; set -a; if [ -f ./env/certificates.env ]; then . ./env/certificates.env; fi; set +a
load_certificates_cluster_env = set -e; . ./env/general.env; export CLUSTER_DOMAIN; \
	namespace="$${KUBE_NAMESPACE:?Set KUBE_NAMESPACE in env/general.env}"

certs-k3s: certs-root ## Generate the CA, NGINX HTTPS certificate, and OpenSearch transport certificate
	$(MAKE) certs-nginx
	@$(load_certificates_cluster_env); \
	$(MAKE) certs-opensearch-shared KUBE_NAMESPACE="$$namespace"

certs-all: certs-k3s ## Generate the K3s and Docker certificate bundles
	@$(load_certificates_cluster_env); \
	$(MAKE) certs-nifi KUBE_NAMESPACE="$$namespace"
	@$(load_certificates_env); \
	OPENSEARCH_DASHBOARDS_DNS_NAMES="$${OPENSEARCH_DASHBOARDS_DNS_NAMES:-localhost}" \
		bash scripts/security/create_opensearch_client_admin_certs.sh

certs-root: ## Generate the root CA bundle
	@$(load_certificates_env); \
	bash scripts/security/create_root_ca_cert.sh

certs-nifi: ## Generate the NiFi certificate and stores with the existing CA
	bash scripts/security/create_nifi_certs.sh

certs-nginx: ## Generate the NGINX certificate with the existing CA
	@$(load_certificates_env); \
	bash scripts/security/create_nginx_certs.sh

certs-opensearch: certs-opensearch-shared ## Generate the shared OpenSearch node and admin client certificates
	@$(load_certificates_env); \
	bash scripts/security/create_opensearch_client_admin_certs.sh --admin-only

certs-opensearch-shared:
	@$(load_certificates_env); \
	service=opensearch-cluster-master; \
	service_dns="$$service.$${KUBE_NAMESPACE:-search}.svc"; \
	$(MAKE) certs-opensearch-nodes NODES=opensearch-shared \
		OPENSEARCH_NODE_DNS_NAMES="$${OPENSEARCH_NODE_DNS_NAMES:-localhost,$$service,$$service_dns,$$service_dns.$${CLUSTER_DOMAIN:-cluster.local}}"

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

.PHONY: k3s-load-certs k3s-load-certs-all k3s-load-certs-nginx k3s-load-certs-opensearch

k3s-load-certs: k3s-load-certs-all
k3s-load-certs-all: ## Load the NGINX HTTPS and OpenSearch transport TLS Secrets
k3s-load-certs-nginx: ## Load the NGINX certificate and key into nginx-tls
k3s-load-certs-opensearch: ## Load the shared node certificate into opensearch-node-tls

k3s-load-certs-all k3s-load-certs-nginx k3s-load-certs-opensearch:
	@set -eo pipefail; \
	. ./env/general.env; \
	if [ -f ./env/certificates.env ]; then . ./env/certificates.env; fi; \
	namespace="$${KUBE_NAMESPACE:?Set KUBE_NAMESPACE in env/general.env}"; \
	certs="$${SECURITY_DIR:-security}/certificates"; \
	services=$(@:k3s-load-certs-%=%); \
	if [ "$$services" = all ]; then services="nginx opensearch"; fi; \
	manifests=(); \
	for service in $$services; do \
		case "$$service" in \
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
