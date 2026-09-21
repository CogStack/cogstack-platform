
# CogStack Natural Language Processing

## Overview

CogStack ecosystem provides a standard set of natural language processing applications that are used either as standalone applications or implemented as RESTful services with uniform API, each running in a Docker container. <br> These NLP applications when used inside the data processing pipeline cover one of the key steps of information extraction. They may include extracting medical concepts from free-text notes using a specific terminology, such as [SNOMED CT](https://en.wikipedia.org/wiki/SNOMED_CT) or using all the terminologies as available in [UMLS](https://www.nlm.nih.gov/research/umls/index.html). Often, more specialised applications will be built on top of the standard set of NLP applications provided in CogStack, utilising both structured and unstructured information tailored to a defined use-case. These custom applications can be further integrated into CogStack and used as a part of standard set of NLP applications.

!!! tip

    Please see [CogStack using Apache NiFi Deployment Examples](https://github.com/CogStack/CogStack-NiFi/tree/devel/deploy) to see how to integrate NLP services in example data pipelines.

!!! tip

    Apart from being integrated directly in the data processing pipeline, many NLP applications are often used as standalone applications and have a rich set of tools build around them – please see below for more details.

---
## Tools

### MedCAT - Medical Concept Annotation Tool

One of the key tools is MedCAT – a Medical Concept Annotation Tool that is used for Named Entity Recognition and Linking (NER+L) tasks for clinical concepts from free-text documents.

 MedCAT is based on a light-weight neural network that calculates vector embeddings and that is used for disambiguation and concept detection. MedCAT also uses Deep Learning Language Model that is used for detection of negation, experiencer or any other type of classification. <br/> MedCAT can utilise a concepts dictionary with a vocabulary provided by the end-user that will be used to perform annotate the concepts in the clinical notes. The provided concepts dictionary can be e.g., SNOMED CT terminology or full/ subset of UMLS resource. Apart from providing the vocabulary and concepts dictionary, the underlying MedCAT model can be further trained and fine-tuned for performing context-aware concept disambiguation with additional meta-annotations tasks. MedCAT be run also directly with pre-trained models. <br/> **MedCAT** can be used either as a standalone Python module, as a part of a model trainer application **MedCAT Trainer** or be deployed as a RESTful **MedCAT Service** inside a data processing pipeline. Below are briefly covered possible ways of working with MedCAT. <br/> 

!!! warning

    Please note that we only provide few basic models for MedCAT that have been prepared using open datasets. Some of the used models are restricted by the external licensing of the resource that was used to build it, such as SNOMED CT or UMLS. In such cases, the user needs to apply for an appropriate license – please see: [UMLS licensing](https://www.nlm.nih.gov/research/umls/knowledge_sources/metathesaurus/release/license_agreement.html) and [SNOMED CT licensing](http://www.snomed.org/snomed-ct/get-snomed).

!!! important

    When deploying MedCAT into data processing pipelines one may be interested in training and tailoring the MedCAT models as a part of model preparation. This can be done directly by using MedCAT Trainer or MedCAT library working with a corpus of input documents. Such trained model can be in the next step provided into MedCAT Service that will be deployed as a service and used in the data pipeline.

**Key resources:** <br>

- GitHub repository with code and documentation: <https://github.com/CogStack/MedCAT>
- MedCAT publication: <https://arxiv.org/abs/1912.10166>
- Tutorial on MedCAT: [MedCAT – Analysing Electronic Health Records](https://towardsdatascience.com/medcat-introduction-analyzing-electronic-health-records-e1c420afa13a) (in a series of articles)
- PIP repository: <https://pypi.org/project/medcat/>

!!! tip

    The MedCAT Python library is the functional core of MedCAT project. The library is used by MedCAT Trainer when training and updating the models. It is also used within the MedCAT Service that exposes the medical concepts extraction functionality.

### MedCAT Trainer

MedCAT Trainer is an interface for building, improving and customising a given Named Entity Recognition and Linking models for biomedical domain text. <br/> The models trained by MedCAT Trainer can be later used directly with custom Python applications using on MedCAT module. Alternatively, the models can be deployed in data pipelines, e.g. behind a RESTful API via MedCAT Service. <br/> 

**Key resources:** <br/><ul><li><p>GitHub repository with code and documentation: <a class="external-link" data-card-appearance="inline" href="https://github.com/CogStack/MedCATTrainer" rel="nofollow">https://github.com/CogStack/MedCATTrainer</a> </p></li><li><p>MedCAT Trainer publication: <a class="external-link" href="https://arxiv.org/abs/1907.07322" rel="nofollow">https://arxiv.org/abs/1907.07322</a></p></li><li><p>Tutorial on using MedCAT Trainer: <a class="external-link" href="https://towardsdatascience.com/medcattrainer-a-tool-for-inspecting-improving-and-customising-medcat-880a11297ebe" rel="nofollow">MedCATTrainer: A Tool For Inspecting, Improving and Customising MedCAT</a></p></li></ul> <br/> 

## MedCAT Service

MedCAT Service implements a RESTful API over MedCAT module to perform extraction of concepts from provided text. Usually, a single instance of MedCAT Service will be serving a single MedCAT model. Such model can be later deployed in data processing pipelines. The API specification is provided in the sections below.

**Key resources:**

- GitHub repository with code, documentation and use examples: <https://github.com/CogStack/MedCATservice>

!!! tip

    Please note that there is available public MedCAT model trained on MedMentions corpus that can be used to play with.
