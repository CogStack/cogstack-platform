FROM node:20

ARG VITE_OAUTH2_USERINFO_PATH
ARG VITE_OAUTH2_LOGIN_PATH
ARG VITE_OAUTH2_LOGOUT_PATH

# VITE_* vars must be ENV (not just ARG) for Vite to pick them up at build time.
ENV VITE_OAUTH2_USERINFO_PATH=${VITE_OAUTH2_USERINFO_PATH}
ENV VITE_OAUTH2_LOGIN_PATH=${VITE_OAUTH2_LOGIN_PATH}
ENV VITE_OAUTH2_LOGOUT_PATH=${VITE_OAUTH2_LOGOUT_PATH}

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
