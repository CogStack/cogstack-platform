# CogStack CE Product Tour

This page gives an overview of the deployed apps in the CogStack Helm chart (Community Edition).

In this tour, we will:

- Open each app in the browser using the local port-forwarded URL.
- Test that the applications are up and running
- See some basic features of each app
- Point you to the relevant documentation for next steps.

## Before you start

!!! tip
    To follow allong with this tour, you should have the cogstack CE installed and local port-forwarding running.

    If needed, re-run this command to port-forward again:

    ```sh
    helm get notes cogstack | bash
    ```

    Running this command will also print all of the URLs for the apps. To follow along with the rest of this tour, you can click the links in your terminal window to open the apps.

## Product Tour

### medcat-service

Open the MedCAT UI at `http://127.0.0.1:5000`, load the sample text, and click Annotate. The concepts and annotations will appear in the results panel on the right.

For a walkthrough of this service in the CogStack platform docs, see [MedCAT service tutorial](../platform/cogstack-ai/medcat-service-tutorial.ipynb).

To learn more about MedCAT and related services, see [CogStack NLP on GitHub](https://github.com/CogStack/cogstack-nlp).

<video autoplay loop muted playsinline controls style="max-width: 100%; height: auto;">
  <source src="../../assets/tour/medcat-service-demo.webm" type="video/webm">
</video>

### AnonCAT Service

Open the AnonCAT UI at `http://127.0.0.1:5001`, load the sample, and click Annotate. The processed/anonymised output will be shown on the right.

For a walkthrough of this service in the CogStack platform docs, see [MedCAT service tutorial](../platform/cogstack-ai/medcat-service-tutorial.ipynb).

To learn more about AnonCAT and related services, see [CogStack NLP on GitHub](https://github.com/CogStack/cogstack-nlp).

<video autoplay loop muted playsinline controls style="max-width: 100%; height: auto;">
  <source src="../../assets/tour/anoncat-service-demo.webm" type="video/webm">
</video>

### MedCAT Trainer

Open MedCAT Trainer at `http://127.0.0.1:8080` and log in with your credentials. You should see it provisioned with two projects corresponding to the two services; open either project to view the documents and start annotating.

For a deeper guide to projects and annotation workflows, see the [MedCATtrainer documentation](https://docs.cogstack.org/projects/medcat-trainer/en/latest/).

<video autoplay loop muted playsinline controls style="max-width: 100%; height: auto;">
  <source src="../../assets/tour/medcat-trainer-demo.webm" type="video/webm">
</video>

### JupyterHub

Open JupyterHub at `http://127.0.0.1:8000` and log in with your credentials, then wait for your server to start. Open the demo notebook and run it to see the example workflow.

For the end-to-end walkthrough in these docs, see [End-to-end JupyterHub](tutorial/end-to-end-jupyterhub.md).

For more details on the JupyterHub setup used here, see [CogStack Jupyter Hub on GitHub](https://github.com/CogStack/cogstack-jupyter-hub/).

!!! warning

    If this is the first time opening jupyterhub, it might take a while starting up your user container. This is mostly spent downloading the cogstack-singleuser

<video autoplay loop muted playsinline controls style="max-width: 100%; height: auto;">
  <source src="../../assets/tour/jupyterhub-demo.webm" type="video/webm">
</video>

### OpenSearch Dashboards

Open OpenSearch Dashboards at `http://127.0.0.1:5601` and log in with your credentials. Browse to Dashboards and open the sample dashboard to explore the visualisations.

By default in the cogstack community edition, it will generate and load test data and a sample dashboard.

<video autoplay loop muted playsinline controls style="max-width: 100%; height: auto;">
  <source src="../../assets/tour/opensearch-dashboard-demo.webm" type="video/webm">
</video>

## Summary and Next Steps

You've now tried out the UIs of each deployed app in the cogstack community edition. 

Next you can try using them in code by following the end-to-end tutorial at [End-to-end JupyterHub](./tutorial/end-to-end-jupyterhub.md).