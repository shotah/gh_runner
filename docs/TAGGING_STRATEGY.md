# Resource Tagging Strategy

This document explains the tagging strategy used for cost tracking, resource organization, and operational visibility.

## 🏷️ Tags Applied to All Resources

Every resource in the GitHub Runner stack is automatically tagged with:

| Tag Key | Default Value | Source | Purpose |
|---------|---------------|--------|---------|
| `Project` | `github-runner` | Hardcoded | Identify all resources belonging to this project |
| `ManagedBy` | `CDK` | Hardcoded | Identify infrastructure-as-code tool |
| `Environment` | `dev` | `$ENVIRONMENT` | Separate dev/staging/prod costs |
| `CostCenter` | `Engineering` | `$COST_CENTER` | Allocate costs to departments |
| `Owner` | `DevOps` | `$OWNER` | Contact person/team |

---

## 📊 How to Use Tags

### 1. Set Tags During Deployment

**Using .env file:**
```bash
# .env
GITHUB_TOKEN=ghp_xxx
ENVIRONMENT=production
COST_CENTER=Platform-Team
OWNER=john.doe@company.com
```

**Using environment variables:**
```bash
ENVIRONMENT=staging \
COST_CENTER=R&D \
OWNER=alice@company.com \
npm run deploy
```

**Using GitHub Actions:**

Tags are automatically applied from GitHub secrets (see `.github/workflows/deploy.yml`):
- `ENVIRONMENT` secret → `Environment` tag
- `COST_CENTER` secret → `CostCenter` tag  
- `OWNER` secret → `Owner` tag

---

## 💰 Cost Tracking in AWS Cost Explorer

### View Costs by Project

1. Go to **AWS Cost Explorer**
2. Click **Create report**
3. Group by: **Tag → Project**
4. Filter: `Project = github-runner`

You'll see total costs for all GitHub runner resources!

### View Costs by Environment

**Useful for comparing dev vs production costs:**

1. Group by: **Tag → Environment**
2. Filter: `Project = github-runner`

Results:
```
Environment: dev         → $25/month
Environment: staging     → $50/month
Environment: production  → $150/month
```

### View Costs by Cost Center

**Useful for departmental chargebacks:**

1. Group by: **Tag → CostCenter**
2. Time range: Last month

Results:
```
CostCenter: Engineering   → $150/month
CostCenter: R&D          → $75/month
CostCenter: QA           → $25/month
```

### View Costs by Resource Type

**See what's expensive:**

1. Group by: **Service**
2. Filter: `Project = github-runner`

Results:
```
Lambda                    → $120/month (runner execution)
ECR                       → $15/month (Docker images)
API Gateway               → $5/month (webhook endpoint)
CloudWatch Logs           → $3/month (logs storage)
Secrets Manager           → $2/month (token storage)
```

---

## 🔍 Finding Resources by Tags

### AWS CLI

**Find all runner resources:**
```bash
aws resourcegroupstaggingapi get-resources \
  --tag-filters Key=Project,Values=github-runner
```

**Find production resources:**
```bash
aws resourcegroupstaggingapi get-resources \
  --tag-filters Key=Project,Values=github-runner Key=Environment,Values=production
```

### AWS Console

1. Go to **Resource Groups & Tag Editor**
2. Click **Tag Editor**
3. Select **All resource types**
4. Add tag filter: `Project = github-runner`
5. Click **Search resources**

You'll see ALL tagged resources across services!

---

## 🏢 Multi-Environment Setup

Deploy separate stacks for each environment with different tags:

### Development
```bash
# .env.dev
GITHUB_TOKEN=ghp_xxx
ENVIRONMENT=dev
COST_CENTER=Engineering
OWNER=dev-team@company.com

# Deploy
cdk deploy --context environment=dev --stack-name GithubRunnerStack-Dev
```

### Staging
```bash
# .env.staging
ENVIRONMENT=staging
COST_CENTER=QA
OWNER=qa-team@company.com

# Deploy
cdk deploy --context environment=staging --stack-name GithubRunnerStack-Staging
```

### Production
```bash
# .env.prod
ENVIRONMENT=production
COST_CENTER=Platform
OWNER=platform-team@company.com

# Deploy
cdk deploy --context environment=prod --stack-name GithubRunnerStack-Prod
```

---

## 📈 Cost Allocation Reports

### Enable Cost Allocation Tags

**One-time setup in AWS Billing:**

1. Go to **AWS Billing Console**
2. Click **Cost allocation tags**
3. Activate these user-defined tags:
   - `Project`
   - `Environment`
   - `CostCenter`
   - `Owner`
4. Wait 24 hours for activation

After activation, these tags will appear in Cost Explorer and billing reports!

### Monthly Cost Report

**Create a saved report:**

1. AWS Cost Explorer → **Saved reports**
2. **Create new report**
3. Name: `GitHub Runner Monthly Costs`
4. Group by: `Tag: Project`
5. Filter: `Project = github-runner`
6. Time range: Month-to-date
7. **Save report**

Now you have a one-click cost report! 📊

---

## 🎯 Tagging Best Practices

### ✅ Do's

- ✅ **Always tag resources** - Use environment variables if defaults don't fit
- ✅ **Be consistent** - Use same tag values across teams
- ✅ **Tag early** - Tags from day 1 = better cost history
- ✅ **Use lowercase** - Easier to filter/search
- ✅ **Update tags** - When projects change ownership/cost centers

### ❌ Don'ts

- ❌ **Don't use sensitive data** - Tags are visible to anyone with read access
- ❌ **Don't use PII** - No emails/names in tags (use team names instead)
- ❌ **Don't over-tag** - 5-10 tags is plenty
- ❌ **Don't use spaces** - Use hyphens: `Platform-Team` not `Platform Team`

---

## 🔧 Troubleshooting

### Tags not showing in Cost Explorer

**Problem:** Tags don't appear in cost reports

**Solutions:**
1. **Activate tags** in AWS Billing → Cost allocation tags
2. **Wait 24 hours** after activation
3. **Deploy again** to apply tags to new resources
4. **Check tag spelling** - Must match exactly

### Tags not applied to some resources

**Problem:** Some resources are missing tags

**Solutions:**
1. **Check CDK version** - Update to latest: `npm update aws-cdk-lib`
2. **Redeploy** - CDK might have skipped unchanged resources
3. **Manual tagging** - Some resources need explicit tagging (rare)

### Different environments showing same tags

**Problem:** All environments tagged as `dev`

**Solution:**
Set `ENVIRONMENT` variable before each deployment:
```bash
ENVIRONMENT=production npm run deploy
```

---

## 📚 Additional Resources

- [AWS Tagging Best Practices](https://docs.aws.amazon.com/whitepapers/latest/tagging-best-practices/tagging-best-practices.html)
- [AWS Cost Explorer Documentation](https://docs.aws.amazon.com/cost-management/latest/userguide/ce-what-is.html)
- [CDK Tagging Documentation](https://docs.aws.amazon.com/cdk/v2/guide/tagging.html)

---

## 🎉 Quick Start

**Local deployment with tags:**
```bash
# .env
GITHUB_TOKEN=ghp_xxx
ENVIRONMENT=dev
COST_CENTER=Engineering
OWNER=DevOps

npm run deploy
```

**Check your tags in AWS:**
```bash
aws resourcegroupstaggingapi get-resources \
  --tag-filters Key=Project,Values=github-runner \
  --query 'ResourceTagMappingList[*].[ResourceARN,Tags]' \
  --output table
```

Done! 🏷️ All your resources are now tagged for cost tracking!

