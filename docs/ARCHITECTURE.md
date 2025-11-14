# Architecture Documentation

## Overview

This document describes the architecture of the Lambda-based GitHub Actions runner system.

## High-Level Architecture

```
┌─────────────────┐
│                 │
│  GitHub.com     │
│                 │
└────────┬────────┘
         │ Webhook (workflow_job event)
         │
         ▼
┌─────────────────────────────────────────┐
│   AWS API Gateway                       │
│   • REST API                            │
│   • POST /                              │
└────────┬────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────┐
│   Lambda: Webhook Receiver              │
│   • Validates GitHub signature          │
│   • Filters workflow_job events         │
│   • Invokes Runner Lambda               │
└────────┬────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────┐
│   Lambda: Runner Executor               │
│   • Pre-baked GitHub Actions runner     │
│   • Registers as ephemeral runner       │
│   • Executes workflow steps             │
│   • Pre-installed: AWS CLI, SAM CLI     │
└────────┬────────────────────────────────┘
         │
         ├───────────────────┬─────────────────┐
         ▼                   ▼                 ▼
┌────────────────┐  ┌────────────────┐  ┌────────────┐
│ AWS Services   │  │ GitHub API     │  │ Secrets    │
│ (deployment)   │  │ (runner reg)   │  │ Manager    │
└────────────────┘  └────────────────┘  └────────────┘
```

## Components

### 1. API Gateway

**Purpose:** HTTP endpoint for receiving GitHub webhooks

**Configuration:**

- Type: REST API
- Endpoint: Regional
- Method: POST
- Integration: Lambda Proxy

**Security:**

- Public endpoint (required by GitHub)
- Signature verification in Lambda
- Rate limiting available
- CloudWatch logging enabled

**Scaling:**

- Automatically scales
- No reserved capacity needed
- Pay per request

### 2. Webhook Receiver Lambda

**Language:** Python 3.13
**Memory:** 256 MB
**Timeout:** 30 seconds
**Architecture:** x86_64

**Responsibilities:**

1. Receive webhook events from API Gateway
2. Verify HMAC signature using shared secret (HMAC-SHA256)
3. Filter for `workflow_job` events with action `queued`
4. Check job labels (self-hosted, lambda-runner)
5. Invoke Runner Lambda asynchronously

**Code Structure:**

- `verify_signature()` - HMAC-SHA256 signature verification
- `should_trigger_runner()` - Label matching logic
- `invoke_runner_lambda()` - Async runner invocation
- `process_workflow_job()` - Workflow event processing
- `handler()` - Main entry point (low complexity)

**Environment Variables:**

- `GITHUB_WEBHOOK_SECRET`: ARN of webhook secret
- `RUNNER_FUNCTION_NAME`: Name of runner Lambda

**IAM Permissions:**

- Read from Secrets Manager (webhook secret)
- Invoke Runner Lambda function
- Write to CloudWatch Logs

**Event Flow:**

```python
Receive Event
    ↓
Verify Signature
    ↓
Parse Event Type
    ↓
If workflow_job + queued
    ↓
Check Labels
    ↓
Invoke Runner (async)
    ↓
Return 200 OK
```

### 3. Runner Executor Lambda

**Language:** Python 3.13
**Container:** Docker (custom image with pre-baked runner)
**Memory:** 3008 MB (high for performance)
**Timeout:** 900 seconds (15 minutes)
**Ephemeral Storage:** 10 GB
**Architecture:** x86_64

**Responsibilities:**

1. Retrieve GitHub token from Secrets Manager
2. Get registration token from GitHub API
3. Copy pre-installed runner from `/opt` to `/tmp` (writable location)
4. Configure runner as ephemeral
5. Execute workflow job
6. Auto-cleanup after completion

**Pre-installed Tools (in Docker image):**

- GitHub Actions runner (latest version auto-fetched at build time)
- AWS CLI v2 (latest)
- AWS SAM CLI
- Git
- Python 3.13
- jq (for JSON parsing in build)
- Common Linux utilities

**Environment Variables:**

- `GITHUB_TOKEN_SECRET_NAME`: Secret containing GitHub PAT

**Performance Optimizations:**

- Runner binary pre-baked into Docker image (~80MB saved per execution)
- Latest runner version fetched automatically during Docker build
- Version tracked in `/opt/actions-runner/version.txt`
- Eliminates download overhead (reduces cold start by ~10-15 seconds)

**IAM Permissions:**
Broad permissions for AWS deployments:

