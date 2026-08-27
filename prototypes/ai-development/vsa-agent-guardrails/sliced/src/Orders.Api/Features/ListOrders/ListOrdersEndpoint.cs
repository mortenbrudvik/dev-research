using Orders.Api.Domain;
using Orders.Api.Platform.Endpoints;

namespace Orders.Api.Features.ListOrders;

public sealed class ListOrdersEndpoint : IEndpoint
{
    public void Map(IEndpointRouteBuilder app) =>
        app.MapGet("/orders", async (string? status, ListOrdersHandler handler, CancellationToken cancellationToken) =>
        {
            OrderStatus? filter = null;
            if (status is not null)
            {
                if (!Enum.TryParse<OrderStatus>(status, ignoreCase: true, out var parsed))
                {
                    return Results.ValidationProblem(new Dictionary<string, string[]>
                    {
                        ["status"] = [$"'{status}' is not one of {string.Join(", ", Enum.GetNames<OrderStatus>())}."],
                    });
                }
                filter = parsed;
            }
            return Results.Ok(await handler.Handle(filter, cancellationToken));
        });
}
