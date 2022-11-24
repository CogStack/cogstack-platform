FROM node:latest
WORKDIR /usr/src/app
COPY . .
RUN cd server && npm install
EXPOSE 3000
WORKDIR /usr/src/app/server
CMD ["node", "--max-old-space-size=32768", "server.js"]
