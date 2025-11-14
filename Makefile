# Load environment variables from .env file if it exists
.SILENT:
ifneq ("$(wildcard .env)","")
    include .env
endif
# Cross-platform Makefile (works on Windows via Git Bash, Mac, Linux)
SHELL := /bin/bash
export

.PHONY: help build deploy deploy-sandbox deploy-dev deploy-prod \
        destroy destroy-sandbox destroy-dev destroy-prod \
        clean clean-cache docker-build docker-push \
        setup-token get-secret logs validate

# Default target
help:
	@echo "GitHub Actions Lambda Runner (SAM CLI) - Available Commands"
	@echo "============================================================="
	@echo ""
	@echo "Setup & Building:"
	@echo "  make build            - Build SAM application (includes Docker)"
	@echo "  make docker-build     - Build runner Docker image"
	@echo "  make docker-push ENV  - Push Docker image to ECR (ENV=sandbox|dev|prod)"
	@echo "  make validate         - Validate SAM template"
	@echo ""
	@echo "Deployment:"
	@echo "  make deploy           - Interactive guided deployment"
	@echo "  make deploy-sandbox   - Deploy to sandbox (auto-confirm)"
	@echo "  make deploy-dev       - Deploy to dev (auto-confirm)"
	@echo "  make deploy-prod      - Deploy to prod (requires confirmation)"
	@echo ""
	@echo "Configuration:"
	@echo "  make setup-token ENV  - Configure GitHub token in Secrets Manager"
	@echo "  make get-secret ENV   - Display webhook secret for GitHub config"
	@echo ""
	@echo "Monitoring:"
	@echo "  make logs ENV         - Tail Lambda logs (ENV=sandbox|dev|prod)"
	@echo "  make logs-webhook ENV - Tail webhook logs only"
	@echo "  make logs-runner ENV  - Tail runner logs only"
	@echo ""
	@echo "Teardown:"
	@echo "  make destroy-sandbox  - Destroy sandbox stack (auto-confirm)"
	@echo "  make destroy-dev      - Destroy dev stack (auto-confirm)"
	@echo "  make destroy-prod     - Destroy prod stack (requires confirmation)"
	@echo ""
	@echo "Maintenance:"
	@echo "  make clean            - Clean build artifacts"
	@echo "  make clean-cache      - Clean SAM cache and Docker containers"
	@echo ""
	@echo "Quick Start:"
	@echo "  make build && make deploy-dev"

# ============================================
# Build Commands
# ============================================

# Build SAM application
build:
	@echo "🔨 Building SAM application..."
	sam build --use-container

# Build just the Docker image for runner
docker-build:
	@echo "🐳 Building runner Docker image..."
	@cd lambda/runner && docker build -t github-runner-executor:latest .

# Push Docker image to ECR
docker-push:
ifndef ENV
	@echo "❌ Error: ENV not specified. Usage: make docker-push ENV=dev"
	@exit 1
endif
	@echo "🚀 Pushing Docker image to ECR for $(ENV) environment..."
	@echo "Logging in to ECR..."
	@aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $$(aws sts get-caller-identity --query Account --output text).dkr.ecr.us-east-1.amazonaws.com
	@echo "Getting ECR repository URI..."
	@REPO_URI=$$(aws cloudformation describe-stacks --stack-name github-runner-$(ENV) --query "Stacks[0].Outputs[?OutputKey=='ECRRepositoryUri'].OutputValue" --output text 2>/dev/null); \
	if [ -z "$$REPO_URI" ] || [ "$$REPO_URI" = "None" ]; then \
		echo "❌ Error: ECR repository not found. Deploy stack first: make deploy-$(ENV)"; \
		exit 1; \
	fi; \
	echo "Tagging image for $$REPO_URI"; \
	docker tag github-runner-executor:latest $$REPO_URI:latest; \
	docker push $$REPO_URI:latest; \
	echo "✅ Image pushed to $$REPO_URI:latest"

# Validate SAM template
validate:
	@echo "✓ Validating SAM template..."
	@sam validate --lint
	@echo "✅ Template is valid"

# ============================================
# Deployment Commands
# ============================================

# Interactive deployment
deploy: build
	@echo "🚀 Starting guided deployment..."
	sam deploy --guided

# Deploy to sandbox (auto-confirm)
deploy-sandbox: build
	@echo "🚀 Deploying to sandbox environment..."
	@sam deploy --config-env sandbox --no-confirm-changeset
	@echo "✅ Sandbox deployment complete!"
	@$(MAKE) get-secret ENV=sandbox

# Deploy to dev (auto-confirm)
deploy-dev: build
	@echo "🚀 Deploying to dev environment..."
	@sam deploy --config-env dev --no-confirm-changeset
	@echo "✅ Dev deployment complete!"
	@$(MAKE) get-secret ENV=dev

# Deploy to prod (SAM will prompt for confirmation)
deploy-prod: build
	@echo "🚀 Deploying to prod environment..."
	@echo "⚠️  This will deploy to PRODUCTION!"
	@echo "⚠️  SAM will prompt you for confirmation..."
	sam deploy --config-env prod
	@echo "✅ Prod deployment complete!"
	$(MAKE) get-secret ENV=prod

# ============================================
# Configuration Commands
# ============================================

