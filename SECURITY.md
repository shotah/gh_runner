# Security Considerations

## Overview

This document outlines the security measures implemented and additional recommendations for securing your Lambda-based GitHub Actions runner.

## Current Security Measures

### ✅ 1. Webhook Authentication

**Protection:** HMAC-SHA256 signature verification

The webhook endpoint verifies every incoming request using GitHub's webhook secret:
- GitHub signs each webhook with a shared secret
- Lambda verifies the signature before processing
- Invalid signatures are rejected with 401 Unauthorized
- Uses constant-time comparison to prevent timing attacks

**Configuration:**
```bash
# Secret is auto-generated during deployment
aws secretsmanager get-secret-value --secret-id github-runner/webhook-secret
```

### ✅ 2. Secrets Management

**Protection:** AWS Secrets Manager with encryption

- GitHub tokens stored encrypted at rest (AWS KMS)
- Webhook secret auto-generated and encrypted
- No secrets in code or environment variables (only ARNs)
- Access controlled via IAM policies
- Secrets cached in Lambda memory to reduce API calls

### ✅ 3. Least Privilege (Partial)

**Current State:**
- Webhook Lambda: Minimal permissions (read secrets, invoke runner)
- Runner Lambda: **BROAD PERMISSIONS** ⚠️ (see concerns below)

### ✅ 4. Ephemeral Runners

**Protection:** Single-use runners that auto-cleanup

- Each runner is ephemeral (--ephemeral flag)
- Automatically deleted after one job
- No persistent state between jobs
- Fresh environment for each execution

### ✅ 5. Audit Logging

**Protection:** CloudWatch Logs + CloudTrail

- All webhook events logged
- Runner execution logged
- API calls logged via CloudTrail
- 7-day retention (configurable)

## Security Concerns & Mitigations

### ⚠️ 1. CRITICAL: Overly Broad IAM Permissions

**Risk:** The runner Lambda has near-admin permissions for many AWS services.

**Current Permissions Include:**
- CloudFormation (full)
- Lambda (full)
- S3 (full)
- IAM (create/manage roles)
- DynamoDB, SQS, SNS, EventBridge (full)
- And more...

**Why This Matters:**
Any code in your GitHub workflows runs with these permissions. A compromised workflow or malicious commit could:
- Delete production resources
- Exfiltrate data
- Create backdoors
- Rack up AWS bills

**Mitigations:**

1. **Scope Down Permissions** (RECOMMENDED):
```typescript
// Edit lib/github-runner-stack.ts
runnerFunction.addToRolePolicy(new iam.PolicyStatement({
  effect: iam.Effect.ALLOW,
  actions: [
    // Only include what you actually need
    'cloudformation:CreateStack',
    'cloudformation:UpdateStack',
    'cloudformation:DescribeStacks',
    's3:PutObject',
    's3:GetObject',
    // etc.
  ],
  resources: [
    // Lock down to specific resources
    'arn:aws:cloudformation:*:*:stack/my-app-*/*',
    'arn:aws:s3:::my-deployment-bucket/*',
  ],
}));
```

2. **Use Resource Tags and Conditions**:
```typescript
runnerFunction.addToRolePolicy(new iam.PolicyStatement({
  effect: iam.Effect.ALLOW,
  actions: ['cloudformation:*'],
  resources: ['*'],
  conditions: {
    'StringEquals': {
      'aws:ResourceTag/ManagedBy': 'github-runner'
    }
  }
}));
```

3. **Separate Runners by Environment**:
- Different runners for dev/staging/prod
- Each with environment-specific permissions

### ⚠️ 2. Code Execution Risk

**Risk:** Anyone who can push to your repository can execute arbitrary code with your AWS permissions.

**Attack Scenarios:**
- Compromised developer account
- Malicious pull request (if you allow PR workflows)
- Supply chain attacks via dependencies

**Mitigations:**

1. **Branch Protection Rules**:
   - Require pull request reviews
   - Require status checks
   - Restrict who can push to main

