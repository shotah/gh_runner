# Project Structure

Clean and organized repository layout for the GitHub Actions Lambda Runner.

## 📁 Root Directory (Clean!)

```
gh_runner/
├── 📂 .github/workflows/     # CI/CD workflows
│   └── deploy.yml           # Auto-deployment workflow
├── 📂 bin/                  # CDK app entry point
│   └── gh-runner.ts
├── 📂 docs/                 # 📚 All documentation here!
│   ├── ARCHITECTURE.md      # System design and components
│   ├── CONTRIBUTING.md      # Development guidelines
│   ├── SECRETS_MANAGEMENT.md # Token and secrets guide
│   ├── SECURITY.md          # Security best practices
│   ├── SETUP.md             # Complete setup guide
│   └── TAGGING_STRATEGY.md  # Cost tracking guide
├── 📂 examples/             # Sample GitHub Actions workflows
│   ├── workflow-cdk-deploy.yml
│   ├── workflow-sam-deploy.yml
│   └── workflow-simple.yml
├── 📂 lambda/               # Lambda function code
│   ├── runner/              # Runner executor (Docker)
│   │   ├── Dockerfile       # Pre-bakes GitHub runner
│   │   ├── index.py         # Runner Lambda handler
│   │   └── requirements.txt
│   └── webhook/             # Webhook receiver
│       ├── index.py         # Webhook Lambda handler
│       └── requirements.txt
├── 📂 lib/                  # CDK stack definition
│   └── github-runner-stack.ts # Infrastructure as code
├── 📂 scripts/              # Helper scripts
│   ├── check-security.sh
│   ├── deploy.sh
│   ├── get-webhook-secret.sh
│   ├── setup-github-token.sh
│   └── view-logs.sh
├── .env.example             # Environment variables template
├── .gitignore               # Git ignore rules
├── LICENSE                  # MIT License
├── Makefile                 # Common commands
├── README.md                # Project overview (links to docs/)
├── package.json             # Node.js dependencies
└── tsconfig.json            # TypeScript configuration
```

## 📚 Documentation Organization

All documentation is centralized in the `/docs` directory:

| Document | Purpose | Audience |
|----------|---------|----------|
| **[SETUP.md](docs/SETUP.md)** | Step-by-step setup | New users |
| **[ARCHITECTURE.md](docs/ARCHITECTURE.md)** | System design | Developers, architects |
| **[SECURITY.md](docs/SECURITY.md)** | Security hardening | Security teams, ops |
| **[SECRETS_MANAGEMENT.md](docs/SECRETS_MANAGEMENT.md)** | Token management | All users |
| **[TAGGING_STRATEGY.md](docs/TAGGING_STRATEGY.md)** | Cost tracking | FinOps, managers |
| **[CONTRIBUTING.md](docs/CONTRIBUTING.md)** | Development guide | Contributors |

## 🎯 Benefits of This Structure

✅ **Clean Root** - Only essential files at the top level
✅ **Clear Navigation** - All docs in one place
✅ **Easy Discovery** - README links to relevant docs
✅ **Scalable** - Easy to add new documentation
✅ **Professional** - Follows open-source best practices

## 🔗 Cross-References

- **README.md** → Points to all docs in `/docs`
- **Docs** → Self-contained (no broken links)
- **Examples** → Referenced from README and SETUP.md

## 🚀 For New Users

1. Start with **[README.md](README.md)** for project overview
2. Follow **[docs/SETUP.md](docs/SETUP.md)** for installation
3. Review **[docs/SECURITY.md](docs/SECURITY.md)** before production
4. Use **[docs/SECRETS_MANAGEMENT.md](docs/SECRETS_MANAGEMENT.md)** for token setup
5. Check **[examples/](examples/)** for workflow samples

## 📝 For Contributors

1. Read **[docs/CONTRIBUTING.md](docs/CONTRIBUTING.md)** first
2. Understand **[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)**
3. Review code in `/lambda` and `/lib`
4. Test using `Makefile` commands
5. Update docs when adding features

---

> 💡 **Pro Tip:** Use `Ctrl+P` (VS Code) or `Cmd+P` (Mac) and type "docs/" to quickly navigate to any documentation file!
