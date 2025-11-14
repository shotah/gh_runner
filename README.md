# GitHub Actions Lambda Runner (SAM CLI)

AWS Lambda-based self-hosted GitHub Actions runner with AWS CLI and SAM CLI pre-installed. This solution provides on-demand, serverless execution of GitHub Actions workflows with automatic scaling and cost optimization.

> 💡 **Built with AWS SAM CLI** - Matches the [aws_fastapi_template](https://github.com/shotah/aws_fastapi_template) pattern for team consistency!

## 📚 Documentation

- **[Setup Guide](docs/SETUP.md)** - Complete step-by-step setup instructions
- **[SAM Migration Guide](SAM_MIGRATION.md)** - Why we chose SAM and migration details
- **[Architecture](docs/ARCHITECTURE.md)** - System design and component details
- **[Security](docs/SECURITY.md)** - Security considerations and hardening guide
- **[Secrets Management](docs/SECRETS_MANAGEMENT.md)** - How to manage GitHub tokens and secrets
- **[Tagging Strategy](docs/TAGGING_STRATEGY.md)** - Cost tracking and resource organization
- **[Contributing](docs/CONTRIBUTING.md)** - Development and contribution guidelines

## Architecture

```
GitHub Webhook → API Gateway → Webhook Lambda → Runner Lambda (with AWS CLI/SAM)
                                                      ↓
                                                 Execute Workflow
```

### Components

1. **API Gateway**: Receives GitHub webhook events
2. **Webhook Lambda**: Validates and routes `workflow_job` events
3. **Runner Lambda**: Executes GitHub Actions workflows as ephemeral runner
   - Pre-installed with AWS CLI v2
   - Pre-installed with SAM CLI
   - 15-minute timeout (perfect for microservices deployments)
   - 10GB ephemeral storage

## Features

✅ **Serverless and on-demand** - Pay only for execution time  
✅ **Auto-scaling** - Up to 10 concurrent runners  
✅ **Pre-installed tools:**
  - AWS CLI v2 (latest)
  - AWS SAM CLI (latest)
  - Python 3.13
  - Git, tar, gzip, jq, and common utilities  
✅ **Ephemeral runners** - Auto-cleanup after each job  
✅ **Security** - Webhook signature verification  
✅ **AWS-ready** - Comprehensive IAM permissions for deployments  
✅ **Fast** - High-memory Lambda for quick execution  

## Prerequisites

- AWS SAM CLI ([Installation Guide](https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/install-sam-cli.html))
- AWS CLI configured with appropriate credentials
- Docker (for building runner image)
- GitHub Personal Access Token ([Generate here](https://github.com/settings/tokens))

**No Node.js or TypeScript required!** ✅

## Quick Start

> 💡 **New to this project?** Start with **[docs/SETUP.md](docs/SETUP.md)** for complete setup instructions!

### Using Make (Recommended)

The Makefile automatically loads environment variables from `.env` file!

```bash
# 1. Build the application
make build

# 2. Deploy to dev environment
make deploy-dev

# 3. Get webhook URL and secret
make get-secret ENV=dev

# 4. Configure in GitHub
# Settings → Webhooks → Add webhook
# Use URL and secret from step 3
```

### Available Commands

```bash
make help               # Show all commands
make build              # Build SAM application
make deploy-dev         # Deploy to dev
make deploy-prod        # Deploy to production
make logs ENV=dev       # Tail logs
make get-secret ENV=dev # Get webhook secret
make destroy-dev        # Remove dev stack
```

> 💡 See `make help` for complete command reference!

### Manual Setup

<details>
<summary>Click to expand manual installation steps</summary>

### 1. Build the Application

```bash
sam build --use-container
```

This builds both Lambda functions and the Docker image for the runner.

### 2. Deploy the Stack

```bash
sam deploy --guided --config-env dev
```

Or use environment-specific commands:
```bash
sam deploy --config-env sandbox  # Sandbox environment
sam deploy --config-env dev      # Development environment
sam deploy --config-env prod     # Production environment
```

Note the outputs:
- `WebhookUrl`: Your API Gateway endpoint
- `GitHubTokenSecretArn`: Secret to update with your GitHub token
- `WebhookSecretArn`: Secret for webhook validation
- `ECRRepositoryUri`: Where to push the runner Docker image

### 3. Configure GitHub Token

```bash
aws secretsmanager put-secret-value \
  --secret-id github-runner/token-dev \
  --secret-string "ghp_yourTokenHere"
```

Or use the helper:
```bash
make setup-token ENV=dev
```

### 4. Build and Push Docker Image

```bash
# Build the runner Docker image
make docker-build

# Push to ECR
make docker-push ENV=dev
```

</details>

**GitHub Token Permissions Required:**
- `repo` (full control)
- `workflow`
- `admin:org` → `read:org` (for organization runners)

> 💡 See **[docs/SECRETS_MANAGEMENT.md](docs/SECRETS_MANAGEMENT.md)** for different ways to provide your GitHub token!

### 5. Get Webhook Secret

```bash
# Using Make (shows URL and secret)
make get-secret ENV=dev

# Or manually
aws secretsmanager get-secret-value \
  --secret-id github-runner/webhook-secret-dev \
  --query SecretString \
  --output text
```

### 6. Configure GitHub Webhook

1. Go to your GitHub repository → Settings → Webhooks → Add webhook
2. **Payload URL**: Use the `WebhookUrl` from CDK output
3. **Content type**: `application/json`
4. **Secret**: Use the value from step 5
5. **Events**: Select "Workflow jobs" only
6. Save webhook

### 7. Update Your GitHub Actions Workflow

Add labels to specify the Lambda runner. Available labels:
- `self-hosted` - Basic self-hosted runner
- `lambda-runner` - Identifies this as the Lambda-based runner
- `aws-cli` - Indicates AWS CLI is available
- `sam-cli` - Indicates SAM CLI is available
- `python` - Python runtime available
- `python3.13` - Specific Python version
- `linux`, `x64` - Platform identifiers

```yaml
name: Deploy with Lambda Runner

on:
  push:
    branches: [main]

jobs:
  deploy:
    # Use any combination of these labels to target this runner
    runs-on: [self-hosted, lambda-runner]
    # Or be more specific:
    # runs-on: [self-hosted, sam-cli, python3.13]
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
      
      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
          aws-region: us-east-1
      
      - name: SAM Build
        run: sam build
      
      - name: SAM Deploy
        run: |
          sam deploy \
            --no-confirm-changeset \
            --no-fail-on-empty-changeset \
            --stack-name my-app \
            --capabilities CAPABILITY_IAM
```

## Configuration

### Environment Variables

The runner Lambda function supports these environment variables:

- `GITHUB_TOKEN_SECRET_NAME`: Secrets Manager secret containing GitHub token
- `ENVIRONMENT`: Deployment environment (sandbox/dev/prod)
- Runner version is automatically detected from the pre-installed runner in the Docker image

### Customizing Permissions

⚠️ **Important:** The default IAM permissions are very broad! 

Edit `template.yaml` to adjust IAM permissions based on your needs. See **[docs/SECURITY.md](docs/SECURITY.md)** for guidance on scoping down permissions.

### Resource Tagging

All resources are tagged for cost tracking. Customize tags via parameters:

```bash
# In samconfig.toml
parameter_overrides = [
    "Environment=production",
    "CostCenter=Platform",
    "Owner=Platform-Team"
]
```

Or via `.env` file (automatically loaded by Makefile):
```bash
ENVIRONMENT=production
COST_CENTER=Platform
OWNER=devops-team
make deploy-prod
```

See **[docs/TAGGING_STRATEGY.md](docs/TAGGING_STRATEGY.md)** for details on cost tracking and tag management.

## Limitations

- **15-minute maximum execution time** (Lambda limit)
- **10GB ephemeral storage** (Lambda limit)
- **Workflow jobs only** (not full self-hosted runner features)

For longer workflows, consider:
1. Breaking jobs into smaller steps
2. Using CodeBuild or Fargate instead (can be triggered via similar webhook pattern)

## Troubleshooting

### Runner not picking up jobs

1. Check CloudWatch Logs for the webhook function
2. Verify GitHub token has correct permissions
3. Ensure workflow labels match: `self-hosted` or `lambda-runner`
4. Check GitHub webhook delivery status

### Timeout issues

- Jobs must complete within 15 minutes
- For SAM deploys, consider async deployment patterns
- Use `sam deploy --no-confirm-changeset` to avoid prompts

### Permission errors

- Review IAM policies in the CDK stack
- Ensure runner has necessary permissions for your AWS operations
- Check CloudWatch Logs for detailed error messages

## Cost Optimization

- Runners are ephemeral (no idle compute costs)
- Pay only for actual execution time
- Default 10 concurrent runner limit prevents runaway costs
- Consider reserved concurrency for predictable workloads

## Security Best Practices

⚠️ **IMPORTANT:** Review **[docs/SECURITY.md](docs/SECURITY.md)** for comprehensive security guidance.

**Critical Actions:**
1. **Scope down IAM permissions** - The default is VERY permissive (admin-level for many services)
2. **Rotate GitHub tokens regularly** - Set up a 90-day rotation schedule
3. **Use GitHub Apps instead of PATs** - More secure with automatic token rotation
4. **Enable branch protection** - Prevent unauthorized workflow modifications
5. **Disable fork PRs** - Don't run workflows from untrusted forks
6. **Monitor CloudWatch Logs** - Watch for suspicious activity

**Already Implemented:**
- ✅ Webhook signature verification (HMAC-SHA256)
- ✅ Secrets encrypted in AWS Secrets Manager
- ✅ Ephemeral runners (auto-cleanup)
- ✅ CloudWatch + CloudTrail logging

See **[docs/SECURITY.md](docs/SECURITY.md)** for detailed security considerations and hardening steps.

## Advanced: Using GitHub Apps (Recommended)

For production use, GitHub Apps provide better security than Personal Access Tokens:

1. Create a GitHub App in your organization
2. Install the app in your repositories
3. Grant permissions: `actions: read/write`, `metadata: read`
4. Generate and download a private key
5. Store private key in Secrets Manager
6. Modify runner Lambda to authenticate with GitHub App

## Development

### Local Testing

Test webhook Lambda locally:

```bash
cd lambda/webhook
python -m pytest
```

### Updating Runner

To update the runner version:

```bash
# Edit lib/github-runner-stack.ts
RUNNER_VERSION: '2.312.0'

# Rebuild and deploy
npm run build
cdk deploy
```

### Logs

View logs interactively:
```bash
make logs
```

Or view specific logs:
```bash
# Webhook logs
make logs-webhook

# Runner logs  
make logs-runner
```

## Cleanup

Remove all resources:

```bash
make destroy
```

Or manually:
```bash
cdk destroy
```

Note: This will delete all Lambda functions, API Gateway, and associated resources but will retain Secrets Manager secrets by default.

## Contributing

Issues and pull requests welcome! See **[docs/CONTRIBUTING.md](docs/CONTRIBUTING.md)** for development guidelines.

## Additional Resources

- **[Example Workflows](examples/)** - Sample GitHub Actions workflows
- **[Architecture Details](docs/ARCHITECTURE.md)** - Deep dive into system design
- **[Security Hardening](docs/SECURITY.md)** - Production security checklist
- **[Cost Optimization](docs/TAGGING_STRATEGY.md)** - Track and optimize AWS costs

## License

MIT License - see LICENSE file