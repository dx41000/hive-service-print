using Amazon.Lambda.Core;
using Amazon.Lambda.SQSEvents;
using hive.service.print.Configuration;
using hive.service.print.Models.PrintReady;
using hive.service.print.Models.SqsMessage;
using hive.service.print.Services;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using Newtonsoft.Json;
using System.Text.Json;

// Assembly attribute to enable the Lambda function's JSON input to be converted into a .NET class.
[assembly: LambdaSerializer(typeof(Amazon.Lambda.Serialization.SystemTextJson.DefaultLambdaJsonSerializer))]

namespace hive.service.print;

public class Function
{
    private readonly IServiceProvider _serviceProvider;
    private readonly ILogger<Function> _logger;

    public Function()
    {
        var services = new ServiceCollection();
        ConfigureServices(services);
        _serviceProvider = services.BuildServiceProvider();
        _logger = _serviceProvider.GetRequiredService<ILogger<Function>>();
    }

    /// <summary>
    /// Lambda function handler for processing SQS messages
    /// </summary>
    /// <param name="sqsEvent">The SQS event containing messages to process</param>
    /// <param name="context">Lambda context</param>
    /// <returns>Task representing the async operation</returns>
    public async Task FunctionHandler(SQSEvent sqsEvent, ILambdaContext context)
    {
        _logger.LogInformation("Processing {MessageCount} SQS messages", sqsEvent.Records.Count);

        var printReadyService = _serviceProvider.GetRequiredService<IPrintReadyService>();
        var tasks = new List<Task>();

        foreach (var record in sqsEvent.Records)
        {
            tasks.Add(ProcessMessage(record, printReadyService, context));
        }

        await Task.WhenAll(tasks);
        
        _logger.LogInformation("Completed processing all SQS messages");
    }

    private async Task ProcessMessage(SQSEvent.SQSMessage sqsMessage, IPrintReadyService printReadyService, ILambdaContext context)
    {
        var messageId = sqsMessage.MessageId;
        
        try
        {
            _logger.LogInformation("Processing message {MessageId}", messageId);

            // Parse the SQS message body
            var printReadyMessage = JsonConvert.DeserializeObject<PrintReadyMessage>(sqsMessage.Body);
            
            if (printReadyMessage?.Payload == null)
            {
                _logger.LogWarning("Message {MessageId} has invalid payload", messageId);
                return;
            }

            _logger.LogInformation("Processing {MessageType} for ProductVariantId: {ProductVariantId}", 
                printReadyMessage.MessageType, printReadyMessage.Payload.ProductVariantId);

            // Process the message based on type
            GenerateImageResponse? response = printReadyMessage.MessageType switch
            {
                "GenerateImage" => await printReadyService.GenerateImage(printReadyMessage.Payload),
                "GetImage" => await printReadyService.GetImageNonCustomisable(printReadyMessage.Payload.ProductVariantId),
                _ => throw new InvalidOperationException($"Unknown message type: {printReadyMessage.MessageType}")
            };

            if (response?.PrintFile != null)
            {
                _logger.LogInformation("Successfully generated PDF for message {MessageId}. PDF size: {PdfSize} bytes, Thumbnail size: {ThumbnailSize} bytes", 
                    messageId, response.PrintFile.Length, response.ThumbnailFile?.Length ?? 0);

                // Here you could save the result to S3, database, or send to another queue
                await SaveResult(printReadyMessage, response);
            }
            else
            {
                _logger.LogWarning("No PDF generated for message {MessageId}", messageId);
            }
        }
        catch (JsonException ex)
        {
            _logger.LogError(ex, "Failed to parse message {MessageId}: {Error}", messageId, ex.Message);
            // Consider sending to DLQ or error handling queue
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error processing message {MessageId}: {Error}", messageId, ex.Message);
            // Consider retry logic or DLQ handling
            throw; // Re-throw to trigger SQS retry mechanism
        }
    }

