# Use a recent stable version of Data API Builder
FROM mcr.microsoft.com/azure-databases/data-api-builder:latest

# Set working directory to the app directory
WORKDIR /App

# Copy configuration files
COPY dab-config.json .
COPY schema.graphql .

# Set environment variables for port 80
ENV ASPNETCORE_URLS=http://+:80
ENV ASPNETCORE_ENVIRONMENT=Production

# Expose port 80
EXPOSE 80

# Start Data API Builder using the actual executable name and dotnet
ENTRYPOINT ["dotnet", "Microsoft.DataApiBuilder.dll", "start", "--config", "/App/dab-config.json"]
