# 🚀 n8n Docker with PostgreSQL & Redis Support

A production‑ready Docker image for [n8n](https://n8n.io) that automatically configures **PostgreSQL** and **Redis** from environment variables.  
Perfect for self‑hosted workflow automation with scalable, persistent storage and queue management.

[![Docker Pulls](https://img.shields.io/docker/pulls/yourusername/n8n-custom?style=flat-square)](https://hub.docker.com/r/yourusername/n8n-custom)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=flat-square)](LICENSE)

---

## ✨ Features

- 🔄 **Automatic database setup** – just pass `DATABASE_URL` and everything is configured (PostgreSQL).
- 📦 **Redis queue support** – enable Bull queues with `REDIS_URL` (supports TLS via `rediss://`).
- 🌐 **Flexible webhook URL** – set `WEBHOOK_URL` to override `N8N_WEBHOOK_URL`.
- 🚦 **Port mapping** – use `PORT` to override the internal n8n port (default `5678`).
- 🛡️ **SSL/TLS ready** – PostgreSQL SSL enabled by default (with `PGSSLMODE=no-verify` for convenience).
- 🧩 **Based on official n8n image** – stays up‑to‑date with all n8n features.

---

## 📦 Quick Start

### 1. Build the image (optional)

```bash
git clone https://github.com/yourusername/n8n-custom.git
cd n8n-custom
docker build -t n8n-custom .
```

### 2. Run with environment variables

#### Minimal example (SQLite, no Redis)

```bash
docker run -d --name n8n -p 5678:5678 n8n-custom
```

#### With PostgreSQL

```bash
docker run -d --name n8n \
  -p 5678:5678 \
  -e DATABASE_URL="postgres://user:pass@postgres-host:5432/n8n" \
  n8n-custom
```

#### With PostgreSQL + Redis

```bash
docker run -d --name n8n \
  -p 5678:5678 \
  -e DATABASE_URL="postgres://user:pass@postgres-host:5432/n8n" \
  -e REDIS_URL="redis://redis-host:6379" \
  n8n-custom
```

#### With TLS for Redis

```bash
docker run -d --name n8n \
  -e REDIS_URL="rediss://redis-host:6379" \
  n8n-custom
```

> ℹ️ All variables can also be set via a `.env` file when using Docker Compose (see below).

---

## 🧩 Docker Compose Example

Create a `docker-compose.yml`:

```yaml
version: '3.8'

services:
  postgres:
    image: postgres:15
    environment:
      POSTGRES_USER: n8n
      POSTGRES_PASSWORD: n8n
      POSTGRES_DB: n8n
    volumes:
      - postgres_data:/var/lib/postgresql/data
    ports:
      - "5432:5432"

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"

  n8n:
    build: .
    ports:
      - "5678:5678"
    environment:
      - DATABASE_URL=postgres://n8n:n8n@postgres:5432/n8n
      - REDIS_URL=redis://redis:6379
      - WEBHOOK_URL=https://your-domain.com
      - N8N_ENCRYPTION_KEY=your-encryption-key
    depends_on:
      - postgres
      - redis
    volumes:
      - n8n_data:/home/node/.n8n

volumes:
  postgres_data:
  n8n_data:
```

Then run:

```bash
docker-compose up -d
```

---

## 🔧 Environment Variables

The image supports all standard n8n environment variables, plus these **convenience overrides**:

| Variable       | Description                                                                 | Example                                 |
|----------------|-----------------------------------------------------------------------------|-----------------------------------------|
| `PORT`         | Overrides `N8N_PORT` if `N8N_PORT` is not set                              | `8080`                                  |
| `WEBHOOK_URL`  | Overrides `N8N_WEBHOOK_URL`                                                 | `https://my-n8n.example.com`            |
| `DATABASE_URL` | PostgreSQL connection string (auto‑sets `DB_TYPE`, host, port, etc.)        | `postgres://user:pass@host:5432/db`     |
| `REDIS_URL`    | Redis connection string (auto‑sets Bull queue host/port, TLS if `rediss://`)| `redis://redis-host:6379` or `rediss://`|

> ⚠️ If `DATABASE_URL` is **not** provided, n8n will use its default SQLite database.

---

## 🧠 How It Works – `start.sh`

The entrypoint script (`start.sh`) does the following:

1. **Port mapping** – if `PORT` is set and `N8N_PORT` is not, it sets `N8N_PORT=$PORT`.
2. **Webhook URL** – if `WEBHOOK_URL` is set, it exports `N8N_WEBHOOK_URL`.
3. **PostgreSQL configuration**  
   - Parses `DATABASE_URL` (must begin with `postgres://`).  
   - Extracts user, password, host, port, database name.  
   - Sets the required `DB_POSTGRESDB_*` variables and enables SSL (`DB_POSTGRESDB_SSL_ENABLED=true`).  
   - Also sets `PGSSLMODE=no-verify` and `NODE_TLS_REJECT_UNAUTHORIZED=0` to accept self‑signed certificates (override if needed).
4. **Redis configuration**  
   - Parses `REDIS_URL` (supports `redis://` and `rediss://`).  
   - Sets `QUEUE_BULL_REDIS_HOST` and `QUEUE_BULL_REDIS_PORT`.  
   - If the URL starts with `rediss://`, it enables TLS (`QUEUE_BULL_REDIS_TLS=true`).
5. **Executes n8n** with any passed arguments.

This design makes it **trivial** to switch between SQLite, PostgreSQL, and Redis without modifying the Dockerfile or command.

---

## 📁 Repository Structure

```
.
├── Dockerfile          # Multi‑stage build (based on official n8n image)
├── start.sh            # Entrypoint script – parses env vars and configures n8n
├── docker-compose.yml  # Example compose file (optional)
└── README.md           # This file
```

---

## 🛠️ Building from Source

```bash
docker build -t n8n-custom .
```

To run with your own environment file:

```bash
docker run --env-file .env -p 5678:5678 n8n-custom
```

---

## 📝 Notes

- The image runs as **root** to allow the entrypoint script to execute; you can switch to a non‑root user if needed by modifying the Dockerfile.
- For production, **set `N8N_ENCRYPTION_KEY`** to a secure random string to encrypt credentials.
- PostgreSQL SSL is enabled by default, but certificate validation is relaxed (`no-verify`) – for stricter validation, override `PGSSLMODE` and `NODE_TLS_REJECT_UNAUTHORIZED` manually.
- Redis TLS is automatically enabled when using `rediss://`, but no certificate verification is performed – you can add additional TLS options via environment variables if needed.

---

## 🤝 Contributing

Feel free to open issues or pull requests for improvements, additional environment variables, or bug fixes.

---

## 📄 License

MIT © [Your Name](https://github.com/yourusername)

---

**Happy automating!** 🎉
