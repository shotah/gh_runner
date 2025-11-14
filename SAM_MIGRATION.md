# CDK to SAM CLI Migration Guide

## 🎯 Why We Switched

**Date:** November 2024  
**Decision:** Convert from AWS CDK (TypeScript) to SAM CLI (YAML)

### Reasons:
1. ✅ **Team Buy-in** - Team already uses SAM CLI (aws_fastapi_template pattern)
2. ✅ **Platform Team Approval** - Matches approved patterns
3. ✅ **Consistency** - Same deployment tools across all projects
4. ✅ **Supportability** - Other team members can support SAM templates

### CDK Work Preserved:
The complete CDK implementation is preserved in the `cdk-exploration` branch for reference:
```bash
git checkout cdk-exploration  # View CDK version
```

---

## 📊 What Changed

| Aspect | CDK (Before) | SAM (After) |
|--------|--------------|-------------|
| **Config Language** | TypeScript | YAML |
| **Main File** | `lib/github-runner-stack.ts` | `template.yaml` |
| **Build Tool** | `npm run build` + `cdk synth` | `sam build` |
| **Deploy Tool** | `cdk deploy` | `sam deploy` |
| **Local Testing** | Not supported | `sam local invoke` ✅ |
| **Config File** | `cdk.json` | `samconfig.toml` |
| **Dependencies** | Node.js packages | None (just SAM CLI) |

---

## 📁 New Project Structure

```
gh_runner/
├── template.yaml           # SAM template (replaces lib/*.ts)
├── samconfig.toml          # Environment configs
├── Makefile                # Updated for SAM commands
├── lambda/                 # ✅ Lambda code unchanged!
│   ├── runner/             # Runner executor
│   │   ├── Dockerfile      # ✅ Keeps pre-baked runner
│   │   ├── index.py        # ✅ Same Python code
│   │   └── requirements.txt
│   └── webhook/            # Webhook receiver
│       ├── index.py        # ✅ Same Python code
│       └── requirements.txt
├── docs/                   # ✅ Documentation preserved
├── examples/               # ✅ Workflow examples preserved
├── scripts/                # ✅ Helper scripts preserved
└── .env.example            # ✅ Environment variables preserved
```

---

## 🚀 Quick Start with SAM

### **Prerequisites**
```bash
# Install SAM CLI
brew install aws-sam-cli  # macOS
# or follow: https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/install-sam-cli.html

# Install Docker (for building)
# https://docs.docker.com/get-docker/
```

### **Build & Deploy**
```bash
# 1. Build the application
make build

# 2. Deploy to dev
make deploy-dev

# 3. Get webhook URL and secret
make get-secret ENV=dev

# 4. Configure in GitHub
# Use the URL and secret from step 3
```

---

## 🔄 Migration Mapping

### **Environment Variables**
Still loaded from `.env` file automatically!

```bash
# .env
GITHUB_TOKEN=ghp_xxx
ENVIRONMENT=dev
COST_CENTER=Engineering
OWNER=DevOps
```

### **Commands Comparison**

| CDK Command | SAM Command |
|-------------|-------------|
| `cdk deploy` | `sam deploy` |
| `cdk diff` | `sam deploy --no-execute-changeset` |
| `cdk synth` | `sam build` |
| `cdk destroy` | `sam delete` |
| N/A | `sam local invoke` ✅ New! |
| N/A | `sam local start-api` ✅ New! |

### **Makefile Commands**

| Purpose | Command |
|---------|---------|
| Build | `make build` |
| Deploy Dev | `make deploy-dev` |
| Deploy Prod | `make deploy-prod` |
| View Logs | `make logs ENV=dev` |
| Get Secret | `make get-secret ENV=dev` |
| Destroy Stack | `make destroy-dev` |

---

## 🎨 What Stayed the Same

### ✅ **Lambda Functions**
- Same Python code
- Same Docker image approach
- Same pre-baked GitHub runner
- Same environment variables

### ✅ **Infrastructure**
- Same AWS resources:
  - API Gateway
  - Lambda Functions
  - Secrets Manager
  - ECR Repository
  - CloudWatch Logs
  - IAM Roles

