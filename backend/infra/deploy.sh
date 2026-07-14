#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# MarketPulse — Full AWS Deployment Script
#
# Deploys:
#   1. AWS ECR → push backend Docker image
#   2. AWS App Runner → run backend container
#   3. AWS OpenSearch Serverless → vector DB (marketpulse-vectors collection)
#   4. AWS S3 + CloudFront → admin-web static site
#
# Usage:
#   chmod +x deploy.sh
#   ./deploy.sh
#
# Requirements:
#   - AWS CLI v2 configured with credentials (aws configure)
#   - Docker running
#   - Node.js 18+ installed
#   - IAM user with policies in infra/aws_policy.json attached
#     PLUS: AmazonEC2ContainerRegistryFullAccess, CloudFrontFullAccess,
#           AmazonS3FullAccess, AppRunnerFullAccess
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

# ── CONFIG ────────────────────────────────────────────────────────────────────
APP_NAME="marketpulse"
REGION="${AWS_REGION:-us-east-1}"
ECR_REPO="${APP_NAME}-backend"
APPRUNNER_SERVICE="${APP_NAME}-backend"
S3_BUCKET="${APP_NAME}-admin-web"
CF_COMMENT="MarketPulse Admin Web"
OPENSEARCH_COLLECTION="${APP_NAME}-vectors"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ADMIN_WEB_DIR="$(cd "$SCRIPT_DIR/../../admin-web" && pwd)"

# ── CHECK PREREQUISITES ───────────────────────────────────────────────────────

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║          MarketPulse AWS Deployment                          ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

check_cmd() {
  if ! command -v "$1" &>/dev/null; then
    echo "❌  '$1' not found. Please install it first."
    exit 1
  fi
}
check_cmd aws
check_cmd docker
check_cmd node
check_cmd npm

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null) || {
  echo "❌  AWS credentials not configured. Run: aws configure"
  exit 1
}

echo "✅  AWS Account: $ACCOUNT_ID"
echo "✅  Region: $REGION"
echo ""

# ── STEP 1: ECR — Create repo and push image ──────────────────────────────────

echo "══════════════════════════════════════════"
echo "  STEP 1: Building & pushing Docker image"
echo "══════════════════════════════════════════"

ECR_URI="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/${ECR_REPO}"

# Create ECR repo if missing
if ! aws ecr describe-repositories --repository-names "$ECR_REPO" --region "$REGION" &>/dev/null; then
  echo "📦  Creating ECR repository: $ECR_REPO"
  aws ecr create-repository \
    --repository-name "$ECR_REPO" \
    --region "$REGION" \
    --image-scanning-configuration scanOnPush=true \
    --output json > /dev/null
  echo "   ✓ ECR repo created"
else
  echo "   ℹ ECR repo already exists"
fi

# Authenticate Docker to ECR
echo "🔐  Authenticating Docker to ECR..."
aws ecr get-login-password --region "$REGION" \
  | docker login --username AWS --password-stdin "$ECR_URI"

# Build and push
echo "🐳  Building Docker image..."
docker build -t "$ECR_REPO" "$BACKEND_DIR" --platform linux/amd64

echo "🚀  Pushing to ECR..."
docker tag "$ECR_REPO:latest" "$ECR_URI:latest"
docker push "$ECR_URI:latest"
echo "   ✓ Image pushed: $ECR_URI:latest"
echo ""

# ── STEP 2: Load env vars for App Runner ─────────────────────────────────────

echo "══════════════════════════════════════════"
echo "  STEP 2: Reading environment variables"
echo "══════════════════════════════════════════"

ENV_FILE="$BACKEND_DIR/.env"
if [ ! -f "$ENV_FILE" ]; then
  echo "❌  .env file not found at $ENV_FILE"
  echo "    Copy .env.example to .env and fill in your credentials."
  exit 1
fi

