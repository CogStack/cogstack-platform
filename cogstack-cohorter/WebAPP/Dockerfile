FROM node:latest
WORKDIR /usr/src/app

COPY . .
RUN cd /usr/src/app/client-react && npm install && npm run build
RUN cd /usr/src/app/server && npm install

# Bundle the demo SNOMED data archive so random/demo mode works with no volume mount.
# Kept separate from server/data/ so a runtime volume mount doesn't shadow it.
RUN mkdir -p /usr/src/app/server/data-bundled
RUN cp /usr/src/app/server/data/snomed_terms_data.tar.gz /usr/src/app/server/data-bundled/

COPY entrypoint.sh /entrypoint.sh
RUN sed -i 's/\r$//' /entrypoint.sh && chmod +x /entrypoint.sh

EXPOSE 3000
WORKDIR /usr/src/app/server
ENTRYPOINT ["/entrypoint.sh"]
