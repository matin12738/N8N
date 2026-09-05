# 🚀 n8n Production-Ready Docker Infrastructure

Fully hardened, dual-environment (Local + Production) stack for **n8n** with **PostgreSQL 15** and **Redis 7**.

---

## 🏗️ Architecture

```text
                    ┌──────────────────────┐
                    │  Reverse Proxy /     │
                    │  Browser / Client    │
                    └──────────┬───────────┘
                               │ :5678 (only published port)
                               ▼
                    ┌──────────────────────┐
                    │  n8n (custom image)  │
                    │  • parses DATABASE_  │
                    │    URL & REDIS_URL   │
                    │  • queue mode        │
                    └──────────┬───────────┘
                               │
               ┌───────────────┴───────────────┐
               ▼                               ▼
     ┌──────────────────┐           ┌──────────────────┐
     │  PostgreSQL 15   │           │  Redis 7         │
     │  (data store)    │           │  (Bull queue)    │
     │  internal only   │           │  internal only   │
     └──────────────────┘           └──────────────────┘


     cp .env.example .env
# ویرایش .env (حداقل POSTGRES_PASSWORD و N8N_ENCRYPTION_KEY)

# Local
make up
# یا
docker compose up -d --build

# Production
make prod
# یا
docker compose -f docker-compose.yml up -d --build
```

## 📚 Documentation

- [n8n Documentation](https://docs.n8n.io/)