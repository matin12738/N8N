# =============================================================================
# Convenience Makefile for n8n infrastructure
# =============================================================================

.PHONY: help up down build logs ps restart clean prod local backup

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-15s\033[0m %s\n", $$1, $$2}'

up: ## Start local stack (with override)
	docker compose up -d --build

prod: ## Start production stack (ignore override)
	docker compose -f docker-compose.yml up -d --build

down: ## Stop and remove containers
	docker compose down

build: ## Rebuild images
	docker compose build --no-cache

logs: ## Follow n8n logs
	docker compose logs -f n8n

ps: ## Show running services
	docker compose ps

restart: ## Restart n8n service
	docker compose restart n8n

clean: ## Stop + remove volumes (DANGER: data loss)
	docker compose down -v

backup: ## Quick backup of named volumes
	@mkdir -p backups
	docker run --rm \
		-v $$(basename $$(pwd))_postgres_data:/data \
		-v $$(pwd)/backups:/backup \
		alpine tar czf /backup/postgres-$$(date +%F_%H%M).tar.gz -C /data .
	@echo "Backup written to ./backups/"