- CloudFormation (full)
- Lambda (full)
- S3 (full)
- IAM (create/manage roles)
- API Gateway, DynamoDB, etc.

**Execution Flow:**

```python
Receive Job Info
    ↓
Get GitHub Token (from Secrets Manager)
    ↓
Get Registration Token (from GitHub API)
    ↓
Copy Runner from /opt to /tmp
    ↓
Configure Runner (ephemeral, --disableupdate)
    ↓
Start Runner (./run.sh)
    ↓
Runner Picks Up Job
    ↓
Execute Job Steps
    ↓
Cleanup /tmp (automatic)
```

**Key Implementation Details:**

- Runner copied from `/opt/actions-runner` (read-only) to `/tmp/runner-work` (writable)
- Work directory set to `/tmp/runner-work/work` (absolute path required)
- Timeout set to 840 seconds (14 minutes) leaving 1 minute for cleanup
- Runner auto-removes itself after job (ephemeral mode)

### 3a. Docker Image Build Process

**Dockerfile Location:** `lambda/runner/Dockerfile`

**Build Process:**

1. Base image: `public.ecr.aws/lambda/python:3.13`
2. Install system dependencies: `curl`, `jq`, `git`, `tar`, AWS CLI v2
3. Install AWS SAM CLI via pip
4. **Fetch latest GitHub Actions runner:**
   - Query GitHub API: `https://api.github.com/repos/actions/runner/releases/latest`
   - Extract version using `jq`
   - Download from: `https://github.com/actions/runner/releases/download/v{VERSION}/actions-runner-linux-x64-{VERSION}.tar.gz`
   - Extract to `/opt/actions-runner`
   - Save version to `/opt/actions-runner/version.txt`
5. Copy Lambda handler code
6. Set CMD to handler function

**Build Commands:**

```bash
# Build locally
make docker-build

# Push to ECR (requires REPO_URI env var)
make docker-push

# Combined
make docker-push  # Includes build step
```

**Image Size Optimization:**

- Multi-stage build could reduce size (~500MB currently)
- Cleanup of package manager caches
- Removal of unnecessary dependencies

**Versioning Strategy:**

- Always fetches latest runner at build time
- Tag images with date or commit hash for rollback
- ECR lifecycle policies to cleanup old images

### 4. Secrets Manager

**Secrets Stored:**

1. **GitHub Token** (`github-runner/token`)
   - Type: Personal Access Token or GitHub App credentials
   - Format: JSON `{"token": "..."}`
   - Rotation: Manual (recommended: 90 days)
   - Access: Runner Lambda only

2. **Webhook Secret** (`github-runner/webhook-secret`)
   - Type: Random string
   - Auto-generated during deployment
   - Used for HMAC verification
   - Access: Webhook Lambda only

**Security:**

- Encrypted at rest (AWS KMS)
- Access via IAM only
- Audit logging via CloudTrail
- No direct console access needed

### 5. CloudWatch Logs

**Log Groups:**

- `/aws/lambda/github-runner-webhook`
- `/aws/lambda/github-runner-executor`

**Retention:** 7 days (configurable)

**What's Logged:**

- Webhook events received
- Signature verification results
- Runner invocations
- Job execution progress
- Errors and exceptions
- GitHub API interactions

## Data Flow

### Webhook Event Processing

1. **GitHub** generates `workflow_job` event
2. **API Gateway** receives HTTP POST
3. **Webhook Lambda** validates and processes:

   ```json
   {
     "action": "queued",
     "workflow_job": {
       "id": 123,
       "name": "build",
       "labels": ["self-hosted", "lambda-runner"],
       "steps": [...]
     },
     "repository": {
       "full_name": "owner/repo"
     }
   }
   ```

4. **Runner Lambda** invoked asynchronously with job details
5. **Response** sent to GitHub (200 OK)

### Runner Execution

1. **Runner Lambda** starts (cold start: ~3-5 seconds with Docker)
2. Retrieves GitHub token from Secrets Manager
3. Calls GitHub API for registration token
4. Copies pre-installed runner from `/opt/actions-runner` to `/tmp/runner-work/runner`
   - Includes version.txt with installed runner version
   - Uses `shutil.copytree()` with symlinks preserved
5. Configures runner:

   ```bash
   ./config.sh \
     --url https://github.com/owner/repo \
     --token <registration-token> \
     --name lambda-runner-<job-id>-<timestamp> \
     --labels self-hosted,lambda-runner,linux,x64,aws-cli,sam-cli,python,python3.13 \
     --work /tmp/runner-work/work \
     --ephemeral \
     --disableupdate \
     --unattended
   ```

