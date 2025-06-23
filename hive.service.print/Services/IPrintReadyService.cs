using hive.service.print.Models.PrintReady;

namespace hive.service.print.Services;

public interface IPrintReadyService
{
    Task<GenerateImageResponse> GenerateImage(GenerateImageRequest request);
    Task<GenerateImageResponse> GetImageNonCustomisable(long productVariantId);
}
