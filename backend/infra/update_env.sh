#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# MarketPulse — Update Backend Env Vars on App Runner
# Run this after setup_aws.py prints the OPENSEARCH_ENDPOINT.
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

APP_NAME="marketpulse"
REGION="${AWS_REGION:-us-east-1}"
APPRUNNER_SERVICE="${APP_NAME}-backend"
BACKEND_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

echo "🔧  Updating App Runner environment variables..."

# Find service ARN
SERVICE_ARN=$(aws apprunner list-services \
  --query "ServiceSummaryList[?ServiceName=='${APPRUNNER_SERVICE}'].ServiceArn" \
  --output text --region "$REGION")

if [ -z "$SERVICE_ARN" ]; then
  echo "❌  App Runner service '$APPRUNNER_SERVICE' not found. Run deploy.sh first."
  exit 1
fi

ECR_ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/${APP_NAME}-apprunner-ecr-role"
ECR_URI="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/${APP_NAME}-backend"

# Parse .env
ENV_JSON="{"
first=1
while IFS='=' read -r key value; do
  [[ "$key" =~ ^#.*$ ]] && continue
  [[ -z "$key" ]] && continue
  value="${value%%#*}"
  value="${value%"${value##*[! ]}"}"
  value="${value#\"}"
  value="${value%\"}"
  value=$(echo -n "$value" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g')
  [ -z "$value" ] && continue
  if [ "$first" = "1" ]; then first=0; else ENV_JSON="${ENV_JSON},"; fi
  ENV_JSON="${ENV_JSON}\"${key}\":\"${value}\""
done < "$BACKEND_DIR/.env"
ENV_JSON="${ENV_JSON}}"

aws apprunner update-service \
  --service-arn "$SERVICE_ARN" \
  --region "$REGION" \
  --source-configuration "{
    \"AuthenticationConfiguration\":{\"AccessRoleArn\":\"${ECR_ROLE_ARN}\"},
    \"ImageRepository\":{
      \"ImageIdentifier\":\"${ECR_URI}:latest\",
      \"ImageConfiguration\":{
        \"Port\":\"8000\",
        \"RuntimeEnvironmentVariables\":${ENV_JSON}
      },
      \"ImageRepositoryType\":\"ECR\"
    }
  }" \
  --output json > /dev/null

echo "✅  App Runner env vars updated. Service will restart automatically."
