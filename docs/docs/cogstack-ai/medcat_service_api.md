# MedCAT Service API

### REST API definition

The API defines 3 endpoints, that consume and return data in JSON format:

- *GET* `/api/info` - displays general information about the the NLP application,
- *POST* `/api/process` - processes the provided single document and returns back the annotations,
- *POST* `/api/process_bulk` - processes the provided list of documents and returns back the annotations.

#### GET `/api/info`

Returns information about the used NLP application. The returned fields are:

- `name`, `version`, `language` of the underlying NLP application
- `parameters` – a generic JSON object representing any relevant parameters that have been specified to the application (optional)

#### POST `/api/process`

Returns the annotations extracted from the provided document.

The request message payload JSON consists of following objects

- `content` that represents the single document content to be processed
- `applicationParams` – a generic JSON object representing NLP application run-time parameters (optional)

The single document processing `content` (\*\*\*) has following keys :

- `text` – the document to be processed
- `metadata` – a generic JSON object representing any relevant metadata associated with the document that will be consumed by the NLP application (optional)
- `footer` – a generic JSON object representing a payload footer that will be returned back with the result (optional)

The response message payload JSON consists of an object `result` that has following fields:

- `text` – the input document that was processed (optional)
- `annotations` – an array of generic JSON annotation objects, not enforcing any schema
- `metadata` – a metadata associated with the processed document that was reported by the NLP application (optional)
- `success` – boolean value indicating whether the NLP processing was successful
- `timestamp` – document processing timestamp
- `errors` – an array of NLP processor errors (present only in case when `success` is `false`)
- `footer` – the footer object as provided in the request payload (present only when provided in the request message)

#### POST `/api/process_bulk`

Returns the annotations extracted from a list of documents.

The request message payload JSON consists of following objects

- `content` – an array of documents content to be processed
- `applicationParams` – a generic JSON object representing NLP application run-time parameters (optional)

Here, the `content` object holds an array of single document content to be processed as defined above in (\*\*\*).

### Example use

!!! tip

    Please see [CogStack using Apache NiFi Deployment Examples](https://github.com/CogStack/CogStack-NiFi/tree/devel/deploy) to see how to deploy example NLP services, i.e. MedCAT with a public MedMentions model.

#### MedCAT

Assuming that the application is running on the `localhost` with the API exposed on port `5000`, one can run:

```bash
curl -XPOST http://localhost:5000/api/process \
  -H 'Content-Type: application/json' \
  -d '{"content":{"text":"The patient was diagnosed with leukemia."}}'

```

and the received result:

```json
{
  "result": {
    "text": "The patient was diagnosed with leukemia.",
    "annotations": [
      {
        "pretty_name": "leukemia",
        "cui": "C0023418",
        "tui": "T191",
        "type": "Neoplastic Process",
        "source_value": "leukemia",
        "acc": "1",
        "start": 31,
        "end": 39,
        "info": {},
        "id": "0",
        "meta_anns": {}
      }
    ],
    "success": true,
    "timestamp": "2019-12-03T16:09:58.196+00:00"
  }
}
```