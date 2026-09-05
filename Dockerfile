FROM n8nio/n8n:latest

USER root

ENV N8N_HOST=0.0.0.0
ENV N8N_PORT=5678
ENV N8N_PROTOCOL=http
ENV GENERIC_TIMEZONE=UTC

WORKDIR /usr/local/bin

COPY start.sh /start.sh
RUN chmod +x /start.sh

EXPOSE 5678

ENTRYPOINT ["/start.sh"]
