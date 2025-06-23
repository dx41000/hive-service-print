namespace hive.service.print.Models.PrintReady;

public class View
{
    public long Id { get; set; }
    public string Name { get; set; } = string.Empty;
    public int? OutputHeight { get; set; }
    public int? OutputWidth { get; set; }
    public int? PrintBoxHeight { get; set; }
    public int? PrintBoxWidth { get; set; }
    public int? PrintBoxTop { get; set; }
    public int? PrintBoxLeft { get; set; }
    public int? FinalFileTop { get; set; }
    public int? FinalFileLeft { get; set; }
    public string? FinalFileName { get; set; }
    public string? FinalFileNameThumb { get; set; }
    public int Order { get; set; }
    public int BaseArtworkTop { get; set; }
    public int BaseArtworkLeft { get; set; }
}