6. Starts runner:

   ```bash
   ./run.sh
   ```

7. Runner automatically picks up the queued job (by job ID)
8. Executes workflow steps with full AWS permissions
9. Reports results to GitHub in real-time
10. Runner auto-removes itself (ephemeral mode)
11. Lambda cleans up `/tmp` directory
12. Lambda exits

**Time Savings vs. Downloading:**

- Old: ~10-15 seconds to download + extract runner
- New: ~1-2 seconds to copy from `/opt` to `/tmp`
- Net improvement: **~10 seconds per execution**

## Scaling Characteristics

### API Gateway

- **Limits:** 10,000 requests/second (default)
- **Scaling:** Automatic
- **Cost:** $3.50 per million requests

### Lambda Functions

**Webhook Lambda:**

- **Concurrency:** Unlimited (default)
- **Cold Start:** ~200ms
- **Warm Execution:** ~50ms
- **Scaling:** Instant

**Runner Lambda:**

- **Concurrency:** 10 (reserved, configurable)
- **Cold Start:** ~3-5 seconds (container)
- **Warm Execution:** N/A (ephemeral)
- **Scaling:** Up to concurrency limit

### Cost Considerations

**Per Job Execution:**

- API Gateway: $0.0000035
- Webhook Lambda: $0.0000002 (256 MB, 50ms)
- Runner Lambda: ~$0.015 (3GB, 300s average)

**Monthly Estimate (100 jobs/day):**

- ~$45/month for compute
- Minimal storage/networking costs

## Security Architecture

### Defense in Depth

1. **Network Layer:**
   - API Gateway in AWS network
   - Regional endpoint (not edge-optimized)

2. **Authentication:**
   - HMAC signature verification
   - GitHub token stored in Secrets Manager
   - IAM role-based access

3. **Authorization:**
   - Lambda execution roles (least privilege)
   - Resource-based policies
   - Secret access policies

4. **Audit:**
   - CloudTrail for API calls
   - CloudWatch Logs for execution
   - VPC Flow Logs (if VPC enabled)

### Threat Model

**Threats Mitigated:**

- ✅ Unauthorized webhook calls (signature verification)
- ✅ Token exposure (Secrets Manager encryption)
- ✅ Excessive costs (concurrency limits)
- ✅ Resource access (IAM policies)

**Threats to Consider:**

- ⚠️ Compromised GitHub token (rotate regularly)
- ⚠️ Malicious workflow code (sandbox in Lambda)
- ⚠️ DDoS on webhook (rate limiting)

## Performance Optimization

### Webhook Lambda

- Minimal processing
- Async invocation of runner
- Quick response to GitHub

### Runner Lambda

- High memory allocation (faster CPU)
- Large ephemeral storage
- Pre-built container image
- Efficient runner download/extraction

### GitHub Runner

- Ephemeral mode (no cleanup overhead)
- Disabled auto-update
- Minimal configuration

## Monitoring and Observability

### Metrics (CloudWatch)

**Webhook Lambda:**

- Invocations
- Duration
- Errors
- Throttles

**Runner Lambda:**

- Invocations
- Duration
- Errors
- Concurrent executions
- Throttles

### Alarms (Recommended)

1. **High Error Rate:**
   - Metric: Errors > 5 in 5 minutes
   - Action: SNS notification

2. **Throttling:**
   - Metric: Throttles > 0
   - Action: Increase concurrency

3. **Long Duration:**
   - Metric: Duration > 840 seconds
   - Action: Review job complexity

### Dashboards

Create CloudWatch Dashboard with:

- Invocation rate
- Success/error rate
- Duration percentiles (p50, p95, p99)
- Concurrent executions
- Cost tracking

## Testing Strategy

### Test Coverage

**Philosophy:** Test what matters, not everything.

- Focus on security-critical code (signature verification)
- Focus on routing logic (label matching)
- Skip orchestration code (AWS SDK calls, subprocess management)

**Current Coverage:** 26% (floor, can only increase)

**Test Suite:**

- 13 focused unit tests for critical functions
- `tests/test_webhook.py` - Webhook Lambda tests
  - 6 signature verification tests (HMAC-SHA256 security)
  - 7 label matching tests (routing logic)

**Running Tests:**

```bash
# Run tests with coverage
make test

# Run only failed tests
make test-failed

# Run all quality checks (lint + test)
make lint
```

