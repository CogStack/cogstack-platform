# Docker Compose

CogStack services are all provided as Docker images with configuration files, so you can use Docker Compose to run your own instances of specific services.

We use Docker Compose internally during development to run services individually or together without the overhead of full orchestration.

## Note

!!! tip

    We are actively working on moving away from docker compose and VMs as the primary way of doing production deployments. Instead we plan to focus more on deployment with Kubernetes and Helm.

    Many of the existing project instructions in github for CogStack will still show how to use docker compose to bring up standalone instances.

## How to run

You can find example Docker Compose `.yml` files throughout our repositories, for example

- [MedCAT Service](https://github.com/CogStack/cogstack-nlp/blob/main/medcat-service/docker/docker-compose.example.yml)  
- [MedCAT Trainer](https://github.com/CogStack/cogstack-nlp/blob/main/medcat-trainer/docker-compose.yml)

To start CogStack with Docker Compose, copy the file and run:

```bash
docker-compose up
```

## Why move to Kuberentes?
We are aiming to move to Kubernetes and Helm as the primary recommended method of deployment. 

Docker Compose has been great for our existing setups and development, but it doesn’t handle scaling, or orchetrating to multiple nodes without a lot of tooling like Portainer. 

Kubernetes, paired with Helm, provides cloud-native support and after the challenge of getting a k8s cluster, it will make deployment much easier and better. 