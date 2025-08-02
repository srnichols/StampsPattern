#!/bin/bash

# Azure Stamps Pattern Deployment Script
# This script deploys the traffic routing infrastructure for the stamps pattern

# Configuration
LOCATION="eastus"
# Generate resource group name with region abbreviation
case $LOCATION in
    "eastus") REGION_SHORT="eus" ;;
    "eastus2") REGION_SHORT="eus2" ;;
    "westus") REGION_SHORT="wus" ;;
    "westus2") REGION_SHORT="wus2" ;;
    "westus3") REGION_SHORT="wus3" ;;
    "centralus") REGION_SHORT="cus" ;;
    "northeurope") REGION_SHORT="neu" ;;
    "westeurope") REGION_SHORT="weu" ;;
    *) REGION_SHORT="${LOCATION:0:3}" ;;
esac
RESOURCE_GROUP_NAME="rg-stamps-${REGION_SHORT}-dev"
TEMPLATE_FILE="traffic-routing.bicep"
PARAMETERS_FILE="traffic-routing.parameters.json"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}🚀 Starting Azure Stamps Pattern Deployment${NC}"

# Check if user is logged in to Azure
echo -e "${YELLOW}Checking Azure login status...${NC}"
az account show > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Not logged in to Azure. Please run 'az login' first.${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Azure login verified${NC}"

# Get current subscription
SUBSCRIPTION_ID=$(az account show --query id -o tsv)
echo -e "${GREEN}📋 Using subscription: ${SUBSCRIPTION_ID}${NC}"

# Create resource group if it doesn't exist
echo -e "${YELLOW}📦 Creating resource group if it doesn't exist...${NC}"
az group create --name $RESOURCE_GROUP_NAME --location $LOCATION

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Resource group ready${NC}"
else
    echo -e "${RED}❌ Failed to create resource group${NC}"
    exit 1
fi

# Deploy the template
echo -e "${YELLOW}🔧 Deploying Bicep template...${NC}"
az deployment group create \
    --resource-group $RESOURCE_GROUP_NAME \
    --template-file $TEMPLATE_FILE \
    --parameters @$PARAMETERS_FILE \
    --verbose

if [ $? -eq 0 ]; then
    echo -e "${GREEN}🎉 Deployment completed successfully!${NC}"
    
    # Get deployment outputs
    echo -e "${YELLOW}📊 Retrieving deployment outputs...${NC}"
    az deployment group show \
        --resource-group $RESOURCE_GROUP_NAME \
        --name $(basename $TEMPLATE_FILE .bicep) \
        --query properties.outputs
        
else
    echo -e "${RED}❌ Deployment failed${NC}"
    exit 1
fi

echo -e "${GREEN}✨ Azure Stamps Pattern deployment complete!${NC}"
