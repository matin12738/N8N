FROM n8nio/n8n:latest

USER root

COPY start.sh /docker-entrypoint.d/99-custom-env-parser.sh

RUN chmod 0755 /docker-entrypoint.d/99-custom-env-parser.sh \
    && chown node:node /docker-entrypoint.d/99-custom-env-parser.sh

USER node

EXPOSE 5678