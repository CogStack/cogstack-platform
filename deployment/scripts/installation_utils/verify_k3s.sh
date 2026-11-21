#!/usr/bin/env bash

set -euo pipefail

export KUBECONFIG="${KUBECONFIG:-${HOME}/.kube/config}"
kubectl get nodes
kubectl get pods -A
