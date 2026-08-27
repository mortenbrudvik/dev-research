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
                // Match by name only: Enum.TryParse would also accept "1" (Shipped) or "99" (an undefined value).
                var name = Enum.GetNames<OrderStatus>().FirstOrDefault(n => n.Equals(status, StringComparison.OrdinalIgnoreCase));
                if (name is null)
                {
                    return Results.ValidationProblem(new Dictionary<string, string[]>
                    {
                        ["status"] = [$"'{status}' is not one of {string.Join(", ", Enum.GetNames<OrderStatus>())}."],
                    });
                }
                filter = Enum.Parse<OrderStatus>(name);
            }
            return Results.Ok(await handler.Handle(filter, cancellationToken));
        });
}
