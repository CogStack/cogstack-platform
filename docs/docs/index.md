<p align="center">
  <img src="assets/brand-logo-dark.svg" alt="CogStack Logo">
</p>
Welcome to the CogStack Documentation site.

## What is CogStack?

CogStack lets you unlock the power of healthcare data.

CogStack is a healthcare suite with interchangeable modules for analysing clinical data using AI to draw insights from text in or documents in an Electronic Health Records.

There are a wide range of features including Generative AI, Natural Language Processing, Full Search, Alerting, Cohort Selection, Population Health Dashboards, Deep Phenotyping and Clinical Research.

CogStack is a commercial open-source product, with the code for the community edition available on GitHub: [https://github.com/CogStack/](https://github.com/CogStack/). For enterprise deployments, full platform setup, and advanced features, please [contact us](https://docs.cogstack.org/en/latest/).

<div class="grid cards" markdown>

-   :zap:{ .lg .middle } **Quickstart Guide**

    ---

    Get running in under 5 minutes with our clean templates.

    [:octicons-arrow-right-24: Get started](platform/deployment/get-started/quickstart.md)

-   :book:{ .lg .middle } **Website**

    ---

    Get in-depth understanding of what CogStack is, and all that it offers.

    [:octicons-arrow-right-24: Visit site](https://cogstack.org/)

-   :key:{ .lg .middle } **Libraries**

    ---

    Peek at the libraries that power CogStack.

    [:octicons-arrow-right-24: Browse](https://github.com/orgs/CogStack/repositories)

</div>

CogStack is comprised of a suite of applications, all using a common AI and data engineering platform. It is designed to be a self hosted platform where you run your own instances and keep all of your data on premise, with full support for air gapped environments.

**The applications provide features for:**

- Clinical Coding
- Search and Audit of EHRs
- Cohorting
- EHR Analytics
- DeIdentification of patient records
- Clinical Decision Support (CDS)

---

## Architecture

![CogStack Architecture](overview/attachments/architecture.png)

To understand the flow of CogStack, and the tools it offers, the below section will provide a brief overview:

## Components of CogStack

### CogStack NiFi

It all begins with Data Engineering, pulling in data from all sources, and creating a data lake for all subsequent resources to use.

Apache NiFi provides fully configurable and scalable data flows with built-in monitoring, data provenance and security features.

[:octicons-arrow-right-24: Explore CogStack NiFi](data-engineering/index.md)

### NLP

Performing Named Entity Recognition and Linking (NER+L), extracting contextual attributes like temporality and subject, and extracting relations between entities is all part of the NLP toolkit.

MedCAT for NER+L, MetaCAT for contextual attribute extraction and RelCAT for relation extraction.

[:octicons-arrow-right-24: Explore NLP](cogstack-ai/overview.md)

### Deployment

To run CogStack and its tools, the deployment guide helps with running, scaling, observing, dashboarding and alerting.

Helm, Docker Compose and cloud options are all covered in the tutorial.

[:octicons-arrow-right-24: Explore Deployment](platform/deployment/_index.md)

!!! tip

    Many of these apps and tools are open source and available on GitHub (subject to the licensing in each project), in the [CogStack GitHub](https://github.com/CogStack).

    The public documentation on this page covers these open source community offerings.

    For advanced use cases and enterprise features see our range of [products](https://cogstack.org/products/).

---

## Support

- **Questions?** Reach out in the [CogStack community forum](https://discourse.cogstack.org/).
- **Code and projects:** [CogStack on GitHub](https://github.com/orgs/CogStack/repositories).