# Parse .env into App Runner env var format (flat map: {"KEY":"VALUE"})
ENV_JSON="{"
first=1
while IFS='=' read -r key value; do
  [[ "$key" =~ ^#.*$ ]] && continue
  [[ -z "$key" ]] && continue
  value="${value%%#*}"       # strip inline comments
  value="${value%"${value##*[! ]}"}"  # rtrim
  value="${value#\"}"        # strip leading quote
  value="${value%\"}"        # strip trailing quote
  # Escape backslashes and double quotes in value for JSON compatibility
  value=$(echo -n "$value" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g')
  [ -z "$value" ] && continue
  if [ "$first" = "1" ]; then
    first=0
  else
    ENV_JSON="${ENV_JSON},"
  fi
  ENV_JSON="${ENV_JSON}\"${key}\":\"${value}\""
done < "$ENV_FILE"
ENV_JSON="${ENV_JSON}}"

echo "   ✓ Parsed environment variables"
echo ""

# ── STEP 3: App Runner — Deploy backend ───────────────────────────────────────

echo "══════════════════════════════════════════"
echo "  STEP 3: Deploying App Runner service"
echo "══════════════════════════════════════════"

# Create IAM role for App Runner to pull from ECR (if not exists)
APPRUNNER_ROLE_NAME="${APP_NAME}-apprunner-ecr-role"
echo "🔑  Configuring App Runner ECR access role..."
TRUST_POLICY='{
  "Version":"2012-10-17",
  "Statement":[{
    "Effect":"Allow",
    "Principal":{"Service":"build.apprunner.amazonaws.com"},
    "Action":"sts:AssumeRole"
  }]
}'
# Create role, ignoring EntityAlreadyExists errors
aws iam create-role \
  --role-name "$APPRUNNER_ROLE_NAME" \
  --assume-role-policy-document "$TRUST_POLICY" \
  --output json > /dev/null 2>&1 || true

# Attach role policy, ignoring errors
aws iam attach-role-policy \
  --role-name "$APPRUNNER_ROLE_NAME" \
  --policy-arn "arn:aws:iam::aws:policy/service-role/AWSAppRunnerServicePolicyForECRAccess" \
  --output json > /dev/null 2>&1 || true

echo "   ✓ Role configured"
sleep 5  # Propagation delay

APPRUNNER_ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/${APPRUNNER_ROLE_NAME}"

# Check if service already exists
EXISTING_ARN=$(aws apprunner list-services \
  --query "ServiceSummaryList[?ServiceName=='${APPRUNNER_SERVICE}'].ServiceArn" \
  --output text --region "$REGION" 2>/dev/null || echo "")

if [ -n "$EXISTING_ARN" ]; then
  echo "🔄  Updating existing App Runner service..."
  aws apprunner update-service \
    --service-arn "$EXISTING_ARN" \
    --region "$REGION" \
    --source-configuration "{
      \"AuthenticationConfiguration\":{\"AccessRoleArn\":\"${APPRUNNER_ROLE_ARN}\"},
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
  SERVICE_ARN="$EXISTING_ARN"
  echo "   ✓ Deployment triggered"
else
  echo "🚀  Creating App Runner service (first deploy)..."
  SERVICE_ARN=$(aws apprunner create-service \
    --service-name "$APPRUNNER_SERVICE" \
    --region "$REGION" \
    --source-configuration "{
      \"AuthenticationConfiguration\":{\"AccessRoleArn\":\"${APPRUNNER_ROLE_ARN}\"},
      \"ImageRepository\":{
        \"ImageIdentifier\":\"${ECR_URI}:latest\",
        \"ImageConfiguration\":{
          \"Port\":\"8000\",
          \"RuntimeEnvironmentVariables\":${ENV_JSON}
        },
        \"ImageRepositoryType\":\"ECR\"
      },
      \"AutoDeploymentsEnabled\":true
    }" \
    --instance-configuration '{"Cpu":"1 vCPU","Memory":"2 GB"}' \
    --health-check-configuration '{"Protocol":"HTTP","Path":"/health","Interval":10,"Timeout":5,"HealthyThreshold":1,"UnhealthyThreshold":5}' \
    --query "Service.ServiceArn" \
    --output text)
  echo "   ✓ App Runner service created: $SERVICE_ARN"
fi

# Wait for deployment
echo "⏳  Waiting for App Runner deployment (takes ~3-5 min)..."
for i in $(seq 1 40); do
  STATUS=$(aws apprunner describe-service \
    --service-arn "$SERVICE_ARN" \
    --region "$REGION" \
    --query "Service.Status" \
    --output text 2>/dev/null)
  echo "   [$i/40] Status: $STATUS"
  if [[ "$STATUS" == "RUNNING" ]]; then
    break
  fi
  if [[ "$STATUS" == "CREATE_FAILED" || "$STATUS" == "UPDATE_FAILED" ]]; then
    echo "   ❌ Deployment FAILED"
    exit 1
  fi
  sleep 15
done

BACKEND_URL=$(aws apprunner describe-service \
  --service-arn "$SERVICE_ARN" \
  --region "$REGION" \
  --query "Service.ServiceUrl" \
  --output text)

BACKEND_URL="https://${BACKEND_URL}"
echo "   ✓ Backend live at: $BACKEND_URL"
echo ""

# ── STEP 4: OpenSearch Serverless Vector DB ───────────────────────────────────

echo "══════════════════════════════════════════"
echo "  STEP 4: Setting up OpenSearch Serverless"
echo "══════════════════════════════════════════"

cd "$BACKEND_DIR"
# Run the Python setup script (reads creds from .env)
python3 setup_aws.py || echo "   ⚠ OpenSearch setup encountered an issue (non-fatal if collection exists)"
echo ""

# ── STEP 5: S3 + CloudFront — Admin Web ──────────────────────────────────────

echo "══════════════════════════════════════════"
echo "  STEP 5: Deploying admin web to S3 + CloudFront"
echo "══════════════════════════════════════════"

# Build admin web with backend URL injected
echo "🔨  Building admin-web..."
cd "$ADMIN_WEB_DIR"

# Inject backend URL into Vite build environment
cat > .env.production << TSEOF
VITE_API_URL=${BACKEND_URL}
TSEOF

npm install --silent
npm run build

echo "   ✓ Admin web built"

# Create S3 bucket (unique name using account ID)
S3_BUCKET="${APP_NAME}-admin-${ACCOUNT_ID}"
if ! aws s3api head-bucket --bucket "$S3_BUCKET" --region "$REGION" 2>/dev/null; then
  echo "🪣  Creating S3 bucket: $S3_BUCKET"
  if [ "$REGION" = "us-east-1" ]; then
    aws s3api create-bucket \
      --bucket "$S3_BUCKET" \
      --region "$REGION"
  else
    aws s3api create-bucket \
      --bucket "$S3_BUCKET" \
      --region "$REGION" \
      --create-bucket-configuration LocationConstraint="$REGION"
  fi
  # Disable block public access for static website
  aws s3api put-public-access-block \
    --bucket "$S3_BUCKET" \
    --public-access-block-configuration \
      "BlockPublicAcls=false,IgnorePublicAcls=false,BlockPublicPolicy=false,RestrictPublicBuckets=false"
  # Enable static website hosting
  aws s3api put-bucket-website \
    --bucket "$S3_BUCKET" \
    --website-configuration '{"IndexDocument":{"Suffix":"index.html"},"ErrorDocument":{"Key":"index.html"}}'
  # Public read policy
  aws s3api put-bucket-policy \
    --bucket "$S3_BUCKET" \
    --policy "{
      \"Version\":\"2012-10-17\",
      \"Statement\":[{
        \"Sid\":\"PublicReadGetObject\",
        \"Effect\":\"Allow\",
        \"Principal\":\"*\",
        \"Action\":\"s3:GetObject\",
        \"Resource\":\"arn:aws:s3:::${S3_BUCKET}/*\"
      }]
    }"
  echo "   ✓ S3 bucket created and configured"
