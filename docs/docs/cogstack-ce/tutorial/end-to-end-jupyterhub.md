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

    To see a non-interactive version of the tutorial notebook, refer to [the MedCAT Service Tutorial notebook](../../platform/cogstack-ai/medcat-service-tutorial.ipynb).

## Before you start

Make sure your CogStack CE release is installed and local port-forwarding is running.

If needed, re-run:

```sh
helm get notes <release> | bash
```

Replace `<release>` with your Helm release name (for example, `cogstack`).

## Step 1: Open JupyterHub

Open:

- http://127.0.0.1:8000

This should show the JupyterHub login page.

## Step 2: Log in

The community chart uses a dummy authenticator (for local/non-production use).

Log in with:

- Username: `admin`
- Password: `SuperSecret`

After login, JupyterLab opens for your user.

## Step 3: Open the bundled notebook

The chart includes an example notebook:

- `medcat-service-tutorial.ipynb`

You can open it directly:

- http://127.0.0.1:8000/user/admin/notebooks/medcat-service-tutorial.ipynb

Or navigate to it in JupyterLab and click to open it.

## Step 4: Run the notebook cells

Run each cell in order from top to bottom.

The notebook demonstrates service calls to:

- `medcat-service` at `/api/process` for named entity extraction
- `anoncat-service` at `/api/process` for de-identification

It uses environment variables for service URLs where available, so the default CogStack CE setup should work without edits.

## Step 5: Verify the end-to-end outputs

As you run cells, confirm that:

- MedCAT returns annotation output for the sample text
- AnonCAT returns de-identified output
- The JSON responses are displayed in the notebook

If those outputs appear, you have validated the full end-to-end flow from JupyterHub to deployed CogStack CE services.

## Troubleshooting

- If JupyterHub does not load, ensure port-forwarding is running.
- If notebook requests fail, verify the cluster services are up and re-run:

  - `helm get notes <release> | bash`
- For production deployments, replace dummy authentication with secure auth configuration.


## Next Steps

- See the [full deployment documentation](../../platform/deployment/_index.md) for more details on scaling, production security, and advanced configuration options.
- See full install instructions of the cogstack CE chart[CogStack CE Helm chart (install + customization)](../../platform/deployment/helm/charts/cogstack-ce-helm.md)
- See further tutorials on medcat on [GitHub](https://github.com/CogStack/cogstack-nlp/tree/79f00cfc204f4ae559b56c8e397bbcaf82d44274/medcat-v2-tutorials)