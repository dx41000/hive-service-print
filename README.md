# Hive Service Print - AWS Lambda Function

This is a .NET 8 AWS Lambda function that processes print-ready image generation requests from SQS messages instead of HTTP calls. It's designed to run in a Docker container with IronPDF.Linux support.

## 🏗️ **Architecture**

- **Input**: SQS messages containing `GenerateImageRequest` payloads
- **Processing**: PDF generation using IronPDF.Linux with optimized memory management
- **Output**: Generated PDFs and thumbnails (can be saved to S3, database, or sent to result queue)
- **Runtime**: .NET 8 in AWS Lambda Container Image

## 📦 **Project Structure**

```
hive-service-print/
├── hive.service.print/
│   ├── Configuration/
│   │   └── ServiceConfiguration.cs
│   ├── Models/
│   │   ├── PrintReady/
│   │   │   ├── GenerateImageRequest.cs
│   │   │   ├── GenerateImageResponse.cs
│   │   │   ├── View.cs
│   │   │   └── DesignerOutput.cs
│   │   ├── SqsMessage/
│   │   │   └── PrintReadyMessage.cs
│   │   └── ArtWork.cs
│   ├── Services/
│   │   ├── IPrintReadyService.cs
│   │   └── PrintReadyService.cs
│   ├── Function.cs
│   ├── Dockerfile
│   ├── appsettings.json
│   └── hive.service.print.csproj
├── hive-service-print.sln
└── README.md
```

## 🚀 **Key Features**

### **SQS Message Processing**
- Processes multiple SQS messages concurrently
- Handles different message types (`GenerateImage`, `GetImage`)
- Comprehensive error handling and logging
- Retry mechanism through SQS

### **PDF Generation**
- IronPDF.Linux for containerized environments
- Memory-optimized image processing with SkiaSharp
- Support for image scaling and resizing
- HTML-to-PDF conversion for precise control

### **Docker Container Support**
- Google Chrome installation for IronPDF
- Optimized for AWS Lambda Container Images
- Environment variable configuration
- Security hardening

## 📋 **SQS Message Format**

### **Input Message Structure**
```json
{
  "MessageId": "unique-message-id",
  "MessageType": "GenerateImage",
  "Payload": {
    "ProductVariantId": 123,
    "GenerateImages": [
      {
        "ProductVariantViewId": 456,
        "PrintOrder": "{\"svg_data\":[{\"svg\":\"...\"}],\"used_fonts\":[{\"name\":\"Arial\"}]}"
      }
    ]
  },
  "Timestamp": "2024-01-01T00:00:00Z",
  "CorrelationId": "optional-correlation-id",
  "RetryCount": 0
}
```

### **Message Types**
- `GenerateImage`: Generate PDF from image data
- `GetImage`: Retrieve existing non-customizable image

## 🔧 **Environment Variables**

| Variable | Description | Default |
|----------|-------------|---------|
| `CART_FILES_PATH` | Path template for cart files | `/tmp/cart/{printRequestId}/{productVariantId}/{productVariantViewId}` |
| `FONTS_PATH` | Path to fonts directory | `/app/Fonts/` |
| `AWS_REGION` | AWS region | `us-east-1` |
| `S3_BUCKET_NAME` | S3 bucket for storing results | `` |
| `SQS_QUEUE_URL` | SQS queue URL for input messages | `` |
| `RESULT_QUEUE_URL` | SQS queue URL for result messages | `` |
| `IRONPDF_LICENSE_KEY` | IronPDF license key (optional) | `` |
| `CHROME_BIN` | Chrome binary path | `/usr/bin/google-chrome` |
| `CHROME_PATH` | Chrome path | `/usr/bin/google-chrome` |
| `DISPLAY` | Display for headless Chrome | `:99` |

## 🐳 **Building and Deployment**

### **Local Development**
```bash
# Build the project
cd /mnt/c/Code/dx41000/hive-service-print/hive.service.print
dotnet build

# Run tests (if you add them)
dotnet test
```

### **Docker Build**
```bash
# Build the Docker image
docker build -t hive-service-print .

# Test locally with Lambda Runtime Interface Emulator
docker run -p 9000:8080 hive-service-print

# Test with sample SQS event
curl -XPOST "http://localhost:9000/2015-03-31/functions/function/invocations" \
  -d @sample-sqs-event.json
```

