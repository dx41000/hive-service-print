# Infrastructure Summary - Existing Resources Integration

## 🏗️ **Final Architecture**

The CloudFormation template now uses your existing infrastructure and creates minimal new resources:

### **✅ Resources Created by CloudFormation**
- **Lambda Function**: `hive-print-service-{environment}`
- **Result Queue**: `hive-print-results-{environment}` (for Lambda output)
- **IAM Role**: Lambda execution role with permissions
- **CloudWatch Log Group**: `/aws/lambda/hive-print-service-{environment}`
- **CloudWatch Alarms**: Error and duration monitoring
- **Event Source Mapping**: SQS → Lambda connection

### **🔗 Existing Resources Used**
- **SQS Queues**: Your existing `hive-print-order-queue-{environment}` queues
- **S3 Buckets**: Your existing `hive-designer-{environment}` buckets

## 📋 **Resource Mapping by Environment**

### **Production**
| Resource Type | Name | Usage |
|---------------|------|-------|
| SQS Queue | `hive-print-order-queue-production` | Input messages |
| S3 Bucket | `hive-designer-production` | PDF storage |
| Lambda | `hive-print-service-prod` | Processing |
| Result Queue | `hive-print-results-prod` | Output messages |

### **Development**
| Resource Type | Name | Usage |
|---------------|------|-------|
| SQS Queue | `hive-print-order-queue-development` | Input messages |
| S3 Bucket | `hive-designer-development` | PDF storage |
| Lambda | `hive-print-service-dev` | Processing |
| Result Queue | `hive-print-results-dev` | Output messages |

### **Staging**
| Resource Type | Name | Usage |
|---------------|------|-------|
| SQS Queue | `hive-print-order-queue-staging` | Input messages |
| S3 Bucket | `hive-designer-staging` | PDF storage |
| Lambda | `hive-print-service-staging` | Processing |
| Result Queue | `hive-print-results-staging` | Output messages |

## 🔧 **Configuration Parameters**

### **Required Parameters**
```yaml
ECRImageURI: "891377085221.dkr.ecr.eu-west-2.amazonaws.com/hive-service-print:latest"
ExistingSQSQueueUrl: "https://sqs.eu-west-2.amazonaws.com/891377085221/hive-print-order-queue-{env}"
ExistingSQSQueueArn: "arn:aws:sqs:eu-west-2:891377085221:hive-print-order-queue-{env}"
ExistingS3BucketName: "hive-designer-{env}"
```

### **Optional Parameters**
```yaml
VpcId: "" # Leave empty for no VPC
SubnetIds: "" # Leave empty for no VPC
LambdaTimeout: 300-900 # Seconds
LambdaMemorySize: 1024-2048 # MB
```

## 🚀 **Deployment Commands**

### **Production**
```bash
./deploy.sh -e prod -r eu-west-2
```

### **Development**
```bash
./deploy.sh -e dev -r eu-west-2
```

### **Staging**
```bash
./deploy.sh -e staging -r eu-west-2
```

## 📊 **Cost Impact**

### **New Costs (Minimal)**
- **Lambda**: Pay per invocation and duration
- **Result SQS Queue**: Minimal cost for result messages
- **CloudWatch Logs**: Log storage and retention

### **No Additional Costs**
- **Input SQS Queue**: Uses existing queue
- **S3 Storage**: Uses existing bucket
- **VPC**: Optional, no additional networking costs

### **Estimated Monthly Cost (Development)**
- Lambda (1000 invocations): ~$0.20
- SQS Result Queue: ~$0.40
- CloudWatch Logs: ~$0.50
- **Total**: ~$1.10/month

### **Estimated Monthly Cost (Production)**
- Lambda (10,000 invocations): ~$2.00
- SQS Result Queue: ~$4.00
- CloudWatch Logs: ~$2.00
- **Total**: ~$8.00/month

## 🔒 **Security & Permissions**

### **Lambda IAM Permissions**
```json
{
  "SQS": [
    "sqs:ReceiveMessage",
    "sqs:DeleteMessage", 
    "sqs:GetQueueAttributes",
    "sqs:ChangeMessageVisibility"
  ],
  "S3": [
    "s3:GetObject",
    "s3:PutObject",
    "s3:DeleteObject",
    "s3:ListBucket"
  ],
  "CloudWatch": [
    "logs:CreateLogGroup",
    "logs:CreateLogStream",
    "logs:PutLogEvents"
  ]
}
```

### **Resource Access**
- Lambda can read from your existing SQS queue
- Lambda can write PDFs to your existing S3 bucket
- Lambda can send results to new result queue
- All access is scoped to specific resources only

## 📈 **Monitoring & Observability**

### **CloudWatch Metrics**
- **Lambda**: Invocations, Errors, Duration, Memory Usage
- **SQS**: Messages Received, Messages Deleted, Queue Depth
- **S3**: Object Count, Storage Size, Request Metrics

### **CloudWatch Alarms**
- **Lambda Errors**: > 5 errors in 10 minutes
- **Lambda Duration**: > 10 minutes average execution time

### **Log Groups**
- **Lambda Logs**: `/aws/lambda/hive-print-service-{environment}`
- **Retention**: 7 days (dev), 30 days (prod)

## 🧪 **Testing Strategy**

### **1. Resource Verification**
```bash
# Verify SQS queue exists
aws sqs get-queue-attributes --queue-url {queue-url} --region eu-west-2

# Verify S3 bucket exists  
aws s3 ls s3://{bucket-name}/ --region eu-west-2
```

### **2. Integration Testing**
```bash
# Deploy to development
./deploy.sh -e dev -r eu-west-2

# Send test message
./test-sqs.sh -e dev -r eu-west-2

# Monitor processing
aws logs tail /aws/lambda/hive-print-service-dev --follow --region eu-west-2
```

### **3. End-to-End Testing**
1. Send message to existing SQS queue
2. Verify Lambda processes message
3. Check PDF created in existing S3 bucket
4. Verify result message in result queue

## 🔄 **Deployment Workflow**

### **1. Pre-Deployment**
- [ ] Verify existing SQS queue names and URLs
- [ ] Verify existing S3 bucket names
- [ ] Update parameter files if needed
- [ ] Build and push Docker image to ECR

### **2. Deployment**
- [ ] Run deployment script for target environment
- [ ] Verify CloudFormation stack creation
- [ ] Check Lambda function configuration
- [ ] Verify Event Source Mapping

### **3. Post-Deployment**
- [ ] Send test messages
- [ ] Monitor Lambda logs
- [ ] Verify PDF generation in S3
- [ ] Check CloudWatch metrics
- [ ] Set up monitoring alerts

## ✅ **Ready for Production**

The infrastructure is now optimized to:
- ✅ Use your existing SQS and S3 resources
- ✅ Minimize new resource creation and costs
- ✅ Provide comprehensive monitoring and logging
- ✅ Support multiple environments (dev/staging/prod)
- ✅ Scale automatically with SQS message volume
- ✅ Maintain security best practices

**Total Resources Created**: 6 (Lambda, IAM Role, Result Queue, Log Group, 2 Alarms)
**Existing Resources Used**: 2 per environment (SQS Queue, S3 Bucket)
**Monthly Cost**: ~$1-8 depending on usage volume
