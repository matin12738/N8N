# n8n Docker Infrastructure

**Production-ready n8n stack with PostgreSQL 15 and Redis 7**

Dual-environment setup (Local + Production), hardened security, robust URL parsing, and performance defaults aligned with official n8n documentation.

[![n8n](https://img.shields.io/badge/n8n-2.x-orange?logo=n8n)](https://n8n.io)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-15-blue?logo=postgresql)](https://www.postgresql.org/)
[![Redis](https://img.shields.io/badge/Redis-7-red?logo=redis)](https://redis.io/)
[![Docker](https://img.shields.io/badge/Docker-Compose-2496ED?logo=docker)](https://docs.docker.com/compose/)

---

## Architecture

```text
                    ┌──────────────────────────┐
                    │   Browser / Reverse Proxy │
                    └────────────┬─────────────┘
                                 │ :5678 (only published port)
                                 ▼
                    ┌──────────────────────────┐
                    │   n8n (custom image)     │
                    │   • start.sh parses URLs │
                    │   • EXECUTIONS_MODE      │
                    │   • Task runners         │
                    └────────────┬─────────────┘
                                 │
               ┌─────────────────┴─────────────────┐
               ▼                                   ▼
     ┌──────────────────┐               ┌──────────────────┐
     │  PostgreSQL 15   │               │  Redis 7         │
     │  (workflows DB)  │               │  (queue / cache) │
     │  internal only   │               │  internal only   │
     └──────────────────┘               └──────────────────┘
```

| Component | Role |
|-----------|------|
| **n8n** | Workflow engine (custom image + entrypoint parser) |
| **PostgreSQL 15** | Primary database for workflows, credentials, executions |
| **Redis 7** | Bull queue backend (ready for workers in production) |

---

## Features

- **Dual environment** — Local (fast) and Production (scalable) from the same files
- **Safe URL parsing** — `DATABASE_URL` and `REDIS_URL` converted to native n8n env vars
- **Performance defaults** — `EXECUTIONS_MODE=regular` for single-node speed (official recommendation)
- **Security hardening** — no published DB/Redis ports, `no-new-privileges`, minimal capabilities
- **Healthchecks** — proper `start_period` and dependency conditions
- **Resource limits** — CPU/memory caps to avoid host exhaustion
- **Fail-fast secrets** — compose refuses to start if critical env vars are missing
- **Queue-ready** — switch to `EXECUTIONS_MODE=queue` + workers when you scale

---

## Quick Start

### 1. Clone

```bash
git clone https://github.com/YOUR_USER/YOUR_REPO.git
cd YOUR_REPO
```

### 2. Configure environment

```bash
cp .env.example .env
```

Edit `.env` and set at least:

```env
POSTGRES_PASSWORD=<strong-password>
N8N_ENCRYPTION_KEY=<output of: openssl rand -hex 32>
DATABASE_URL=postgres://n8n:<same-password>@postgres:5432/n8n
```

> **Important:** After the first successful start, never change `N8N_ENCRYPTION_KEY`.  
> Changing it causes: `Mismatching encryption keys`.

### 3. Start (Local)

```bash
docker compose up -d --build
```

Open: [http://localhost:5678](http://localhost:5678)

### 4. Start (Production)

```bash
docker compose -f docker-compose.yml up -d --build
```

Or with Make (if available):

```bash
make up      # local
make prod   # production (ignores override)
```

---

## Environment overview

| Variable | Local default | Production note |
|----------|---------------|-----------------|
| `EXECUTIONS_MODE` | `regular` | Use `queue` only with workers |
| `N8N_CONCURRENCY_PRODUCTION_LIMIT` | `-1` | e.g. `10–20` on small servers |
| `N8N_RUNNERS_ENABLED` | `true` | Code node isolation |
| `REDIS_PASSWORD` | empty | **Required** in production |
| `N8N_ENCRYPTION_KEY` | required | Generate once, never rotate casually |

Full list: see [`.env.example`](.env.example).

---

## File structure

```text
.
├── docker-compose.yml           # Production baseline
├── docker-compose.override.yml  # Local overrides (auto-merged)
├── Dockerfile                   # Custom n8n image
├── start.sh                     # Safe DATABASE_URL / REDIS_URL parser
├── .env.example                 # Template (copy to .env)
├── .dockerignore
├── .gitignore
├── Makefile                     # Optional helpers
└── README.md
```

---

## How `start.sh` works

The official n8n image does **not** natively understand `DATABASE_URL` / `REDIS_URL`.

`start.sh` is installed into `/docker-entrypoint.d/` and runs **before** the real n8n process. It:

1. Parses `DATABASE_URL` → `DB_TYPE`, `DB_POSTGRESDB_*`
2. Parses `REDIS_URL` → `QUEUE_BULL_REDIS_*` (including TLS / password)
3. Does **not** force `EXECUTIONS_MODE=queue` (so local stays fast)
4. Never prints secrets

Pure POSIX `sh` — no bashisms, works on Alpine.

---

## Performance (official n8n guidance)

| Scenario | Recommended mode |
|----------|------------------|
| Single instance (Local / small VPS) | `EXECUTIONS_MODE=regular` |
| Multiple workers / high load | `EXECUTIONS_MODE=queue` + Redis + workers |

Queue mode without separate workers only adds Redis overhead and makes executions slower.  
This stack defaults to **regular** for speed; switch to queue when you add workers.

Useful knobs:

```env
EXECUTIONS_MODE=regular
N8N_CONCURRENCY_PRODUCTION_LIMIT=-1
N8N_RUNNERS_ENABLED=true
N8N_RUNNERS_MODE=internal
N8N_RUNNERS_MAX_CONCURRENCY=5
```

---

## Security layers

1. **Network** — only n8n port is published; Postgres and Redis stay internal  
2. **Secrets** — required via compose `:?` syntax; `.env` is gitignored  
3. **Container** — `security_opt: no-new-privileges`, selective `cap_drop` / `cap_add`  
4. **Application** — diagnostics and personalization disabled by default; execution pruning enabled  

For production also:

- Put a reverse proxy (Caddy / Traefik / Nginx) in front and enable HTTPS  
- Set `N8N_PROTOCOL=https` and `WEBHOOK_URL=https://your-domain`  
- Set a strong `REDIS_PASSWORD` and matching `REDIS_URL`

---

## Common commands

```bash
# Status
docker compose ps

# Logs
docker compose logs -f n8n

# Restart n8n only
docker compose restart n8n

# Rebuild after changing Dockerfile / start.sh
docker compose up -d --build

# Stop
docker compose down

# Stop + delete volumes (DESTROYS DATA)
docker compose down -v
```

---

## Troubleshooting

### `Mismatching encryption keys`

The key in `.env` does not match the key stored in the n8n volume.

**Local (no important data):**

```bash
docker compose down
docker volume ls | grep n8n
docker volume rm <n8n_data_volume_name>
# Ensure N8N_ENCRYPTION_KEY is set, then:
docker compose up -d
```

**Keep data:** read the existing key from the volume and put it back into `.env`:

```bash
docker run --rm -v <n8n_data_volume>:/data alpine cat /data/config
```

### Redis unhealthy (especially on Windows / Git Bash)

This stack uses a simple Redis command and healthcheck (`redis-cli ping`) to avoid fragile shell escaping.  
If it still fails, check:

```bash
docker compose logs redis
docker compose ps -a
```

### Workflows feel slow

1. Confirm `EXECUTIONS_MODE=regular` in `.env` and in the running container  
2. Check external HTTP nodes (timeouts / 403s are not n8n core lag)  
3. Only enable `queue` when you actually run worker processes  

---

## Production checklist

- [ ] Strong unique `POSTGRES_PASSWORD`
- [ ] Strong unique `REDIS_PASSWORD` + `REDIS_URL=redis://:PASSWORD@redis:6379`
- [ ] `N8N_ENCRYPTION_KEY` from `openssl rand -hex 32` (never change after first boot)
- [ ] Run with `docker compose -f docker-compose.yml up -d` (no local override)
- [ ] Reverse proxy + HTTPS
- [ ] `N8N_PROTOCOL=https` and public `WEBHOOK_URL`
- [ ] Regular volume backups
- [ ] Monitor healthchecks

---

## Backup example

```bash
# Postgres
docker run --rm \
  -v $(basename $(pwd))_postgres_data:/data \
  -v $(pwd)/backups:/backup \
  alpine tar czf /backup/postgres-$(date +%F).tar.gz -C /data .
```

---

## References

- [n8n Documentation](https://docs.n8n.io/)
- [Queue mode](https://docs.n8n.io/hosting/scaling/queue-mode/)
- [Executions environment variables](https://docs.n8n.io/hosting/configuration/environment-variables/executions/)
- [Task runners](https://docs.n8n.io/hosting/configuration/task-runners/)
- [Concurrency control](https://docs.n8n.io/hosting/scaling/concurrency-control/)
