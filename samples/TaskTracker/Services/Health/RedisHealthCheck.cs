using System;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Diagnostics.HealthChecks;
using StackExchange.Redis;

namespace TaskTracker.Blazor.Services.Health;

public sealed class RedisHealthCheck : IHealthCheck
{
    private readonly IConfiguration _configuration;
    private readonly IConnectionMultiplexer? _connection;

    public RedisHealthCheck(IConfiguration configuration, IServiceProvider services)
    {
        _configuration = configuration;
        // Resolve optional IConnectionMultiplexer if present (when Redis is configured)
        _connection = services.GetService(typeof(IConnectionMultiplexer)) as IConnectionMultiplexer;
    }

    public async Task<HealthCheckResult> CheckHealthAsync(HealthCheckContext context, CancellationToken cancellationToken = default)
    {
        var redisConnStr = _configuration.GetConnectionString("Redis");
        if (string.IsNullOrWhiteSpace(redisConnStr))
        {
            // Not configured: treat as Healthy for liveness but Degraded for readiness
            return context.Registration.FailureStatus == HealthStatus.Degraded
                ? HealthCheckResult.Degraded("Redis not configured.")
                : HealthCheckResult.Healthy("Redis not configured.");
        }

        try
        {
            if (_connection == null || !_connection.IsConnected)
            {
                // Try to create a transient connection for the check
                using var mux = await ConnectionMultiplexer.ConnectAsync(redisConnStr);
                var pong = await mux.GetDatabase().PingAsync();
                return HealthCheckResult.Healthy($"Redis reachable ({pong.TotalMilliseconds:0} ms).");
            }
            else
            {
                var pong = await _connection.GetDatabase().PingAsync();
                return HealthCheckResult.Healthy($"Redis reachable ({pong.TotalMilliseconds:0} ms).");
            }
        }
        catch (Exception ex)
        {
            return HealthCheckResult.Unhealthy("Redis unreachable.", ex);
        }
    }
}
