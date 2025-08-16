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

# Start Data API Builder using the built-in entrypoint
ENTRYPOINT ["dab", "start", "--host", "0.0.0.0", "--config", "/App/dab-config.json"]
