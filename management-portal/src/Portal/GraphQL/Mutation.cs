using HotChocolate;
using HotChocolate.Types;
using HotChocolate.Subscriptions;
using Stamps.ManagementPortal.Models;
using Stamps.ManagementPortal.Services;
using System;
using System.Threading;
using System.Threading.Tasks;

namespace Stamps.ManagementPortal.GraphQL;

public class Mutation
{
    /// <summary>
    /// Create a new Tenant entity.
    /// </summary>
    [GraphQLDescription("Create a new Tenant entity.")]
    public async Task<Tenant> CreateTenantAsync(
        Tenant input,
        [Service] ICosmosDiscoveryService cosmosService,
        [Service] ITopicEventSender eventSender,
        CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(input.DisplayName) || string.IsNullOrWhiteSpace(input.Domain))
            throw new GraphQLException(ErrorBuilder.New().SetMessage("DisplayName and Domain are required.").Build());
        try
        {
            var tenant = await cosmosService.CreateTenantAsync(input);
            await eventSender.SendAsync("TASK_EVENTS", new TaskEvent
            {
                Id = tenant.Id,
                Status = "Created",
                Message = $"Tenant '{tenant.DisplayName}' created.",
                Timestamp = DateTime.UtcNow
            }, cancellationToken);
            return tenant;
        }
        catch (Exception ex)
        {
            throw new GraphQLException(ErrorBuilder.New().SetMessage($"Failed to create tenant: {ex.Message}").Build());
        }
    }

    /// <summary>
    /// Update an existing Tenant entity.
    /// </summary>
    [GraphQLDescription("Update an existing Tenant entity.")]
    public async Task<Tenant> UpdateTenantAsync(
        string id,
        Tenant input,
        [Service] ICosmosDiscoveryService cosmosService,
        [Service] ITopicEventSender eventSender,
        CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(id))
            throw new GraphQLException(ErrorBuilder.New().SetMessage("Tenant id is required.").Build());
        try
        {
            var tenant = await cosmosService.UpdateTenantAsync(id, input);
            await eventSender.SendAsync("TASK_EVENTS", new TaskEvent
            {
                Id = tenant.Id,
                Status = "Updated",
                Message = $"Tenant '{tenant.DisplayName}' updated.",
                Timestamp = DateTime.UtcNow
            }, cancellationToken);
            return tenant;
        }
        catch (Exception ex)
        {
            throw new GraphQLException(ErrorBuilder.New().SetMessage($"Failed to update tenant: {ex.Message}").Build());
        }
    }

    /// <summary>
    /// Delete a Tenant entity by id.
    /// </summary>
    [GraphQLDescription("Delete a Tenant entity by id.")]
    public async Task<bool> DeleteTenantAsync(
        string id,
        [Service] ICosmosDiscoveryService cosmosService,
        [Service] ITopicEventSender eventSender,
        CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(id))
            throw new GraphQLException(ErrorBuilder.New().SetMessage("Tenant id is required.").Build());
        try
        {
            var result = await cosmosService.DeleteTenantAsync(id);
            await eventSender.SendAsync("TASK_EVENTS", new TaskEvent
            {
                Id = id,
                Status = "Deleted",
                Message = $"Tenant '{id}' deleted.",
                Timestamp = DateTime.UtcNow
            }, cancellationToken);
            return result;
        }
        catch (Exception ex)
        {
            throw new GraphQLException(ErrorBuilder.New().SetMessage($"Failed to delete tenant: {ex.Message}").Build());
        }
    }

    /// <summary>
    /// Create a new Cell entity.
    /// </summary>
    [GraphQLDescription("Create a new Cell entity.")]
    public async Task<Cell> CreateCellAsync(
        Cell input,
        [Service] ICosmosDiscoveryService cosmosService,
        [Service] ITopicEventSender eventSender,
        CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(input.Region) || string.IsNullOrWhiteSpace(input.Status))
            throw new GraphQLException(ErrorBuilder.New().SetMessage("Region and Status are required.").Build());
        try
        {
            var cell = await cosmosService.CreateCellAsync(input);
            await eventSender.SendAsync("TASK_EVENTS", new TaskEvent
            {
                Id = cell.Id,
                Status = "Created",
                Message = $"Cell '{cell.Id}' created.",
                Timestamp = DateTime.UtcNow
            }, cancellationToken);
            return cell;
        }
        catch (Exception ex)
        {
            throw new GraphQLException(ErrorBuilder.New().SetMessage($"Failed to create cell: {ex.Message}").Build());
        }
    }

    /// <summary>
    /// Update an existing Cell entity.
    /// </summary>
    [GraphQLDescription("Update an existing Cell entity.")]
    public async Task<Cell> UpdateCellAsync(
        string id,
        Cell input,
        [Service] ICosmosDiscoveryService cosmosService,
        [Service] ITopicEventSender eventSender,
        CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(id))
            throw new GraphQLException(ErrorBuilder.New().SetMessage("Cell id is required.").Build());
        try
        {
            var cell = await cosmosService.UpdateCellAsync(id, input);
            await eventSender.SendAsync("TASK_EVENTS", new TaskEvent
            {
                Id = cell.Id,
                Status = "Updated",
                Message = $"Cell '{cell.Id}' updated.",
                Timestamp = DateTime.UtcNow
            }, cancellationToken);
            return cell;
        }
        catch (Exception ex)
        {
            throw new GraphQLException(ErrorBuilder.New().SetMessage($"Failed to update cell: {ex.Message}").Build());
        }
    }

    /// <summary>
    /// Delete a Cell entity by id.
    /// </summary>
    [GraphQLDescription("Delete a Cell entity by id.")]
    public async Task<bool> DeleteCellAsync(
        string id,
        [Service] ICosmosDiscoveryService cosmosService,
        [Service] ITopicEventSender eventSender,
        CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(id))
            throw new GraphQLException(ErrorBuilder.New().SetMessage("Cell id is required.").Build());
        try
        {
            var result = await cosmosService.DeleteCellAsync(id);
            await eventSender.SendAsync("TASK_EVENTS", new TaskEvent
            {
                Id = id,
                Status = "Deleted",
                Message = $"Cell '{id}' deleted.",
                Timestamp = DateTime.UtcNow
            }, cancellationToken);
            return result;
        }
        catch (Exception ex)
        {
            throw new GraphQLException(ErrorBuilder.New().SetMessage($"Failed to delete cell: {ex.Message}").Build());
        }
    }
}
