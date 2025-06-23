#!/bin/bash

# Deployment script for Hive Service Print Lambda

set -e

# Default values
ENVIRONMENT="dev"
REGION="eu-west-2"
STACK_NAME=""
ECR_REPO=""
AWS_PROFILE=""

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -e, --environment    Environment (dev, staging, prod) [default: dev]"
    echo "  -r, --region         AWS region [default: eu-west-2]"
    echo "  -s, --stack-name     CloudFormation stack name [default: hive-print-{environment}]"
    echo "  -i, --ecr-repo       ECR repository name [default: hive-service-print]"
    echo "  -p, --profile        AWS profile to use"
    echo "  -h, --help           Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 -e dev -r eu-west-2"
    echo "  $0 -e prod -r eu-west-1 -p production"
    echo "  $0 --environment staging --ecr-repo my-hive-print"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -e|--environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        -r|--region)
            REGION="$2"
            shift 2
            ;;
        -s|--stack-name)
            STACK_NAME="$2"
            shift 2
            ;;
        -i|--ecr-repo)
            ECR_REPO="$2"
            shift 2
            ;;
        -p|--profile)
            AWS_PROFILE="$2"
            shift 2
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            echo "Unknown option $1"
            show_usage
            exit 1
            ;;
    esac
done

# Set defaults if not provided
if [ -z "$STACK_NAME" ]; then
    STACK_NAME="hive-print-${ENVIRONMENT}"
fi

if [ -z "$ECR_REPO" ]; then
    ECR_REPO="hive-service-print"
fi

# Set AWS profile if provided
if [ -n "$AWS_PROFILE" ]; then
    export AWS_PROFILE="$AWS_PROFILE"
fi

echo "🚀 Deploying Hive Service Print Lambda"
echo "Environment: $ENVIRONMENT"
echo "Region: $REGION"
echo "Stack Name: $STACK_NAME"
echo "ECR Repo: $ECR_REPO"
if [ -n "$AWS_PROFILE" ]; then
    echo "AWS Profile: $AWS_PROFILE"
fi
echo ""

# Get AWS Account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "AWS Account ID: $ACCOUNT_ID"

# Construct ECR Image URI
ECR_IMAGE_URI="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/${ECR_REPO}:latest"
echo "ECR Image URI: $ECR_IMAGE_URI"
echo ""

# Check if ECR repository exists
echo "🔍 Checking ECR repository..."
if ! aws ecr describe-repositories --repository-names "$ECR_REPO" --region "$REGION" >/dev/null 2>&1; then
    echo "📦 Creating ECR repository: $ECR_REPO"
    aws ecr create-repository \
        --repository-name "$ECR_REPO" \
        --region "$REGION" \
        --image-scanning-configuration scanOnPush=true \
        --encryption-configuration encryptionType=AES256
else
    echo "✅ ECR repository exists: $ECR_REPO"
fi

# Build and push Docker image
echo ""
echo "🐳 Building and pushing Docker image..."
cd hive.service.print

# Get ECR login token
aws ecr get-login-password --region "$REGION" | docker login --username AWS --password-stdin "${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"

# Build Docker image
docker build -t "$ECR_REPO:latest" .

# Tag for ECR
docker tag "$ECR_REPO:latest" "$ECR_IMAGE_URI"

# Push to ECR
docker push "$ECR_IMAGE_URI"

cd ..

# Update parameters file with correct ECR URI
echo ""
echo "📝 Updating parameters file..."
PARAMS_FILE="cloudformation-parameters-${ENVIRONMENT}.json"

if [ ! -f "$PARAMS_FILE" ]; then
    echo "❌ Parameters file not found: $PARAMS_FILE"
    echo "Creating default parameters file..."
    cat > "$PARAMS_FILE" << EOF
