using System;
using System.Collections.Generic;
using System.Net;
using System.Threading.Tasks;
using Microsoft.Azure.Cosmos;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Caching.Distributed;
using Moq;
using Xunit;
using AzureStampsPattern.Models;
using AzureStampsPattern.Services;

namespace AzureStampsPattern.Tests.Integration
{
    /// <summary>
    /// Integration tests using Cosmos DB Emulator
    /// These tests require Cosmos DB Emulator to be running locally
    /// Start emulator: https://docs.microsoft.com/en-us/azure/cosmos-db/local-emulator
    /// </summary>
    [Collection("Integration Tests")]
    public class CosmosDbIntegrationTests : IDisposable
    {
        private readonly CosmosClient _cosmosClient;
        private readonly Database _database;
        private readonly Container _tenantsContainer;
        private readonly Container _cellsContainer;
        private readonly ILogger<CreateTenantFunction> _logger;
        private readonly Mock<IDistributedCache> _mockCache;
        private readonly ITenantCacheService _cacheService;

        // Cosmos DB Emulator connection string
        private const string EmulatorConnectionString = "AccountEndpoint=https://localhost:8081/;AccountKey=C2y6yDjf5/R+ob0N8A7Cgv30VRDJIWEHLM+4QDU5DE2nQ9nDuVTqobD4b8mGGyPMbIZnqyMsEcaGQy67XIw/Jw==";
        private const string DatabaseName = "StampsPatternTestDb";
        private const string TenantsContainerName = "tenants";
        private const string CellsContainerName = "cells";

        public CosmosDbIntegrationTests()
        {
            // Initialize Cosmos DB client for emulator
            var cosmosClientOptions = new CosmosClientOptions
            {
                HttpClientTimeout = TimeSpan.FromSeconds(30),
                ConnectionMode = ConnectionMode.Gateway, // Emulator requires Gateway mode
                ConsistencyLevel = ConsistencyLevel.Session
            };

            _cosmosClient = new CosmosClient(EmulatorConnectionString, cosmosClientOptions);
            
            // Setup test database and containers
            SetupTestDatabase().Wait();
            
            _database = _cosmosClient.GetDatabase(DatabaseName);
            _tenantsContainer = _database.GetContainer(TenantsContainerName);
            _cellsContainer = _database.GetContainer(CellsContainerName);

            // Setup mocks
            _logger = Mock.Of<ILogger<CreateTenantFunction>>();
            _mockCache = new Mock<IDistributedCache>();
            _cacheService = new MemoryTenantCacheService(Mock.Of<IMemoryCache>());
        }

        private async Task SetupTestDatabase()
        {
            try
            {
                // Create database
                var databaseResponse = await _cosmosClient.CreateDatabaseIfNotExistsAsync(
                    DatabaseName,
                    ThroughputProperties.CreateAutoscaleThroughput(1000)
                );

                var database = databaseResponse.Database;

                // Create tenants container
                await database.CreateContainerIfNotExistsAsync(new ContainerProperties
                {
                    Id = TenantsContainerName,
                    PartitionKeyPath = "/tenantId",
                    IndexingPolicy = new IndexingPolicy
                    {
                        IndexingMode = IndexingMode.Consistent,
                        Automatic = true,
                        CompositeIndexes =
                        {
                            new Collection<CompositePath>
                            {
                                new CompositePath { Path = "/region", Order = CompositePathSortOrder.Ascending },
                                new CompositePath { Path = "/tenantTier", Order = CompositePathSortOrder.Ascending }
                            }
                        }
                    }
                });

                // Create cells container
                await database.CreateContainerIfNotExistsAsync(new ContainerProperties
                {
                    Id = CellsContainerName,
                    PartitionKeyPath = "/region",
                    IndexingPolicy = new IndexingPolicy
                    {
                        IndexingMode = IndexingMode.Consistent,
                        Automatic = true,
                        CompositeIndexes =
                        {
                            new Collection<CompositePath>
                            {
                                new CompositePath { Path = "/region", Order = CompositePathSortOrder.Ascending },
                                new CompositePath { Path = "/cellType", Order = CompositePathSortOrder.Ascending },
                                new CompositePath { Path = "/currentTenants", Order = CompositePathSortOrder.Ascending }
                            }
                        }
                    }
                });
            }
            catch (CosmosException ex)
            {
                // If emulator is not running, skip these tests
                Assert.True(false, $"Cosmos DB Emulator not available: {ex.Message}. Please start the Cosmos DB Emulator to run integration tests.");
            }
        }

