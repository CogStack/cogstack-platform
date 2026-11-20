SHELL := /usr/bin/env bash
.SHELLFLAGS := -o pipefail -c

.PHONY: setup-install-pre-requisites setup-k3s-cluster-init setup-verify setup-k3s-cluster-remote

setup-install-pre-requisites:
	bash scripts/installation_utils/install_os_tools_and_software.sh

setup-k3s-cluster-init:
	bash scripts/installation_utils/setup_kubernetes_cluster.sh k3s server --cluster-init

setup-verify:
	bash scripts/installation_utils/verify_docker.sh
	bash scripts/installation_utils/verify_k3s.sh

setup-k3s-cluster-remote:
	bash scripts/installation_utils/setup_k3s_cluster.sh $(NODES)
