# Tutorial
This page is a tutorial for using helm to deploy CogStack.

We will use the CLI to interact with the cluster, then use Terraform to declaratively install our helm chart.

## Prerequisites
- A kubernetes cluster
- Helm CLI
- Terraform CLI

## Helm Terraform Provider
Terraform is a recommended way to declaritively run CogStack using helm.

```hcl
resource "helm_release" "medcat-service" {
  name         = "medcat-service-helm"
  chart        = "oci://registry-1.docker.io/cogstacksystems/medcat-service-helm"
}
```

### Values
We can pass values into the helm chart to customize it.

```hcl
resource "helm_release" "medcat-service" {
  name         = "medcat-service-helm"
  chart        = "oci://registry-1.docker.io/cogstacksystems/medcat-service-helm"
  values = [<<EOT
replicaCount: 3
EOT
    ]
}
```


## Helm CLI Install
We can also use the Helm CLI to deploy CogStack.

Whilst this is quick and useful for development, we advise instead to use IaC with terraform for production deployments so you can easily see what was deployed, how and when. 

```
helm install my-medcat oci://registry-1.docker.io/cogstacksystems/medcat-service-helm --wait --timeout 10m0s
```

## Test
Use Helm Test to verify the deployments.

```bash
helm test my-chart
```