        [Fact]
        public async Task CreateTenant_WithValidData_ShouldPersistToCosmosDb()
        {
            // Arrange
            var createTenantFunction = new CreateTenantFunction(_cosmosClient, _logger, _cacheService);
            var tenantRequest = new CreateTenantRequest
            {
                TenantId = $"integration-test-{Guid.NewGuid()}",
                Subdomain = $"integration-{DateTime.UtcNow.Ticks}",
                TenantTier = TenantTier.Shared,
                Region = "eastus",
                ComplianceRequirements = new[] { ComplianceRequirement.SOC2 }
            };

            // Act
            var result = await createTenantFunction.CreateTenantAsync(tenantRequest);

            // Assert
            Assert.NotNull(result);
            Assert.NotNull(result.CellId);
            
            // Verify tenant was created in Cosmos DB
            var tenantResponse = await _tenantsContainer.ReadItemAsync<TenantInfo>(
                tenantRequest.TenantId,
                new PartitionKey(tenantRequest.TenantId)
            );

            Assert.Equal(tenantRequest.TenantId, tenantResponse.Resource.TenantId);
            Assert.Equal(tenantRequest.TenantTier, tenantResponse.Resource.TenantTier);
            Assert.Equal(tenantRequest.Region, tenantResponse.Resource.Region);
        }

        [Fact]
        public async Task GetTenantInfo_WithCachedData_ShouldReturnFromCache()
        {
            // Arrange
            var tenantId = $"cached-test-{Guid.NewGuid()}";
            var cachedTenantInfo = new TenantInfo
            {
                TenantId = tenantId,
                CellId = "test-cell-001",
                TenantTier = TenantTier.Dedicated,
                Region = "westus2"
            };

            // Setup cache mock to return cached data
            _mockCache.Setup(x => x.GetAsync(It.IsAny<string>(), default))
                     .ReturnsAsync(System.Text.Json.JsonSerializer.SerializeToUtf8Bytes(cachedTenantInfo));

            var getTenantFunction = new GetTenantInfoFunction(_cosmosClient, _logger, _cacheService);

            // Act
            var result = await getTenantFunction.GetTenantInfoAsync(tenantId);

            // Assert
            Assert.NotNull(result);
            Assert.Equal(tenantId, result.TenantId);
            Assert.Equal("test-cell-001", result.CellId);
        }

        [Theory]
        [InlineData(TenantTier.Startup, "eastus", CellType.Shared)]
        [InlineData(TenantTier.Growth, "westus2", CellType.Shared)]
        [InlineData(TenantTier.Enterprise, "eastus", CellType.Dedicated)]
        [InlineData(TenantTier.Dedicated, "westus2", CellType.Dedicated)]
        public async Task TenantAssignment_ShouldMapToCorrectCellType(TenantTier tenantTier, string region, CellType expectedCellType)
        {
            // Arrange
            var createTenantFunction = new CreateTenantFunction(_cosmosClient, _logger, _cacheService);
            var tenantRequest = new CreateTenantRequest
            {
                TenantId = $"tier-test-{Guid.NewGuid()}",
                Subdomain = $"tier-{DateTime.UtcNow.Ticks}",
                TenantTier = tenantTier,
                Region = region
            };

            // Ensure appropriate cell exists
            await CreateTestCell(region, expectedCellType);

            // Act
            var result = await createTenantFunction.CreateTenantAsync(tenantRequest);

            // Assert
            Assert.NotNull(result);
            Assert.Contains(expectedCellType.ToString().ToLower(), result.CellId.ToLower());
        }

        [Fact]
        public async Task TenantMigration_FromSharedToDedicated_ShouldUpdateCellAssignment()
        {
            // Arrange
            var migrationFunction = new TenantMigrationFunction(_cosmosClient, _logger, _cacheService);
            var tenantId = $"migration-test-{Guid.NewGuid()}";

            // Create initial shared tenant
            var sharedTenant = new TenantInfo
            {
                TenantId = tenantId,
                CellId = "shared-eastus-001",
                TenantTier = TenantTier.Shared,
                Region = "eastus",
                CreatedAt = DateTime.UtcNow
            };

            await _tenantsContainer.CreateItemAsync(sharedTenant);

            // Create dedicated cell for migration
            await CreateTestCell("eastus", CellType.Dedicated);

            // Act
            var migrationRequest = new TenantMigrationRequest
            {
                TenantId = tenantId,
                TargetCellType = CellType.Dedicated,
                MigrationReason = "Upgraded to Enterprise tier"
            };

            var result = await migrationFunction.MigrateTenantAsync(migrationRequest);

            // Assert
            Assert.True(result.Success);
            Assert.Contains("dedicated", result.NewCellId.ToLower());

            // Verify tenant was updated
            var updatedTenant = await _tenantsContainer.ReadItemAsync<TenantInfo>(
                tenantId,
                new PartitionKey(tenantId)
            );

            Assert.Equal(result.NewCellId, updatedTenant.Resource.CellId);
        }

