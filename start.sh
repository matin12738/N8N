#!/bin/sh
# =============================================================================
# n8n Custom Entrypoint Script
# -----------------------------------------------------------------------------
# Location : /docker-entrypoint.d/99-custom-env-parser.sh
# Purpose  : Safely parse DATABASE_URL & REDIS_URL into the individual
#            environment variables that the official n8n binary expects.
#            This script runs *before* the official entrypoint continues.
#
# Security layers applied:
#   1. set -eu          → exit on any error or undefined variable
#   2. Pure POSIX sh    → no bashisms, works on alpine
#   3. Defensive parsing → never eval, never source untrusted input
# =============================================================================

set -eu

# -----------------------------------------------------------------------------
# Helper: log only when N8N_LOG_LEVEL is debug/info (avoid noise in production)
# -----------------------------------------------------------------------------
log() {
    # shellcheck disable=SC2039
    case "${N8N_LOG_LEVEL:-info}" in
        debug|info) printf '%s\n' "$*" ;;
    esac
}

# -----------------------------------------------------------------------------
# 1. PORT fallback (useful for platforms that inject $PORT)
# -----------------------------------------------------------------------------
if [ -n "${PORT:-}" ] && [ -z "${N8N_PORT:-}" ]; then
    export N8N_PORT="${PORT}"
    log "↪️  N8N_PORT set from \$PORT=${PORT}"
fi

# -----------------------------------------------------------------------------
# 2. Webhook URL (common on PaaS / reverse-proxy setups)
# -----------------------------------------------------------------------------
if [ -n "${WEBHOOK_URL:-}" ]; then
    export N8N_WEBHOOK_URL="${WEBHOOK_URL}"
    log "↪️  N8N_WEBHOOK_URL set from \$WEBHOOK_URL"
fi

# -----------------------------------------------------------------------------
# 3. PostgreSQL – robust URL parser
#    Supports: postgres://user:pass@host:port/db
#              postgresql://user:pass@host:port/db?sslmode=require
#    Password may contain almost any character except unencoded @
# -----------------------------------------------------------------------------
if [ -n "${DATABASE_URL:-}" ]; then
    log "⚙️  Configuring PostgreSQL from DATABASE_URL..."

    export DB_TYPE=postgresdb

    # Strip scheme (postgres:// or postgresql://)
    _url="${DATABASE_URL#postgres://}"
    _url="${_url#postgresql://}"

    # Split userinfo and hostinfo on the *last* @ (password may contain @ if encoded)
    case "$_url" in
        *@*)
            _userinfo="${_url%@*}"
            _hostinfo="${_url#*@}"
            ;;
        *)
            _userinfo=""
            _hostinfo="$_url"
            ;;
    esac

    # user:password
    if [ -n "$_userinfo" ]; then
        export DB_POSTGRESDB_USER="${_userinfo%%:*}"
        case "$_userinfo" in
            *:*) export DB_POSTGRESDB_PASSWORD="${_userinfo#*:}" ;;
            *)   export DB_POSTGRESDB_PASSWORD="" ;;
        esac
    fi

    # host:port/database[?query]
    _hostinfo_noquery="${_hostinfo%%\?*}"

    case "$_hostinfo_noquery" in
        *:*)
            export DB_POSTGRESDB_HOST="${_hostinfo_noquery%%:*}"
            _port_db="${_hostinfo_noquery#*:}"
            export DB_POSTGRESDB_PORT="${_port_db%%/*}"
            export DB_POSTGRESDB_DATABASE="${_port_db#*/}"
            ;;
        *)
            export DB_POSTGRESDB_HOST="${_hostinfo_noquery%%/*}"
            export DB_POSTGRESDB_PORT=5432
            export DB_POSTGRESDB_DATABASE="${_hostinfo_noquery#*/}"
            ;;
    esac

    export DB_POSTGRESDB_DATABASE="${DB_POSTGRESDB_DATABASE%%/*}"

    # Optional SSL detection from query string
    case "${DATABASE_URL}" in
        *sslmode=require*|*sslmode=verify-ca*|*sslmode=verify-full*)
            export DB_POSTGRESDB_SSL_ENABLED=true
            export PGSSLMODE=require
            log "🔒 SSL enabled for PostgreSQL"
            ;;
    esac

    log "✅ PostgreSQL → ${DB_POSTGRESDB_USER}@${DB_POSTGRESDB_HOST}:${DB_POSTGRESDB_PORT}/${DB_POSTGRESDB_DATABASE}"
fi

# -----------------------------------------------------------------------------
# 4. Redis – robust URL parser (used by Bull queue)
#    Supports: redis://[:password@]host:port[/db]
#              rediss://[:password@]host:port   (TLS)
# -----------------------------------------------------------------------------
if [ -n "${REDIS_URL:-}" ]; then
    log "⚙️  Configuring Redis from REDIS_URL..."

    # Detect TLS
    case "${REDIS_URL}" in
        rediss://*)
            export QUEUE_BULL_REDIS_TLS=true
            _rurl="${REDIS_URL#rediss://}"
            ;;
        *)
            _rurl="${REDIS_URL#redis://}"
            ;;
    esac

    # Split userinfo / hostinfo
    case "$_rurl" in
        *@*)
            _ruserinfo="${_rurl%@*}"
            _rhostinfo="${_rurl#*@}"
            ;;
        *)
            _ruserinfo=""
            _rhostinfo="$_rurl"
            ;;
    esac

    # Password
    if [ -n "$_ruserinfo" ]; then
        case "$_ruserinfo" in
            :*) export QUEUE_BULL_REDIS_PASSWORD="${_ruserinfo#:}" ;;
            *:*) export QUEUE_BULL_REDIS_PASSWORD="${_ruserinfo#*:}" ;;
            *)   export QUEUE_BULL_REDIS_PASSWORD="$_ruserinfo" ;;
        esac
    fi

    # host:port[/db]
    _rhostinfo_noquery="${_rhostinfo%%\?*}"
    case "$_rhostinfo_noquery" in
        *:*)
            export QUEUE_BULL_REDIS_HOST="${_rhostinfo_noquery%%:*}"
            _rport_db="${_rhostinfo_noquery#*:}"
            export QUEUE_BULL_REDIS_PORT="${_rport_db%%/*}"
            ;;
        *)
            export QUEUE_BULL_REDIS_HOST="${_rhostinfo_noquery%%/*}"
            export QUEUE_BULL_REDIS_PORT=6379
            ;;
    esac

    # Enable queue mode when Redis is present
    export EXECUTIONS_MODE=queue
    export QUEUE_BULL_REDIS_DB=0

    log "✅ Redis → ${QUEUE_BULL_REDIS_HOST}:${QUEUE_BULL_REDIS_PORT} (TLS=${QUEUE_BULL_REDIS_TLS:-false})"
fi

# -----------------------------------------------------------------------------
# Final confirmation (never print secrets)
# -----------------------------------------------------------------------------
log "✅ Environment variables parsed successfully. Handing control back to official n8n entrypoint..."

# Important: do NOT exec here.
# The official /docker-entrypoint.sh will continue after all scripts in
# /docker-entrypoint.d/ have finished.