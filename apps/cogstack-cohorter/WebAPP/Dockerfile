FROM node:20
WORKDIR /usr/src/app/client-react
COPY client-react/package*.json ./
RUN --mount=type=secret,id=npm_token,required=true \
    sh -c ' \
      TOKEN=$(cat /run/secrets/npm_token) && \
      echo "Token length: ${#TOKEN}" && \
      echo "@cogstack:registry=https://npm.pkg.github.com/" > ~/.npmrc && \
      echo "//npm.pkg.github.com/:_authToken=$TOKEN" >> ~/.npmrc && \
      npm whoami --registry=https://npm.pkg.github.com && \
      npm ci \
    '
COPY client-react/ ./
RUN npm ls vite
RUN npm run build

# Stage 2: Server
WORKDIR /usr/src/app
COPY server/package*.json ./server/
RUN cd server && npm install

COPY server/ ./server/
COPY entrypoint.sh /entrypoint.sh
# Strip Windows CRLF line endings that break the shebang on Linux.
RUN sed -i 's/\r//' /entrypoint.sh && chmod +x /entrypoint.sh

EXPOSE 3000
WORKDIR /usr/src/app/server
ENTRYPOINT ["/entrypoint.sh"]
