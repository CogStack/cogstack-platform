# Data pipelines

## Introduction

This page covers the data pipelines used in CogStack ecosystem.

## CogStack-NiFi

### Overview
CogStack-NiFi is the re-architected version of CogStack-Pipeline that replaces the fixed Spring Batch-based pipeline engine with [Apache NiFi](https://nifi.apache.org/). It focuses on fully configurable and scalable data flows with the data processing engine that is easy to use, deploy and tailor to any site-specific data flow requirements. Apache NiFi also comes in with build-in monitoring, data provenance and security features that puts the operations in better control and reliability.

**CogStack-NiFi useful links:**

- GitHub: [https://github.com/CogStack/CogStack-NiFi](https://github.com/CogStack/CogStack-NiFi)
- Documentation with deployment examples: [https://github.com/CogStack/CogStack-NiFi/tree/devel/deploy](https://github.com/CogStack/CogStack-NiFi/tree/devel/deploy)
- Documentation on available services: [https://github.com/CogStack/CogStack-NiFi/tree/devel/services](https://github.com/CogStack/CogStack-NiFi/tree/devel/services)
- DockerHub: [https://cloud.docker.com/repository/docker/cogstacksystems/nifi](https://cloud.docker.com/repository/docker/cogstacksystems/nifi)

**Apache NiFi resources:**

- The official website: [https://nifi.apache.org/](https://nifi.apache.org/)
- The official documentation: [https://nifi.apache.org/docs.html](https://nifi.apache.org/docs.html)

![](./attachments/b5fc6b57-faf2-4747-9e77-eb9adf51d8b3.jpg)


### Apache NiFi – overview

*From the official documentation:* Apache NiFi is a dataflow system based on the concepts of flow-based programming. It supports powerful and scalable directed graphs of data routing, transformation, and system mediation logic. NiFi has a web-based user interface for design, control, feedback, and monitoring of dataflows. It is highly configurable along several dimensions of quality of service, such as loss-tolerant versus guaranteed delivery, low latency versus high throughput, and priority-based queuing. NiFi provides fine-grained data provenance for all data received, forked, joined cloned, modified, sent, and ultimately dropped upon reaching its configured end-state.

Some of the key features of Apache NiFi engine are:

- Highly configurable and extendable

  - Can build own data processors and modules that can be easily integrated into data pipeline
  - Enables rapid prototyping, development and effective testing
  - Data flows can be modified, inspected and troubleshoot at runtime
- Web-based user interface

  - Seamless experience between design, control, feedback, and monitoring of the data flows
- Data Provenance

  - Can track data flow from beginning to end for addressing information governance requirements
- Security

  - Support for SSL, SSH, HTTPS, encrypted content, etc.
  - Multi-tenant authorization and internal authorization/policy management

For a detailed description of Apache NiFi, it’s functionality and broad set of features please refer to [the official documentation](https://nifi.apache.org/docs.html) and [the official Apache NiFi website](https://nifi.apache.org/).

### Major changes from CogStack-Pipeline

There are some key major changes when using and deploying Apache NiFi as compared with CogStack-Pipeline.

One of the most important changes is the way how defining, configuring and monitoring data flows works. When using CogStack-Pipeline the ingestion jobs were defined in `.properties` files and were having very limited job execution monitoring and troubleshooting possibilities. Apache NiFi implements (an optional) web-based user interface that can be used to define data flows on drag-and-drop fashion with further configuration and monitoring capabilities. The data flow definitions can be saved and exported into XML format and later loaded into other instances of Apache NiFi or just kept under version control.

Each ingestion job that is being run by CogStack-Pipeline also requires a separate CogStack-Pipeline application instance. In Apache NiFi multiple data flows can be run in parallel each being managed by a single, main Apache NiFi data processing engine instance.

Moreover, one of the main limitations of CogStack pipeline has been support only for a document-centric data model for performing ingestion where each ingested record could only contain one document to be processed. Apache NiFi does not enforce document-centric data model and provides flexibility on defining custom data flows and data schemas. Handling multiple documents in a single record or using a patient-centric data model is a matter of tailoring the pipeline and defining or tailoring appropriate schema.

Moreover, fixed ETL operations (implemented as modules in CogStack-Pipeline) can be included as custom ETL scripts or application modules inside a defined Apache NiFi data flow. For example, NLP functionality, such as running [MedCAT](https://github.com/CogStack/MedCATservice) was implemented as external micro-services exposing that expose a REST API and hence can be used directly in the data flow. All the third-party application dependencies are handled by the external services that further allows for separating the responsibilities.


### Example deployment and services

Please see [CogStack-NiFI example deployment with workflow examples](https://github.com/CogStack/CogStack-NiFi/tree/devel/deploy) .
