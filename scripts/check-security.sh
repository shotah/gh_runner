#!/bin/bash

echo "🔒 GitHub Runner Security Check"
echo "================================"
echo ""

# Colors
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

ISSUES=0

# Check 1: GitHub Token Rotation
echo "📅 Checking GitHub Token Age..."
TOKEN_LAST_CHANGED=$(aws secretsmanager describe-secret \
  --secret-id github-runner/token \
  --query 'LastChangedDate' \
  --output text 2>/dev/null)

if [ $? -eq 0 ]; then
    TOKEN_AGE_DAYS=$(( ( $(date +%s) - $(date -d "$TOKEN_LAST_CHANGED" +%s) ) / 86400 ))
    if [ $TOKEN_AGE_DAYS -gt 90 ]; then
        echo -e "${RED}❌ CRITICAL: GitHub token is $TOKEN_AGE_DAYS days old (rotate every 90 days)${NC}"
        ISSUES=$((ISSUES + 1))
    elif [ $TOKEN_AGE_DAYS -gt 60 ]; then
        echo -e "${YELLOW}⚠️  WARNING: GitHub token is $TOKEN_AGE_DAYS days old (consider rotating soon)${NC}"
    else
        echo -e "${GREEN}✅ OK: Token age: $TOKEN_AGE_DAYS days${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  Unable to check token age${NC}"
fi

echo ""

# Check 2: Lambda Concurrency Limit
echo "🔢 Checking Lambda Concurrency Limits..."
RUNNER_CONCURRENCY=$(aws lambda get-function-concurrency \
  --function-name github-runner-executor \
  --query 'ReservedConcurrentExecutions' \
  --output text 2>/dev/null)

if [ "$RUNNER_CONCURRENCY" == "None" ]; then
    echo -e "${YELLOW}⚠️  WARNING: No concurrency limit set (unlimited invocations possible)${NC}"
elif [ "$RUNNER_CONCURRENCY" == "0" ]; then
    echo -e "${RED}❌ Runner is DISABLED (concurrency = 0)${NC}"
    ISSUES=$((ISSUES + 1))
else
    echo -e "${GREEN}✅ OK: Concurrency limited to $RUNNER_CONCURRENCY${NC}"
fi

echo ""

# Check 3: CloudWatch Alarms
echo "🚨 Checking CloudWatch Alarms..."
ALARM_COUNT=$(aws cloudwatch describe-alarms \
  --alarm-name-prefix "GithubRunner" \
  --query 'length(MetricAlarms)' \
  --output text 2>/dev/null)

if [ "$ALARM_COUNT" == "0" ] || [ -z "$ALARM_COUNT" ]; then
    echo -e "${YELLOW}⚠️  WARNING: No CloudWatch alarms configured${NC}"
    echo "   Consider adding alarms for errors, high usage, and costs"
else
    echo -e "${GREEN}✅ OK: $ALARM_COUNT alarm(s) configured${NC}"
fi

echo ""

# Check 4: API Gateway Throttling
echo "🌐 Checking API Gateway Rate Limiting..."
API_ID=$(aws apigateway get-rest-apis \
  --query "items[?name=='GitHub Runner Webhook'].id" \
  --output text 2>/dev/null)

if [ -n "$API_ID" ]; then
    RATE_LIMIT=$(aws apigateway get-stages \
      --rest-api-id "$API_ID" \
      --query 'item[0].methodSettings."*/*".throttlingRateLimit' \
      --output text 2>/dev/null)
    
    if [ -z "$RATE_LIMIT" ] || [ "$RATE_LIMIT" == "None" ]; then
        echo -e "${YELLOW}⚠️  WARNING: No rate limiting configured on API Gateway${NC}"
    else
        echo -e "${GREEN}✅ OK: Rate limit: $RATE_LIMIT requests/second${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  Unable to check API Gateway settings${NC}"
fi

echo ""

# Check 5: IAM Role Permissions
echo "🔐 Checking IAM Permissions..."
ROLE_NAME=$(aws lambda get-function \
  --function-name github-runner-executor \
  --query 'Configuration.Role' \
  --output text 2>/dev/null | awk -F'/' '{print $NF}')

if [ -n "$ROLE_NAME" ]; then
    POLICY_COUNT=$(aws iam list-attached-role-policies \
      --role-name "$ROLE_NAME" \
      --query 'length(AttachedPolicies)' \
      --output text 2>/dev/null)
    
    echo "   Role: $ROLE_NAME"
    echo "   Attached Policies: $POLICY_COUNT"
    
    # Check for overly permissive policies
    ADMIN_POLICY=$(aws iam list-attached-role-policies \
      --role-name "$ROLE_NAME" \
      --query "AttachedPolicies[?PolicyName=='AdministratorAccess'].PolicyName" \
      --output text 2>/dev/null)
    
    if [ -n "$ADMIN_POLICY" ]; then
        echo -e "${RED}❌ CRITICAL: AdministratorAccess policy attached!${NC}"
        ISSUES=$((ISSUES + 1))
    else
        echo -e "${YELLOW}⚠️  Review inline policies - default permissions are very broad${NC}"
    fi
else
    echo -e "${YELLOW}⚠️  Unable to check IAM role${NC}"
fi

echo ""

# Check 6: VPC Configuration
echo "🌍 Checking VPC Isolation..."
VPC_CONFIG=$(aws lambda get-function-configuration \
  --function-name github-runner-executor \
  --query 'VpcConfig.VpcId' \
  --output text 2>/dev/null)

if [ "$VPC_CONFIG" == "None" ] || [ -z "$VPC_CONFIG" ]; then
    echo -e "${YELLOW}⚠️  INFO: Runner not in VPC (no network isolation)${NC}"
    echo "   Consider VPC deployment for production"
else
    echo -e "${GREEN}✅ OK: Runner deployed in VPC: $VPC_CONFIG${NC}"
fi

echo ""

# Check 7: CloudTrail
echo "📊 Checking CloudTrail..."
TRAIL_COUNT=$(aws cloudtrail describe-trails \
  --query 'length(trailList)' \
  --output text 2>/dev/null)

if [ "$TRAIL_COUNT" == "0" ]; then
    echo -e "${YELLOW}⚠️  WARNING: No CloudTrail trails found${NC}"
    echo "   Enable CloudTrail for audit logging"
else
    echo -e "${GREEN}✅ OK: $TRAIL_COUNT CloudTrail(s) configured${NC}"
fi

echo ""
echo "================================"

if [ $ISSUES -gt 0 ]; then
    echo -e "${RED}Found $ISSUES critical security issues${NC}"
    echo "Review SECURITY.md for mitigation steps"
    exit 1
else
    echo -e "${GREEN}No critical issues found${NC}"
    echo "Review warnings above and see SECURITY.md for hardening steps"
    exit 0
fi

