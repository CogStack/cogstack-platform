FROM python:3.11-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    HOST=0.0.0.0 \
    PORT=3001 \
    MEDCAT_MODEL_PACK=/app/models/medcat_model_pack.zip

WORKDIR /app

# System deps
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential curl \
  && rm -rf /var/lib/apt/lists/*

# Python deps
COPY requirements.txt .
RUN pip install --upgrade pip \
 && pip install -r requirements.txt \
 && python -m spacy download en_core_web_sm
# requirements.txt: medcat, fastapi, uvicorn, pydantic, spacy. :contentReference[oaicite:0]{index=0}

# App code
COPY . .

EXPOSE 3001

# Optional healthcheck
#HEALTHCHECK --interval=30s --timeout=3s CMD curl -fsS http://localhost:3001/health || exit 1

# Start server
CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "3001", "--workers", "1"]