        [Fact]
        public async Task CellCapacityMonitoring_ShouldTrackTenantCounts()
        {
            // Arrange
            var cellId = "capacity-test-shared-001";
            var region = "eastus";

            // Create test cell
            var testCell = new CellInfo
            {
                CellId = cellId,
                Region = region,
                CellType = CellType.Shared,
                MaxTenants = 10,
                CurrentTenants = 0,
                CreatedAt = DateTime.UtcNow
            };

            await _cellsContainer.CreateItemAsync(testCell);

            // Create multiple tenants
            var createTenantFunction = new CreateTenantFunction(_cosmosClient, _logger, _cacheService);
            var tenantIds = new List<string>();

            for (int i = 0; i < 5; i++)
            {
                var tenantRequest = new CreateTenantRequest
                {
                    TenantId = $"capacity-tenant-{i}-{Guid.NewGuid()}",
                    Subdomain = $"capacity-{i}-{DateTime.UtcNow.Ticks}",
                    TenantTier = TenantTier.Shared,
                    Region = region
                };

                var result = await createTenantFunction.CreateTenantAsync(tenantRequest);
                tenantIds.Add(tenantRequest.TenantId);
            }

            // Act & Assert
            // Query actual tenant count for the cell
            var tenantQuery = new QueryDefinition("SELECT VALUE COUNT(1) FROM c WHERE c.cellId = @cellId")
                .WithParameter("@cellId", cellId);

            var tenantCountIterator = _tenantsContainer.GetItemQueryIterator<int>(tenantQuery);
            var tenantCountResponse = await tenantCountIterator.ReadNextAsync();
            var actualTenantCount = tenantCountResponse.First();

            Assert.Equal(5, actualTenantCount);
        }

        [Fact]
        public async Task ComplianceRequirements_ShouldRouteToCompliantCells()
        {
            // Arrange
            var createTenantFunction = new CreateTenantFunction(_cosmosClient, _logger, _cacheService);
            var tenantRequest = new CreateTenantRequest
            {
                TenantId = $"compliance-test-{Guid.NewGuid()}",
                Subdomain = $"compliance-{DateTime.UtcNow.Ticks}",
                TenantTier = TenantTier.Dedicated,
                Region = "eastus",
                ComplianceRequirements = new[] { ComplianceRequirement.HIPAA, ComplianceRequirement.SOC2 }
            };

            // Create compliant cell
            var compliantCell = new CellInfo
            {
                CellId = "hipaa-compliant-dedicated-001",
                Region = "eastus",
                CellType = CellType.Dedicated,
                MaxTenants = 1,
                CurrentTenants = 0,
                ComplianceFeatures = new[] { ComplianceRequirement.HIPAA, ComplianceRequirement.SOC2 },
                CreatedAt = DateTime.UtcNow
            };

            await _cellsContainer.CreateItemAsync(compliantCell);

            // Act
            var result = await createTenantFunction.CreateTenantAsync(tenantRequest);

            // Assert
            Assert.NotNull(result);
            Assert.Contains("hipaa", result.CellId.ToLower());
        }

        private async Task CreateTestCell(string region, CellType cellType)
        {
            var cellId = $"test-{cellType.ToString().ToLower()}-{region}-{DateTime.UtcNow.Ticks}";
            var testCell = new CellInfo
            {
                CellId = cellId,
                Region = region,
                CellType = cellType,
                MaxTenants = cellType == CellType.Shared ? 100 : 1,
                CurrentTenants = 0,
                CreatedAt = DateTime.UtcNow
            };

            try
            {
                await _cellsContainer.CreateItemAsync(testCell);
            }
            catch (CosmosException ex) when (ex.StatusCode == HttpStatusCode.Conflict)
            {
                // Cell already exists, ignore
            }
        }

        public void Dispose()
        {
            try
            {
                // Clean up test database
                _database?.DeleteAsync().Wait(5000);
            }
            catch
            {
                // Ignore cleanup errors
            }

            _cosmosClient?.Dispose();
        }
    }

    /// <summary>
    /// Collection definition for integration tests to ensure they run sequentially
    /// </summary>
    [CollectionDefinition("Integration Tests", DisableParallelization = true)]
    public class IntegrationTestCollection
    {
    }
}
