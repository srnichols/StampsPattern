# Build stage  
FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build
WORKDIR /src

# Copy project file
COPY ["Portal.csproj", "."]

# Restore dependencies
RUN dotnet restore "Portal.csproj"

# Copy source code
COPY . .

# Build and publish application
RUN dotnet publish "Portal.csproj" -c Release -o /app/publish /p:UseAppHost=false

# Runtime stage
FROM mcr.microsoft.com/dotnet/aspnet:9.0 AS final
WORKDIR /app

# Create non-root user for security
RUN groupadd -r appuser && useradd -r -g appuser appuser

# Copy published files
COPY --from=build /app/publish .

# Set proper permissions
RUN chown -R appuser:appuser /app
USER appuser

# Configure ASP.NET Core for Container Apps
ENV ASPNETCORE_URLS=http://+:8080
ENV ASPNETCORE_ENVIRONMENT=Production
EXPOSE 8080

ENTRYPOINT ["dotnet", "Portal.dll"]
