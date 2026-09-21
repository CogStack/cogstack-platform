# Cogstack-NiFi

### Major changes from Cogstack-Pipeline

There are some key major changes when using and deploying Apache NiFi as compared with CogStack-Pipeline.

One of the most important changes is the way how defining, configuring and monitoring data flows works. When using CogStack-Pipeline the ingestion jobs were defined in `.properties` files and were having very limited job execution monitoring and troubleshooting possibilities. Apache NiFi implements (an optional) web-based user interface that can be used to define data flows on drag-and-drop fashion with further configuration and monitoring capabilities. The data flow definitions can be saved and exported into XML format and later loaded into other instances of Apache NiFi or just kept under version control.

Each ingestion job that is being run by CogStack-Pipeline also requires a separate CogStack-Pipeline application instance. In Apache NiFi multiple data flows can be run in parallel each being managed by a single, main Apache NiFi data processing engine instance.

Moreover, one of the main limitations of CogStack pipeline has been support only for a document-centric data model for performing ingestion where each ingested record could only contain one document to be processed. Apache NiFi does not enforce document-centric data model and provides flexibility on defining custom data flows and data schemas. Handling multiple documents in a single record or using a patient-centric data model is a matter of tailoring the pipeline and defining or tailoring appropriate schema.

Moreover, fixed ETL operations (implemented as modules in CogStack-Pipeline) can be included as custom ETL scripts or application modules inside a defined Apache NiFi data flow. For example, NLP functionality, such as running [MedCAT](https://github.com/CogStack/MedCATservice) was implemented as external micro-services exposing that expose a REST API and hence can be used directly in the data flow. All the third-party application dependencies are handled by the external services that further allows for separating the responsibilities.
