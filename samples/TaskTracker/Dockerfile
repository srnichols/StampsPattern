# Build stage
FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build
WORKDIR /src

# Copy project file and restore dependencies
COPY ["TaskTracker.Blazor.csproj", "."]
COPY ["Directory.Build.props", "."]
RUN dotnet restore "TaskTracker.Blazor.csproj"

# Copy source code and build
COPY . .
RUN dotnet build "TaskTracker.Blazor.csproj" -c Release -o /app/build

# Publish stage
FROM build AS publish
RUN dotnet publish "TaskTracker.Blazor.csproj" -c Release -o /app/publish /p:UseAppHost=false

# Runtime stage
FROM mcr.microsoft.com/dotnet/aspnet:9.0 AS final
WORKDIR /app

# Create non-root user for security
RUN adduser --disabled-password --gecos '' appuser
USER appuser

# Copy published application
COPY --from=publish /app/publish .

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:80/health || exit 1

# Expose port
EXPOSE 80
EXPOSE 443

ENTRYPOINT ["dotnet", "TaskTracker.Blazor.dll"]