using hive.service.print.Configuration;
using hive.service.print.Models;
using hive.service.print.Models.PrintReady;
using ImageMagick;
using IronPdf;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using Newtonsoft.Json;
using SkiaSharp;

namespace hive.service.print.Services;

public class PrintReadyService : IPrintReadyService
{
    private readonly ILogger<PrintReadyService> _logger;
    private readonly IOptions<ServiceConfiguration> _serviceOptions;

    public PrintReadyService(ILogger<PrintReadyService> logger, IOptions<ServiceConfiguration> serviceOptions)
    {
        _logger = logger;
        _serviceOptions = serviceOptions;
    }

    public async Task<GenerateImageResponse> GenerateImage(GenerateImageRequest request)
    {
        try
        {
            _logger.LogInformation("Starting PDF generation for ProductVariantId: {ProductVariantId}", request.ProductVariantId);

            // For Lambda version, we'll simulate the product variant data
            // In a real implementation, you'd fetch this from a database or API
            var mockProductVariant = CreateMockProductVariant(request.ProductVariantId);

            // Ensure we have images to generate
            if (!request.GenerateImages.Any())
            {
                _logger.LogWarning("No images specified for generation, creating default image");
                request.GenerateImages.Add(new GenerateImage
                {
                    ProductVariantViewId = 1,
                    PrintOrder = null
                });
            }

            // Use proper disposal pattern for all streams and resources
            using var baseArtWorkStream = new MemoryStream(mockProductVariant.BaseArtwork);
            var artWorks = new List<ArtWork>();

            try
            {
                // Process each image generation request
                foreach (var generateImage in request.GenerateImages)
                {
                    var printReadyView = CreateMockView(generateImage.ProductVariantViewId);

                    if (!string.IsNullOrEmpty(generateImage.PrintOrder))
                    {
                        var designerOutput = JsonConvert.DeserializeObject<DesignerOutput>(generateImage.PrintOrder);
                        if (designerOutput?.svg_data?.Any() == true)
                        {
                            var usedFonts = designerOutput.used_fonts ?? new List<UsedFont>();
                            var fontsPath = _serviceOptions.Value.FontsPath;

                            // For Lambda version, we'll create a mock PNG stream
                            // In real implementation, you'd convert SVG to PNG
                            var pngStream = CreateMockPngStream();

                            artWorks.Add(new ArtWork
                            {
                                PngStream = pngStream,
                                BaseArtworkLeft = printReadyView.PrintBoxLeft ?? 0,
                                BaseArtworkTop = printReadyView.PrintBoxTop ?? 0
                            });
                        }
                    }
                }

                // Create the final image with proper disposal
                using var overlayedImage = OverlayImage(baseArtWorkStream, artWorks);
                using var pdfStream = CreatePdf(overlayedImage);
                
                var printFile = StreamToByteArray(pdfStream);

                // Generate thumbnail if needed
                byte[]? thumbnail = CreateThumbnail(printFile);

                _logger.LogInformation("PDF generation completed successfully for ProductVariantId: {ProductVariantId}", request.ProductVariantId);

                return new GenerateImageResponse
                {
                    PrintFile = printFile,
                    ThumbnailFile = thumbnail
                };
            }
            finally
            {
                // Ensure all artwork streams are disposed
                foreach (var artWork in artWorks)
                {
                    artWork.PngStream?.Dispose();
                }
                artWorks.Clear();
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error generating PDF for ProductVariantId: {ProductVariantId}", request.ProductVariantId);
            throw;
        }
    }

    public async Task<GenerateImageResponse> GetImageNonCustomisable(long productVariantId)
    {
        _logger.LogInformation("Getting non-customisable image for ProductVariantId: {ProductVariantId}", productVariantId);
        
        // For Lambda version, return mock data
        // In real implementation, you'd fetch from database
        var mockData = CreateMockProductVariant(productVariantId);
        
        return new GenerateImageResponse
        {
            PrintFile = mockData.PrintFile,
            ThumbnailFile = mockData.BaseArtworkThumb,
        };
    }

    public Stream OverlayImage(Stream backgroundImage, List<ArtWork> artWorks)
    {
        // Reset background image position
        backgroundImage.Position = 0;

        using var backgroundBitmap = SKBitmap.Decode(backgroundImage);
        if (backgroundBitmap == null)
        {
            throw new InvalidOperationException("Failed to decode background image");
        }

        var imageInfo = new SKImageInfo(backgroundBitmap.Width, backgroundBitmap.Height, SKColorType.Bgra8888, SKAlphaType.Premul);
        
        using var surface = SKSurface.Create(imageInfo);
        if (surface == null)
        {
            throw new InvalidOperationException("Failed to create SkiaSharp surface");
        }

        var canvas = surface.Canvas;
        canvas.Clear(SKColors.Transparent);
        canvas.DrawBitmap(backgroundBitmap, 0, 0);

        // Draw overlay images with proper disposal and null checks
        foreach (var artWork in artWorks)
        {
            if (artWork.PngStream != null)
            {
                artWork.PngStream.Position = 0;
                using var overlayBitmap = SKBitmap.Decode(artWork.PngStream);
                if (overlayBitmap != null)
                {
                    canvas.DrawBitmap(overlayBitmap, artWork.BaseArtworkLeft, artWork.BaseArtworkTop);
                }
            }
        }

        // Create final image with proper disposal
        using var image = surface.Snapshot();
        using var data = image.Encode(SKEncodedImageFormat.Png, 100);
        
        var resultStream = new MemoryStream();
        data.SaveTo(resultStream);
        resultStream.Position = 0;
        
        return resultStream;
    }

    public Stream CreatePdf(Stream pngFile)
    {
        try
        {
            // Reset stream position
            pngFile.Position = 0;
            
            // Convert stream to byte array efficiently
            byte[] imageBytes;
            if (pngFile is MemoryStream ms)
            {
                imageBytes = ms.ToArray();
            }
            else
            {
                using var tempMs = new MemoryStream();
                pngFile.CopyTo(tempMs);
                imageBytes = tempMs.ToArray();
            }

            // Get image dimensions using SkiaSharp for size validation
            using var bitmap = SKBitmap.Decode(imageBytes);
            if (bitmap == null)
            {
                throw new InvalidOperationException("Failed to decode PNG image for PDF creation");
            }

            var originalWidth = bitmap.Width;
            var originalHeight = bitmap.Height;

            // Apply size constraints (same logic as original)
            const float maxSize = 14400f;
            var scaleFactor = 1.0f;
            
            if (originalWidth > maxSize || originalHeight > maxSize)
            {
                var widthRatio = maxSize / originalWidth;
                var heightRatio = maxSize / originalHeight;
                scaleFactor = Math.Min(widthRatio, heightRatio);
            }

            // Resize image if needed using SkiaSharp
            byte[] finalImageBytes = imageBytes;
            if (scaleFactor < 1.0f)
            {
                var newWidth = (int)(originalWidth * scaleFactor);
                var newHeight = (int)(originalHeight * scaleFactor);
                
                using var resizedBitmap = bitmap.Resize(new SKImageInfo(newWidth, newHeight), SKFilterQuality.High);
                if (resizedBitmap == null)
                {
                    throw new InvalidOperationException("Failed to resize image for PDF creation");
                }
                
                using var resizedImage = SKImage.FromBitmap(resizedBitmap);
                using var data = resizedImage.Encode(SKEncodedImageFormat.Png, 100);
                finalImageBytes = data.ToArray();
            }

            // Create PDF using IronPDF Linux - using HTML approach for better Linux compatibility
            var base64Image = Convert.ToBase64String(finalImageBytes);
            
            // Create HTML with embedded image for precise control
            var html = $@"
<!DOCTYPE html>
<html>
<head>
    <style>
        * {{ margin: 0; padding: 0; box-sizing: border-box; }}
        html, body {{ width: 100%; height: 100%; }}
        .image-container {{ 
            width: 100%; 
            height: 100vh; 
            display: flex; 
            justify-content: center; 
            align-items: center; 
        }}
        img {{ 
            max-width: 100%; 
            max-height: 100%; 
            object-fit: contain; 
        }}
    </style>
</head>
<body>
    <div class='image-container'>
        <img src='data:image/png;base64,{base64Image}' alt='Print Ready Image' />
    </div>
</body>
</html>";

            // Configure Chrome PDF renderer for Linux
            var renderer = new ChromePdfRenderer();
            
            // Configure rendering options for print quality
            renderer.RenderingOptions.PaperSize = PdfPaperSize.Custom;
            renderer.RenderingOptions.PaperOrientation = PdfPaperOrientation.Portrait;
            renderer.RenderingOptions.MarginTop = 0;
            renderer.RenderingOptions.MarginBottom = 0;
            renderer.RenderingOptions.MarginLeft = 0;
            renderer.RenderingOptions.MarginRight = 0;
            renderer.RenderingOptions.EnableJavaScript = false;
            renderer.RenderingOptions.Timeout = 60; // 60 second timeout
            renderer.RenderingOptions.CreatePdfFormsFromHtml = false;
            
            // Set custom paper size based on image dimensions
            var dpi = 300; // Standard print DPI
            var widthInches = (float)originalWidth / dpi;
            var heightInches = (float)originalHeight / dpi;
            renderer.RenderingOptions.SetCustomPaperSizeInInches(widthInches, heightInches);

            // Render HTML to PDF
            using var pdfDocument = renderer.RenderHtmlAsPdf(html);
            
            // Return the PDF as a stream
            var resultStream = new MemoryStream(pdfDocument.BinaryData);
            resultStream.Position = 0;
            
            return resultStream;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error creating PDF from PNG stream using IronPDF Linux");
            throw;
        }
    }

    private static byte[] StreamToByteArray(Stream stream)
    {
        if (stream == null)
            throw new ArgumentNullException(nameof(stream));

        stream.Position = 0;

        // Optimize for MemoryStream to avoid unnecessary copying
        if (stream is MemoryStream memoryStream)
        {
            return memoryStream.ToArray();
        }

        // For other stream types, use efficient copying
        using var ms = new MemoryStream();
        stream.CopyTo(ms);
        return ms.ToArray();
    }

    private byte[]? CreateThumbnail(byte[] pdfBytes)
    {
        try
        {
            // Create a simple thumbnail from the PDF
            // In real implementation, you'd use ImageMagick or similar
            using var image = new MagickImage(pdfBytes);
            image.Resize(400, 0); // Resize to 400px width, maintain aspect ratio
            image.Format = MagickFormat.Png;
            return image.ToByteArray();
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Failed to create thumbnail");
            return null;
        }
    }

    // Mock methods for Lambda version - replace with real data access in production
    private MockProductVariant CreateMockProductVariant(long productVariantId)
    {
        // Create a simple 100x100 white PNG as base artwork
        var baseArtwork = CreateMockImageBytes(800, 600, SKColors.White);
        
        return new MockProductVariant
        {
            Id = productVariantId,
            BaseArtwork = baseArtwork,
            PrintFile = null,
            BaseArtworkThumb = null
        };
    }

    private View CreateMockView(long viewId)
    {
        return new View
        {
            Id = viewId,
            Name = $"View {viewId}",
            OutputHeight = 600,
            OutputWidth = 800,
            PrintBoxHeight = 400,
            PrintBoxWidth = 600,
            PrintBoxTop = 100,
            PrintBoxLeft = 100,
            BaseArtworkTop = 0,
            BaseArtworkLeft = 0
        };
    }

    private Stream CreateMockPngStream()
    {
        // Create a simple colored rectangle as mock artwork
        var imageBytes = CreateMockImageBytes(200, 200, SKColors.Blue);
        return new MemoryStream(imageBytes);
    }

    private byte[] CreateMockImageBytes(int width, int height, SKColor color)
    {
        var imageInfo = new SKImageInfo(width, height, SKColorType.Bgra8888, SKAlphaType.Premul);
        using var surface = SKSurface.Create(imageInfo);
        var canvas = surface.Canvas;
        canvas.Clear(color);
        
        using var image = surface.Snapshot();
        using var data = image.Encode(SKEncodedImageFormat.Png, 100);
        return data.ToArray();
    }

    private class MockProductVariant
    {
        public long Id { get; set; }
        public byte[] BaseArtwork { get; set; } = Array.Empty<byte>();
        public byte[]? PrintFile { get; set; }
        public byte[]? BaseArtworkThumb { get; set; }
    }
}
