using System;
using System.Threading.Tasks;
using Microsoft.Azure.Cosmos;
using Azure.Identity;

class Program
{
    static async Task Main(string[] args)
    {
        try
        {
            string endpoint = Environment.GetEnvironmentVariable("COSMOS_ACCOUNT_ENDPOINT");
            if (string.IsNullOrEmpty(endpoint))
            {
                Console.WriteLine("Error: COSMOS_ACCOUNT_ENDPOINT environment variable not set");
                return;
            }

            // Use DefaultAzureCredential for authentication (same as seeder)
            var credential = new DefaultAzureCredential();
            var client = new CosmosClient(endpoint, credential);
            
            var database = client.GetDatabase("stamps-control-plane");
            
            Console.WriteLine("Clearing all seeded data from database...");
            
            // Clear cells container
            var cellsContainer = database.GetContainer("cells");
            await ClearContainer(cellsContainer, "cells");
            
            // Clear tenants container  
            var tenantsContainer = database.GetContainer("tenants");
            await ClearContainer(tenantsContainer, "tenants");
            
            // Clear operations container
            var operationsContainer = database.GetContainer("operations");
            await ClearContainer(operationsContainer, "operations");
            
            // Clear catalogs container
            var catalogsContainer = database.GetContainer("catalogs");
            await ClearContainer(catalogsContainer, "catalogs");
            
            Console.WriteLine("Database cleared successfully. All seeded data removed.");
        }
        catch (Exception ex)
        {
            Console.WriteLine($"Error clearing database: {ex.Message}");
        }
    }
    
    static async Task ClearContainer(Container container, string containerName)
    {
        try
        {
            Console.WriteLine($"Clearing {containerName} container...");
            
            // Query all documents
            var query = new QueryDefinition("SELECT c.id, c.pk FROM c");
            var iterator = container.GetItemQueryIterator<dynamic>(query);
            
            int deletedCount = 0;
            while (iterator.HasMoreResults)
            {
                var response = await iterator.ReadNextAsync();
                foreach (var item in response)
                {
                    try
                    {
                        string id = item.id;
                        string partitionKey = item.pk ?? item.id; // Use pk field or fallback to id
                        
                        await container.DeleteItemAsync<dynamic>(id, new PartitionKey(partitionKey));
                        deletedCount++;
                    }
                    catch (Exception ex)
                    {
                        Console.WriteLine($"Warning: Could not delete item {item.id}: {ex.Message}");
                    }
                }
            }
            
            Console.WriteLine($"Cleared {deletedCount} items from {containerName}");
        }
        catch (Exception ex)
        {
            Console.WriteLine($"Error clearing {containerName}: {ex.Message}");
        }
    }
}
