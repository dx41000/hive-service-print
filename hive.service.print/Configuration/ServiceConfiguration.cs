namespace hive.service.print.Configuration;

public class ServiceConfiguration
{
    public string CartFilesPath { get; set; } = string.Empty;
    public string FontsPath { get; set; } = "/app/Fonts/";
    public AwsConfiguration Aws { get; set; } = new();
}

public class AwsConfiguration
{
    public string Region { get; set; } = "us-east-1";
    public string S3BucketName { get; set; } = string.Empty;
    public string SqsQueueUrl { get; set; } = string.Empty;
}
