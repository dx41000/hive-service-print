namespace hive.service.print.Models.PrintReady;

public class GenerateImageRequest
{
    public long ProductVariantId { get; set; }
    public List<GenerateImage> GenerateImages { get; set; } = new();
}

public class GenerateImage
{
    public long ProductVariantViewId { get; set; }
    public string? PrintOrder { get; set; }
}
