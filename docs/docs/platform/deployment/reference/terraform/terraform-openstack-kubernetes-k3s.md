# Terraform OpenStack Kubernetes K3s

<div class="tech-stack-banner" markdown="block">

{{ cogstack_banner_logo() }}

:simple-openstack:{ .tech-icon-openstack } :simple-kubernetes:{ .tech-icon-kubernetes } :simple-terraform:{ .tech-icon-terraform }

</div>

This Terraform module provisions a Kubernetes cluster on OpenStack using [K3s](https://k3s.io/). It creates the VMs, installs K3s on them, sets up networking, and returns a kubeconfig so you can use the cluster with `kubectl`, Helm, and other Terraform Kubernetes providers.

The module is published to the Terraform Registry:

- [CogStack/kubernetes-k3s/openstack](https://registry.terraform.io/modules/CogStack/kubernetes-k3s/openstack/latest)

Source code lives in this repository:

- [terraform-modules/openstack-kubernetes-k3s](https://github.com/CogStack/cogstack-platform/tree/main/terraform-modules/openstack-kubernetes-k3s)

For a full CogStack platform deployment that uses this module, see the [OpenStack Kubernetes K3s example](../../examples/openstack-kubernetes-k3s.md).
