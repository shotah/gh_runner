#!/bin/bash

echo "🔑 GitHub Token Setup"
echo "===================="
echo ""

read -sp "Enter your GitHub Personal Access Token: " GITHUB_TOKEN
echo ""

if [ -z "$GITHUB_TOKEN" ]; then
    echo "❌ Token cannot be empty"
    exit 1
fi

echo ""
echo "📝 Updating secret in AWS Secrets Manager..."

aws secretsmanager put-secret-value \
  --secret-id github-runner/token \
  --secret-string "{\"token\":\"$GITHUB_TOKEN\"}" \
  > /dev/null

if [ $? -eq 0 ]; then
    echo "✅ GitHub token updated successfully!"
else
    echo "❌ Failed to update token"
    exit 1
fi

echo ""
echo "🔍 Verifying secret was stored..."
aws secretsmanager get-secret-value \
  --secret-id github-runner/token \
  --query SecretString \
  --output text | jq -r '.token' | head -c 10

echo "..."
echo ""
echo "✅ Token verified (showing first 10 characters)"

