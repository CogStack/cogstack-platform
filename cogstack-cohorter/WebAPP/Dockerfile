FROM node:20-alpine

ARG VITE_OAUTH2_USERINFO_PATH
ARG VITE_OAUTH2_LOGIN_PATH
ARG VITE_OAUTH2_LOGOUT_PATH

# VITE_* vars must be ENV (not just ARG) for Vite to pick them up at build time.
ENV VITE_OAUTH2_USERINFO_PATH=${VITE_OAUTH2_USERINFO_PATH}
ENV VITE_OAUTH2_LOGIN_PATH=${VITE_OAUTH2_LOGIN_PATH}
ENV VITE_OAUTH2_LOGOUT_PATH=${VITE_OAUTH2_LOGOUT_PATH}

WORKDIR /usr/src/app
RUN mkdir -p client-react
COPY client-react/ ./client-react/
WORKDIR /usr/src/app/client-react


RUN --mount=type=secret,id=npm_token,required=true \
    sh -c 'echo "@cogstack:registry=https://npm.pkg.github.com/" > ~/.npmrc && \
           echo "//npm.pkg.github.com/:_authToken=$(cat /run/secrets/npm_token)" >> ~/.npmrc && \
           npm ci && npm run build'

# Stage 2: Server
WORKDIR /usr/src/app
COPY server/package.json server/package-lock.json* ./server/
RUN cd server && npm install

COPY server/ ./server/

COPY entrypoint.sh /entrypoint.sh
RUN sed -i 's/\r$//' /entrypoint.sh && chmod +x /entrypoint.sh

EXPOSE 3000
WORKDIR /usr/src/app/server
ENTRYPOINT ["/entrypoint.sh"]
