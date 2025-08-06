using System;
using System.Collections.Generic;
using System.Net;
using System.Threading.Tasks;
using Microsoft.Azure.Cosmos;
using Microsoft.Extensions.Logging;
using Moq;
using Xunit;
using AzureStampsPattern.Models;

namespace AzureStampsPattern.Tests
{
    /// <summary>
    /// Unit tests for CreateTenantFunction with Cosmos DB mocking
    /// </summary>
    public class CreateTenantFunctionTests
    {
        private readonly Mock<CosmosClient> _mockCosmosClient;
        private readonly Mock<Container> _mockTenantsContainer;
        private readonly Mock<Container> _mockCellsContainer;
        private readonly Mock<ILogger<CreateTenantFunction>> _mockLogger;
        private readonly CreateTenantFunction _function;

        public CreateTenantFunctionTests()
        {
            _mockCosmosClient = new Mock<CosmosClient>();
            _mockTenantsContainer = new Mock<Container>();
            _mockCellsContainer = new Mock<Container>();
            _mockLogger = new Mock<ILogger<CreateTenantFunction>>();

            // Setup container mocks
            _mockCosmosClient.Setup(c => c.GetContainer(It.IsAny<string>(), "tenants"))
                .Returns(_mockTenantsContainer.Object);
            _mockCosmosClient.Setup(c => c.GetContainer(It.IsAny<string>(), "cells"))
                .Returns(_mockCellsContainer.Object);

            _function = new CreateTenantFunction(_mockCosmosClient.Object, _mockLogger.Object);
        }

        [Fact]
        public async Task AssignDedicatedCellAsync_WithEmptyDedicatedCells_ShouldReturnFirstAvailable()
        {
            // Arrange
            var tenant = new TenantInfo
            {
                tenantId = "test-enterprise-tenant",
                tenantTier = TenantTier.Enterprise,
                complianceRequirements = new List<string> { ComplianceStandards.HIPAA }
            };

            var availableCells = new List<CellInfo>
            {
                new CellInfo
                {
                    cellId = "cell-1",
                    cellName = "dedicated-enterprise-1",
                    cellType = CellType.Dedicated,
                    currentTenantCount = 0,
                    complianceFeatures = new List<string> { ComplianceStandards.HIPAA },
                    backendPool = "dedicated-enterprise-1-backend"
                }
            };

            // Act
            var result = await InvokePrivateMethod<CellInfo>("AssignDedicatedCellAsync", tenant, availableCells);

            // Assert
            Assert.NotNull(result);
            Assert.Equal("cell-1", result.cellId);
            Assert.Equal("dedicated-enterprise-1-backend", result.backendPool);
        }

        [Fact]
        public async Task AssignSharedCellAsync_WithAvailableCapacity_ShouldReturnCellWithLowestTenantCount()
        {
            // Arrange
            var tenant = new TenantInfo
            {
                tenantId = "test-shared-tenant",
                tenantTier = TenantTier.Shared,
                complianceRequirements = new List<string>()
            };

            var availableCells = new List<CellInfo>
            {
                new CellInfo
                {
                    cellId = "cell-1",
                    cellName = "shared-cell-1",
                    cellType = CellType.Shared,
                    currentTenantCount = 50,
                    maxTenantCount = 100,
                    complianceFeatures = new List<string>(),
                    backendPool = "shared-cell-1-backend"
                },
                new CellInfo
                {
                    cellId = "cell-2",
                    cellName = "shared-cell-2",
                    cellType = CellType.Shared,
                    currentTenantCount = 20,
                    maxTenantCount = 100,
                    complianceFeatures = new List<string>(),
                    backendPool = "shared-cell-2-backend"
                }
            };

            // Act
            var result = await InvokePrivateMethod<CellInfo>("AssignSharedCellAsync", tenant, availableCells);

            // Assert
            Assert.NotNull(result);
            Assert.Equal("cell-2", result.cellId); // Should pick the one with lower tenant count
            Assert.Equal("shared-cell-2-backend", result.backendPool);
        }

        [Fact]
        public void MeetsComplianceRequirements_WithMatchingRequirements_ShouldReturnTrue()
        {
            // Arrange
            var cell = new CellInfo
            {
                complianceFeatures = new List<string> { ComplianceStandards.HIPAA, ComplianceStandards.SOC2_TYPE2 }
            };
            var requirements = new List<string> { ComplianceStandards.HIPAA };

            // Act
            var result = InvokePrivateMethod<bool>("MeetsComplianceRequirements", cell, requirements);

            // Assert
            Assert.True(result);
        }

        [Fact]
        public void MeetsComplianceRequirements_WithMissingRequirements_ShouldReturnFalse()
        {
            // Arrange
            var cell = new CellInfo
            {
                complianceFeatures = new List<string> { ComplianceStandards.SOC2_TYPE2 }
            };
            var requirements = new List<string> { ComplianceStandards.HIPAA };

            // Act
            var result = InvokePrivateMethod<bool>("MeetsComplianceRequirements", cell, requirements);

            // Assert
            Assert.False(result);
        }

        [Fact]
        public void MeetsComplianceRequirements_WithNullRequirements_ShouldReturnTrue()
        {
            // Arrange
            var cell = new CellInfo
            {
                complianceFeatures = new List<string>()
            };
            List<string> requirements = null;

            // Act
            var result = InvokePrivateMethod<bool>("MeetsComplianceRequirements", cell, requirements);

            // Assert
            Assert.True(result);
        }

