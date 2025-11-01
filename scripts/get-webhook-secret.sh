#!/bin/bash

echo "🔐 Retrieving Webhook Secret"
echo "============================"
echo ""

SECRET=$(aws secretsmanager get-secret-value \
  --secret-id github-runner/webhook-secret \
  --query SecretString \
  --output text 2>/dev/null)

if [ $? -ne 0 ]; then
    echo "❌ Failed to retrieve webhook secret"
    echo "Make sure the stack is deployed and you have proper AWS credentials"
    exit 1
fi

echo "Your webhook secret is:"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "$SECRET"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📋 Use this value when configuring your GitHub webhook"
echo ""
echo "Steps:"
echo "1. Go to GitHub → Repository/Organization Settings → Webhooks"
echo "2. Click 'Add webhook'"
echo "3. Paste this secret in the 'Secret' field"

