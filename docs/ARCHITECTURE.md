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
│   • Downloads GitHub Actions runner     │
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

**Language:** Python 3.12
**Memory:** 256 MB
**Timeout:** 30 seconds

**Responsibilities:**
1. Receive webhook events from API Gateway
2. Verify HMAC signature using shared secret
3. Filter for `workflow_job` events with action `queued`
4. Check job labels (self-hosted, lambda-runner)
5. Invoke Runner Lambda asynchronously

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

**Language:** Python 3.12
**Container:** Docker (for AWS CLI/SAM)
**Memory:** 3008 MB (high for performance)
**Timeout:** 900 seconds (15 minutes)
**Ephemeral Storage:** 10 GB

**Responsibilities:**
1. Retrieve GitHub token from Secrets Manager
2. Get registration token from GitHub API
3. Download GitHub Actions runner binary
4. Configure runner as ephemeral
5. Execute workflow job
6. Auto-cleanup after completion

**Pre-installed Tools:**
- AWS CLI v2 (latest)
- AWS SAM CLI
- Git
- Common Linux utilities

**Environment Variables:**
- `GITHUB_TOKEN_SECRET_NAME`: Secret containing GitHub PAT
- `RUNNER_VERSION`: GitHub runner version

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
Get GitHub Token
    ↓
Get Registration Token
    ↓
Download Runner
    ↓
Extract to /tmp
    ↓
Configure (ephemeral)
    ↓
Start Runner
    ↓
Execute Job Steps
    ↓
Cleanup
```

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

1. **Runner Lambda** starts
2. Retrieves GitHub token
3. Calls GitHub API for registration token
4. Downloads runner binary (~80 MB)
5. Configures runner:
   ```bash
   ./config.sh --ephemeral --token XXX --url github.com/owner/repo
   ```
6. Starts runner:
   ```bash
   ./run.sh
   ```
7. Runner picks up queued job
8. Executes workflow steps
9. Reports results to GitHub
10. Auto-cleanup and exit

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

## Disaster Recovery

### Backup Strategy
- Infrastructure as Code (CDK)
- Secrets backed up automatically
- No stateful data

### Recovery Procedure
1. Redeploy stack: `cdk deploy`
2. Update GitHub token secret
3. Update webhook URL in GitHub

**RTO:** ~10 minutes
**RPO:** 0 (no data loss)

## Future Enhancements

### Potential Improvements

1. **Job Queuing:**
   - Add SQS queue for job buffering
   - Handle burst traffic better
   - Priority queuing

2. **Multiple Runners:**
   - Pool of warm runners
   - Faster job pickup
   - Better concurrency

3. **VPC Integration:**
   - Access private resources
   - Enhanced security
   - Database access

4. **GitHub App:**
   - Better security than PAT
   - Fine-grained permissions
   - Automatic token rotation

5. **Metrics Dashboard:**
   - Custom CloudWatch dashboard
   - Job statistics
   - Cost tracking

6. **Multi-Region:**
   - High availability
   - Disaster recovery
   - Geographic distribution

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

- [AWS Lambda Limits](https://docs.aws.amazon.com/lambda/latest/dg/gettingstarted-limits.html)
- [GitHub Actions Runner](https://github.com/actions/runner)
- [GitHub Webhooks](https://docs.github.com/en/developers/webhooks-and-events/webhooks)
- [AWS CDK Best Practices](https://docs.aws.amazon.com/cdk/latest/guide/best-practices.html)
