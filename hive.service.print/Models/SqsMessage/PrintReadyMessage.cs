using hive.service.print.Models.PrintReady;

namespace hive.service.print.Models.SqsMessage;

public class PrintReadyMessage
{
    public string MessageId { get; set; } = string.Empty;
    public string MessageType { get; set; } = "GenerateImage";
    public GenerateImageRequest? Payload { get; set; }
    public DateTime Timestamp { get; set; } = DateTime.UtcNow;
    public string? CorrelationId { get; set; }
    public int RetryCount { get; set; } = 0;
}
