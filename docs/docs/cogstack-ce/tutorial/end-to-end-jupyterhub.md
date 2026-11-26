# End-to-end JupyterHub tutorial

In this tutorial, you will open JupyterHub and run a notebook that calls deployed CogStack CE services.

By the end, you will have completed an end-to-end user flow:

1. Open JupyterHub
2. Log in
3. Open the bundled tutorial notebook
4. Run cells that call MedCAT and AnonCAT service APIs
5. Inspect the outputs

!!! tip
    The following tutorial will use your CogStack CE installation and let you run real code against your environment.

    To see a non-interactive version of the tutorial notebook, refer to:

    - [the MedCAT Service Tutorial notebook](../../platform/cogstack-ai/medcat-service-tutorial.ipynb).
    - [the OpenSearch E2E notebook](./medcat-opensearch-e2e.ipynb).

## Before you start

Make sure CogStack CE is installed and local port-forwarding is running.

If needed, re-run the port-forward commands from the [Quickstart](./quickstart-installation.md#port-forward-and-open-jupyterhub), for example:

```sh
kubectl -n cogstack port-forward svc/jupyterhub 8000:8000 &
```

## Step 1: Open JupyterHub

Open:

- http://127.0.0.1:8000

This should show the JupyterHub login page.

## Step 2: Log in

CogStack CE uses a dummy authenticator (for local/non-production use).

Log in with:

- Username: `admin`
- Password: `SuperSecret`

After login, JupyterLab opens for your user.

## Step 3: Open the bundled notebooks

CogStack CE includes example notebooks to interact with CogStack CE:

- `medcat-service-tutorial.ipynb`
- `medcat-opensearch-e2e.ipynb`

You can open it directly:

- http://127.0.0.1:8000/user/admin/notebooks/medcat-service-tutorial.ipynb

Or navigate to it in JupyterLab and click to open it.

## Step 4: Run the notebook cells

Run each cell in order from top to bottom.

The notebooks demonstrates service calls to:

- `medcat-service` at `/api/process` for named entity extraction
- `anoncat-service` at `/api/process` for de-identification
- `OpenSearch` for indexing and searching data.

It uses environment variables for service URLs where available, so the default CogStack CE setup should work without edits.

## Step 5: Verify the end-to-end outputs

As you run cells, confirm that:

- MedCAT returns annotation output for the sample text
- AnonCAT returns de-identified output
- The JSON responses are displayed in the notebook

If those outputs appear, you have validated the full end-to-end flow from JupyterHub to deployed CogStack CE services.

## Troubleshooting

- If JupyterHub does not load, ensure port-forwarding is running.
- If notebook requests fail, verify the cluster services are up with `kubectl -n cogstack get pods`, and re-run the port-forward commands.

- For production deployments, replace dummy authentication with secure auth configuration.

## Next Steps

- See the [full deployment documentation](../../platform/deployment/index.md) for more details on scaling, production security, and advanced configuration options.
- See the [Kubernetes manifests](../../platform/deployment/kubernetes.md) for full install instructions and customisation
- See further tutorials on medcat on [GitHub](https://github.com/CogStack/cogstack-nlp/tree/79f00cfc204f4ae559b56c8e397bbcaf82d44274/medcat-v2-tutorials)
