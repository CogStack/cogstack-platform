#!/usr/bin/env bash
minikube start --cni=calico --cpus=no-limit --memory=no-limit
minikube addons enable metrics-server

minikube dashboard --url=true &

helm upgrade medcat-service ./medcat-service-helm --install --recreate-pods  --wait --timeout 5m0s # Install if it doesnt already exist, else upgrade
helm test medcat-service --logs

# Run CT  Lint
# docker run -it --network host --workdir=/data --volume ~/.kube/config:/root/.kube/config:ro --volume $(pwd):/data quay.io/helmpack/chart-testing:v3.7.1 ct lint --chart-dirs . --charts .

# Helm Install from Docker Hub
# helm install my-medcat oci://registry-1.docker.io/cogstacksystems/medcat-service-helm --wait --timeout 5m0s

# Test with host header set for ingress routing
# HOST_IP=10.211.112.82
# curl --resolve chart-example.local:80:${HOST_IP} http://chart-example.local/api/info

# Test medcat trainer
# kubectl port-forward svc/nginx 8000:8000

# helm upgrade medcat-trainer-helm ./medcat-trainer-helm --install  --wait --timeout 5m0s # Install if it doesnt already exist, else upgrade
# kubectl port-forward svc/medcat-trainer-solr 8983:8983

## helm install trainer-registry oci://registry-1.docker.io/cogstacksystems/medcat-trainer-helm --wait --timeout 5m0s

helm upgrade cogstack-ce-helm ./cogstack-ce-helm --install

# Stop any running port forwards
# ps -ef | grep '[p]ort-forward' | awk '{print $2}' | xargs -r kill
# Port forward all services in  cogstack-ce-helm
# helm get notes cogstack-ce-helm | bash