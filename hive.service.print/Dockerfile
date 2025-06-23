FROM public.ecr.aws/lambda/dotnet:8 AS base

# Install system dependencies for image processing
RUN yum update -y && yum install -y \
    fontconfig \
    freetype \
    freetype-devel \
    fontconfig-devel \
    libstdc++ \
    && yum clean all

# Install additional dependencies for SkiaSharp and ImageSharp
RUN yum install -y \
    libX11 \
    libXext \
    libXrender \
    libICE \
    libSM \
    && yum clean all

FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src

# Copy project file and restore dependencies
COPY ["hive.service.print.csproj", "./"]
RUN dotnet restore "hive.service.print.csproj"

# Copy source code and build
COPY . .
RUN dotnet build "hive.service.print.csproj" -c Release -o /app/build

FROM build AS publish
RUN dotnet publish "hive.service.print.csproj" -c Release -o /app/publish

FROM base AS final

# Copy the published application
COPY --from=publish /app/publish ${LAMBDA_TASK_ROOT}

# Create Fonts directory (you can mount or copy fonts as needed)
RUN mkdir -p ${LAMBDA_TASK_ROOT}/Fonts

# Set environment variables for image processing
ENV DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=1
ENV MAGICK_CONFIGURE_PATH=${LAMBDA_TASK_ROOT}

# Set the Lambda handler
CMD ["hive.service.print::hive.service.print.Function::FunctionHandler"]