**Pre-commit Hooks:**
All code is validated before commit:

- Black (formatting)
- isort (import sorting)
- flake8 (linting, complexity checks)
- pyupgrade (modern Python syntax)
- pytest (unit tests with coverage)

**Quality Metrics:**

- Max complexity: 8
- Max cognitive complexity: 8
- Code coverage floor: 26% (enforced)
- All lint checks must pass

### Integration Testing

**Manual Testing Checklist:**

1. Deploy to sandbox environment
2. Configure webhook in test repository
3. Trigger workflow with `self-hosted` label
4. Verify webhook receives event
5. Verify runner Lambda executes
6. Verify job completes in GitHub
7. Check CloudWatch logs for errors

**Future Improvements:**

- Automated integration tests with mocked GitHub webhooks
- End-to-end tests using GitHub API
- Performance testing for cold start times

## Disaster Recovery

### Backup Strategy

- Infrastructure as Code (AWS SAM CLI)
- Secrets backed up automatically (AWS Secrets Manager)
- Docker image stored in ECR (versioned)
- No stateful data to lose

### Recovery Procedure

1. Rebuild Docker image: `make docker-build && make docker-push`
2. Redeploy stack: `sam deploy --config-env <env>`
3. Update GitHub token secret: `make setup-token`
4. Update webhook URL in GitHub repository settings

**RTO:** ~15 minutes (includes Docker build)
**RPO:** 0 (no data loss - fully stateless)

### Multi-Environment Strategy

- Separate stacks per environment (sandbox, dev, prod)
- Independent ECR repositories per environment
- Environment-specific tagging for cost tracking
- `samconfig.toml` manages all environment configurations

## Future Enhancements

### Potential Improvements

1. **Job Queuing with SQS:**
   - Add SQS queue for job buffering
   - Handle burst traffic better
   - Priority queuing by label
   - Dead letter queue for failed jobs

2. **Runner Optimization:**
   - Layer caching for faster cold starts
   - Provisioned concurrency for critical jobs
   - Runner pool with warm instances
   - Smaller container image (alpine-based)

3. **VPC Integration:**
   - Access private RDS databases
   - Internal API access
   - Enhanced network security
   - VPC endpoints for AWS services

4. **GitHub App Authentication:**
   - Better security than PAT
   - Fine-grained permissions
   - Automatic token rotation
   - Installation-level access control

5. **Enhanced Observability:**
   - Custom CloudWatch dashboard
   - X-Ray tracing for debugging
   - Job duration/cost tracking
   - Success rate metrics
   - Slack/Teams notifications

6. **Multi-Region Deployment:**
   - Active-active setup
   - Geographic failover
   - Lower latency globally
   - Disaster recovery

7. **Advanced Features:**
   - Runner version selection per job
   - Custom Docker images per repository
   - Job artifacts stored in S3
   - Build cache in S3 or ElastiCache
   - Matrix job coordination

## Limitations

### AWS Lambda Limits

- 15-minute maximum execution
- 10 GB ephemeral storage
- 6 MB payload size (async invocation)

### GitHub Actions Limits

- Runner must stay connected
- No matrix builds spanning runners
- Limited caching options

### Cost Limits

- High-memory Lambda is expensive for long jobs
- Container image storage in ECR
- CloudWatch Logs storage

## References

### AWS Documentation

- [AWS Lambda Limits](https://docs.aws.amazon.com/lambda/latest/dg/gettingstarted-limits.html)
- [AWS SAM CLI Documentation](https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/what-is-sam.html)
- [Lambda Container Images](https://docs.aws.amazon.com/lambda/latest/dg/images-create.html)
- [AWS Secrets Manager](https://docs.aws.amazon.com/secretsmanager/latest/userguide/intro.html)

### GitHub Documentation

- [GitHub Actions Runner](https://github.com/actions/runner)
- [Self-Hosted Runners](https://docs.github.com/en/actions/hosting-your-own-runners)
- [GitHub Webhooks](https://docs.github.com/en/developers/webhooks-and-events/webhooks)
- [Webhook Events](https://docs.github.com/en/webhooks/webhook-events-and-payloads#workflow_job)

### Project Documentation

- [README.md](../README.md) - Quick start guide
- [MAKEFILE_GUIDE.md](./MAKEFILE_GUIDE.md) - Makefile commands reference
- [DEPLOYMENT.md](./DEPLOYMENT.md) - Deployment instructions