### ✅ **Features**
- Webhook signature verification
- Ephemeral runners
- Auto-scaling
- CloudWatch alarms
- Multi-environment support
- Resource tagging

### ✅ **Documentation**
- All docs preserved in `/docs`
- Examples in `/examples`
- Helper scripts in `/scripts`

---

## 🆕 New Features with SAM

### **1. Local Testing** 🎉
```bash
# Test webhook function locally
sam local invoke WebhookFunction -e events/webhook-event.json

# Start API Gateway locally
sam local start-api
curl http://localhost:3000/
```

### **2. Simpler Template**
```yaml
# SAM is more concise for common patterns
WebhookFunction:
  Type: AWS::Serverless::Function  # SAM shorthand
  Properties:
    CodeUri: lambda/webhook/
    Events:
      WebhookApi:
        Type: Api  # Auto-creates API Gateway!
```

### **3. Environment-Based Configs**
```toml
# samconfig.toml
[dev.deploy.parameters]
stack_name = "github-runner-dev"
parameter_overrides = ["Environment=dev"]

[prod.deploy.parameters]
stack_name = "github-runner-prod"
parameter_overrides = ["Environment=prod"]
```

---

## 🔧 Development Workflow

### **Before (CDK)**
```bash
npm install
npm run build
cdk synth
cdk deploy
```

### **After (SAM)**
```bash
make build        # sam build
make deploy-dev   # sam deploy
```

**Simpler and faster!** ⚡

---

## 📚 Resources

### **SAM Documentation**
- [SAM CLI Reference](https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/what-is-sam.html)
- [SAM Template Specification](https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/sam-specification.html)
- [SAM Policy Templates](https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/serverless-policy-templates.html)

### **aws_fastapi_template Reference**
- [GitHub Repository](https://github.com/shotah/aws_fastapi_template)
- Uses same SAM patterns
- Similar Makefile structure
- Proven in production

### **CDK Branch (Reference)**
```bash
git checkout cdk-exploration  # View CDK implementation
```

---

## 🐛 Troubleshooting

### **"Command not found: sam"**
**Solution:** Install SAM CLI
```bash
brew install aws-sam-cli  # macOS
```

### **"Docker not running"**
**Solution:** Start Docker Desktop
```bash
docker ps  # Verify Docker is running
```

### **"Stack already exists"**
**Solution:** The stack from CDK might still exist
```bash
# Delete old CDK stack first
aws cloudformation delete-stack --stack-name GithubRunnerStack

# Then deploy SAM version
make deploy-dev
```

### **"ECR repository not found"**
**Solution:** Deploy stack first, then push Docker image
```bash
make deploy-dev            # Creates ECR repository
make docker-build          # Build image
make docker-push ENV=dev   # Push to ECR
```

---

## ✅ Validation Checklist

After migration, verify:

- [ ] `make build` completes successfully
- [ ] `make deploy-dev` deploys to AWS
- [ ] Webhook URL is accessible
- [ ] Webhook secret is retrievable
- [ ] Lambda functions are created
- [ ] CloudWatch logs are created
- [ ] GitHub webhook can be configured
- [ ] Test workflow executes successfully

---

## 🎉 Benefits Achieved

1. ✅ **Team Alignment** - Everyone uses SAM now
2. ✅ **Simpler Onboarding** - YAML easier than TypeScript
3. ✅ **Local Testing** - Can test without deploying
4. ✅ **Platform Approved** - Matches company standards
5. ✅ **Better Support** - Team can help with SAM issues
6. ✅ **Faster Builds** - No npm install, no TypeScript compilation
7. ✅ **Cleaner Repo** - Fewer dependencies

---

## 📞 Questions?

- **SAM Issues:** Check [SAM CLI Docs](https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/serverless-sam-cli-command-reference.html)
- **Pattern Questions:** Reference [aws_fastapi_template](https://github.com/shotah/aws_fastapi_template)
- **CDK Reference:** `git checkout cdk-exploration`

**Migration complete! Welcome to SAM! 🚀**