[
  {
    "ParameterKey": "Environment",
    "ParameterValue": "$ENVIRONMENT"
  },
  {
    "ParameterKey": "ECRImageURI",
    "ParameterValue": "$ECR_IMAGE_URI"
  },
  {
    "ParameterKey": "ExistingSQSQueueUrl",
    "ParameterValue": "https://sqs.eu-west-2.amazonaws.com/891377085221/hive-print-order-queue-$ENVIRONMENT"
  },
  {
    "ParameterKey": "ExistingSQSQueueArn",
    "ParameterValue": "arn:aws:sqs:eu-west-2:891377085221:hive-print-order-queue-$ENVIRONMENT"
  },
  {
    "ParameterKey": "ExistingS3BucketName",
    "ParameterValue": "hive-designer-$ENVIRONMENT"
  },
  {
    "ParameterKey": "VpcId",
    "ParameterValue": ""
  },
  {
    "ParameterKey": "SubnetIds",
    "ParameterValue": ""
  },
  {
    "ParameterKey": "LambdaTimeout",
    "ParameterValue": "300"
  },
  {
    "ParameterKey": "LambdaMemorySize",
    "ParameterValue": "1024"
  }
]
EOF
else
    # Update ECR URI in existing parameters file
    jq --arg uri "$ECR_IMAGE_URI" '(.[] | select(.ParameterKey == "ECRImageURI") | .ParameterValue) = $uri' "$PARAMS_FILE" > "${PARAMS_FILE}.tmp" && mv "${PARAMS_FILE}.tmp" "$PARAMS_FILE"
fi

# Validate CloudFormation template
echo ""
echo "✅ Validating CloudFormation template..."
aws cloudformation validate-template \
    --template-body file://cloudformation-lambda.yaml \
    --region "$REGION"

# Deploy CloudFormation stack
echo ""
echo "🚀 Deploying CloudFormation stack: $STACK_NAME"

# Check if stack exists
if aws cloudformation describe-stacks --stack-name "$STACK_NAME" --region "$REGION" >/dev/null 2>&1; then
    echo "📝 Updating existing stack..."
    aws cloudformation update-stack \
        --stack-name "$STACK_NAME" \
        --template-body file://cloudformation-lambda.yaml \
        --parameters file://"$PARAMS_FILE" \
        --capabilities CAPABILITY_NAMED_IAM \
        --region "$REGION"
    
    echo "⏳ Waiting for stack update to complete..."
    aws cloudformation wait stack-update-complete \
        --stack-name "$STACK_NAME" \
        --region "$REGION"
else
    echo "🆕 Creating new stack..."
    aws cloudformation create-stack \
        --stack-name "$STACK_NAME" \
        --template-body file://cloudformation-lambda.yaml \
        --parameters file://"$PARAMS_FILE" \
        --capabilities CAPABILITY_NAMED_IAM \
        --region "$REGION"
    
    echo "⏳ Waiting for stack creation to complete..."
    aws cloudformation wait stack-create-complete \
        --stack-name "$STACK_NAME" \
        --region "$REGION"
fi

# Get stack outputs
echo ""
echo "📋 Stack Outputs:"
aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME" \
    --region "$REGION" \
    --query 'Stacks[0].Outputs[*].[OutputKey,OutputValue]' \
    --output table

echo ""
echo "✅ Deployment completed successfully!"
echo ""
echo "🔗 Useful commands:"
echo "  View logs: aws logs tail /aws/lambda/hive-print-service-${ENVIRONMENT} --follow"
echo "  Send test message: aws sqs send-message --queue-url \$(aws cloudformation describe-stacks --stack-name $STACK_NAME --query 'Stacks[0].Outputs[?OutputKey==\`SQSQueueURL\`].OutputValue' --output text) --message-body '{\"MessageId\":\"test\",\"MessageType\":\"GenerateImage\",\"Payload\":{\"ProductVariantId\":123,\"GenerateImages\":[]}}'"
echo "  Monitor DLQ: aws sqs get-queue-attributes --queue-url \$(aws cloudformation describe-stacks --stack-name $STACK_NAME --query 'Stacks[0].Outputs[?OutputKey==\`DLQQueueURL\`].OutputValue' --output text) --attribute-names ApproximateNumberOfMessages"
