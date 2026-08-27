namespace Orders.Api.Platform.Endpoints;

/// <summary>Each slice exposes one endpoint class that maps its route(s).</summary>
public interface IEndpoint
{
    void Map(IEndpointRouteBuilder app);
}

public static class EndpointExtensions
{
    private const string FeaturesNamespace = "Orders.Api.Features";

    /// <summary>Registers every *Handler class under Features as scoped, so a slice never touches Program.cs.</summary>
    public static IServiceCollection AddFeatureHandlers(this IServiceCollection services)
    {
        var handlers = typeof(EndpointExtensions).Assembly.GetTypes()
            .Where(t => t.IsClass && !t.IsAbstract
                        && t.Name.EndsWith("Handler", StringComparison.Ordinal)
                        && t.Namespace?.StartsWith(FeaturesNamespace, StringComparison.Ordinal) == true);
        foreach (var handler in handlers)
        {
            services.AddScoped(handler);
        }
        return services;
    }

    public static IEndpointRouteBuilder MapEndpoints(this IEndpointRouteBuilder app)
    {
        var endpoints = typeof(EndpointExtensions).Assembly.GetTypes()
            .Where(t => t.IsClass && !t.IsAbstract && typeof(IEndpoint).IsAssignableFrom(t))
            .Select(t => (IEndpoint)Activator.CreateInstance(t)!);
        foreach (var endpoint in endpoints)
        {
            endpoint.Map(app);
        }
        return app;
    }
}