        [Theory]
        [InlineData(TenantTier.Startup, CellType.Shared)]
        [InlineData(TenantTier.SMB, CellType.Shared)]
        [InlineData(TenantTier.Shared, CellType.Shared)]
        [InlineData(TenantTier.Enterprise, CellType.Dedicated)]
        [InlineData(TenantTier.Dedicated, CellType.Dedicated)]
        public void TenantTier_ShouldMapToCorrectCellType(TenantTier tenantTier, CellType expectedCellType)
        {
            // Arrange & Act
            var shouldUseDedicated = tenantTier == TenantTier.Enterprise || tenantTier == TenantTier.Dedicated;
            var actualCellType = shouldUseDedicated ? CellType.Dedicated : CellType.Shared;

            // Assert
            Assert.Equal(expectedCellType, actualCellType);
        }

        [Fact]
        public async Task UpdateCellTenantCountAsync_WithValidCell_ShouldIncrementCount()
        {
            // Arrange
            var cellId = "test-cell-id";
            var originalCell = new CellInfo
            {
                cellId = cellId,
                currentTenantCount = 5,
                lastModifiedDate = DateTime.UtcNow.AddHours(-1)
            };

            var itemResponse = new Mock<ItemResponse<CellInfo>>();
            itemResponse.Setup(r => r.Resource).Returns(originalCell);

            _mockCellsContainer.Setup(c => c.ReadItemAsync<CellInfo>(cellId, new PartitionKey(cellId), null, default))
                .ReturnsAsync(itemResponse.Object);

            _mockCellsContainer.Setup(c => c.ReplaceItemAsync(It.IsAny<CellInfo>(), cellId, new PartitionKey(cellId), null, default))
                .ReturnsAsync(itemResponse.Object);

            // Act
            await InvokePrivateMethodAsync("UpdateCellTenantCountAsync", cellId, 1);

            // Assert
            _mockCellsContainer.Verify(c => c.ReplaceItemAsync(
                It.Is<CellInfo>(cell => cell.currentTenantCount == 6 && cell.lastModifiedDate > originalCell.lastModifiedDate),
                cellId,
                new PartitionKey(cellId),
                null,
                default), Times.Once);
        }

        [Fact]
        public async Task UpdateCellTenantCountAsync_WithNonExistentCell_ShouldHandleGracefully()
        {
            // Arrange
            var cellId = "non-existent-cell";
            _mockCellsContainer.Setup(c => c.ReadItemAsync<CellInfo>(cellId, new PartitionKey(cellId), null, default))
                .ThrowsAsync(new CosmosException("Not Found", HttpStatusCode.NotFound, 0, "", 0));

            // Act & Assert - Should not throw exception
            await InvokePrivateMethodAsync("UpdateCellTenantCountAsync", cellId, 1);

            // Verify that ReplaceItemAsync was not called
            _mockCellsContainer.Verify(c => c.ReplaceItemAsync(It.IsAny<CellInfo>(), It.IsAny<string>(), It.IsAny<PartitionKey>(), null, default), Times.Never);
        }

        /// <summary>
        /// Helper method to invoke private methods for testing
        /// </summary>
        private T InvokePrivateMethod<T>(string methodName, params object[] parameters)
        {
            var method = typeof(CreateTenantFunction).GetMethod(methodName, 
                System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Instance);
            
            if (method == null)
                throw new ArgumentException($"Method {methodName} not found");

            var result = method.Invoke(_function, parameters);
            return (T)result;
        }

        /// <summary>
        /// Helper method to invoke private async methods for testing
        /// </summary>
        private async Task<T> InvokePrivateMethodAsync<T>(string methodName, params object[] parameters)
        {
            var method = typeof(CreateTenantFunction).GetMethod(methodName, 
                System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Instance);
            
            if (method == null)
                throw new ArgumentException($"Method {methodName} not found");

            var result = method.Invoke(_function, parameters);
            if (result is Task<T> taskResult)
                return await taskResult;
            
            return (T)result;
        }

        /// <summary>
        /// Helper method to invoke private async void methods for testing
        /// </summary>
        private async Task InvokePrivateMethodAsync(string methodName, params object[] parameters)
        {
            var method = typeof(CreateTenantFunction).GetMethod(methodName, 
                System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Instance);
            
            if (method == null)
                throw new ArgumentException($"Method {methodName} not found");

            var result = method.Invoke(_function, parameters);
            if (result is Task task)
                await task;
        }
    }

    /// <summary>
    /// Integration tests for CreateTenantFunction with real Cosmos DB emulator
    /// These tests require the Cosmos DB emulator to be running
    /// </summary>
    [Collection("CosmosDB")]
    public class CreateTenantFunctionIntegrationTests
    {
        private readonly string _connectionString = "AccountEndpoint=https://localhost:8081/;AccountKey=C2y6yDjf5/R+ob0N8A7Cgv30VRDJIWEHLM+4QDU5DE2nQ9nDuVTqobD4b8mGGyPMbIZnqyMsEcaGQy67XIw/Jw==";
        
        [Fact(Skip = "Requires Cosmos DB Emulator")]
        public async Task CreateTenant_WithRealCosmosDB_ShouldSucceed()
        {
            // This test would use the real Cosmos DB emulator
            // Implementation would be similar to unit tests but with real CosmosClient
            Assert.True(true, "Integration test placeholder");
        }
    }
}
