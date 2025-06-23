# Hive Service Print Lambda - Deployment Guide

This guide covers the complete deployment process for the Hive Service Print Lambda function using AWS CloudFormation.

## 📋 **Prerequisites**

### **Required Tools**
- AWS CLI v2 configured with appropriate credentials
- Docker installed and running
- jq (for JSON processing in scripts)
- Bash shell (Linux/macOS/WSL)

### **AWS Permissions Required**
Your AWS user/role needs the following permissions:
- CloudFormation: Full access
- Lambda: Full access
- SQS: Full access
- S3: Full access
- IAM: Create/manage roles and policies
- ECR: Full access
- CloudWatch: Logs and metrics access

## 🏗️ **Architecture Overview**

The CloudFormation template creates:

### **Core Resources**
- **Lambda Function**: Container-based .NET 8 function
- **Result Queue**: For processing results (new SQS queue)

### **Existing Resources Used**
- **SQS Queue**: Uses your existing `hive-print-order-queue-{environment}` queue
- **S3 Bucket**: Uses your existing `hive-designer-{environment}` bucket
- **Event Source Mapping**: Connects existing SQS queue to Lambda

### **Supporting Resources**
- **IAM Role**: Lambda execution role with necessary permissions
- **CloudWatch Log Groups**: For Lambda and S3 logging
- **CloudWatch Alarms**: For monitoring errors and performance
- **SNS Topic**: For alerts (optional)
- **Lambda Alias**: For blue/green deployments

### **Optional Resources**
- **VPC Configuration**: If Lambda needs VPC access
- **Security Groups**: For VPC-based deployments

## 🚀 **Quick Deployment**

### **1. Basic Deployment (Development)**
```bash
# Deploy to development environment
./deploy.sh -e dev -r eu-west-2

# Or with custom ECR repository name
./deploy.sh -e dev -r eu-west-2 -i my-hive-print-repo
```

### **2. Production Deployment**
```bash
# Deploy to production with VPC (update parameters file first)
./deploy.sh -e prod -r eu-west-2 -p production-profile
```

### **3. Custom Deployment**
```bash
# Deploy with custom stack name and region
./deploy.sh -e staging -r eu-west-1 -s my-hive-print-stack
```

## 📝 **Step-by-Step Deployment**

### **Step 1: Prepare Parameters**

Edit the parameters file for your environment:

**For Development (`cloudformation-parameters-dev.json`):**
```json
[
  {
    "ParameterKey": "Environment",
    "ParameterValue": "dev"
  },
  {
    "ParameterKey": "ECRImageURI",
    "ParameterValue": "891377085221.dkr.ecr.eu-west-2.amazonaws.com/hive-service-print:latest"
  },
  {
    "ParameterKey": "ExistingSQSQueueUrl",
    "ParameterValue": "https://sqs.eu-west-2.amazonaws.com/891377085221/hive-print-order-queue-development"
  },
  {
    "ParameterKey": "ExistingSQSQueueArn",
    "ParameterValue": "arn:aws:sqs:eu-west-2:891377085221:hive-print-order-queue-development"
  },
  {
    "ParameterKey": "ExistingS3BucketName",
    "ParameterValue": "hive-designer-development"
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
```

**For Production (`cloudformation-parameters-prod.json`):**
```json
[
  {
    "ParameterKey": "Environment",
    "ParameterValue": "prod"
  },
  {
    "ParameterKey": "ECRImageURI",
    "ParameterValue": "891377085221.dkr.ecr.eu-west-2.amazonaws.com/hive-service-print:latest"
  },
  {
    "ParameterKey": "ExistingSQSQueueUrl",
    "ParameterValue": "https://sqs.eu-west-2.amazonaws.com/891377085221/hive-print-order-queue-production"
  },
  {
    "ParameterKey": "ExistingSQSQueueArn",
    "ParameterValue": "arn:aws:sqs:eu-west-2:891377085221:hive-print-order-queue-production"
  },
  {
    "ParameterKey": "ExistingS3BucketName",
    "ParameterValue": "hive-designer-production"
  },
  {
    "ParameterKey": "VpcId",
    "ParameterValue": "vpc-12345678"
  },
  {
    "ParameterKey": "SubnetIds",
    "ParameterValue": "subnet-12345678,subnet-87654321"
  },
  {
    "ParameterKey": "LambdaTimeout",
    "ParameterValue": "900"
  },
  {
    "ParameterKey": "LambdaMemorySize",
    "ParameterValue": "2048"
  }
]
```