    private async Task SaveResult(PrintReadyMessage originalMessage, GenerateImageResponse response)
    {
        try
        {
            // TODO: Implement result saving logic
            // Options:
            // 1. Save PDF to S3
            // 2. Save metadata to database
            // 3. Send result to another SQS queue
            // 4. Call a webhook/API endpoint

            _logger.LogInformation("Saving result for ProductVariantId: {ProductVariantId}", 
                originalMessage.Payload?.ProductVariantId);

            // Example: Save to S3 (uncomment and configure as needed)
            // await SaveToS3(originalMessage, response);

            // Example: Send to result queue (uncomment and configure as needed)
            // await SendToResultQueue(originalMessage, response);

            await Task.CompletedTask; // Placeholder
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to save result for ProductVariantId: {ProductVariantId}", 
                originalMessage.Payload?.ProductVariantId);
            throw;
        }
    }

    private void ConfigureServices(IServiceCollection services)
    {
        // Configure logging
        services.AddLogging(builder =>
        {
            builder.AddConsole();
            builder.SetMinimumLevel(LogLevel.Information);
        });

        // Configure options
        services.Configure<ServiceConfiguration>(options =>
        {
            options.CartFilesPath = Environment.GetEnvironmentVariable("CART_FILES_PATH") ?? "/tmp/cart/{printRequestId}/{productVariantId}/{productVariantViewId}";
            options.FontsPath = Environment.GetEnvironmentVariable("FONTS_PATH") ?? "/app/Fonts/";
            options.Aws.Region = Environment.GetEnvironmentVariable("AWS_REGION") ?? "us-east-1";
            options.Aws.S3BucketName = Environment.GetEnvironmentVariable("S3_BUCKET_NAME") ?? "";
            options.Aws.SqsQueueUrl = Environment.GetEnvironmentVariable("SQS_QUEUE_URL") ?? "";
        });

        // Register services
        services.AddScoped<IPrintReadyService, PrintReadyService>();

        // Configure IronPDF for Lambda environment
        ConfigureIronPdf();
    }

    private void ConfigureIronPdf()
    {
        try
        {
            // Configure IronPDF for Lambda/Linux environment
            if (Environment.OSVersion.Platform == PlatformID.Unix)
            {
                IronPdf.Installation.ChromeGpuMode = IronPdf.Engines.Chrome.ChromeGpuModes.Disabled;
                IronPdf.Installation.DefaultRenderingEngine = IronPdf.Rendering.ChromePdfRenderingEngine.Chrome;
            }

            // Set license key if available
            var licenseKey = Environment.GetEnvironmentVariable("IRONPDF_LICENSE_KEY");
            if (!string.IsNullOrEmpty(licenseKey))
            {
                IronPdf.License.LicenseKey = licenseKey;
                _logger?.LogInformation("IronPDF license configured");
            }
            else
            {
                _logger?.LogWarning("IronPDF license not configured - PDFs will have watermarks");
            }
        }
        catch (Exception ex)
        {
            _logger?.LogError(ex, "Failed to configure IronPDF");
        }
    }

    // Example methods for saving results (implement as needed)
    /*
    private async Task SaveToS3(PrintReadyMessage originalMessage, GenerateImageResponse response)
    {
        var s3Client = new AmazonS3Client();
        var bucketName = Environment.GetEnvironmentVariable("S3_BUCKET_NAME");
        
        if (response.PrintFile != null)
        {
            var pdfKey = $"print-files/{originalMessage.Payload.ProductVariantId}/print.pdf";
            await s3Client.PutObjectAsync(new PutObjectRequest
            {
                BucketName = bucketName,
                Key = pdfKey,
                InputStream = new MemoryStream(response.PrintFile),
                ContentType = "application/pdf"
            });
        }

        if (response.ThumbnailFile != null)
        {
            var thumbKey = $"print-files/{originalMessage.Payload.ProductVariantId}/thumbnail.png";
            await s3Client.PutObjectAsync(new PutObjectRequest
            {
                BucketName = bucketName,
                Key = thumbKey,
                InputStream = new MemoryStream(response.ThumbnailFile),
                ContentType = "image/png"
            });
        }
    }

    private async Task SendToResultQueue(PrintReadyMessage originalMessage, GenerateImageResponse response)
    {
        var sqsClient = new AmazonSQSClient();
        var resultQueueUrl = Environment.GetEnvironmentVariable("RESULT_QUEUE_URL");
        
        var resultMessage = new
        {
            OriginalMessageId = originalMessage.MessageId,
            ProductVariantId = originalMessage.Payload.ProductVariantId,
            Success = true,
            PdfSize = response.PrintFile?.Length ?? 0,
            ThumbnailSize = response.ThumbnailFile?.Length ?? 0,
            ProcessedAt = DateTime.UtcNow
        };

        await sqsClient.SendMessageAsync(new SendMessageRequest
        {
            QueueUrl = resultQueueUrl,
            MessageBody = JsonConvert.SerializeObject(resultMessage)
        });
    }
    */
}
