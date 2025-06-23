#!/bin/bash

# Deployment script for CodePipeline infrastructure

set -e

# Default values
ENVIRONMENT="dev"
REGION="eu-west-2"
GITHUB_OWNER=""
GITHUB_REPO="hive-service-print"
GITHUB_TOKEN=""
AWS_PROFILE=""

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -e, --environment    Environment (dev, staging, prod) [default: dev]"
    echo "  -r, --region         AWS region [default: eu-west-2]"
    echo "  -o, --github-owner   GitHub repository owner/organization [required]"
    echo "  -g, --github-repo    GitHub repository name [default: hive-service-print]"
    echo "  -t, --github-token   GitHub personal access token [required]"
    echo "  -p, --profile        AWS profile to use"
    echo "  -h, --help           Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 -e dev -o myorg -t ghp_xxxxxxxxxxxx"
    echo "  $0 -e prod -o myorg -t ghp_xxxxxxxxxxxx -p production"
    echo ""
    echo "Prerequisites:"
    echo "  1. GitHub Personal Access Token with repo permissions"
    echo "  2. AWS CLI configured with appropriate permissions"
    echo "  3. Repository pushed to GitHub"
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
        -o|--github-owner)
            GITHUB_OWNER="$2"
            shift 2
            ;;
        -g|--github-repo)
            GITHUB_REPO="$2"
            shift 2
            ;;
        -t|--github-token)
            GITHUB_TOKEN="$2"
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

# Validate required parameters
if [ -z "$GITHUB_OWNER" ]; then
    echo "❌ GitHub owner is required"
    show_usage
    exit 1
fi

if [ -z "$GITHUB_TOKEN" ]; then
    echo "❌ GitHub token is required"
    show_usage
    exit 1
fi

# Set AWS profile if provided
if [ -n "$AWS_PROFILE" ]; then
    export AWS_PROFILE="$AWS_PROFILE"
fi

STACK_NAME="hive-pipeline-${ENVIRONMENT}"
PARAMS_FILE="codepipeline-parameters-${ENVIRONMENT}.json"

echo "🚀 Deploying CodePipeline Infrastructure"
echo "Environment: $ENVIRONMENT"
echo "Region: $REGION"
echo "Stack Name: $STACK_NAME"
echo "GitHub Owner: $GITHUB_OWNER"
echo "GitHub Repo: $GITHUB_REPO"
if [ -n "$AWS_PROFILE" ]; then
    echo "AWS Profile: $AWS_PROFILE"
fi
echo ""

# Get AWS Account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "AWS Account ID: $ACCOUNT_ID"
echo ""

# Create or update parameters file
echo "📝 Creating/updating parameters file..."
cat > "$PARAMS_FILE" << EOF
[
  {
    "ParameterKey": "GitHubOwner",
    "ParameterValue": "$GITHUB_OWNER"
  },
  {
    "ParameterKey": "GitHubRepo",
    "ParameterValue": "$GITHUB_REPO"
  },
  {
    "ParameterKey": "GitHubBranch",
    "ParameterValue": "$([ "$ENVIRONMENT" = "prod" ] && echo "main" || echo "develop")"
  },
  {
    "ParameterKey": "GitHubToken",
    "ParameterValue": "$GITHUB_TOKEN"
  },
  {
    "ParameterKey": "ECRRepositoryName",
    "ParameterValue": "hive-service-print"
  },
  {
    "ParameterKey": "Environment",
    "ParameterValue": "$ENVIRONMENT"
  }
]
EOF

echo "✅ Parameters file created: $PARAMS_FILE"

# Validate CloudFormation template
echo ""
echo "✅ Validating CloudFormation template..."
aws cloudformation validate-template \
    --template-body file://codepipeline-infrastructure.yaml \
    --region "$REGION"

# Deploy CloudFormation stack
echo ""
echo "🚀 Deploying CodePipeline infrastructure..."

# Check if stack exists
if aws cloudformation describe-stacks --stack-name "$STACK_NAME" --region "$REGION" >/dev/null 2>&1; then
    echo "📝 Updating existing stack..."
    aws cloudformation update-stack \
        --stack-name "$STACK_NAME" \
        --template-body file://codepipeline-infrastructure.yaml \
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
        --template-body file://codepipeline-infrastructure.yaml \
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
echo "📋 Pipeline Infrastructure Outputs:"
aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME" \
    --region "$REGION" \
    --query 'Stacks[0].Outputs[*].[OutputKey,OutputValue]' \
    --output table

# Get pipeline status
PIPELINE_NAME=$(aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME" \
    --region "$REGION" \
    --query 'Stacks[0].Outputs[?OutputKey==`PipelineName`].OutputValue' \
    --output text)

echo ""
echo "📊 Pipeline Status:"
aws codepipeline get-pipeline-state \
    --name "$PIPELINE_NAME" \
    --region "$REGION" \
    --query 'stageStates[*].[stageName,latestExecution.status]' \
    --output table

echo ""
echo "✅ CodePipeline deployment completed successfully!"
echo ""
echo "🔗 Next Steps:"
echo "1. Push your code to the GitHub repository"
echo "2. The pipeline will automatically trigger on push to the configured branch"
echo "3. Monitor the pipeline execution in the AWS Console"
echo ""
echo "🔧 Useful Commands:"
echo "  View pipeline: aws codepipeline get-pipeline --name $PIPELINE_NAME --region $REGION"
echo "  Start pipeline: aws codepipeline start-pipeline-execution --name $PIPELINE_NAME --region $REGION"
echo "  View executions: aws codepipeline list-pipeline-executions --pipeline-name $PIPELINE_NAME --region $REGION"
echo ""
echo "🌐 AWS Console Links:"
echo "  Pipeline: https://${REGION}.console.aws.amazon.com/codesuite/codepipeline/pipelines/${PIPELINE_NAME}/view"
echo "  CodeBuild: https://${REGION}.console.aws.amazon.com/codesuite/codebuild/projects"
echo "  ECR: https://${REGION}.console.aws.amazon.com/ecr/repositories"
