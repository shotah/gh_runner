# GitHub Actions Lambda Runner - Quick Start (SAM CLI)

## 🚀 5-Minute Setup

### Prerequisites
- [AWS SAM CLI](https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/install-sam-cli.html) installed
- [Docker](https://docs.docker.com/get-docker/) running
- AWS CLI configured (`aws configure`)
- GitHub Personal Access Token ([generate here](https://github.com/settings/tokens))

### Step-by-Step

```bash
# 1. Clone and enter directory
git clone https://github.com/shotah/gh_runner.git
cd gh_runner

# 2. (Optional) Create .env file
cp .env.example .env
# Edit .env with your GITHUB_TOKEN

# 3. Build
make build

# 4. Deploy to dev
make deploy-dev

# 5. Get webhook configuration
make get-secret ENV=dev
# Copy the URL and secret

# 6. Build and push Docker image
make docker-build
make docker-push ENV=dev

# 7. Configure in GitHub
# Go to: Settings → Webhooks → Add webhook
# Paste URL and secret from step 5
# Select event: Workflow jobs
```

**Done!** Test by running a workflow with `runs-on: [self-hosted, lambda-runner]`

---

## 📋 Commands Cheat Sheet

| Task | Command |
|------|---------|
| Build | `make build` |
| Deploy Dev | `make deploy-dev` |
| Deploy Prod | `make deploy-prod` |
| View Logs | `make logs ENV=dev` |
| Get Secret | `make get-secret ENV=dev` |
| Remove Stack | `make destroy-dev` |
| Build Docker | `make docker-build` |
| Push Docker | `make docker-push ENV=dev` |
| Check Status | `make status ENV=dev` |
| Show All Commands | `make help` |

---

## 🏷️ Multi-Environment Setup

Deploy to multiple environments:

```bash
# Sandbox (for testing)
make deploy-sandbox
make get-secret ENV=sandbox

# Development
make deploy-dev
make get-secret ENV=dev

# Production
make deploy-prod
make get-secret ENV=prod
```

Each environment gets:
- Separate stack name (`github-runner-sandbox`, `github-runner-dev`, etc.)
- Separate secrets (`github-runner/token-dev`, etc.)
- Separate ECR repositories
- Separate tags (Environment=dev, etc.)

---

## 🧪 Testing Locally

SAM CLI supports local testing (not available with CDK!):

```bash
# Start API Gateway locally
sam local start-api

# Test webhook endpoint
curl -X POST http://localhost:3000/ \
  -H "Content-Type: application/json" \
  -d '{"action": "queued"}'

# Invoke function with test event
sam local invoke WebhookFunction \
  -e events/webhook-test.json
```

---

## 📊 Monitoring

### View Logs
```bash
# All logs (webhook + runner)
make logs ENV=dev

# Just webhook
make logs-webhook ENV=dev

# Just runner
make logs-runner ENV=dev
```

### Check Status
```bash
# Stack status
make status ENV=dev

# List all stacks
make list-stacks

# Show outputs
make outputs ENV=dev
```

---

## 🔧 Troubleshooting

### "SAM CLI not found"
```bash
# Install SAM CLI
brew install aws-sam-cli  # macOS
```

### "Docker not running"
```bash
# Start Docker Desktop
docker ps  # Verify it works
```

### "Stack already exists" (from CDK)
```bash
# Delete old CDK stack
aws cloudformation delete-stack \
  --stack-name GithubRunnerStack

# Then deploy SAM version
make deploy-dev
```

### "ECR image not found"
```bash
# Deploy stack first (creates ECR repo)
make deploy-dev

# Then build and push
make docker-build
make docker-push ENV=dev
```

### "Webhook not triggering"
1. Check GitHub webhook deliveries (Settings → Webhooks → Recent Deliveries)
2. Verify secret matches: `make get-secret ENV=dev`
3. Check webhook Lambda logs: `make logs-webhook ENV=dev`
4. Ensure workflow uses correct labels: `runs-on: [self-hosted, lambda-runner]`

---

## 📚 Learn More

- **[SAM_MIGRATION.md](SAM_MIGRATION.md)** - Why we chose SAM over CDK
- **[docs/SETUP.md](docs/SETUP.md)** - Complete setup guide
- **[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)** - How it works
- **[docs/SECURITY.md](docs/SECURITY.md)** - Security hardening
- **[aws_fastapi_template](https://github.com/shotah/aws_fastapi_template)** - Similar SAM pattern

---

## 🎉 Success Checklist

After setup, verify:

- [ ] `make build` completes without errors
- [ ] `make deploy-dev` successfully deploys
- [ ] `make get-secret ENV=dev` shows URL and secret
- [ ] GitHub webhook is configured and deliveries show success
- [ ] Test workflow with `runs-on: [self-hosted, lambda-runner]` executes
- [ ] Logs appear in CloudWatch: `make logs ENV=dev`
- [ ] Job completes successfully in GitHub Actions

**All green?** You're ready to go! 🚀

---

## 💡 Pro Tips

1. **Use .env for tokens**
   ```bash
   echo "GITHUB_TOKEN=ghp_xxx" > .env
   make deploy-dev  # Automatically uses .env
   ```

2. **Deploy to sandbox first**
   ```bash
   make deploy-sandbox  # Test without affecting dev/prod
   ```

3. **Watch logs during deployment**
   ```bash
   make logs-runner ENV=dev  # In one terminal
   # Trigger workflow in another terminal
   ```

4. **Keep CDK version as reference**
   ```bash
   git checkout cdk-exploration  # View CDK implementation
   ```

---

**Questions?** Check [SAM_MIGRATION.md](SAM_MIGRATION.md) or the [aws_fastapi_template](https://github.com/shotah/aws_fastapi_template) for similar patterns!
