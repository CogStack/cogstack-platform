FROM node:20-alpine

ENV NODE_ENV=production \
    PORT=3002 \
    OLLAMA_URL=http://ollama:11434/api/generate \
    OLLAMA_MODEL=gpt-oss:20b \
    MEDCAT_URL=http://cohorter-medcat:3001 \
    ALLOW_ORIGINS=*

WORKDIR /app

# Install deps first (better layer caching)
COPY package.json package-lock.json* ./
RUN npm ci --only=production || npm i --only=production

# Copy app code
COPY server.js ./server.js
COPY public ./public

EXPOSE 3002

# Optional healthcheck (needs apk add curl if you want)
# RUN apk add --no-cache curl
# HEALTHCHECK --interval=30s --timeout=3s CMD curl -fsS http://localhost:3002/ || exit 1

CMD ["node", "server.js"]
