# Secrets Management Guide

This document explains the three ways to provide your GitHub token during deployment.

## ⚠️ Security Note

The GitHub token is stored in **AWS Secrets Manager** (encrypted at rest). The methods below only affect how you provide the token **during CDK deployment** - it always ends up securely in AWS Secrets Manager.

---

## Option 1: .env File (Local Development) ✅ Recommended

**Best for:** Local development and testing

### Setup

1. Copy the example file:
   ```bash
   cp .env.example .env
   ```

2. Edit `.env` and add your GitHub token:
   ```bash
   GITHUB_TOKEN=ghp_yourActualTokenHere123456789
   ```

3. Deploy:
   ```bash
   npm run deploy
   ```

**Pros:**
- ✅ Simple and convenient for local development
- ✅ Never accidentally committed (`.env` is in `.gitignore`)
- ✅ Same token used across multiple deployments

**Cons:**
- ⚠️ Token stored on your local machine

---

## Option 2: Environment Variable (One-Time)

**Best for:** CI/CD, automated deployments, or one-off deploys

### Setup

Set the environment variable inline during deployment:

```bash
# Linux/macOS
GITHUB_TOKEN=ghp_yourToken123 npm run deploy

# Windows PowerShell
$env:GITHUB_TOKEN="ghp_yourToken123"; npm run deploy

# Windows CMD
set GITHUB_TOKEN=ghp_yourToken123 && npm run deploy
```

**Pros:**
- ✅ No files on disk
- ✅ Perfect for CI/CD pipelines
- ✅ Token only exists in that shell session

**Cons:**
- ⚠️ Need to provide on every deployment
- ⚠️ May appear in shell history

---

## Option 3: GitHub Actions Secrets (CI/CD) 🚀 Most Secure

**Best for:** Production deployments via GitHub Actions

### Setup

1. **Add secrets to your GitHub repository:**
   - Go to: `Settings` → `Secrets and variables` → `Actions`
   - Click `New repository secret`
   - Add these secrets:

   | Secret Name | Value | Description |
   |-------------|-------|-------------|
   | `GH_RUNNER_TOKEN` | `ghp_xxxxx` | GitHub PAT for runner registration |
   | `AWS_ROLE_ARN` | `arn:aws:iam::123:role/xxx` | AWS IAM role for OIDC (recommended) |
   | `AWS_REGION` | `us-east-1` | AWS region |

   **Alternative to OIDC (less secure):**
   | Secret Name | Value | Description |
   |-------------|-------|-------------|
   | `AWS_ACCESS_KEY_ID` | `AKIAXXXXX` | AWS access key |
   | `AWS_SECRET_ACCESS_KEY` | `xxxxxxx` | AWS secret key |

2. **Use the provided workflow:**

   The workflow at `.github/workflows/deploy.yml` is already configured!

   ```yaml
   - name: Deploy with CDK
     env:
       GITHUB_TOKEN: ${{ secrets.GH_RUNNER_TOKEN }}
     run: npm run deploy -- --require-approval never
   ```

3. **Trigger deployment:**
   - Push to `main` branch, or
   - Manually trigger from Actions tab

**Pros:**
- ✅ Most secure (no token on local machines)
- ✅ Centralized secret management
- ✅ Automatic deployments on push
- ✅ Audit trail in GitHub
- ✅ Can use AWS OIDC (no long-lived credentials)

**Cons:**
- ⚠️ Requires GitHub Actions setup
- ⚠️ Slightly more complex initial setup

---

## GitHub Token Requirements

Your GitHub Personal Access Token (PAT) needs these scopes:

### For Repository-Level Runners:
- ✅ `repo` (Full control of private repositories)
- ✅ `workflow` (Update GitHub Action workflows)

### For Organization-Level Runners:
- ✅ `repo` (Full control of private repositories)
- ✅ `workflow` (Update GitHub Action workflows)
- ✅ `admin:org` (Full control of orgs and teams)

### Generate a token:
1. Go to: https://github.com/settings/tokens
2. Click **Generate new token (classic)**
3. Select the required scopes above
4. Set expiration (recommend 90 days)
5. Click **Generate token**
6. Copy immediately (you won't see it again!)

---

## What Happens During Deployment?

1. CDK reads `GITHUB_TOKEN` from environment
2. Creates/updates AWS Secrets Manager secret: `github-runner/token`
3. Encrypts token using AWS KMS
4. Lambda functions access it securely at runtime

---

## Fallback Behavior

If no `GITHUB_TOKEN` environment variable is provided:
- Secret is created with placeholder value: `REPLACE_ME`
- You'll need to manually update it:
  ```bash
  aws secretsmanager put-secret-value \
    --secret-id github-runner/token \
    --secret-string "ghp_yourTokenHere"
  ```

---

## Updating the Token Later

If your token expires or needs rotation:

### Using AWS CLI:
```bash
aws secretsmanager put-secret-value \
  --secret-id github-runner/token \
  --secret-string "ghp_newTokenHere"
```

### Using AWS Console:
1. Go to AWS Secrets Manager console
2. Find secret: `github-runner/token`
3. Click **Retrieve secret value** → **Edit**
4. Update the value
5. Click **Save**

### Re-deploy with new token:
```bash
GITHUB_TOKEN=ghp_newToken npm run deploy
```

---

## Security Best Practices

1. ✅ **Use OIDC for AWS** (no long-lived credentials in GitHub)
2. ✅ **Rotate tokens regularly** (every 90 days)
3. ✅ **Use minimal scopes** (only what you need)
4. ✅ **Monitor CloudTrail** for secret access
5. ✅ **Use GitHub Apps** instead of PATs (more secure, future enhancement)
6. ❌ **Never commit tokens** to git
7. ❌ **Never print tokens** in logs or output

---

## Comparison Table

| Method | Security | Convenience | CI/CD Ready | Local Dev |
|--------|----------|-------------|-------------|-----------|
| `.env` file | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ❌ | ✅ |
| Env variable | ⭐⭐⭐⭐ | ⭐⭐⭐ | ✅ | ✅ |
| GitHub Actions | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ✅ | ❌ |

---

## Troubleshooting

### "Secret contains REPLACE_ME"
**Problem:** Token wasn't provided during deployment

**Solution:** Redeploy with `GITHUB_TOKEN` environment variable or manually update in AWS Secrets Manager

### "Invalid token" errors in Lambda logs
**Problem:** Token expired or has insufficient permissions

**Solution:** Generate new token with correct scopes and update secret

### "Error retrieving secret"
**Problem:** Lambda doesn't have permission to read secret

**Solution:** Check IAM role permissions (should be auto-configured by CDK)

---

## Questions?

See also:
- [SETUP.md](../SETUP.md) - Full setup guide
- [SECURITY.md](../SECURITY.md) - Security considerations
- [ARCHITECTURE.md](../ARCHITECTURE.md) - How it all works

