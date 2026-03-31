# Makefile for Horizen Network Deployment
# Provides convenient commands for common operations

.PHONY: help deploy-dev deploy-prod deploy-staging backup restore health logs clean validate test security-scan rollback

# Default target
.DEFAULT_GOAL := help

# Colors for output
BLUE := \033[0;34m
GREEN := \033[0;32m
YELLOW := \033[1;33m
RED := \033[0;31m
NC := \033[0m # No Color

help: ## Show this help message
	@echo "$(BLUE)Horizen Network - Available Commands$(NC)"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "$(GREEN)%-20s$(NC) %s\n", $$1, $$2}'
	@echo ""
	@echo "$(YELLOW)Examples:$(NC)"
	@echo "  make deploy-dev     # Deploy in development mode"
	@echo "  make backup         # Create backup"
	@echo "  make health         # Check health status"

##@ Deployment Commands

deploy-dev: ## Deploy in development mode
	@echo "$(BLUE)Deploying in development mode...$(NC)"
	@./scripts/deploy.sh dev

deploy-prod: ## Deploy in production mode
	@echo "$(BLUE)Deploying in production mode...$(NC)"
	@./scripts/deploy.sh prod

deploy-staging: ## Deploy in staging mode
	@echo "$(BLUE)Deploying in staging mode...$(NC)"
	@cp .env.staging .env
	@./scripts/deploy.sh dev

start: ## Start all services
	@echo "$(BLUE)Starting services...$(NC)"
	@docker-compose up -d
	@echo "$(GREEN)✓ Services started$(NC)"

stop: ## Stop all services
	@echo "$(BLUE)Stopping services...$(NC)"
	@docker-compose down
	@echo "$(GREEN)✓ Services stopped$(NC)"

restart: ## Restart all services
	@echo "$(BLUE)Restarting services...$(NC)"
	@docker-compose restart
	@echo "$(GREEN)✓ Services restarted$(NC)"

##@ Backup and Restore

backup: ## Create backup of all data
	@echo "$(BLUE)Creating backup...$(NC)"
	@./scripts/backup.sh

restore: ## Restore from latest backup
	@echo "$(BLUE)Restoring from backup...$(NC)"
	@echo "$(YELLOW)Please specify backup file manually in scripts/restore.sh$(NC)"

rollback: ## Rollback to previous deployment
	@echo "$(RED)Rollback requires commit hash or tag$(NC)"
	@echo "Usage: make rollback COMMIT=<commit-hash>"
	@echo "   or: make rollback TAG=<tag-name>"
ifdef COMMIT
	@./scripts/rollback.sh --commit $(COMMIT)
else ifdef TAG
	@./scripts/rollback.sh --tag $(TAG)
else
	@echo "$(RED)Error: Must specify COMMIT or TAG$(NC)"
	@exit 1
endif

##@ Health and Monitoring

health: ## Run health check
	@echo "$(BLUE)Running health check...$(NC)"
	@./scripts/health-check.sh

validate: ## Run pre-deployment validation
	@echo "$(BLUE)Running validation...$(NC)"
	@./scripts/validate.sh

test: ## Run integration tests
	@echo "$(BLUE)Running tests...$(NC)"
	@./scripts/test.sh

security-scan: ## Run security scan
	@echo "$(BLUE)Running security scan...$(NC)"
	@./scripts/security-scan.sh

##@ Logs and Monitoring

logs: ## View logs for all services
	@docker-compose logs -f

logs-nginx: ## View Nginx logs
	@docker-compose logs -f nginx

logs-druid: ## View Druid logs
	@docker-compose logs -f druid-coordinator druid-broker druid-router druid-historical druid-middlemanager

logs-db: ## View database logs
	@docker-compose logs -f postgres mongodb

logs-error: ## View error logs only
	@docker-compose logs | grep -i error

ps: ## Show running containers
	@docker-compose ps

stats: ## Show container resource usage
	@docker stats --no-stream

##@ Database Operations

db-psql: ## Connect to PostgreSQL
	@docker-compose exec postgres psql -U $$POSTGRES_USER -d $$POSTGRES_DB

db-mongo: ## Connect to MongoDB
	@docker-compose exec mongodb mongosh

db-redis: ## Connect to Redis
	@docker-compose exec redis redis-cli -a $$REDIS_PASSWORD

db-backup: ## Backup databases only
	@echo "$(BLUE)Backing up databases...$(NC)"
	@docker-compose exec -T postgres pg_dump -U $$POSTGRES_USER $$POSTGRES_DB > backups/postgres_$$(date +%Y%m%d_%H%M%S).sql
	@docker-compose exec -T mongodb mongodump --quiet --out=/tmp/backup
	@docker cp horizen-mongodb:/tmp/backup backups/mongodb_$$(date +%Y%m%d_%H%M%S)
	@echo "$(GREEN)✓ Database backup completed$(NC)"

##@ Development

shell-nginx: ## Open shell in Nginx container
	@docker-compose exec nginx /bin/sh

shell-druid: ## Open shell in Druid coordinator container
	@docker-compose exec druid-coordinator /bin/bash

shell-postgres: ## Open shell in PostgreSQL container
	@docker-compose exec postgres /bin/bash

shell-mongodb: ## Open shell in MongoDB container
	@docker-compose exec mongodb /bin/bash

##@ Cleanup

clean: ## Clean up stopped containers and unused images
	@echo "$(BLUE)Cleaning up...$(NC)"
	@docker-compose down
	@docker system prune -f
	@echo "$(GREEN)✓ Cleanup completed$(NC)"

clean-all: ## Clean up everything including volumes (CAUTION: This deletes data!)
	@echo "$(RED)WARNING: This will delete all data!$(NC)"
	@echo "Press Ctrl+C within 10 seconds to cancel..."
	@sleep 10
	@docker-compose down -v
	@docker system prune -a -f --volumes
	@echo "$(GREEN)✓ Complete cleanup done$(NC)"

clean-backups: ## Remove old backups (older than 30 days)
	@echo "$(BLUE)Cleaning old backups...$(NC)"
	@find ./backups -name "*.tar.gz" -mtime +30 -delete
	@find ./backups -name "*.sql" -mtime +30 -delete
	@echo "$(GREEN)✓ Old backups removed$(NC)"

##@ Configuration

config: ## Validate Docker Compose configuration
	@docker-compose config

config-dev: ## Validate development configuration
	@docker-compose -f docker-compose.yml -f docker-compose.dev.yml config

config-prod: ## Validate production configuration
	@docker-compose -f docker-compose.yml -f docker-compose.prod.yml config

env-example: ## Create .env from example
	@cp .env.example .env
	@echo "$(GREEN)✓ Created .env from .env.example$(NC)"
	@echo "$(YELLOW)! Please edit .env and set your passwords$(NC)"

##@ SSL/TLS

ssl-setup: ## Setup SSL certificates
	@echo "$(BLUE)Setting up SSL certificates...$(NC)"
	@sudo ./scripts/ssl-setup.sh

ssl-renew: ## Renew SSL certificates
	@echo "$(BLUE)Renewing SSL certificates...$(NC)"
	@sudo certbot renew
	@docker-compose exec nginx nginx -s reload
	@echo "$(GREEN)✓ SSL certificates renewed$(NC)"

ssl-check: ## Check SSL certificate expiration
	@echo "$(BLUE)Checking SSL certificates...$(NC)"
	@sudo certbot certificates

##@ Notifications

notify-test: ## Send test notification
	@./scripts/notify.sh -m "Test notification from Makefile" -s info --all

notify-success: ## Send success notification
	@./scripts/notify.sh -m "Operation completed successfully" -s success --all

notify-error: ## Send error notification
	@./scripts/notify.sh -m "Operation failed" -s error --all

##@ Updates

pull: ## Pull latest Docker images
	@echo "$(BLUE)Pulling latest images...$(NC)"
	@docker-compose pull
	@echo "$(GREEN)✓ Images updated$(NC)"

update: ## Update repository and restart services
	@echo "$(BLUE)Updating deployment...$(NC)"
	@git pull
	@docker-compose pull
	@docker-compose up -d
	@echo "$(GREEN)✓ Update completed$(NC)"

##@ Kubernetes (if applicable)

k8s-apply: ## Apply Kubernetes manifests
	@echo "$(BLUE)Applying Kubernetes manifests...$(NC)"
	@kubectl apply -f kubernetes/namespace.yaml
	@kubectl apply -f kubernetes/configmaps/
	@kubectl apply -f kubernetes/deployments/
	@kubectl apply -f kubernetes/services/
	@kubectl apply -f kubernetes/ingress.yaml
	@kubectl apply -f kubernetes/hpa.yaml
	@kubectl apply -f kubernetes/network-policies.yaml
	@echo "$(GREEN)✓ Kubernetes manifests applied$(NC)"

k8s-delete: ## Delete Kubernetes resources
	@echo "$(RED)Deleting Kubernetes resources...$(NC)"
	@kubectl delete -f kubernetes/ --recursive
	@echo "$(GREEN)✓ Resources deleted$(NC)"

k8s-status: ## Show Kubernetes deployment status
	@kubectl get all -n horizen-network

##@ Documentation

docs-serve: ## Serve documentation locally (requires Python)
	@echo "$(BLUE)Serving documentation at http://localhost:8000$(NC)"
	@cd docs && python3 -m http.server 8000

docs-check: ## Check documentation for broken links
	@echo "$(BLUE)Checking documentation links...$(NC)"
	@find docs -name "*.md" -exec grep -l "http" {} \;

##@ Utilities

version: ## Show version information
	@echo "$(BLUE)Horizen Network Deployment$(NC)"
	@echo "Git commit: $$(git rev-parse --short HEAD)"
	@echo "Git branch: $$(git rev-parse --abbrev-ref HEAD)"
	@echo "Docker version: $$(docker --version)"
	@echo "Docker Compose version: $$(docker compose version || docker-compose --version)"

check-requirements: ## Check if all requirements are installed
	@echo "$(BLUE)Checking requirements...$(NC)"
	@command -v docker >/dev/null 2>&1 || { echo "$(RED)✗ Docker not installed$(NC)"; exit 1; }
	@echo "$(GREEN)✓ Docker installed$(NC)"
	@command -v docker-compose >/dev/null 2>&1 || docker compose version >/dev/null 2>&1 || { echo "$(RED)✗ Docker Compose not installed$(NC)"; exit 1; }
	@echo "$(GREEN)✓ Docker Compose installed$(NC)"
	@command -v git >/dev/null 2>&1 || { echo "$(YELLOW)! Git not installed (optional)$(NC)"; }
	@test -f .env || { echo "$(YELLOW)! .env file not found (run: make env-example)$(NC)"; }
	@echo "$(GREEN)✓ All requirements met$(NC)"

init: ## Initialize the project (first-time setup)
	@echo "$(BLUE)Initializing Horizen Network...$(NC)"
	@test -f .env || cp .env.example .env
	@chmod +x scripts/*.sh
	@mkdir -p backups
	@docker-compose pull
	@echo "$(GREEN)✓ Initialization completed$(NC)"
	@echo "$(YELLOW)! Please edit .env and set your passwords before deploying$(NC)"
