FROM node:latest
WORKDIR /usr/src/app

COPY . .
RUN cd /usr/src/app/client-react && npm install && npm run build
RUN cd /usr/src/app/server && npm install

COPY entrypoint.sh /entrypoint.sh
RUN sed -i 's/\r$//' /entrypoint.sh && chmod +x /entrypoint.sh

EXPOSE 3000
WORKDIR /usr/src/app/server
ENTRYPOINT ["/entrypoint.sh"]
