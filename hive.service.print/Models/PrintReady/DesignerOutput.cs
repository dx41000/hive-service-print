namespace hive.service.print.Models.PrintReady;

public class DesignerOutput
{
    public List<UsedFont>? used_fonts { get; set; }
    public List<SvgDatum> svg_data { get; set; } = new();
    public List<string> custom_images { get; set; } = new();
}

public class SvgDatum
{
    public string svg { get; set; } = string.Empty;
}

public class UsedFont
{
    public string name { get; set; } = string.Empty;
}
