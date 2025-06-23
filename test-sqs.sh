#!/bin/bash

# Test script to send messages to the SQS queue

set -e

# Default values
ENVIRONMENT="dev"
REGION="eu-west-2"
STACK_NAME=""
AWS_PROFILE=""

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -e, --environment    Environment (dev, staging, prod) [default: dev]"
    echo "  -r, --region         AWS region [default: eu-west-2]"
    echo "  -s, --stack-name     CloudFormation stack name [default: hive-print-{environment}]"
    echo "  -p, --profile        AWS profile to use"
    echo "  -h, --help           Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 -e dev"
    echo "  $0 -e prod -r eu-west-1 -p production"
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

# Set AWS profile if provided
if [ -n "$AWS_PROFILE" ]; then
    export AWS_PROFILE="$AWS_PROFILE"
fi

echo "🧪 Testing Hive Service Print Lambda"
echo "Environment: $ENVIRONMENT"
echo "Region: $REGION"
echo "Stack Name: $STACK_NAME"
echo ""

# Get SQS Queue URL from CloudFormation stack
echo "🔍 Getting SQS Queue URL..."
QUEUE_URL=$(aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME" \
    --region "$REGION" \
    --query 'Stacks[0].Outputs[?OutputKey==`ExistingSQSQueueURL`].OutputValue' \
    --output text)

if [ -z "$QUEUE_URL" ]; then
    echo "❌ Could not find SQS Queue URL in stack outputs, using existing queue directly"
    QUEUE_URL="https://sqs.eu-west-2.amazonaws.com/891377085221/hive-print-order-queue-${ENVIRONMENT}"
fi

echo "Queue URL: $QUEUE_URL"
echo ""

# Test Message 1: GenerateImage
echo "📤 Sending GenerateImage test message..."
MESSAGE_1='{
  "MessageId": "test-generate-'$(date +%s)'",
  "MessageType": "GenerateImage",
  "Payload": {
    "ProductVariantId": 123,
    "GenerateImages": [
      {
        "ProductVariantViewId": 456,
        "PrintOrder": "{\"svg_data\":[{\"svg\":\"<svg width=\"200\" height=\"200\"><rect width=\"200\" height=\"200\" fill=\"blue\"/></svg>\"}],\"used_fonts\":[{\"name\":\"Arial\"}]}"
      }
    ]
  },
  "Timestamp": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'",
  "CorrelationId": "test-correlation-1"
}'

aws sqs send-message \
    --queue-url "$QUEUE_URL" \
    --message-body "$MESSAGE_1" \
    --region "$REGION"

echo "✅ GenerateImage message sent"

# Test Message 2: GetImage
echo "📤 Sending GetImage test message..."
MESSAGE_2='{
  "MessageId": "test-get-'$(date +%s)'",
  "MessageType": "GetImage",
  "Payload": {
    "ProductVariantId": 789,
    "GenerateImages": []
  },
  "Timestamp": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'",
  "CorrelationId": "test-correlation-2"
}'

aws sqs send-message \
    --queue-url "$QUEUE_URL" \
    --message-body "$MESSAGE_2" \
    --region "$REGION"

echo "✅ GetImage message sent"
echo ""

# Monitor the queue
echo "📊 Queue status:"
aws sqs get-queue-attributes \
    --queue-url "$QUEUE_URL" \
    --attribute-names ApproximateNumberOfMessages,ApproximateNumberOfMessagesNotVisible \
    --region "$REGION" \
    --query 'Attributes' \
    --output table

echo ""
echo "🔍 Monitoring Lambda logs (press Ctrl+C to stop)..."
echo "You can also run: aws logs tail /aws/lambda/hive-print-service-${ENVIRONMENT} --follow --region ${REGION}"

# Tail Lambda logs
aws logs tail "/aws/lambda/hive-print-service-${ENVIRONMENT}" \
    --follow \
    --region "$REGION" \
    --since 1m
