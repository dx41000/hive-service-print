# Existing SQS Queue and S3 Bucket Integration

This document explains how the CloudFormation template has been updated to use your existing SQS queues and S3 buckets instead of creating new ones.

## 🔄 **Changes Made**

### **Removed Resources**
- ❌ `PrintRequestQueue` - No longer creates new SQS queue
- ❌ `PrintRequestDLQ` - No longer creates dead letter queue
- ❌ `DLQMessageAlarm` - No longer monitors DLQ (since we don't create it)
- ❌ `PrintFilesBucket` - No longer creates new S3 bucket
- ❌ `PrintFilesBucketPolicy` - No longer creates S3 bucket policy
- ❌ `S3LogGroup` - No longer creates S3 log group

### **New Parameters Added**
- ✅ `ExistingSQSQueueUrl` - URL of your existing queue
- ✅ `ExistingSQSQueueArn` - ARN of your existing queue
- ✅ `ExistingS3BucketName` - Name of your existing S3 bucket

### **Updated Resources**
- 🔄 **Lambda IAM Role**: Now references existing queue ARN and S3 bucket
- 🔄 **Event Source Mapping**: Now connects to existing queue
- 🔄 **Lambda Environment Variables**: Uses existing queue URL and S3 bucket name
- 🔄 **CloudFormation Outputs**: Shows existing resource information

## 📋 **Your Existing Resources**

Based on the information provided:

### **SQS Queues**

#### **Production**
- **Queue URL**: `https://sqs.eu-west-2.amazonaws.com/891377085221/hive-print-order-queue-production`
- **Queue ARN**: `arn:aws:sqs:eu-west-2:891377085221:hive-print-order-queue-production`

#### **Development** (Assumed)
- **Queue URL**: `https://sqs.eu-west-2.amazonaws.com/891377085221/hive-print-order-queue-development`
- **Queue ARN**: `arn:aws:sqs:eu-west-2:891377085221:hive-print-order-queue-development`

#### **Staging** (Assumed)
- **Queue URL**: `https://sqs.eu-west-2.amazonaws.com/891377085221/hive-print-order-queue-staging`
- **Queue ARN**: `arn:aws:sqs:eu-west-2:891377085221:hive-print-order-queue-staging`

### **S3 Buckets**

#### **Production**
- **Bucket Name**: `hive-designer-production`

#### **Development** (Assumed)
- **Bucket Name**: `hive-designer-development`

#### **Staging** (Assumed)
- **Bucket Name**: `hive-designer-staging`

## 🔧 **Updated Parameter Files**

### **Development**
```json
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
}
```

### **Production**
```json
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
}
```

## 🚀 **Deployment Impact**

### **What Still Gets Created**
- ✅ Lambda function
- ✅ Result queue (for Lambda to send results)
- ✅ IAM roles and policies
- ✅ CloudWatch logs and alarms

### **What Uses Existing Resources**
- 🔗 Event Source Mapping connects to your existing SQS queue
- 🔗 Lambda receives messages from your existing SQS queue
- 🔗 Lambda stores PDFs in your existing S3 bucket
- 🔗 IAM permissions grant access to your existing SQS queue and S3 bucket

## ⚠️ **Important Considerations**

### **Queue Configuration**
Your existing queue should have:
- **Visibility Timeout**: Should be greater than Lambda timeout (recommend 960 seconds)
- **Message Retention**: Appropriate for your use case (default 14 days is good)
- **Dead Letter Queue**: Configure if you want failed message handling

### **Permissions**
The Lambda execution role will need permissions to:

**SQS Permissions:**
- `sqs:ReceiveMessage` on your existing queue
- `sqs:DeleteMessage` on your existing queue
- `sqs:GetQueueAttributes` on your existing queue
- `sqs:ChangeMessageVisibility` on your existing queue

**S3 Permissions:**
- `s3:GetObject` on your existing bucket
- `s3:PutObject` on your existing bucket
- `s3:DeleteObject` on your existing bucket
- `s3:ListBucket` on your existing bucket

### **Message Format**
Your existing queue should send messages in the expected format:
```json
{
  "MessageId": "unique-id",
  "MessageType": "GenerateImage",
  "Payload": {
    "ProductVariantId": 123,
    "GenerateImages": [
      {
        "ProductVariantViewId": 456,
        "PrintOrder": "json-string-or-null"
      }
    ]
  },
  "Timestamp": "2024-01-01T00:00:00Z",
  "CorrelationId": "optional-correlation-id"
}
```

## 🧪 **Testing**

### **Resource Verification**
Before deployment, verify your resources exist:

**SQS Queue:**
```bash
aws sqs get-queue-attributes \
    --queue-url "https://sqs.eu-west-2.amazonaws.com/891377085221/hive-print-order-queue-development" \
    --attribute-names All \
    --region eu-west-2
```

**S3 Bucket:**
```bash
aws s3 ls s3://hive-designer-development/ --region eu-west-2
```

### **Send Test Message**
After deployment, test with:
```bash
aws sqs send-message \
    --queue-url "https://sqs.eu-west-2.amazonaws.com/891377085221/hive-print-order-queue-development" \
    --message-body '{
        "MessageId": "test-123",
        "MessageType": "GenerateImage",
        "Payload": {
            "ProductVariantId": 123,
            "GenerateImages": []
        }
    }' \
    --region eu-west-2
```

## 📊 **Monitoring**

### **Lambda Metrics**
- Monitor Lambda invocations to ensure messages are being processed
- Check Lambda errors for any processing issues
- Monitor Lambda duration for performance

### **Queue Metrics**
- Monitor your existing queue's `ApproximateNumberOfMessages`
- Check `ApproximateAgeOfOldestMessage` for processing delays
- Monitor `NumberOfMessagesReceived` and `NumberOfMessagesDeleted`

### **S3 Metrics**
- Monitor your existing bucket's object count and size
- Check `PutObject` and `GetObject` operations
- Monitor storage costs and access patterns

### **CloudWatch Alarms**
The template still creates alarms for:
- Lambda errors (> 5 errors in 10 minutes)
- Lambda duration (> 10 minutes average)

## 🔄 **Migration Benefits**

### **Cost Savings**
- No additional SQS queue charges
- No additional S3 bucket charges
- Reuse existing infrastructure
- Simplified architecture

### **Operational Benefits**
- Single queue and bucket to monitor and manage
- Existing resource configurations preserved
- No data migration required
- Consolidated billing and monitoring

### **Integration Benefits**
- Works with existing message producers
- Uses existing S3 storage structure
- Maintains current data flow
- No changes needed to upstream systems

## 📝 **Next Steps**

1. **Verify Resource Names**: Confirm the development and staging resource names match the pattern
2. **Update Parameters**: Modify parameter files if resource names differ
3. **Check Permissions**: Ensure your existing resources have appropriate access policies
4. **Deploy**: Use the updated CloudFormation template
5. **Test**: Send test messages and verify S3 storage
6. **Monitor**: Watch CloudWatch metrics and logs for both SQS and S3

The integration is now ready to use your existing SQS and S3 infrastructure! 🎉
