FROM public.ecr.aws/lambda/dotnet:8 AS base

# Install Google Chrome and dependencies for IronPDF.Linux
RUN yum update -y && yum install -y \
    wget \
    unzip \
    && wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | rpm --import - \
    && echo -e "[google-chrome]\nname=google-chrome\nbaseurl=http://dl.google.com/linux/chrome/rpm/stable/x86_64\nenabled=1\ngpgcheck=1\ngpgkey=https://dl.google.com/linux/linux_signing_key.pub" > /etc/yum.repos.d/google-chrome.repo \
    && yum install -y google-chrome-stable \
    && yum clean all

# Install additional dependencies for headless Chrome and IronPDF
RUN yum install -y \
    nss \
    atk \
    at-spi2-atk \
    gtk3 \
    cups-libs \
    libdrm \
    libxkbcommon \
    libXcomposite \
    libXdamage \
    libXrandr \
    libgbm \
    libXss \
    alsa-lib \
    && yum clean all

# Set environment variables for Chrome in Lambda
ENV CHROME_BIN=/usr/bin/google-chrome
ENV CHROME_PATH=/usr/bin/google-chrome
ENV DISPLAY=:99
ENV CHROME_ARGS="--no-sandbox --disable-dev-shm-usage --disable-gpu --remote-debugging-port=9222 --disable-extensions --disable-plugins --single-process --no-zygote"

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

# Set the Lambda handler
CMD ["hive.service.print::hive.service.print.Function::FunctionHandler"]