# Setup GitHub token
setup-token:
ifndef ENV
	@echo "❌ Error: ENV not specified. Usage: make setup-token ENV=dev"
	@exit 1
endif
	@echo "🔑 Configuring GitHub token for $(ENV) environment..."
	@echo "Enter your GitHub Personal Access Token and press Enter:"
	@read TOKEN && \
	aws secretsmanager put-secret-value \
		--secret-id github-runner/token-$(ENV) \
		--secret-string "$$TOKEN" \
		--region us-east-1 && \
	echo "✅ GitHub token configured!"

# Get webhook secret
get-secret:
ifndef ENV
	@echo "❌ Error: ENV not specified. Usage: make get-secret ENV=dev"
	@exit 1
endif
	@echo "🔐 Webhook Secret for $(ENV) environment:"
	@echo "================================================"
	@aws secretsmanager get-secret-value \
		--secret-id github-runner/webhook-secret-$(ENV) \
		--query SecretString \
		--output text \
		--region us-east-1 2>/dev/null || echo "Secret not found. Deploy first with: make deploy-$(ENV)"
	@echo ""
	@echo "🔗 Webhook URL:"
	@aws cloudformation describe-stacks \
		--stack-name github-runner-$(ENV) \
		--query "Stacks[0].Outputs[?OutputKey=='WebhookUrl'].OutputValue" \
		--output text \
		--region us-east-1 2>/dev/null || echo "Stack not deployed yet"

# ============================================
# Monitoring Commands
# ============================================

# Tail all logs (runner only - use logs-webhook for webhook logs)
logs:
ifndef ENV
	@echo "❌ Error: ENV not specified. Usage: make logs ENV=dev"
	@exit 1
endif
	@echo "📡 Tailing runner logs for $(ENV) environment (Ctrl+C to exit)..."
	@echo "Tip: Open another terminal and run 'make logs-webhook ENV=$(ENV)' for webhook logs"
	aws logs tail /aws/lambda/github-runner-executor-$(ENV) --follow

# Tail webhook logs only
logs-webhook:
ifndef ENV
	@echo "❌ Error: ENV not specified. Usage: make logs-webhook ENV=dev"
	@exit 1
endif
	@echo "📡 Webhook Lambda Logs for $(ENV) (Ctrl+C to exit)..."
	@aws logs tail /aws/lambda/github-runner-webhook-$(ENV) --follow

# Tail runner logs only
logs-runner:
ifndef ENV
	@echo "❌ Error: ENV not specified. Usage: make logs-runner ENV=dev"
	@exit 1
endif
	@echo "🏃 Runner Lambda Logs for $(ENV) (Ctrl+C to exit)..."
	@aws logs tail /aws/lambda/github-runner-executor-$(ENV) --follow

# ============================================
# Teardown Commands
# ============================================

# Destroy sandbox stack
destroy-sandbox:
	@echo "💣 Destroying sandbox stack..."
	sam delete --config-env sandbox --no-prompts
	@echo "✅ Sandbox stack destroyed"

# Destroy dev stack
destroy-dev:
	@echo "💣 Destroying dev stack..."
	sam delete --config-env dev --no-prompts
	@echo "✅ Dev stack destroyed"

# Destroy prod stack (requires manual confirmation in SAM)
destroy-prod:
	@echo "💣 Destroying prod stack..."
	@echo "⚠️  This will DESTROY the PRODUCTION stack!"
	@echo "⚠️  SAM will prompt you for confirmation..."
	sam delete --config-env prod

# ============================================
# Maintenance Commands
# ============================================

# Clean build artifacts
clean:
	@echo "🧹 Cleaning build artifacts..."
	@rm -rf .aws-sam/ dist/
	@find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
	@find . -type f -name "*.pyc" -delete 2>/dev/null || true
	@echo "✅ Build artifacts cleaned"

# Clean SAM cache and Docker
clean-cache: clean
	@echo "🧹 Cleaning SAM cache and Docker containers..."
	@docker system prune -f
	@echo "✅ Cache cleaned"

# ============================================
# Utility Commands
# ============================================

# Get stack status
status:
ifndef ENV
	@echo "❌ Error: ENV not specified. Usage: make status ENV=dev"
	@exit 1
endif
	@echo "📊 Stack Status for $(ENV):"
	@aws cloudformation describe-stacks \
		--stack-name github-runner-$(ENV) \
		--query "Stacks[0].{Status:StackStatus,Created:CreationTime,Updated:LastUpdatedTime}" \
		--output table \
		--region us-east-1 2>/dev/null || echo "Stack not deployed"

# List all stacks
list-stacks:
	@echo "📋 All GitHub Runner Stacks:"
	@aws cloudformation list-stacks \
		--query "StackSummaries[?starts_with(StackName, 'github-runner')].{Name:StackName,Status:StackStatus,Created:CreationTime}" \
		--output table \
		--region us-east-1

# Show outputs
outputs:
ifndef ENV
	@echo "❌ Error: ENV not specified. Usage: make outputs ENV=dev"
	@exit 1
endif
	@echo "📤 Stack Outputs for $(ENV):"
	@aws cloudformation describe-stacks \
		--stack-name github-runner-$(ENV) \
		--query "Stacks[0].Outputs" \
		--output table \
		--region us-east-1 2>/dev/null || echo "Stack not deployed"