### **Step 2: Run Deployment Script**

The deployment script will:
1. Create ECR repository if it doesn't exist
2. Build and push Docker image
3. Update parameters with correct ECR URI
4. Validate CloudFormation template
5. Deploy/update the stack
6. Display stack outputs

```bash
./deploy.sh -e dev -r eu-west-2
```

### **Step 3: Verify Deployment**

Check the stack outputs:
```bash
aws cloudformation describe-stacks \
    --stack-name hive-print-dev \
    --query 'Stacks[0].Outputs[*].[OutputKey,OutputValue]' \
    --output table
```

## 🧪 **Testing the Deployment**

### **1. Send Test Messages**
```bash
# Send test messages to SQS queue
./test-sqs.sh -e dev -r eu-west-2
```

### **2. Monitor Lambda Logs**
```bash
# Tail Lambda logs
aws logs tail /aws/lambda/hive-print-service-dev --follow
```

### **3. Check Queue Status**
```bash
# Get queue attributes
aws sqs get-queue-attributes \
    --queue-url $(aws cloudformation describe-stacks --stack-name hive-print-dev --query 'Stacks[0].Outputs[?OutputKey==`SQSQueueURL`].OutputValue' --output text) \
    --attribute-names ApproximateNumberOfMessages,ApproximateNumberOfMessagesNotVisible
```

### **4. Manual Test Message**
```bash
# Send a manual test message
QUEUE_URL=$(aws cloudformation describe-stacks --stack-name hive-print-dev --query 'Stacks[0].Outputs[?OutputKey==`SQSQueueURL`].OutputValue' --output text)

aws sqs send-message \
    --queue-url "$QUEUE_URL" \
    --message-body '{
        "MessageId": "manual-test-123",
        "MessageType": "GenerateImage",
        "Payload": {
            "ProductVariantId": 123,
            "GenerateImages": [
                {
                    "ProductVariantViewId": 456,
                    "PrintOrder": null
                }
            ]
        },
        "Timestamp": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"
    }'
```

## 📊 **Monitoring and Observability**

### **CloudWatch Dashboards**
The deployment creates several CloudWatch alarms:
- **Lambda Errors**: Triggers when error count exceeds threshold
- **Lambda Duration**: Triggers when execution time is too long
- **DLQ Messages**: Triggers when messages appear in dead letter queue

### **Key Metrics to Monitor**
- Lambda invocations and errors
- Lambda duration and memory usage
- SQS queue depth and message age
- S3 bucket object count and size

### **Log Groups Created**
- `/aws/lambda/hive-print-service-{environment}`
- `/aws/s3/hive-print-files-{environment}`

## 🔧 **Configuration Options**

### **Lambda Configuration**
| Parameter | Development | Production | Description |
|-----------|-------------|------------|-------------|
| Memory | 1024 MB | 2048 MB | Lambda memory allocation |
| Timeout | 5 minutes | 15 minutes | Maximum execution time |
| Concurrency | 10 | 100 | Reserved concurrency limit |

### **SQS Configuration**
| Setting | Value | Description |
|---------|-------|-------------|
| Visibility Timeout | 960s | Should be > Lambda timeout |
| Message Retention | 14 days | How long messages are kept |
| Batch Size | 10 | Messages per Lambda invocation |
| Max Receive Count | 3 | Retries before DLQ |

