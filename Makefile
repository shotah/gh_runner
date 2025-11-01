.PHONY: help install build deploy destroy diff synth clean \
        setup-token get-secret logs security-check bootstrap

# Default target
help:
	@echo "GitHub Actions Lambda Runner - Available Commands"
	@echo "=================================================="
	@echo ""
	@echo "Setup & Deployment:"
	@echo "  make install          - Install Node.js dependencies"
	@echo "  make build            - Build TypeScript code"
	@echo "  make bootstrap        - Bootstrap CDK (first time only)"
	@echo "  make deploy           - Deploy the stack to AWS"
	@echo "  make destroy          - Remove all AWS resources"
	@echo ""
	@echo "Configuration:"
	@echo "  make setup-token      - Configure GitHub Personal Access Token"
	@echo "  make get-secret       - Display webhook secret for GitHub config"
	@echo ""
	@echo "Development:"
	@echo "  make diff             - Show changes that will be deployed"
	@echo "  make synth            - Synthesize CloudFormation template"
	@echo "  make clean            - Remove build artifacts"
	@echo ""
	@echo "Monitoring:"
	@echo "  make logs             - View Lambda function logs (interactive)"
	@echo "  make security-check   - Run security audit"
	@echo ""
	@echo "Quick Start:"
	@echo "  make install && make build && make deploy"

# Install dependencies
install:
	@echo "📦 Installing dependencies..."
	npm install

# Build TypeScript
build:
	@echo "🔨 Building TypeScript..."
	npm run build

# Bootstrap CDK (first time only)
bootstrap:
	@echo "🔧 Bootstrapping CDK..."
	cdk bootstrap

# Deploy to AWS
deploy: build
	@echo "🚀 Deploying to AWS..."
	cdk deploy --require-approval never

# Deploy with approval
deploy-confirm: build
	@echo "🚀 Deploying to AWS (with confirmation)..."
	cdk deploy

# Show diff
diff: build
	@echo "🔍 Showing deployment diff..."
	cdk diff

# Synthesize CloudFormation
synth: build
	@echo "📝 Synthesizing CloudFormation template..."
	cdk synth

# Destroy stack
destroy:
	@echo "💣 Destroying stack..."
	@echo "⚠️  This will remove all resources!"
	@read -p "Are you sure? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		cdk destroy; \
	else \
		echo "Cancelled."; \
	fi

# Setup GitHub token
setup-token:
	@bash scripts/setup-github-token.sh

# Get webhook secret
get-secret:
	@bash scripts/get-webhook-secret.sh

# View logs
logs:
	@bash scripts/view-logs.sh

# Security check
security-check:
	@bash scripts/check-security.sh

# Clean build artifacts
clean:
	@echo "🧹 Cleaning build artifacts..."
	rm -rf dist/
	rm -rf cdk.out/
	rm -rf node_modules/
	rm -f *.js *.d.ts
	find . -name "*.js" -type f -not -path "./node_modules/*" -delete
	find . -name "*.d.ts" -type f -not -path "./node_modules/*" -delete

# Quick deploy (all in one)
quick-deploy: install deploy
	@echo "✅ Deployment complete!"
	@echo ""
	@echo "Next steps:"
	@echo "1. Run: make setup-token"
	@echo "2. Run: make get-secret"
	@echo "3. Configure GitHub webhook with the secret"

# Watch mode for development
watch:
	@echo "👀 Watching for changes..."
	npm run watch

# List all Lambda functions
list-functions:
	@echo "📋 Lambda Functions:"
	@aws lambda list-functions \
		--query "Functions[?starts_with(FunctionName, 'github-runner')].{Name:FunctionName,Runtime:Runtime,Memory:MemorySize,Timeout:Timeout}" \
		--output table

# Get webhook URL
get-webhook-url:
	@echo "🔗 Webhook URL:"
	@aws cloudformation describe-stacks \
		--stack-name GithubRunnerStack \
		--query "Stacks[0].Outputs[?OutputKey=='WebhookUrl'].OutputValue" \
		--output text

# Complete setup info
setup-info:
	@echo "⚙️  Setup Information"
	@echo "===================="
	@echo ""
	@echo "Webhook URL:"
	@aws cloudformation describe-stacks \
		--stack-name GithubRunnerStack \
		--query "Stacks[0].Outputs[?OutputKey=='WebhookUrl'].OutputValue" \
		--output text || echo "Stack not deployed yet"
	@echo ""
	@echo "Webhook Secret:"
	@aws secretsmanager get-secret-value \
		--secret-id github-runner/webhook-secret \
		--query SecretString \
		--output text 2>/dev/null || echo "Not available yet"
	@echo ""
	@echo "GitHub Token Status:"
	@aws secretsmanager describe-secret \
		--secret-id github-runner/token \
		--query '{LastChanged:LastChangedDate,Created:CreatedDate}' \
		--output table 2>/dev/null || echo "Not configured yet"

# Tail webhook logs
logs-webhook:
	@echo "📡 Webhook Lambda Logs (Ctrl+C to exit)..."
	@aws logs tail /aws/lambda/github-runner-webhook --follow

# Tail runner logs
logs-runner:
	@echo "🏃 Runner Lambda Logs (Ctrl+C to exit)..."
	@aws logs tail /aws/lambda/github-runner-executor --follow

# Check stack status
status:
	@echo "📊 Stack Status:"
	@aws cloudformation describe-stacks \
		--stack-name GithubRunnerStack \
		--query "Stacks[0].{Status:StackStatus,Created:CreationTime,Updated:LastUpdatedTime}" \
		--output table 2>/dev/null || echo "Stack not deployed"

# Validate templates
validate: build
	@echo "✓ Validating CDK templates..."
	cdk synth --quiet
	@echo "✅ Templates are valid"

