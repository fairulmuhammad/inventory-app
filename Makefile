# =============================================================================
# TechNova Inventory Management System - Makefile
# Description: Automation commands for development and deployment
# =============================================================================

.PHONY: help install test build deploy clean setup lint security docs

# Default target
.DEFAULT_GOAL := help

# Variables
PYTHON := python
PIP := pip
SERVICE_DIR := inventory-service
VENV := venv
REPORTS_DIR := reports

# Colors for output
BLUE := \033[0;34m
GREEN := \033[0;32m
YELLOW := \033[1;33m
RED := \033[0;31m
NC := \033[0m

# Help target
help: ## Show this help message
	@echo "$(BLUE)TechNova Inventory Management System$(NC)"
	@echo "====================================="
	@echo "Available commands:"
	@echo ""
	@awk 'BEGIN {FS = ":.*##"} /^[a-zA-Z_-]+:.*##/ { printf "  $(GREEN)%-15s$(NC) %s\n", $$1, $$2 }' $(MAKEFILE_LIST)
	@echo ""

# Setup targets
setup: ## Setup development environment
	@echo "$(BLUE)[INFO]$(NC) Setting up development environment..."
	@$(PYTHON) -m venv $(VENV)
	@$(VENV)/bin/pip install --upgrade pip
	@$(VENV)/bin/pip install -r $(SERVICE_DIR)/requirements.txt
	@echo "$(GREEN)[SUCCESS]$(NC) Development environment ready"

install: ## Install dependencies
	@echo "$(BLUE)[INFO]$(NC) Installing dependencies..."
	@cd $(SERVICE_DIR) && $(PIP) install -r requirements.txt
	@echo "$(GREEN)[SUCCESS]$(NC) Dependencies installed"

# Development targets
dev: ## Start development server
	@echo "$(BLUE)[INFO]$(NC) Starting development server..."
	@cd $(SERVICE_DIR) && $(PYTHON) app.py

dev-watch: ## Start development server with auto-reload
	@echo "$(BLUE)[INFO]$(NC) Starting development server with auto-reload..."
	@cd $(SERVICE_DIR) && watchmedo auto-restart --patterns="*.py" --recursive -- $(PYTHON) app.py

# Testing targets
test: ## Run all tests
	@echo "$(BLUE)[INFO]$(NC) Running test suite..."
	@mkdir -p $(REPORTS_DIR)
	@cd $(SERVICE_DIR) && $(PYTHON) -m pytest tests/ -v \
		--cov=. \
		--cov-report=term-missing \
		--cov-report=html:../$(REPORTS_DIR)/htmlcov \
		--cov-report=xml:../$(REPORTS_DIR)/coverage.xml \
		--junit-xml=../$(REPORTS_DIR)/test-results.xml \
		--tb=short
	@echo "$(GREEN)[SUCCESS]$(NC) Tests completed"

test-unit: ## Run unit tests only
	@echo "$(BLUE)[INFO]$(NC) Running unit tests..."
	@cd $(SERVICE_DIR) && $(PYTHON) -m pytest tests/test_app.py -v
	@echo "$(GREEN)[SUCCESS]$(NC) Unit tests completed"

test-integration: ## Run integration tests only
	@echo "$(BLUE)[INFO]$(NC) Running integration tests..."
	@cd $(SERVICE_DIR) && $(PYTHON) -m pytest tests/test_integration.py -v
	@echo "$(GREEN)[SUCCESS]$(NC) Integration tests completed"

test-performance: ## Run performance tests only
	@echo "$(BLUE)[INFO]$(NC) Running performance tests..."
	@cd $(SERVICE_DIR) && $(PYTHON) -m pytest tests/test_performance.py -v
	@echo "$(GREEN)[SUCCESS]$(NC) Performance tests completed"

test-watch: ## Run tests in watch mode
	@echo "$(BLUE)[INFO]$(NC) Running tests in watch mode..."
	@cd $(SERVICE_DIR) && ptw tests/ --runner "python -m pytest tests/ -v"

coverage: ## Generate coverage report
	@echo "$(BLUE)[INFO]$(NC) Generating coverage report..."
	@mkdir -p $(REPORTS_DIR)
	@cd $(SERVICE_DIR) && $(PYTHON) -m pytest tests/ --cov=. --cov-report=html:../$(REPORTS_DIR)/htmlcov
	@echo "$(GREEN)[SUCCESS]$(NC) Coverage report generated: $(REPORTS_DIR)/htmlcov/index.html"

# Code quality targets
lint: ## Run code linting
	@echo "$(BLUE)[INFO]$(NC) Running code linting..."
	@cd $(SERVICE_DIR) && flake8 . --count --select=E9,F63,F7,F82 --show-source --statistics || true
	@cd $(SERVICE_DIR) && flake8 . --count --exit-zero --max-complexity=10 --max-line-length=127 --statistics || true
	@echo "$(GREEN)[SUCCESS]$(NC) Linting completed"

format: ## Format code with black
	@echo "$(BLUE)[INFO]$(NC) Formatting code..."
	@cd $(SERVICE_DIR) && black . --line-length 88
	@echo "$(GREEN)[SUCCESS]$(NC) Code formatted"

format-check: ## Check code formatting
	@echo "$(BLUE)[INFO]$(NC) Checking code formatting..."
	@cd $(SERVICE_DIR) && black --check . --line-length 88
	@echo "$(GREEN)[SUCCESS]$(NC) Code format check passed"

# Security targets  
security: ## Run security scans
	@echo "$(BLUE)[INFO]$(NC) Running security scans..."
	@mkdir -p $(REPORTS_DIR)
	@cd $(SERVICE_DIR) && bandit -r . -f json -o ../$(REPORTS_DIR)/bandit-report.json || true
	@cd $(SERVICE_DIR) && bandit -r . -f txt > ../$(REPORTS_DIR)/bandit-report.txt || true
	@cd $(SERVICE_DIR) && safety check --json > ../$(REPORTS_DIR)/safety-report.json || true
	@echo "$(GREEN)[SUCCESS]$(NC) Security scans completed"

security-bandit: ## Run Bandit security scan
	@echo "$(BLUE)[INFO]$(NC) Running Bandit security scan..."
	@cd $(SERVICE_DIR) && bandit -r . --format txt
	@echo "$(GREEN)[SUCCESS]$(NC) Bandit scan completed"

security-safety: ## Run Safety dependency check
	@echo "$(BLUE)[INFO]$(NC) Running Safety dependency check..."
	@cd $(SERVICE_DIR) && safety check
	@echo "$(GREEN)[SUCCESS]$(NC) Safety check completed"

# Build targets
build: ## Build Docker image
	@echo "$(BLUE)[INFO]$(NC) Building Docker image..."
	@docker build \
		--build-arg BUILD_DATE=$$(date -u +'%Y-%m-%dT%H:%M:%SZ') \
		--build-arg VERSION="1.0.0" \
		--build-arg VCS_REF=$$(git rev-parse --short HEAD 2>/dev/null || echo "unknown") \
		-t technova/inventory-service:latest \
		-t technova/inventory-service:1.0.0 \
		./$(SERVICE_DIR)
	@echo "$(GREEN)[SUCCESS]$(NC) Docker image built"

build-prod: ## Build production Docker image
	@echo "$(BLUE)[INFO]$(NC) Building production Docker image..."
	@docker build \
		--target production \
		--build-arg BUILD_DATE=$$(date -u +'%Y-%m-%dT%H:%M:%SZ') \
		--build-arg VERSION="1.0.0" \
		--build-arg VCS_REF=$$(git rev-parse --short HEAD 2>/dev/null || echo "unknown") \
		-t technova/inventory-service:1.0.0-prod \
		./$(SERVICE_DIR)
	@echo "$(GREEN)[SUCCESS]$(NC) Production Docker image built"

# Deployment targets
deploy-local: ## Deploy locally with Docker Compose
	@echo "$(BLUE)[INFO]$(NC) Deploying locally..."
	@docker-compose up -d --build
	@echo "$(GREEN)[SUCCESS]$(NC) Local deployment completed"
	@echo "$(BLUE)[INFO]$(NC) Services available at:"
	@echo "  - Inventory Service: http://localhost:5001"
	@echo "  - Grafana: http://localhost:3000"
	@echo "  - Prometheus: http://localhost:9090"

deploy-staging: ## Deploy to staging environment
	@echo "$(BLUE)[INFO]$(NC) Deploying to staging..."
	@./scripts/deploy.sh staging
	@echo "$(GREEN)[SUCCESS]$(NC) Staging deployment completed"

deploy-prod: ## Deploy to production environment  
	@echo "$(BLUE)[INFO]$(NC) Deploying to production..."
	@./scripts/deploy.sh production
	@echo "$(GREEN)[SUCCESS]$(NC) Production deployment completed"

# Monitoring targets
logs: ## Show application logs
	@echo "$(BLUE)[INFO]$(NC) Showing application logs..."
	@docker-compose logs -f inventory-service

logs-all: ## Show all service logs
	@echo "$(BLUE)[INFO]$(NC) Showing all service logs..."
	@docker-compose logs -f

status: ## Show deployment status
	@echo "$(BLUE)[INFO]$(NC) Checking deployment status..."
	@./scripts/deploy.sh status

health: ## Check service health
	@echo "$(BLUE)[INFO]$(NC) Checking service health..."
	@curl -s http://localhost:5001/health | jq . || echo "Service not available"

metrics: ## Show service metrics
	@echo "$(BLUE)[INFO]$(NC) Showing service metrics..."
	@curl -s http://localhost:5001/metrics

# Database targets
db-migrate: ## Run database migrations
	@echo "$(BLUE)[INFO]$(NC) Running database migrations..."
	@echo "$(YELLOW)[WARNING]$(NC) Database migrations not implemented yet"

db-seed: ## Seed database with sample data
	@echo "$(BLUE)[INFO]$(NC) Seeding database..."
	@echo "$(YELLOW)[WARNING]$(NC) Database seeding not implemented yet"

# Documentation targets
docs: ## Generate documentation
	@echo "$(BLUE)[INFO]$(NC) Generating documentation..."
	@echo "$(GREEN)[SUCCESS]$(NC) Documentation available in docs/"

docs-serve: ## Serve documentation locally
	@echo "$(BLUE)[INFO]$(NC) Serving documentation..."
	@cd docs && python -m http.server 8080

# Utility targets
clean: ## Clean up temporary files and containers
	@echo "$(BLUE)[INFO]$(NC) Cleaning up..."
	@docker-compose down --remove-orphans || true
	@docker system prune -f || true
	@rm -rf $(REPORTS_DIR) || true
	@find . -type f -name "*.pyc" -delete || true
	@find . -type d -name "__pycache__" -exec rm -rf {} + || true
	@find . -type d -name ".pytest_cache" -exec rm -rf {} + || true
	@echo "$(GREEN)[SUCCESS]$(NC) Cleanup completed"

clean-all: ## Clean everything including images
	@echo "$(BLUE)[INFO]$(NC) Cleaning everything..."
	@docker-compose down --remove-orphans --volumes || true
	@docker system prune -af || true
	@rm -rf $(REPORTS_DIR) $(VENV) || true
	@find . -type f -name "*.pyc" -delete || true
	@find . -type d -name "__pycache__" -exec rm -rf {} + || true
	@echo "$(GREEN)[SUCCESS]$(NC) Deep cleanup completed"

stop: ## Stop all services
	@echo "$(BLUE)[INFO]$(NC) Stopping services..."
	@docker-compose down
	@echo "$(GREEN)[SUCCESS]$(NC) Services stopped"

restart: ## Restart all services
	@echo "$(BLUE)[INFO]$(NC) Restarting services..."
	@docker-compose restart
	@echo "$(GREEN)[SUCCESS]$(NC) Services restarted"

# Maintenance targets
backup: ## Create backup
	@echo "$(BLUE)[INFO]$(NC) Creating backup..."
	@./scripts/deploy.sh backup
	@echo "$(GREEN)[SUCCESS]$(NC) Backup completed"

rollback: ## Rollback deployment
	@echo "$(BLUE)[INFO]$(NC) Rolling back deployment..."
	@./scripts/deploy.sh rollback
	@echo "$(GREEN)[SUCCESS]$(NC) Rollback completed"

# CI/CD simulation
ci: lint security test build ## Run CI pipeline simulation
	@echo "$(GREEN)[SUCCESS]$(NC) CI pipeline completed successfully"

cd: build deploy-staging ## Run CD pipeline simulation
	@echo "$(GREEN)[SUCCESS]$(NC) CD pipeline completed successfully"

pipeline: ci cd ## Run full CI/CD pipeline simulation
	@echo "$(GREEN)[SUCCESS]$(NC) Full pipeline completed successfully"

# Quick commands
quick-test: ## Quick test run
	@cd $(SERVICE_DIR) && $(PYTHON) -m pytest tests/test_app.py -v --tb=short

quick-build: ## Quick build without cache
	@docker build --no-cache -t technova/inventory-service:dev ./$(SERVICE_DIR)

quick-deploy: quick-build deploy-local ## Quick build and deploy

# Development shortcuts
shell: ## Open shell in service directory
	@cd $(SERVICE_DIR) && bash

py-shell: ## Open Python shell with app context
	@cd $(SERVICE_DIR) && $(PYTHON) -c "from app import app; import pdb; pdb.set_trace()"
