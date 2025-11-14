# Windows Setup Guide

## Prerequisites for Windows

### 1. Git Bash (Required for Makefile)
The Makefile uses bash syntax and requires **Git Bash** on Windows.

**Install Git for Windows:**
- Download: https://git-scm.com/download/win
- During installation, select "Git Bash Here" option
- Git Bash provides a bash shell on Windows

**Why Git Bash?**
- ✅ Provides bash shell on Windows
- ✅ Included with Git for Windows (you already have it!)
- ✅ Supports all Makefile commands
- ✅ Works identically to Mac/Linux

### 2. AWS SAM CLI
- Download: https://docs.aws.amazon.com/serverless-application-model/latest/developerguide/install-sam-cli.html#install-sam-cli-instructions
- Install the Windows 64-bit version
- Verify: Open Git Bash and run `sam --version`

### 3. Docker Desktop
- Download: https://www.docker.com/products/docker-desktop
- Install Docker Desktop for Windows
- Start Docker Desktop before building
- Verify: `docker --version` in Git Bash

### 4. AWS CLI
- Download: https://awscli.amazonaws.com/AWSCLIV2.msi
- Install and configure: `aws configure`
- Verify: `aws --version` in Git Bash

---

## Using the Makefile on Windows

### Open Git Bash
1. Right-click in the project folder
2. Select **"Git Bash Here"**
3. Or open Git Bash and `cd` to project

### Run Make Commands
```bash
# All commands work the same as Mac/Linux
make help
make build
make deploy-dev
make logs ENV=dev
```

---

## Common Windows Issues

### "make: command not found"
**Solution:** Use Git Bash, not PowerShell or CMD
```bash
# Open Git Bash (not PowerShell!)
make help
```

### "bash: sam: command not found"
**Solution:** Restart Git Bash after installing SAM CLI
```bash
# Close and reopen Git Bash
sam --version  # Should work now
```

### "Docker daemon not running"
**Solution:** Start Docker Desktop
```bash
# Start Docker Desktop application
docker ps  # Verify it works
```

### Path Issues
**Solution:** Git Bash uses Unix-style paths
```bash
# Use forward slashes (/)
cd /c/workspace/gh_runner

# Not backslashes (\)
# cd C:\workspace\gh_runner  # DON'T do this in Git Bash
```

---

## Alternative: WSL2 (Windows Subsystem for Linux)

If you prefer a full Linux environment:

### 1. Install WSL2
```powershell
# In PowerShell (as Administrator)
wsl --install
```

### 2. Install Ubuntu
```powershell
wsl --install -d Ubuntu
```

### 3. Install tools in WSL
```bash
# In WSL Ubuntu terminal
# Install AWS SAM CLI
brew install aws-sam-cli

# Install Docker
# Follow: https://docs.docker.com/desktop/wsl/

# Clone and run project
git clone https://github.com/shotah/gh_runner.git
cd gh_runner
make build
```

---

## Recommended: Git Bash (Simpler)

**For most Windows users, Git Bash is recommended:**
- ✅ Easier setup (comes with Git)
- ✅ Familiar to Windows developers
- ✅ Works with Windows paths
- ✅ Integrates with Windows Docker Desktop
- ✅ No need for WSL2

**WSL2 is better if you:**
- Want a full Linux environment
- Develop primarily on Linux
- Need Linux-specific tools

---

## Quick Start (Windows)

```bash
# 1. Open Git Bash in project folder
# Right-click → "Git Bash Here"

# 2. Verify tools
sam --version
docker --version
aws --version

# 3. Build and deploy
make build
make deploy-dev

# 4. Get webhook configuration
make get-secret ENV=dev
```

Done! 🎉

---

## Troubleshooting Make on Windows

### Line Ending Issues
Git Bash expects Unix line endings (LF), not Windows (CRLF).

**Fix:**
```bash
# Configure Git to use LF
git config --global core.autocrlf input

# Re-clone repository
cd ..
rm -rf gh_runner
git clone https://github.com/shotah/gh_runner.git
```

### Permission Issues
```bash
# If scripts aren't executable
chmod +x scripts/*.sh
```

### Makefile Not Working
```bash
# Verify you're in Git Bash (not PowerShell)
echo $SHELL
# Should show: /usr/bin/bash or similar

# If in PowerShell, open Git Bash instead
```

---

## Summary

| Tool | Windows Solution |
|------|------------------|
| **Make** | Git Bash (included with Git) |
| **SAM CLI** | Download Windows installer |
| **Docker** | Docker Desktop for Windows |
| **AWS CLI** | Download Windows installer |
| **Bash** | Git Bash (included with Git) |

**All Makefile commands work identically on Windows (via Git Bash), Mac, and Linux!** ✅