else
  echo "   ℹ S3 bucket already exists"
fi

# Upload dist/
echo "📤  Uploading admin-web build to S3..."
aws s3 sync dist/ "s3://${S3_BUCKET}/" \
  --delete \
  --cache-control "max-age=31536000" \
  --exclude "index.html"
aws s3 cp dist/index.html "s3://${S3_BUCKET}/index.html" \
  --cache-control "no-cache, no-store, must-revalidate"
echo "   ✓ Files uploaded"

S3_WEBSITE_URL="http://${S3_BUCKET}.s3-website-${REGION}.amazonaws.com"

# Create CloudFront distribution (skip if already exists for this bucket)
echo "🌐  Setting up CloudFront..."
EXISTING_CF=$(aws cloudfront list-distributions \
  --query "DistributionList.Items[?Origins.Items[0].DomainName=='${S3_BUCKET}.s3.amazonaws.com'].Id" \
  --output text 2>/dev/null || echo "")

if [ -z "$EXISTING_CF" ]; then
  CF_ORIGIN_ID="${APP_NAME}-admin-origin"
  CF_DIST=$(aws cloudfront create-distribution \
    --distribution-config "{
      \"CallerReference\":\"${APP_NAME}-admin-$(date +%s)\",
      \"Comment\":\"${CF_COMMENT}\",
      \"DefaultRootObject\":\"index.html\",
      \"Origins\":{
        \"Quantity\":1,
        \"Items\":[{
          \"Id\":\"${CF_ORIGIN_ID}\",
          \"DomainName\":\"${S3_BUCKET}.s3-website-${REGION}.amazonaws.com\",
          \"CustomOriginConfig\":{
            \"HTTPPort\":80,
            \"HTTPSPort\":443,
            \"OriginProtocolPolicy\":\"http-only\"
          }
        }]
      },
      \"DefaultCacheBehavior\":{
        \"TargetOriginId\":\"${CF_ORIGIN_ID}\",
        \"ViewerProtocolPolicy\":\"redirect-to-https\",
        \"AllowedMethods\":{\"Quantity\":2,\"Items\":[\"GET\",\"HEAD\"]},
        \"CachePolicyId\":\"658327ea-f89d-4fab-a63d-7e88639e58f6\",
        \"Compress\":true
      },
      \"CustomErrorResponses\":{
        \"Quantity\":1,
        \"Items\":[{\"ErrorCode\":404,\"ResponseCode\":\"200\",\"ResponsePagePath\":\"/index.html\",\"ErrorCachingMinTTL\":0}]
      },
      \"Enabled\":true,
      \"PriceClass\":\"PriceClass_100\"
    }" \
    --query "Distribution.DomainName" \
    --output text)
  echo "   ✓ CloudFront distribution created: https://$CF_DIST"
  ADMIN_URL="https://$CF_DIST"
else
  ADMIN_URL="(existing distribution)"
  echo "   ℹ CloudFront distribution already exists"
fi

echo ""

# ── DONE ─────────────────────────────────────────────────────────────────────

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  ✅  DEPLOYMENT COMPLETE                                     ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
echo "  🔌 Backend API     : $BACKEND_URL"
echo "  📊 Admin Panel     : $ADMIN_URL"
echo "  🗄  S3 Static URL   : $S3_WEBSITE_URL"
echo "  🧠 Vector DB       : AWS OpenSearch Serverless (us-east-1)"
echo ""
echo "Next steps:"
echo "  1. Add OPENSEARCH_ENDPOINT to App Runner env vars (from setup_aws.py output)"
echo "  2. Go to Admin Panel → Vector Training → 'Sync All' to train the vector DB"
echo "  3. Enable Bedrock Titan model access at: AWS Console → Bedrock → Model access"
echo ""
