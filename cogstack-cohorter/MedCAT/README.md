# MedCAT API (Cohorter)

This folder contains the **MedCAT annotation API** used by the Cohorter application.

It is packaged as a Docker service and is typically run via the root `docker-compose.yml` together with:
- `NL2DSL/` (natural language → JSON DSL)
- `WebAPP/` (main UI/backend)
- `ollama` (LLM backend)

> **Important:** The MedCAT **model pack is NOT committed** to GitHub.  
> You must provide it locally and mount it into the container at runtime.

---

## What this service does

- Loads a MedCAT **model pack** (zip) from a local path
- Exposes HTTP endpoints for concept annotation (used by the WebAPP / NL2DSL)

---

## File layout

- `app.py` — FastAPI app entrypoint
- `requirements.txt` — Python dependencies (includes `medcat`, `fastapi`, `uvicorn`, `spacy`, etc.)
- `Dockerfile` — Container build
- `models/` — **Local-only** model pack location (not tracked by git)
- `docker_build.sh`, `docker_run.sh` — legacy helper scripts (optional if you use Docker Compose)

---

## Prerequisites

- Docker (recommended)
- Alternatively: Python 3.11+ if running locally without Docker

---

## Model pack setup (local only)

Place your model pack zip at:

```
MedCAT/models/medcat_model_pack.zip
```

Make sure it is ignored by git (root `.gitignore` should include `MedCAT/models/` or the `.zip`).

---

## Run with Docker Compose (recommended)

From the **repo root**:

```bash
docker compose up --build medcat
```

MedCAT API will be available at:

- http://localhost:3001

---

## Run standalone with Docker (optional)

From within the `MedCAT/` folder:

```bash
docker build -t cohorter-medcat:latest .
docker run --rm -it \
  -p 3001:3001 \
  -v "$(pwd)/models/medcat_model_pack.zip:/app/models/medcat_model_pack.zip:ro" \
  cohorter-medcat:latest
```

---

## Environment variables

The Dockerfile sets defaults:

- `HOST` (default `0.0.0.0`)
- `PORT` (default `3001`)
- `MEDCAT_MODEL_PACK` (default `/app/models/medcat_model_pack.zip`)

If you want to override:

```bash
docker run --rm -it \
  -p 3001:3001 \
  -e PORT=3001 \
  -e MEDCAT_MODEL_PACK=/app/models/medcat_model_pack.zip \
  -v "$(pwd)/models/medcat_model_pack.zip:/app/models/medcat_model_pack.zip:ro" \
  cohorter-medcat:latest
```

---

## Health check / quick test

If your API exposes a health endpoint (commonly `/health`), test:

```bash
curl -sS http://localhost:3001/health
```

If your API exposes an annotation endpoint, you can test it similarly (endpoint name depends on `app.py`).

---

## Notes

- The Docker image installs `en_core_web_sm` during build.
- The model pack is mounted read-only into the container for safety.
- Do **not** commit model packs or any sensitive data into the repository.

---

## Troubleshooting

### Model pack not found
- Confirm the file exists locally:
  ```bash
  ls -lh MedCAT/models/medcat_model_pack.zip
  ```
- Confirm it is mounted inside the container:
  ```bash
  docker exec -it cohorter-medcat ls -lh /app/models/
  ```

### Port already in use
Change the host port mapping:
```bash
docker run -p 3101:3001 ...
```