2. **Repository Settings**:
   ```
   Settings → Actions → General
   ✅ Disable "Fork pull request workflows"
   ✅ Require approval for first-time contributors
   ```

3. **Workflow Restrictions**:
   ```yaml
   # Only run on specific branches
   on:
     push:
       branches: [main]
   
   # Require manual approval for deployments
   jobs:
     deploy:
       environment: production  # Requires approval in GitHub
   ```

4. **Code Review Workflows**:
   - Review all workflow changes carefully
   - Monitor for unexpected AWS API calls
   - Use CODEOWNERS for workflow files

### ⚠️ 3. No Network Isolation

**Risk:** Runner has full internet access and can reach AWS services.

**Current State:**
- Runner Lambda runs in AWS-managed network
- Can access any public endpoint
- Can access AWS APIs

**Mitigations:**

1. **VPC Deployment** (Advanced):
```typescript
// Add to lib/github-runner-stack.ts
const vpc = new ec2.Vpc(this, 'RunnerVpc', {
  maxAzs: 2,
  natGateways: 1,
});

const runnerFunction = new lambda.DockerImageFunction(this, 'RunnerFunction', {
  // ... existing config ...
  vpc: vpc,
  vpcSubnets: { subnetType: ec2.SubnetType.PRIVATE_WITH_EGRESS },
  securityGroups: [securityGroup],
});
```

2. **VPC Endpoints** (reduce internet exposure):
   - S3 VPC endpoint
   - Secrets Manager VPC endpoint
   - CloudFormation VPC endpoint

### ⚠️ 4. Public Webhook Endpoint

**Risk:** The API Gateway endpoint is publicly accessible.

**Current Protections:**
- ✅ HMAC signature verification
- ✅ Only processes valid GitHub events

**Additional Mitigations:**

1. **Rate Limiting**:
```typescript
const api = new apigateway.RestApi(this, 'WebhookApi', {
  // ... existing config ...
  deployOptions: {
    throttle: {
      rateLimit: 10,
      burstLimit: 20,
    }
  }
});
```

2. **AWS WAF** (Advanced):
```typescript
const webAcl = new wafv2.CfnWebACL(this, 'WebhookWAF', {
  scope: 'REGIONAL',
  defaultAction: { allow: {} },
  rules: [
    {
      name: 'RateLimitRule',
      priority: 1,
      action: { block: {} },
      statement: {
        rateBasedStatement: {
          limit: 100,
          aggregateKeyType: 'IP',
        },
      },
      visibilityConfig: { /* ... */ },
    },
  ],
});
```

3. **IP Allowlist** (if using GitHub Enterprise):
```typescript
// Restrict to GitHub's webhook IPs
// https://api.github.com/meta
```

### ⚠️ 5. Secrets Rotation

**Risk:** GitHub tokens don't automatically rotate.

**Current State:**
- Manual rotation required
- PATs can be long-lived

**Mitigations:**

1. **Use GitHub Apps** (RECOMMENDED):
   - Short-lived tokens (1 hour)
   - Automatic refresh
   - Fine-grained permissions
   - See SETUP.md for GitHub App configuration

2. **Set Rotation Reminders**:
```bash
# Rotate every 90 days
aws secretsmanager rotate-secret \
  --secret-id github-runner/token \
  --rotation-lambda-arn <rotation-function-arn>
```

3. **Monitor Secret Age**:
   - CloudWatch alarm for secrets > 90 days old
   - Calendar reminder to rotate manually

### ⚠️ 6. Cost Controls

**Risk:** Malicious or buggy workflows could trigger excessive Lambda invocations.

**Current Protection:**
- ✅ Concurrency limit (10)

**Additional Mitigations:**

1. **AWS Budgets**:
```bash
aws budgets create-budget \
  --account-id 123456789012 \
  --budget file://budget.json
```

2. **CloudWatch Alarms**:
```typescript
new cloudwatch.Alarm(this, 'HighConcurrency', {
  metric: runnerFunction.metricConcurrentExecutions(),
  threshold: 8,
  evaluationPeriods: 2,
});
```

