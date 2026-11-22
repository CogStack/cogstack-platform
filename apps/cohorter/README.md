# CogStack Cohorter (MedCAT + NL2DSL + WebAPP)

A lightweight cohort discovery application that combines:
- **MedCAT** annotations API (clinical concept extraction)
- **NL2DSL** API (natural language → JSON cohort query via Ollama)
- **WebAPP** (frontend + backend for the full Cohorter experience)

**Live demo:** https://cogstackcohort.sites.er.kcl.ac.uk/

![Cohorter demo](./cohorter.gif)

---

## Repository structure
- `NL2DSL/`  
  API service that accepts natural language queries, calls **Ollama** to translate them into a JSON DSL query, and uses MedCAT to normalize medical terms.

- `WebAPP/`  
  Full application (frontend + backend) providing the UI and orchestration of the workflow.

- `docker/`: Docker Compose configuration for the full stack.

---

## Quick start (Docker Compose)

### Prerequisites
- Docker Desktop (or Docker Engine) with Docker Compose
- (Optional) GPU setup if you want Ollama GPU acceleration (depends on your host OS)

### 1) Build and start all services
From `apps/cohorter/`, configure [`env/cohorter.env`](env/cohorter.env), then run
Compose from `docker/`:

```bash
cd docker
docker compose --env-file ../env/cohorter.env up --build
```

Or run in background:

```bash
docker compose --env-file ../env/cohorter.env up --build -d
```

### 2) Access the app
- Web UI: http://localhost:3000  
- MedCAT API: http://localhost:5000
- NL2DSL API: http://localhost:3002  
- Ollama: http://localhost:11434  

---

## Configuration

### NL2DSL environment variables (via docker/docker-compose.yml)

NL2DSL uses:
- `OLLAMA_URL` (default in compose: `http://ollama:11434/api/generate`)
- `OLLAMA_MODEL` (default: `llama3.2:3b`)
- `MEDCAT_URL` (default: `http://cohorter-medcat:5000`)
- `ALLOW_ORIGINS` (default: `*`)

### WebAPP environment variables
WebAPP uses:
- `NL2DSL_URL` (default: `http://cohorter-nl2dsl:3002`)

### WebAPP random data generation (optional)
Set the runtime `RANDOM_DATA` variable to generate random data:

```bash
RANDOM_DATA=true docker compose --env-file ../env/cohorter.env up --build
```

Set `RANDOM_DATA=false` in `env/cohorter.env` to disable random data generation.

---

## Development

You can work on each component independently:

- `NL2DSL/` — API service (see its folder README)
- `WebAPP/` — Node app (server + client)

Each folder contains its own `Dockerfile` and scripts.

---

## Notes on models and licensing

- MedCAT model packs and any potentially sensitive data **must not** be committed to the repository.
- Ollama models are stored in a Docker named volume by default (`ollama:` in `docker/docker-compose.yml`) so they persist across restarts.

---

## Troubleshooting

### Rebuild everything cleanly
```bash
docker compose --env-file ../env/cohorter.env down
docker compose --env-file ../env/cohorter.env up --build
```

### Remove Ollama downloaded models (if needed)
This deletes the named volume that stores Ollama models:

```bash
docker compose --env-file ../env/cohorter.env down -v
```

### Check logs
```bash
docker compose --env-file ../env/cohorter.env logs -f
```

---

## Acknowledgements
Built within the CogStack ecosystem to support clinical cohort discovery workflows.
