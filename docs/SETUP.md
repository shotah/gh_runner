# Detailed Setup Guide

This guide provides step-by-step instructions for setting up the Lambda-based GitHub Actions runner.

## Table of Contents

1. [Initial Setup](#initial-setup)
2. [GitHub Token Setup](#github-token-setup)
3. [GitHub Webhook Configuration](#github-webhook-configuration)
4. [GitHub App Setup (Advanced)](#github-app-setup-advanced)
5. [Testing Your Setup](#testing-your-setup)
6. [Troubleshooting](#troubleshooting)

## Initial Setup

### Prerequisites Check

Before deploying, ensure you have:

```bash
# Check Node.js version (18+ required)
node --version

# Check npm
npm --version

# Check AWS CLI
aws --version

# Check Docker
docker --version

# Check CDK CLI (install if needed)
cdk --version
# If not installed: npm install -g aws-cdk
```

### AWS Account Setup

1. **Configure AWS credentials:**

```bash
aws configure
# Enter your AWS Access Key ID
# Enter your AWS Secret Access Key
# Default region: us-east-1 (or your preferred region)
# Default output format: json
```

2. **Bootstrap CDK (first time in this AWS account/region):**

```bash
cdk bootstrap aws://ACCOUNT-ID/REGION
# Or simply: cdk bootstrap
```

### Deploy the Stack

```bash
# Install dependencies
npm install

# Build TypeScript
npm run build

# Preview changes (optional)
cdk diff

# Deploy
cdk deploy

# Approve the IAM changes when prompted
```

**Save the output values!** You'll need:
- `WebhookUrl`
- `GithubTokenSecretArn`
- `WebhookSecretArn`

## GitHub Token Setup

### Option 1: Personal Access Token (Quickest)

1. **Generate a Personal Access Token:**
   - Go to GitHub → Settings → Developer settings → Personal access tokens → Tokens (classic)
   - Click "Generate new token (classic)"
   - Token name: `lambda-runner`
   - Expiration: Choose based on your security policy
   - Scopes:
     - ✅ `repo` (Full control of private repositories)
     - ✅ `workflow` (Update GitHub Action workflows)
     - ✅ `admin:org` → `read:org` (if using organization runners)

2. **Copy the token** (you won't see it again!)

3. **Update the secret in AWS:**

```bash
aws secretsmanager put-secret-value \
  --secret-id github-runner/token \
  --secret-string '{"token":"ghp_YOUR_TOKEN_HERE"}'
```

4. **Verify:**

```bash
aws secretsmanager get-secret-value \
  --secret-id github-runner/token \
  --query SecretString \
  --output text
```

### Option 2: GitHub App (Production Recommended)

See [GitHub App Setup](#github-app-setup-advanced) section below.

## GitHub Webhook Configuration

### Get Your Webhook Secret

```bash
aws secretsmanager get-secret-value \
  --secret-id github-runner/webhook-secret \
  --query SecretString \
  --output text
```

Copy this value - you'll need it for GitHub webhook configuration.

### Configure Webhook in GitHub

#### For Repository-Level Runner:

1. Go to your repository on GitHub
2. Click **Settings** → **Webhooks** → **Add webhook**
3. Configure:
   - **Payload URL**: `https://YOUR_API_GATEWAY_URL/` (from CDK output)
   - **Content type**: `application/json`
   - **Secret**: Paste the webhook secret from above
   - **SSL verification**: Enable SSL verification
   - **Which events**: Select "Let me select individual events"
     - ✅ Workflow jobs
     - ❌ Uncheck everything else
   - **Active**: ✅ Checked
4. Click **Add webhook**

#### For Organization-Level Runner:

1. Go to your organization on GitHub
2. Click **Settings** → **Webhooks** → **Add webhook**
3. Follow same configuration as repository-level
4. This will trigger for ALL repositories in the organization

### Verify Webhook

After adding the webhook:

1. GitHub will send a `ping` event
2. Check **Recent Deliveries** tab
3. Should see a green checkmark ✅
4. Response body should be: `{"message": "pong"}`

## GitHub App Setup (Advanced)

GitHub Apps provide better security and granular permissions than Personal Access Tokens.

### Create GitHub App

1. **Go to GitHub → Settings → Developer settings → GitHub Apps → New GitHub App**

2. **Configure the app:**
   - **GitHub App name**: `lambda-runner-app`
   - **Homepage URL**: Your organization/repo URL
   - **Webhook URL**: Your API Gateway URL (from CDK output)
   - **Webhook secret**: Your webhook secret (from AWS Secrets Manager)
   - **Repository permissions:**
     - Actions: Read & write
     - Contents: Read
     - Metadata: Read (automatically selected)
   - **Subscribe to events:**
     - ✅ Workflow job
   - **Where can this GitHub App be installed**:
     - Choose based on your needs (only this account or any account)

3. **Create the app**

### Install GitHub App

1. After creation, click **Install App**
2. Choose which repositories to install on
3. Click **Install**

### Generate Private Key

1. In your GitHub App settings, scroll to **Private keys**
2. Click **Generate a private key**
3. Download the `.pem` file

### Update Lambda Function

The runner Lambda needs to be modified to use GitHub App authentication:

```bash
# Store the private key in Secrets Manager
aws secretsmanager create-secret \
  --name github-runner/app-private-key \
  --secret-string file://path/to/your-app.private-key.pem

# Update the GitHub token secret with app details
aws secretsmanager put-secret-value \
  --secret-id github-runner/token \
  --secret-string '{
    "app_id": "YOUR_APP_ID",
    "installation_id": "YOUR_INSTALLATION_ID",
    "private_key_secret": "github-runner/app-private-key"
  }'
```

**Note:** You'll need to modify `lambda/runner/index.py` to handle GitHub App authentication (JWT token generation).

## Testing Your Setup

### Create a Test Workflow

Create `.github/workflows/test-runner.yml` in your repository:

```yaml
name: Test Lambda Runner

on:
  workflow_dispatch:  # Manual trigger for testing

jobs:
  test:
    runs-on: [self-hosted, lambda-runner]

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Test AWS CLI
        run: aws --version

      - name: Test SAM CLI
        run: sam --version

      - name: Check environment
        run: |
          echo "Runner: $RUNNER_NAME"
          echo "OS: $RUNNER_OS"
          echo "Architecture: $RUNNER_ARCH"
          echo "Working directory: $(pwd)"
          df -h
          free -h
```

### Run the Test

1. Go to your repository → Actions
2. Select "Test Lambda Runner" workflow
3. Click "Run workflow"
4. Watch the workflow execution

### Monitor Logs

**Watch webhook logs:**
```bash
aws logs tail /aws/lambda/github-runner-webhook --follow
```

**Watch runner logs:**
```bash
aws logs tail /aws/lambda/github-runner-executor --follow
```

## Troubleshooting

### Webhook Not Receiving Events

**Check:**
1. Webhook is active in GitHub
2. Events include "Workflow jobs"
3. Recent Deliveries shows successful delivery (green checkmark)

**Debug:**
```bash
# Check API Gateway logs
aws logs tail /aws/apigateway/welcome --follow

# Check webhook Lambda logs
aws logs tail /aws/lambda/github-runner-webhook --follow
```

### Runner Not Starting

**Check:**
1. GitHub token is valid and has correct permissions
2. Webhook Lambda has permission to invoke Runner Lambda
3. Runner Lambda has been deployed successfully

**Debug:**
```bash
# Test webhook Lambda directly
aws lambda invoke \
  --function-name github-runner-webhook \
  --payload '{"body":"{\"action\":\"queued\"}","headers":{"x-github-event":"workflow_job"}}' \
  response.json

# Check runner Lambda exists
aws lambda get-function --function-name github-runner-executor
```

### Permission Errors in Runner

**Check:**
1. Runner Lambda has necessary IAM permissions
2. Review `lib/github-runner-stack.ts` IAM policies

**Add specific permissions:**
```typescript
// Edit lib/github-runner-stack.ts
runnerFunction.addToRolePolicy(new iam.PolicyStatement({
  effect: iam.Effect.ALLOW,
  actions: ['service:Action'],
  resources: ['arn:aws:service:::resource'],
}));
```

Then redeploy:
```bash
npm run build && cdk deploy
```

### Timeout Issues

If jobs are timing out:

1. **Check job execution time:**
   - Must be < 15 minutes
   - Review CloudWatch Logs for timing

2. **Optimize SAM deployments:**
   ```bash
   sam deploy --no-confirm-changeset --no-fail-on-empty-changeset
   ```

3. **Consider breaking into multiple jobs:**
   ```yaml
   jobs:
     build:
       runs-on: [self-hosted, lambda-runner]
       steps:
         - run: sam build

     deploy:
       needs: build
       runs-on: [self-hosted, lambda-runner]
       steps:
         - run: sam deploy
   ```

### GitHub Token Expired

**Rotate token:**
```bash
# Generate new token in GitHub
# Update secret
aws secretsmanager put-secret-value \
  --secret-id github-runner/token \
  --secret-string '{"token":"NEW_TOKEN"}'
```

### Clean Up and Redeploy

If things are completely broken:

```bash
# Destroy the stack
cdk destroy

# Redeploy fresh
npm run build
cdk deploy
```

## Next Steps

Once everything is working:

1. Update IAM permissions to least privilege
2. Set up monitoring and alerting (CloudWatch Alarms)
3. Consider GitHub Apps for better security
4. Add custom metrics for runner performance
5. Implement cost tracking tags

## Support

- Check CloudWatch Logs first
- Review GitHub webhook delivery status
- Test with simple workflows before complex ones
- Verify IAM permissions match your needs

Happy CI/CD! 🚀