3. **Service Control Policies** (for Organizations):
   - Limit Lambda invocations per day
   - Restrict resource creation in sensitive regions

## Security Checklist

Before deploying to production:

### Must Do
- [ ] Scope down IAM permissions to minimum required
- [ ] Enable branch protection rules
- [ ] Disable fork pull request workflows
- [ ] Set up secret rotation schedule
- [ ] Review all workflows for suspicious activity
- [ ] Configure AWS Budgets and billing alarms

### Should Do
- [ ] Enable API Gateway rate limiting
- [ ] Set up CloudWatch alarms for errors/high usage
- [ ] Use GitHub Apps instead of PATs
- [ ] Enable AWS CloudTrail in all regions
- [ ] Document approved AWS services/actions
- [ ] Regular security audits of workflows

### Consider
- [ ] Deploy runner in VPC with private subnets
- [ ] Add AWS WAF to API Gateway
- [ ] Implement approval gates for production deployments
- [ ] Use separate runners for different environments
- [ ] Enable VPC Flow Logs
- [ ] Implement automated compliance scanning

## Monitoring & Incident Response

### Detection

**Monitor for:**
- Unusual AWS API calls (CloudTrail)
- Failed webhook authentication attempts
- Spike in Lambda invocations
- Unexpected resource creation
- High AWS costs

**CloudWatch Insights Query** (suspicious activity):
```sql
fields @timestamp, @message
| filter @message like /ERROR/ 
    or @message like /unauthorized/ 
    or @message like /Invalid signature/
| sort @timestamp desc
```

### Response

**If you suspect compromise:**

1. **Immediately:**
   ```bash
   # Disable the runner
   aws lambda put-function-concurrency \
     --function-name github-runner-executor \
     --reserved-concurrent-executions 0
   
   # Rotate GitHub token
   aws secretsmanager put-secret-value \
     --secret-id github-runner/token \
     --secret-string '{"token":"NEW_TOKEN"}'
   ```

2. **Investigate:**
   - Review CloudWatch Logs
   - Check CloudTrail for unusual API calls
   - Review recent workflow runs
   - Check for unexpected AWS resources

3. **Remediate:**
   - Remove malicious code from repository
   - Delete unauthorized resources
   - Update IAM policies
   - Re-enable runner with tighter controls

## Compliance Considerations

### Data Protection
- Secrets encrypted at rest (AWS KMS)
- Logs encrypted (CloudWatch)
- No sensitive data in workflow logs

### Audit Requirements
- All API calls logged (CloudTrail)
- Execution logs retained (CloudWatch)
- Secret access logged

### Access Control
- IAM role-based access
- No long-term credentials in Lambda
- Webhook authentication required

## Best Practices

1. **Principle of Least Privilege**: Only grant permissions actually needed
2. **Defense in Depth**: Multiple layers of security
3. **Monitoring**: Active monitoring and alerting
4. **Rapid Response**: Plan for incident response
5. **Regular Reviews**: Audit permissions and workflows regularly
6. **Secure Development**: Treat infrastructure as code with same rigor as application code

## Resources

- [GitHub Actions Security Best Practices](https://docs.github.com/en/actions/security-guides/security-hardening-for-github-actions)
- [AWS IAM Best Practices](https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html)
- [AWS Lambda Security Best Practices](https://docs.aws.amazon.com/lambda/latest/dg/lambda-security.html)
- [OWASP Top 10 CI/CD Security Risks](https://owasp.org/www-project-top-10-ci-cd-security-risks/)

## Reporting Security Issues

If you discover a security vulnerability in this project, please report it responsibly:

1. **Do not** open a public GitHub issue
2. Email details to [your-security-email]
3. Include reproduction steps if possible
4. Allow time for a fix before public disclosure

---

**Remember:** Security is a continuous process, not a one-time setup. Regularly review and update your security posture as your usage evolves.

