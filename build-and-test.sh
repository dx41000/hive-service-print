#!/bin/bash

# Build and Test Script for Hive Service Print Lambda (Updated Version)

set -e

echo "🚀 Building Hive Service Print Lambda (Updated with PdfSharpCore)..."

# Change to project directory
cd "$(dirname "$0")/hive.service.print"

# Build the .NET project
echo "📦 Building .NET project..."
dotnet build -c Release

# Build Docker image
echo "🐳 Building Docker image..."
docker build -t hive-service-print:latest .

# Start the container for testing
echo "🔧 Starting Lambda container for testing..."
docker run -d --name hive-service-print-test -p 9000:8080 \
  -e AWS_REGION=eu-west-2 \
  -e CART_FILES_PATH=/tmp/cart/{printRequestId}/{productVariantId}/{productVariantViewId} \
  -e FONTS_PATH=/app/Fonts/ \
  -e DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1 \
  hive-service-print:latest

# Wait for container to start
echo "⏳ Waiting for container to start..."
sleep 15

# Test the Lambda function with sample SQS event
echo "🧪 Testing Lambda function..."
curl -XPOST "http://localhost:9000/2015-03-31/functions/function/invocations" \
  -H "Content-Type: application/json" \
  -d @sample-sqs-event.json

# Check container logs
echo "📋 Container logs:"
docker logs hive-service-print-test

# Cleanup
echo "🧹 Cleaning up test container..."
docker stop hive-service-print-test
docker rm hive-service-print-test

echo "✅ Build and test completed successfully!"
echo ""
echo "🔧 Key Changes in Updated Version:"
echo "- Uses PdfSharpCore instead of IronPDF"
echo "- Uses SixLabors.ImageSharp for image processing"
echo "- Maintains SkiaSharp for image overlaying"
echo "- No Chrome dependencies needed"
echo "- Lighter Docker image"
echo ""
echo "🚀 To deploy to AWS Lambda:"
echo "1. Tag the image: docker tag hive-service-print:latest YOUR_ECR_REPO:latest"
echo "2. Push to ECR: docker push YOUR_ECR_REPO:latest"
echo "3. Update Lambda function to use the new image"
echo ""
echo "🔧 To run locally with docker-compose:"
echo "docker-compose up -d"
