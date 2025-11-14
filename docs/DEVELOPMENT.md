# Development Guide

## Overview

This guide covers local development, testing, code quality, and contribution workflows for the GitHub Actions Lambda Runner project.

## Prerequisites

### Required Tools

- **Python 3.13+** - Lambda runtime version
- **Pipenv** - Dependency management
- **AWS CLI** - AWS operations
- **AWS SAM CLI** - Local testing and deployment
- **Docker** - Container builds and local Lambda testing
- **Git** - Version control
- **Make** - Task automation

### Installation

```bash
# Python dependencies
pip install pipenv

# AWS SAM CLI
pip install aws-sam-cli

# Verify installations
python --version   # Should be 3.13+
pipenv --version
sam --version
docker --version
```

## Project Setup

### 1. Clone and Install Dependencies

```bash
# Clone repository
git clone <repo-url>
cd gh_runner

# Install all dependencies (including dev tools)
make install-dev

# Install pre-commit hooks
make hooks
```

### 2. Environment Configuration

```bash
# Create local environment file (optional)
make env

# Edit .env with your values
# GITHUB_TOKEN=ghp_...
# AWS_PROFILE=your-profile
# etc.
```

The Makefile automatically loads `.env` if it exists.

## Development Workflow

### Quick Start

```bash
# Full setup: hooks, install, lint, and test
make all

# Daily development workflow
make lint          # Check code quality
make test          # Run tests with coverage
make build         # Build SAM application
```

### Code Quality Standards

This project enforces strict code quality standards:

#### Linting Tools

- **Black** - Code formatting (line length: 99)
- **isort** - Import sorting
- **flake8** - Style guide enforcement
  - Max complexity: 8
  - Max cognitive complexity: 8
- **pyupgrade** - Modern Python syntax (Python 3.13+)
- **pytest** - Unit tests with coverage (floor: 26%)

#### Running Quality Checks

```bash
# Run all linters and tests (recommended)
make lint

# Run tests only
make test

# Re-run failed tests
make test-failed
```

#### Pre-commit Hooks

All code is automatically validated before commits:

```bash
# Install hooks (one-time setup)
make hooks

# Hooks run automatically on git commit
git commit -m "Your message"

# Skip hooks (not recommended)
git commit --no-verify
```

**What gets checked:**

- ✅ Valid TOML/JSON/YAML syntax
- ✅ No debug statements
- ✅ Consistent line endings
- ✅ End-of-file newlines
- ✅ Trailing whitespace removed
- ✅ Imports sorted (isort)
- ✅ Code formatted (black)
- ✅ Linting passed (flake8)
- ✅ Tests passed (pytest)

### Testing

#### Test Philosophy

**Test what matters, not everything.**

This project focuses on:

- Security-critical code (signature verification)
- Routing logic (label matching)
- Skip orchestration code (AWS SDK calls, subprocess management)

#### Running Tests

```bash
# Run all tests with coverage
make test

# Run only failed tests (fast iteration)
make test-failed

# Generate requirements-dev.txt
make requirements-dev
```

#### Test Coverage

- **Current coverage:** 26% (floor, can only increase)
- **13 unit tests** covering critical functions
- Coverage enforced in CI/CD

**Coverage by file:**

- `lambda/webhook/index.py` - 27% (focused on critical functions)
- Tests located in `tests/test_webhook.py`

#### Writing Tests

Tests use pytest with fixtures and parametrization:

```python
# tests/test_webhook.py
def test_verify_signature_valid():
    """Test that valid signatures are accepted"""
    secret = "my-webhook-secret"
    payload = '{"action":"queued","workflow_job":{}}'
    
    signature = "sha256=" + hmac.new(
        secret.encode("utf-8"),
        payload.encode("utf-8"),
        hashlib.sha256
    ).hexdigest()
    
    assert verify_signature(payload, signature, secret) is True
```

## Local Testing

### SAM Local Testing

```bash
# Build application
make build

# Start local API Gateway (requires Docker)
make start

# In another terminal, test webhook endpoint
curl -X POST http://localhost:3000/ \
  -H "Content-Type: application/json" \
  -d '{"action":"ping"}'
```

### Invoke Lambda Locally

```bash
# Invoke with test event
make invoke

# Or use SAM directly
sam local invoke HelloWorldFunction --event events/hello.json
```

### Docker Image Testing

```bash
# Build runner Docker image
make docker-build

# Run container locally (for debugging)
docker run -it --entrypoint /bin/bash github-runner-lambda:latest
```

## Project Structure

```
gh_runner/
├── lambda/
│   ├── webhook/               # Webhook receiver Lambda
│   │   ├── index.py          # Main handler
│   │   └── requirements.txt  # Dependencies
│   └── runner/               # Runner executor Lambda
│       ├── index.py          # Main handler
│       ├── Dockerfile        # Container definition
│       └── requirements.txt  # Dependencies
├── tests/
│   ├── __init__.py
│   └── test_webhook.py       # Webhook tests
├── docs/
│   ├── ARCHITECTURE.md       # System architecture
│   ├── SECURITY.md           # Security considerations
│   └── DEVELOPMENT.md        # This file
├── template.yaml             # SAM template
├── samconfig.toml            # SAM deployment configs
├── Makefile                  # Task automation
├── Pipfile                   # Python dependencies
├── pyproject.toml            # Tool configuration
├── .pre-commit-config.yaml   # Pre-commit hooks
└── README.md                 # Quick start guide
```

## Common Tasks

### Dependency Management

```bash
# Add a package
pipenv install requests

# Add a dev package
pipenv install --dev pytest

# Update Pipfile.lock
pipenv lock

# Sync dependencies from lock file
make sync-dev

# Generate requirements.txt for Lambda
pipenv requirements --from-pipfile > lambda/webhook/requirements.txt
```

