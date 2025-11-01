# Makefile Guide

Complete reference for all `make` commands available in this project.

## 🔧 Setup

The Makefile automatically:
- ✅ **Loads `.env` file** - All environment variables are available to make commands
- ✅ **Exports variables** - Variables are passed to all subcommands
- ✅ **Silent mode** - Clean output without echoing commands

### Environment Variables

Create a `.env` file and the Makefile will automatically load it:

```bash
# .env
GITHUB_TOKEN=ghp_xxx
ENVIRONMENT=dev
COST_CENTER=Engineering
OWNER=DevOps
AWS_REGION=us-east-1
```

These variables will be available to all CDK and deployment commands!

---

## 📋 Command Reference

### Setup & Deployment

#### `make install`
Install Node.js dependencies.

```bash
make install
```

#### `make build`
Build TypeScript code.

```bash
make build
```

#### `make bootstrap`
Bootstrap CDK in your AWS account (first time only).

```bash
make bootstrap
```

#### `make deploy`
Deploy the stack to AWS (auto-approval).

```bash
# Uses environment variables from .env
make deploy

# Or inline
ENVIRONMENT=production make deploy
```

#### `make deploy-confirm`
Deploy with manual approval prompt.

```bash
make deploy-confirm
```

#### `make destroy`
Remove all AWS resources (with confirmation).

```bash
make destroy
```

---

### Configuration

#### `make setup-token`
Interactive setup for GitHub Personal Access Token.

```bash
make setup-token
```

#### `make get-secret`
Display webhook secret for GitHub configuration.

```bash
make get-secret
```

#### `make get-webhook-url`
Get the webhook URL for GitHub.

```bash
make get-webhook-url
```

#### `make setup-info`
Display all setup information at once.

```bash
make setup-info
```

---

### Development

#### `make diff`
Show changes that will be deployed.

```bash
make diff
```

#### `make synth`
Synthesize CloudFormation template.

```bash
make synth
```

#### `make validate`
Validate CDK templates.

```bash
make validate
```

#### `make watch`
Watch for TypeScript changes and rebuild automatically.

```bash
make watch
```

#### `make clean`
Remove build artifacts.

```bash
make clean
```

#### `make npm-upgrade` 🆕
Upgrade all npm packages to latest versions (with confirmation).

```bash
make npm-upgrade
```

**What it does:**
1. Prunes unused packages
2. Installs `npm-check-updates` globally if needed
3. Updates `package.json` with latest versions
4. Runs `npm update` to install

**Warning:** Review changes before deploying!

---

### Monitoring

#### `make logs`
View Lambda function logs interactively.

```bash
make logs
```

#### `make logs-webhook`
Tail webhook Lambda logs only.

```bash
make logs-webhook
```

#### `make logs-runner`
Tail runner Lambda logs only.

```bash
make logs-runner
```

#### `make security-check`
Run security audit on dependencies.

```bash
make security-check
```

#### `make status`
Check CloudFormation stack status.

```bash
make status
```

#### `make list-functions`
List all GitHub runner Lambda functions.

```bash
make list-functions
```

---

## 🚀 Common Workflows

### First-Time Setup

```bash
# 1. Create .env file
cp .env.example .env
# Edit .env with your GITHUB_TOKEN

# 2. Install and deploy
make install
make build
make bootstrap  # First time only
make deploy

# 3. Get setup info
make setup-info

# 4. Configure GitHub webhook with URL and secret
```

### Daily Development

```bash
# Make changes to code...

# Preview changes
make diff

# Deploy
make deploy

# Watch logs
make logs
```

### Update Dependencies

```bash
# Upgrade all packages
make npm-upgrade

# Build and test
make build
make validate

# Deploy if tests pass
make deploy
```

### Troubleshooting

```bash
# Check stack status
make status

# View webhook logs
make logs-webhook

# View runner logs
make logs-runner

# Get current setup
make setup-info
```

### Cleanup

```bash
# Remove all AWS resources
make destroy

# Clean local build artifacts
make clean
```

---

## 🎯 Quick Reference Table

| Category | Command | Description |
|----------|---------|-------------|
| **Setup** | `make install` | Install dependencies |
| | `make build` | Build TypeScript |
| | `make bootstrap` | Bootstrap CDK |
| | `make deploy` | Deploy to AWS |
| **Config** | `make setup-token` | Configure GitHub token |
| | `make get-secret` | Get webhook secret |
| | `make setup-info` | All setup info |
| **Dev** | `make diff` | Preview changes |
| | `make synth` | Generate CloudFormation |
| | `make watch` | Auto-rebuild |
| | `make npm-upgrade` | Update packages |
| **Monitor** | `make logs` | View all logs |
| | `make logs-webhook` | Webhook logs |
| | `make logs-runner` | Runner logs |
| | `make status` | Stack status |
| **Cleanup** | `make clean` | Remove build files |
| | `make destroy` | Delete stack |

---

## 💡 Pro Tips

### 1. Environment-Specific Deployments

```bash
# Development
ENVIRONMENT=dev make deploy

# Staging
ENVIRONMENT=staging make deploy

# Production
ENVIRONMENT=production make deploy
```

### 2. Chain Commands

```bash
# Build, validate, and deploy in one go
make build && make validate && make deploy

# Or use quick-deploy
make quick-deploy
```

### 3. Background Log Watching

```bash
# In one terminal
make logs-webhook

# In another terminal
make logs-runner
```

### 4. Quick Status Check

```bash
# One-liner to check everything
make status && make list-functions && make setup-info
```

### 5. Safe Updates

```bash
# Before upgrading
make diff > before.txt

# Upgrade
make npm-upgrade
make build

# Check changes
make diff > after.txt
diff before.txt after.txt

# Deploy if safe
make deploy
```

---

## 🔍 Environment Variable Precedence

Variables are loaded in this order (later overrides earlier):

1. `.env` file (loaded by Makefile)
2. Shell environment variables
3. Inline variables

**Example:**

```bash
# .env file
ENVIRONMENT=dev

# Overridden by inline
ENVIRONMENT=production make deploy  # Uses "production"
```

---

## 🐛 Troubleshooting

### "make: command not found"

**Solution:** Install make:
- **macOS:** `xcode-select --install`
- **Linux:** `apt-get install build-essential` or `yum install make`
- **Windows:** Use WSL or Git Bash

### ".env not loaded"

**Verify:**
```bash
# Check if .env exists
ls -la .env

# Test variable loading
echo "GITHUB_TOKEN is: $GITHUB_TOKEN"
make deploy  # Should use .env variables
```

### "Permission denied" on scripts

**Fix:**
```bash
chmod +x scripts/*.sh
```

---

## 📚 See Also

- [Setup Guide](SETUP.md) - Complete setup instructions
- [Secrets Management](SECRETS_MANAGEMENT.md) - Managing tokens and secrets
- [Contributing](CONTRIBUTING.md) - Development guidelines

