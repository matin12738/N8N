#!/bin/sh
set -eu

# ۱. تنظیم پورت
if [ -n "${PORT:-}" ] && [ -z "${N8N_PORT:-}" ]; then
  export N8N_PORT="${PORT}"
fi

# ۲. تنظیم وب‌هوک
if [ -n "${WEBHOOK_URL:-}" ]; then
  export N8N_WEBHOOK_URL="${WEBHOOK_URL}"
fi

# ۳. تنظیم PostgreSQL (منطق پارس ایمن‌تر)
if [ -n "${DATABASE_URL:-}" ]; then
  echo "⚙️ Configuring PostgreSQL from DATABASE_URL..."
  export DB_TYPE=postgresdb
  
  # حذف scheme
  temp_url="${DATABASE_URL#postgres://}"
  temp_url="${temp_url#postgresql://}"
  
  # استخراج user و password (تا قبل از @)
  user_pass="${temp_url%%@*}"
  export DB_POSTGRESDB_USER="${user_pass%%:*}"
  export DB_POSTGRESDB_PASSWORD="${user_pass#*:}"
  
  # استخراج host, port, database
  host_db="${temp_url#*@}"
  export DB_POSTGRESDB_HOST="${host_db%%:*}"
  
  port_db="${host_db#*:}"
  export DB_POSTGRESDB_PORT="${port_db%%/*}"
  export DB_POSTGRESDB_DATABASE="${port_db#*/}"
  
  export DB_POSTGRESDB_SSL_ENABLED=true
  export PGSSLMODE=no-verify
  # حذف NODE_TLS_REJECT_UNAUTHORIZED=0 به دلایل امنیتی شدید
fi

# ۴. تنظیم Redis
if [ -n "${REDIS_URL:-}" ]; then
  echo "⚙️ Configuring Redis from REDIS_URL..."
  temp_redis="${REDIS_URL#redis://}"
  temp_redis="${temp_redis#rediss://}"
  
  host_port="${temp_redis%%/*}"
  export QUEUE_BULL_REDIS_HOST="${host_port%%:*}"
  export QUEUE_BULL_REDIS_PORT="${host_port##*:}"
  
  case "${REDIS_URL}" in
    rediss://*) export QUEUE_BULL_REDIS_TLS=true ;;
  esac
fi
