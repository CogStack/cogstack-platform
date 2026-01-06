# NL2DSL API (Cohorter)

This folder contains the **NL2DSL** service for the Cohorter application.

NL2DSL accepts a **natural-language cohort request** and uses an LLM (via **Ollama**) to translate it into a **JSON cohort DSL**. It can optionally call the **MedCAT** service for clinical concept annotation / normalization (depending on your server implementation).

This service is designed to run as part of the full stack (recommended) using the repo-root `docker-compose.yml`.

---

## What this service does

- Receives a natural language query (e.g., “adult HFpEF patients”)
- Calls **Ollama** (`/api/generate`) with a configured model
- Returns a **JSON DSL** representation suitable for the Cohorter WebAPP backend
- (Optional) Calls **MedCAT** for annotation support, if enabled in `server.js`

---

## Run with Docker Compose (recommended)

From the **repo root**:

```bash
docker compose up --build nl2dsl
```

NL2DSL API will be available at:

- http://localhost:3002

---

## Run standalone with Docker (equivalent to your current command)

Build the image from within `NL2DSL/`:

```bash
docker build -t cohorter-nl2dsl:latest .
```

Run:

```bash
docker run -d --name cohorter-nl2dsl \
  -p 3002:3002 \
  -e OLLAMA_URL="http://ollama:11434/api/generate" \
  -e OLLAMA_MODEL="gpt-oss:20b" \
  -e MEDCAT_URL="http://cohorter-medcat:3001" \
  -e ALLOW_ORIGINS="*" \
  --restart unless-stopped \
  cohorter-nl2dsl:latest
```

> If you run via Docker Compose and include the `ollama` service, `http://ollama:11434` will resolve automatically inside the compose network.

---

## Environment variables

NL2DSL reads the following environment variables (as used in `docker_run.sh` / your `docker run` command):

- `OLLAMA_URL`  
  Ollama generate endpoint URL, e.g. `http://ollama:11434/api/generate`

- `OLLAMA_MODEL`  
  Model name to use in Ollama, e.g. `gpt-oss:20b`

- `MEDCAT_URL`  
  MedCAT API base URL, e.g. `http://cohorter-medcat:3001`

- `ALLOW_ORIGINS`  
  CORS allowlist. Use `*` during local development.

---

## API usage (example)

The exact endpoints depend on `server.js`. Once running, you can confirm the routes by checking `server.js` or hitting any health route you expose.

Typical quick checks:

```bash
curl -sS http://localhost:3002
```

If your server exposes a health endpoint (commonly `/health`):

```bash
curl -sS http://localhost:3002/health
```

---

## Development notes

### Install dependencies locally (optional)

```bash
npm install
node server.js
```

(For local development, ensure Ollama is reachable and set the environment variables accordingly.)

---

## Troubleshooting

### Ollama not reachable
- If using Docker Compose with included Ollama: confirm `ollama` container is up
  ```bash
  docker compose ps
  ```
- Check Ollama is responding:
  ```bash
  curl -sS http://localhost:11434/api/tags
  ```

### Model not found in Ollama
Pull the model inside the ollama container (example):

```bash
docker exec -it ollama ollama pull gpt-oss:20b
```

(Replace with your actual model name.)
