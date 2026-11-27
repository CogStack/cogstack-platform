# Helm values and releases

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
		nifi) \
			node_setting=NIFI_K3S_WHITELIST; \
			export NIFI_K3S_ALLOWED_NODES='[]'; \
			export NIFI_K3S_FLOWFILE_VOLUME_SIZE="$${NIFI_K3S_FLOWFILE_VOLUME_SIZE:-20Gi}"; \
			export NIFI_K3S_CONTENT_VOLUME_SIZE="$${NIFI_K3S_CONTENT_VOLUME_SIZE:-100Gi}"; \
			export NIFI_K3S_PROVENANCE_VOLUME_SIZE="$${NIFI_K3S_PROVENANCE_VOLUME_SIZE:-50Gi}"; \
			export NIFI_K3S_DATABASE_VOLUME_SIZE="$${NIFI_K3S_DATABASE_VOLUME_SIZE:-5Gi}"; \
			export NIFI_K3S_STATE_VOLUME_SIZE="$${NIFI_K3S_STATE_VOLUME_SIZE:-5Gi}"; \
			export NIFI_K3S_CONF_VOLUME_SIZE="$${NIFI_K3S_CONF_VOLUME_SIZE:-5Gi}"; \
			export NIFI_K3S_STORAGE_CLASS_YAML=null; \
			if [ -n "$${NIFI_K3S_STORAGE_CLASS:-}" ]; then \
				printf -v NIFI_K3S_STORAGE_CLASS_YAML '"%s"' "$$NIFI_K3S_STORAGE_CLASS"; \
			fi;; \
		opensearch) \
			node_setting=OPENSEARCH_K3S_BLACKLIST; \
			export OPENSEARCH_K3S_NODE_AFFINITY='{}'; \
			export OPENSEARCH_K3S_VOLUME_SIZE="$${OPENSEARCH_K3S_VOLUME_SIZE:-8Gi}";; \
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
		if [ "$$name" = OPENSEARCH_K3S_STORAGE_CLASS ]; then continue; fi; \
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

.PHONY: helm-install helm-install-all helm-install-nifi helm-install-nginx helm-install-nifi-stack
.PHONY: helm-install-opensearch helm-install-opensearch-dashboards helm-install-opensearch-stack
.PHONY: helm-install-jupyter-hub

# Set KUBE_NAMESPACE in deployment/env/general.env and create the namespace
# and required Secrets and ConfigMaps. Run these from the repository root.
#   make -C deployment helm-install-nifi HELM_TIMEOUT=15m
#   make -C deployment helm-install-nginx
#   make -C deployment helm-install-nifi-stack
# Load dashboards-auth first to share its service account password with bootstrap.
#   make -C deployment k3s-load-auth-opensearch-dashboards
#   make -C deployment k3s-load-auth-opensearch
#   make -C deployment helm-install-opensearch
#   make -C deployment helm-install-opensearch-dashboards HELM_VALUES=/path/to/dashboards-values.yaml
# Set BOOTSTRAP_OPENSEARCH_SECURITY=0 to use existing auth Secrets.
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
		jupyter-hub) \
			helm repo add jupyterhub https://hub.jupyter.org/helm-chart/; \
			helm dependency build "$$chart";; \
	esac; \
	if [ "$$CHART" = opensearch ]; then \
		args+=(--set-file "opensearch.config.opensearch\\.yml=$$chart/config/opensearch.yml"); \
	fi; \
	if [ -n "$${HELM_VALUES:-}" ]; then args+=(-f "$$HELM_VALUES"); fi; \
	helm upgrade --install "$$release" "$$chart" -n "$$namespace" \
		--wait --timeout "$${HELM_TIMEOUT:-10m}" "$${args[@]}"

helm-install-all: k3s-prepare-all ## Prepare and install or upgrade both application stacks
	$(MAKE) helm-install-nifi-stack
	$(MAKE) helm-install-opensearch-stack BOOTSTRAP_OPENSEARCH_SECURITY=0

helm-install-nifi: ## Install or upgrade NiFi
helm-install-nginx: k3s-load-env-nginx ## Load the NGINX environment, then install or upgrade NGINX
helm-install-opensearch: k3s-load-env-opensearch ## Load the OpenSearch environment, then install or upgrade OpenSearch
helm-install-opensearch-dashboards: ## Install or upgrade OpenSearch Dashboards
helm-install-jupyter-hub: ## Install or upgrade standalone JupyterHub

helm-install-nifi helm-install-nginx helm-install-opensearch \
helm-install-opensearch-dashboards helm-install-jupyter-hub:
	$(MAKE) helm-install CHART=$(@:helm-install-%=%)

helm-install-nifi-stack: helm-install-nifi ## Load the runtime environment and install or upgrade NiFi and NGINX
	$(MAKE) helm-install-nginx

helm-install-opensearch-stack: ## Install OpenSearch and then Dashboards
	@if [ "$${BOOTSTRAP_OPENSEARCH_SECURITY:-1}" = 1 ]; then \
		$(MAKE) k3s-load-auth-opensearch-dashboards && $(MAKE) k3s-bootstrap-opensearch; \
	fi
	$(MAKE) helm-install-opensearch HELM_VALUES=
	$(MAKE) helm-install-opensearch-dashboards

.PHONY: helm-uninstall-nifi helm-uninstall-nginx helm-uninstall-nifi-stack
.PHONY: helm-uninstall-opensearch helm-uninstall-opensearch-dashboards helm-uninstall-opensearch-stack
.PHONY: helm-delete-opensearch-volumes

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

helm-delete-opensearch-volumes: ## Delete OpenSearch data PVCs after uninstalling
	@set -e; \
	. ./env/general.env; \
	namespace="$${KUBE_NAMESPACE:?Set KUBE_NAMESPACE in env/general.env}"; \
	kubectl -n "$$namespace" delete pvc --ignore-not-found \
		-l 'app.kubernetes.io/instance=opensearch,app.kubernetes.io/name=opensearch'