### **AWS Lambda Deployment**
```bash
# Tag for ECR
docker tag hive-service-print:latest 123456789012.dkr.ecr.us-east-1.amazonaws.com/hive-service-print:latest

# Push to ECR
docker push 123456789012.dkr.ecr.us-east-1.amazonaws.com/hive-service-print:latest

# Deploy Lambda function using AWS CLI or CDK/CloudFormation
aws lambda create-function \
  --function-name hive-service-print \
  --package-type Image \
  --code ImageUri=123456789012.dkr.ecr.us-east-1.amazonaws.com/hive-service-print:latest \
  --role arn:aws:iam::123456789012:role/lambda-execution-role \
  --timeout 900 \
  --memory-size 2048
```

## 🔍 **Testing**

### **Sample SQS Event**
Create `sample-sqs-event.json`:
```json
{
  "Records": [
    {
      "messageId": "test-message-1",
      "receiptHandle": "test-receipt-handle",
      "body": "{\"MessageId\":\"test-msg-1\",\"MessageType\":\"GenerateImage\",\"Payload\":{\"ProductVariantId\":123,\"GenerateImages\":[{\"ProductVariantViewId\":456,\"PrintOrder\":null}]},\"Timestamp\":\"2024-01-01T00:00:00Z\"}",
      "attributes": {
        "ApproximateReceiveCount": "1",
        "SentTimestamp": "1640995200000",
        "SenderId": "123456789012",
        "ApproximateFirstReceiveTimestamp": "1640995200000"
      },
      "messageAttributes": {},
      "md5OfBody": "test-md5",
      "eventSource": "aws:sqs",
      "eventSourceARN": "arn:aws:sqs:us-east-1:123456789012:test-queue",
      "awsRegion": "us-east-1"
    }
  ]
}
```

### **Local Testing**
```bash
# Test the function locally
curl -XPOST "http://localhost:9000/2015-03-31/functions/function/invocations" \
  -d @sample-sqs-event.json
```

## 📊 **Performance Considerations**

### **Memory Configuration**
- **Minimum**: 1GB for basic PDF generation
- **Recommended**: 2GB for optimal performance
- **High Load**: 4GB+ for concurrent processing

### **Timeout Configuration**
- **Minimum**: 5 minutes for simple PDFs
- **Recommended**: 15 minutes for complex processing
- **Maximum**: 15 minutes (Lambda limit)

### **Concurrency**
- Lambda handles SQS message batching automatically
- Configure reserved concurrency based on downstream capacity
- Monitor memory usage and cold start times

## 🔒 **Security**

### **IAM Permissions Required**
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "sqs:ReceiveMessage",
        "sqs:DeleteMessage",
        "sqs:GetQueueAttributes"
      ],
      "Resource": "arn:aws:sqs:*:*:your-queue-name"
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:GetObject"
      ],
      "Resource": "arn:aws:s3:::your-bucket-name/*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:*:*:*"
    }
  ]
}
```

## 🐛 **Troubleshooting**

### **Common Issues**
1. **Chrome not found**: Ensure Dockerfile installs Google Chrome correctly
2. **Memory issues**: Increase Lambda memory allocation
3. **Timeout errors**: Increase Lambda timeout setting
4. **IronPDF license**: Set `IRONPDF_LICENSE_KEY` environment variable

### **Debugging**
- Check CloudWatch logs for detailed error messages
- Use Lambda insights for performance monitoring
- Test locally with Docker before deploying

## 🔄 **Migration from HTTP to SQS**

This Lambda function replaces the HTTP endpoint `api/printready/GenerateImage/` with SQS message processing:

### **Before (HTTP)**
```csharp
[HttpPost]
[Route("api/printready/GenerateImage/")]
public async Task<IActionResult> GenerateImage(GenerateImageRequest request)
```

### **After (SQS)**
```csharp
public async Task FunctionHandler(SQSEvent sqsEvent, ILambdaContext context)
```

### **Benefits of SQS Approach**
- **Scalability**: Automatic scaling based on queue depth
- **Reliability**: Built-in retry and dead letter queue support
- **Decoupling**: Asynchronous processing reduces API response times
- **Cost**: Pay only for actual processing time

## 📈 **Monitoring**

### **Key Metrics**
- Lambda duration and memory usage
- SQS message processing rate
- Error rates and retry counts
- PDF generation success/failure rates

### **Alarms**
- High error rates
- Long processing times
- Memory usage approaching limits
- Dead letter queue message accumulation

Your Lambda function is now ready for deployment and can process print-ready image generation requests from SQS messages with full Docker container support!