### **S3 Configuration**
- **Versioning**: Enabled
- **Public Access**: Blocked
- **Lifecycle**: Delete old versions after 30 days
- **Encryption**: AES256

## 🔄 **Updates and Rollbacks**

### **Updating the Lambda Function**
1. Build new Docker image
2. Push to ECR with new tag
3. Update parameters file with new image URI
4. Run deployment script

```bash
# Update with new image
./deploy.sh -e prod -r us-east-1
```

### **Rolling Back**
```bash
# Rollback to previous stack version
aws cloudformation cancel-update-stack --stack-name hive-print-prod

# Or deploy with previous image URI
# Update parameters file and redeploy
```

### **Blue/Green Deployment**
The template creates Lambda aliases for blue/green deployments:
```bash
# Update alias to point to new version
aws lambda update-alias \
    --function-name hive-print-service-prod \
    --name prod \
    --function-version $NEW_VERSION
```

## 🚨 **Troubleshooting**

### **Common Issues**

#### **1. ECR Authentication Failed**
```bash
# Re-authenticate with ECR
aws ecr get-login-password --region eu-west-2 | docker login --username AWS --password-stdin 891377085221.dkr.ecr.eu-west-2.amazonaws.com
```

#### **2. Lambda Function Not Triggered**
- Check SQS event source mapping
- Verify Lambda execution role permissions
- Check CloudWatch logs for errors

#### **3. PDF Generation Fails**
- Check Lambda memory allocation
- Verify timeout settings
- Check for missing fonts or dependencies

#### **4. S3 Access Denied**
- Verify S3 bucket policy
- Check Lambda execution role permissions
- Ensure bucket exists and is accessible

### **Debugging Commands**
```bash
# Check Lambda function configuration
aws lambda get-function --function-name hive-print-service-dev

# Check SQS queue attributes
aws sqs get-queue-attributes --queue-url $QUEUE_URL --attribute-names All

# Check S3 bucket policy
aws s3api get-bucket-policy --bucket hive-print-files-dev-123456789012

# View recent Lambda logs
aws logs filter-log-events --log-group-name /aws/lambda/hive-print-service-dev --start-time $(date -d '1 hour ago' +%s)000
```

## 🔒 **Security Considerations**

### **IAM Permissions**
- Lambda execution role follows least privilege principle
- S3 bucket blocks public access
- SQS queues are not publicly accessible

### **VPC Configuration**
For production deployments in VPC:
- Use private subnets for Lambda
- Ensure NAT Gateway for internet access
- Configure security groups appropriately

### **Encryption**
- S3 bucket uses AES256 encryption
- SQS messages can be encrypted (configure if needed)
- Lambda environment variables are encrypted

## 📈 **Cost Optimization**

### **Development Environment**
- Lower memory allocation (1024 MB)
- Shorter log retention (7 days)
- Lower reserved concurrency (10)

### **Production Environment**
- Right-size memory based on actual usage
- Monitor and adjust timeout settings
- Use S3 lifecycle policies for old files

### **Cost Monitoring**
- Set up billing alerts
- Monitor Lambda costs by function
- Track S3 storage costs

## 📞 **Support**

### **Stack Outputs**
After deployment, the stack provides these outputs:
- **LambdaFunctionArn**: ARN of the Lambda function
- **SQSQueueURL**: URL of the input queue
- **DLQQueueURL**: URL of the dead letter queue
- **S3BucketName**: Name of the storage bucket

### **Useful Commands**
```bash
# Get all stack outputs
aws cloudformation describe-stacks --stack-name hive-print-dev --query 'Stacks[0].Outputs'

# Delete stack (careful!)
aws cloudformation delete-stack --stack-name hive-print-dev

# View stack events
aws cloudformation describe-stack-events --stack-name hive-print-dev
```

Your Lambda function is now ready for production use with comprehensive monitoring, error handling, and scalability features!
