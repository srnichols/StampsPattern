# Testing — Instructions

applyTo: "AzureArchitecture/Tests/**/*.cs"

## Test Framework

- **xUnit** for test framework
- **Moq** for mocking
- Tests are co-located at `AzureArchitecture/Tests/` but excluded from the Functions app build via `<Compile Remove="Tests/**/*.cs" />`
- Test files follow the `{ClassName}Tests.cs` naming convention

## Mocking Patterns

### Cosmos DB

- Mock `CosmosClient` and individual `Container` instances
- Use `_mockCosmosClient.Setup(c => c.GetContainer(It.IsAny<string>(), "containerName")).Returns(mockContainer.Object)`
- Mock `FeedIterator<T>` for query results — setup `HasMoreResults` and `ReadNextAsync`
- Mock `ItemResponse<T>` for point reads

### Logger

- Mock `ILogger<T>` — do not verify log calls unless testing specific log behavior

### HTTP Request/Response

- Use Azure Functions Worker test utilities for `HttpRequestData` and `HttpResponseData`
- Test both success paths and error/validation paths

## Test Structure

```csharp
public class FunctionNameTests
{
    private readonly Mock<CosmosClient> _mockCosmosClient;
    private readonly Mock<Container> _mockContainer;
    private readonly Mock<ILogger<FunctionName>> _mockLogger;
    private readonly FunctionName _function;

    public FunctionNameTests()
    {
        // Setup mocks in constructor
        _mockCosmosClient = new Mock<CosmosClient>();
        _mockContainer = new Mock<Container>();
        _mockLogger = new Mock<ILogger<FunctionName>>();
        
        _mockCosmosClient.Setup(c => c.GetContainer(It.IsAny<string>(), "tenants"))
            .Returns(_mockContainer.Object);
        
        _function = new FunctionName(_mockCosmosClient.Object, _mockLogger.Object);
    }

    [Fact]
    public async Task MethodName_Scenario_ExpectedBehavior()
    {
        // Arrange
        // Act
        // Assert
    }
}
```

## Test Categories

- **Unit tests**: Test individual function logic, CELL assignment, validation, migration eligibility
- **Integration tests**: `CosmosDbIntegrationTests.cs` for Cosmos DB connectivity (require emulator or live instance)
- Name tests descriptively: `MethodName_Scenario_ExpectedBehavior` pattern

## Key Test Scenarios

Ensure coverage for:

1. **Tenant CRUD**: Create with valid/invalid data, missing required fields, duplicate tenantId
2. **CELL assignment**: Shared cell selection (lowest tenant count), dedicated cell for enterprise, compliance matching, capacity limits
3. **Tenant migration**: Shared → Dedicated migration, eligibility validation, status transitions
4. **Caching**: Cache hits/misses, cache invalidation, graceful degradation on cache failure
5. **Authentication**: Valid JWT, expired tokens, missing tokens, invalid audience
6. **Capacity monitoring**: Region reports, auto-provisioning thresholds
7. **HTTP responses**: Correct status codes for each scenario (201, 400, 404, 500)

## Private Method Testing

- Use reflection helper to test private methods when direct testing isn't feasible:

```csharp
private async Task<T> InvokePrivateMethod<T>(string methodName, params object[] args)
```

## Assertions

- Use `Assert.NotNull()`, `Assert.Equal()`, `Assert.True()` from xUnit
- For collections: `Assert.Contains()`, `Assert.Empty()`, `Assert.Single()`
- Verify mock calls: `_mockContainer.Verify(c => c.CreateItemAsync(...), Times.Once)`
