#!/bin/sh
set -eu

if [ -n "${PORT:-}" ] && [ -z "${N8N_PORT:-}" ]; then
  export N8N_PORT="${PORT}"
fi

if [ -n "${WEBHOOK_URL:-}" ]; then
  export N8N_WEBHOOK_URL="${WEBHOOK_URL}"
fi

if [ -n "${DATABASE_URL:-}" ]; then
  echo "Configuring PostgreSQL from DATABASE_URL"
  export DB_TYPE=postgresdb

  db_url_without_scheme="${DATABASE_URL#postgres://}"
  db_user="${db_url_without_scheme%%@*}"
  db_password="${DATABASE_URL#*://}"
  db_password="${db_password#*:}"
  db_password="${db_password%%@*}"
  db_host_port="${DATABASE_URL#*@}"
  db_host_port="${db_host_port%%/*}"
  db_name="${DATABASE_URL##*/}"
  db_host="${db_host_port%%:*}"
  db_port="${db_host_port##*:}"

  export DB_POSTGRESDB_HOST="${db_host}"
  export DB_POSTGRESDB_PORT="${db_port}"
  export DB_POSTGRESDB_DATABASE="${db_name}"
  export DB_POSTGRESDB_USER="${db_user}"
  export DB_POSTGRESDB_PASSWORD="${db_password}"
  export DB_POSTGRESDB_SSL_ENABLED=true
  export PGSSLMODE=no-verify
  export NODE_TLS_REJECT_UNAUTHORIZED=0
fi

if [ -n "${REDIS_URL:-}" ]; then
  echo "Configuring Redis from REDIS_URL"
  redis_url="${REDIS_URL#redis://}"
  redis_url="${redis_url#rediss://}"
  redis_host_port="${redis_url%%/*}"
  redis_host="${redis_host_port%%:*}"
  redis_port="${redis_host_port##*:}"

  export QUEUE_BULL_REDIS_HOST="${redis_host}"
  export QUEUE_BULL_REDIS_PORT="${redis_port}"

  case "${REDIS_URL}" in
    rediss://*)
      export QUEUE_BULL_REDIS_TLS=true
      ;;
  esac
fi

exec n8n "$@"
