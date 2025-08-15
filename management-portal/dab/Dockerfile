# Use a specific stable version that's known to work
FROM mcr.microsoft.com/azure-databases/data-api-builder:1.2.10

# Set working directory to the app directory
WORKDIR /App

# Copy configuration files
COPY dab-config.json .
COPY schema.graphql .

# Set environment variables
ENV ASPNETCORE_URLS=http://+:5000
ENV ASPNETCORE_ENVIRONMENT=Production

# Expose the port
EXPOSE 5000

# Let the base image handle the startup
ENTRYPOINT ["dotnet", "/App/Azure.DataApiBuilder.Service.dll", "--config", "dab-config.json"]
