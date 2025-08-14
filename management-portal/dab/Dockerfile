# Use the pre-built Data API Builder image from Microsoft
FROM mcr.microsoft.com/azure-databases/data-api-builder:latest

# Copy configuration files
COPY dab-config.json /app/
COPY schema.graphql /app/

# Set working directory
WORKDIR /app

# Configure environment
ENV ASPNETCORE_URLS=http://+:5000
ENV ASPNETCORE_ENVIRONMENT=Production
EXPOSE 5000

# Start Data API Builder
CMD ["dab", "start", "--config", "dab-config.json"]