### Docker Operations

```bash
# Build Docker image
make docker-build

# Push to ECR (requires REPO_URI env var)
export REPO_URI=123456789012.dkr.ecr.us-east-1.amazonaws.com/github-runner
make docker-push

# Login to ECR manually
make docker-login

# Clean Docker resources
make docker-clean
```

### Deployment

```bash
# Deploy to environments
make deploy-sandbox    # Auto-confirm
make deploy-dev        # Auto-confirm
make deploy-prod       # Requires confirmation

# Or use SAM directly
sam deploy --config-env dev
```

### Cleanup

```bash
# Clean build artifacts and virtual env
make clean

# Clean SAM cache and Docker
make clean-cache

# Destroy environment stacks
make destroy-sandbox
make destroy-dev
make destroy-prod      # DANGEROUS - requires confirmation
```

## Code Style Guide

### Python Style

Follow PEP 8 with these specific rules:

```python
# Line length: 99 characters (configured in pyproject.toml)
# Target: Python 3.13

# Use type hints
def handler(event: dict[str, Any], context: Any) -> dict[str, Any]:
    pass

# Use f-strings
print(f"Processing job {job_id}")

# Use pathlib for paths
from pathlib import Path
runner_dir = Path("/opt/actions-runner")

# Explicit error messages
raise ValueError("GITHUB_TOKEN_SECRET_NAME environment variable not set")
```

### Import Ordering (isort)

```python
# Standard library
import hashlib
import json
import os
from pathlib import Path
from typing import Any

# Third-party packages
import boto3
import requests

# Local imports
from utils import helper_function
```

### Complexity Limits

- **Max cyclomatic complexity:** 8
- **Max cognitive complexity:** 8

If a function exceeds these, refactor into smaller helper functions:

```python
# Bad: Too complex
def handler(event, context):
    # 50 lines of nested logic
    pass

# Good: Broken down
def handler(event, context):
    validate_event(event)
    result = process_event(event)
    return format_response(result)
```

## Debugging

### Local Debugging

```python
# Add to Lambda function for debugging
import traceback
try:
    # your code
except Exception as e:
    traceback.print_exc()
    raise
```

### CloudWatch Logs

```bash
# View Lambda logs
make logs

# View webhook logs specifically
make logs-webhook

# View runner logs specifically
make logs-runner
```

### Common Issues

#### Issue: Pre-commit hooks fail

```bash
# Run hooks manually to see details
pipenv run pre-commit run --all-files

# Skip hooks temporarily (not recommended)
git commit --no-verify
```

#### Issue: Tests fail locally but pass in CI

```bash
# Ensure Python version matches (3.13)
python --version

# Reinstall dependencies
make clean
make install-dev
```

#### Issue: Docker build fails

```bash
# Check Docker is running
docker ps

# Clean Docker cache
make clean-cache

# Try building without cache
docker build --no-cache -t github-runner-lambda:latest ./lambda/runner
```

## Contributing

### Workflow

1. **Create a branch**

   ```bash
   git checkout -b feature/your-feature
   ```

2. **Make changes**
   - Follow code style guide
   - Add tests for new functionality
   - Update documentation

3. **Test locally**

   ```bash
   make lint      # Must pass
   make test      # Must pass
   make build     # Must succeed
   ```

4. **Commit**

   ```bash
   git add .
   git commit -m "feat: add new feature"
   # Pre-commit hooks run automatically
   ```

5. **Push and create PR**

   ```bash
   git push origin feature/your-feature
   ```

### Commit Message Format

Use conventional commits:

```
feat: add new feature
fix: resolve bug in webhook handler
docs: update architecture diagram
refactor: simplify runner logic
test: add signature verification tests
chore: update dependencies
```

### Pull Request Checklist

Before submitting a PR:

- [ ] All tests pass (`make test`)
- [ ] All linters pass (`make lint`)
- [ ] Code coverage hasn't decreased
- [ ] Documentation updated (if needed)
- [ ] CHANGELOG updated (if user-facing change)
- [ ] Tested locally with `make start`

## Troubleshooting

### Environment Issues

```bash
# Check Python version (must be 3.13+)
python --version

# Check virtual environment
pipenv --venv

# Rebuild virtual environment
pipenv --rm
pipenv install --dev
```

### AWS Issues

```bash
# Check AWS credentials
aws sts get-caller-identity

# Check SAM CLI version
sam --version

# Validate SAM template
sam validate
```

### Build Issues

```bash
# Clean everything and rebuild
make clean
make clean-cache
make install-dev
make build
```

## Resources

### Documentation

- [README.md](../README.md) - Quick start guide
- [ARCHITECTURE.md](./ARCHITECTURE.md) - System design
- [SECURITY.md](./SECURITY.md) - Security best practices

### External Resources

- [AWS SAM Documentation](https://docs.aws.amazon.com/serverless-application-model/)
- [GitHub Actions Runner](https://github.com/actions/runner)
- [Python Type Hints](https://docs.python.org/3/library/typing.html)
- [Pytest Documentation](https://docs.pytest.org/)

## Getting Help

### Common Commands Reference

```bash
make help          # Show all available commands
make all           # Full setup and validation
make lint          # Run all quality checks
make test          # Run tests
make build         # Build application
make deploy-dev    # Deploy to dev
```

### Debug Mode

```bash
# Enable SAM debug logging
sam build --debug
sam deploy --debug

# Enable verbose output
pipenv run pytest -v
```

---

**Remember:** Quality over speed. Take time to write tests, document your code, and ensure everything passes linting before pushing.
