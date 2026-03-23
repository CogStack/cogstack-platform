# Quickstart

This tutorial installs CogStack CE using Helm, sets up port-forwarding, and opens the bundled JupyterHub in your browser.

The install should take around 15 minutes, and by the end of this tutorial you will have a fully working and integrated CogStack environment that you can start using.

## Prerequisites

- A Kubernetes cluster
- Helm 3+

## 1. Install CogStack CE

Run:

```sh
helm install cogstack oci://registry-1.docker.io/cogstacksystems/cogstack-helm-ce --timeout 15m
```

This command will install Cogstack community edition with all the default values.

!!! warning
    For brand new installations, this might take a while, so expect up to 15 minutes. It needs to download    many GB of docker images first and then startup processes.
    
    Once the initial installation is done, then any updates should be significantly faster.
    
    The defaults are set for a production-ready environment. See [Deployment](../../platform/deployment/_index.md) for detailed deployment information and customization options.


## Port-forward and open JupyterHub

1. Set up the port-forwarding endpoints for the services:

<!-- termynal -->

```sh
$ helm get notes cogstack | bash
bash: line 1: NOTES:: command not found
Forwarding from 127.0.0.1:5001 -> 5000
Forwarding from [::1]:5001 -> 5000
Forwarding from 127.0.0.1:5000 -> 5000
Forwarding from [::1]:5000 -> 5000
...
Visit http://127.0.0.1:5000 to use MedCAT Service
Visit http://127.0.0.1:5001 to use AnonCAT
Visit http://127.0.0.1:8080 to use MedCAT Trainer
Visit https://127.0.0.1:9200 to use OpenSearch
Visit http://127.0.0.1:5601 to use OpenSearch Dashboards
Visit http://127.0.0.1:8000 to use jupyterhub
Visit http://127.0.0.1:8000/user/admin/notebooks/medcat-service-tutorial.ipynb to get started with a tutorial
   ```

   This command runs `kubectl port-forward` in the background.

2. Open JupyterHub:

   - http://127.0.0.1:8000

If you use a custom namespace or Helm release name, replace `cogstack` in the commands above with your own release name.

## Next step: run the bundled notebook

Continue with: [Tutorial: Open and operate JupyterHub](./end-to-end-jupyterhub.md).

