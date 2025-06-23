#!/bin/bash

# Multi-environment pipeline setup script

set -e

GITHUB_OWNER=""
GITHUB_TOKEN=""
REGION="eu-west-2"
AWS_PROFILE=""

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "This script sets up CodePipelines for all environments (dev, staging, prod)"
    echo ""
    echo "Options:"
    echo "  -o, --github-owner   GitHub repository owner/organization [required]"
    echo "  -t, --github-token   GitHub personal access token [required]"
    echo "  -r, --region         AWS region [default: eu-west-2]"
    echo "  -p, --profile        AWS profile to use"
    echo "  -h, --help           Show this help message"
    echo ""
    echo "Example:"
    echo "  $0 -o myorg -t ghp_xxxxxxxxxxxx"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -o|--github-owner)
            GITHUB_OWNER="$2"
            shift 2
            ;;
        -t|--github-token)
            GITHUB_TOKEN="$2"
            shift 2
            ;;
        -r|--region)
            REGION="$2"
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
if [ -z "$GITHUB_OWNER" ] || [ -z "$GITHUB_TOKEN" ]; then
    echo "❌ GitHub owner and token are required"
    show_usage
    exit 1
fi

# Set AWS profile if provided
if [ -n "$AWS_PROFILE" ]; then
    export AWS_PROFILE="$AWS_PROFILE"
fi

echo "🚀 Setting up Multi-Environment CodePipeline Infrastructure"
echo "GitHub Owner: $GITHUB_OWNER"
echo "Region: $REGION"
if [ -n "$AWS_PROFILE" ]; then
    echo "AWS Profile: $AWS_PROFILE"
fi
echo ""

# Deploy development pipeline
echo "📦 Deploying Development Pipeline..."
./deploy-pipeline.sh -e dev -r "$REGION" -o "$GITHUB_OWNER" -t "$GITHUB_TOKEN" $([ -n "$AWS_PROFILE" ] && echo "-p $AWS_PROFILE")

echo ""
echo "⏳ Waiting 30 seconds before next deployment..."
sleep 30

# Deploy staging pipeline
echo "📦 Deploying Staging Pipeline..."
./deploy-pipeline.sh -e staging -r "$REGION" -o "$GITHUB_OWNER" -t "$GITHUB_TOKEN" $([ -n "$AWS_PROFILE" ] && echo "-p $AWS_PROFILE")

echo ""
echo "⏳ Waiting 30 seconds before next deployment..."
sleep 30

# Deploy production pipeline
echo "📦 Deploying Production Pipeline..."
./deploy-pipeline.sh -e prod -r "$REGION" -o "$GITHUB_OWNER" -t "$GITHUB_TOKEN" $([ -n "$AWS_PROFILE" ] && echo "-p $AWS_PROFILE")

echo ""
echo "✅ All pipelines deployed successfully!"
echo ""
echo "📋 Summary:"
echo "  - Development Pipeline: Triggers on 'develop' branch"
echo "  - Staging Pipeline: Triggers on 'staging' branch"  
echo "  - Production Pipeline: Triggers on 'main' branch"
echo ""
echo "🔗 AWS Console:"
echo "  Pipelines: https://${REGION}.console.aws.amazon.com/codesuite/codepipeline/pipelines"
echo ""
echo "📝 Next Steps:"
echo "1. Create and push to the appropriate branches in your GitHub repository"
echo "2. Pipelines will automatically trigger on code changes"
echo "3. Monitor deployments in the AWS Console"
