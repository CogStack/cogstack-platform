# Cluster setup

.PHONY: setup-all setup-install-pre-requisites setup-k3s-cluster-init setup-verify setup-k3s-cluster-remote setup-k3s-namespace

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

setup-all: ## Install prerequisites, initialize K3s, create the namespace, and verify
	$(MAKE) setup-install-pre-requisites
	$(MAKE) setup-k3s-cluster-init
	$(MAKE) setup-k3s-namespace
	$(MAKE) setup-verify
