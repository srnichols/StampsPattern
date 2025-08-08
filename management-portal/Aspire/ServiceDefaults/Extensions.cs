using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Diagnostics.HealthChecks;
using Microsoft.Extensions.Hosting;
using OpenTelemetry.Metrics;
using OpenTelemetry.Resources;
using OpenTelemetry.Trace;

namespace ServiceDefaults;

public static class Extensions
{
    public static IHostApplicationBuilder AddServiceDefaults(this IHostApplicationBuilder builder, string serviceName)
    {
        var resourceBuilder = ResourceBuilder.CreateDefault()
            .AddService(serviceName: serviceName);

        var otlpEndpoint = builder.Configuration["OTLP_ENDPOINT"];
        builder.Services.AddOpenTelemetry()
            .ConfigureResource(rb => rb.AddService(serviceName))
            .WithMetrics(m =>
            {
                m.AddAspNetCoreInstrumentation();
                m.AddRuntimeInstrumentation();
                if (!string.IsNullOrWhiteSpace(otlpEndpoint))
                {
                    m.AddOtlpExporter(o => o.Endpoint = new Uri(otlpEndpoint));
                }
            })
            .WithTracing(t =>
            {
                t.AddAspNetCoreInstrumentation();
                if (!string.IsNullOrWhiteSpace(otlpEndpoint))
                {
                    t.AddOtlpExporter(o => o.Endpoint = new Uri(otlpEndpoint));
                }
            });

        builder.Services.AddHealthChecks().AddCheck("self", () => HealthCheckResult.Healthy());
        return builder;
    }
}
