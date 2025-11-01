#!/bin/bash
set -e

echo "🚀 Deploying GitHub Actions Lambda Runner"
echo "=========================================="

# Check prerequisites
echo "📋 Checking prerequisites..."

if ! command -v node &> /dev/null; then
    echo "❌ Node.js is not installed"
    exit 1
fi

if ! command -v npm &> /dev/null; then
    echo "❌ npm is not installed"
    exit 1
fi

if ! command -v aws &> /dev/null; then
    echo "❌ AWS CLI is not installed"
    exit 1
fi

if ! command -v cdk &> /dev/null; then
    echo "❌ CDK CLI is not installed. Install with: npm install -g aws-cdk"
    exit 1
fi

if ! command -v docker &> /dev/null; then
    echo "❌ Docker is not installed"
    exit 1
fi

echo "✅ All prerequisites met"

# Install dependencies
echo ""
echo "📦 Installing dependencies..."
npm install

# Build TypeScript
echo ""
echo "🔨 Building TypeScript..."
npm run build

# Bootstrap CDK if needed
echo ""
echo "🔧 Checking CDK bootstrap..."
if ! aws cloudformation describe-stacks --stack-name CDKToolkit &> /dev/null; then
    echo "⚠️  CDK not bootstrapped. Bootstrapping now..."
    cdk bootstrap
else
    echo "✅ CDK already bootstrapped"
fi

# Deploy
echo ""
echo "🚢 Deploying stack..."
cdk deploy --require-approval never

echo ""
echo "✅ Deployment complete!"
echo ""
echo "📝 Next steps:"
echo "1. Update GitHub token in Secrets Manager"
echo "2. Configure GitHub webhook"
echo "3. Update your workflow to use self-hosted runner"
echo ""
echo "See README.md and SETUP.md for detailed instructions"

