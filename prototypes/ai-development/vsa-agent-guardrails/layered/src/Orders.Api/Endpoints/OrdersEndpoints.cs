using Orders.Api.Common;
using Orders.Application.Orders.Commands.CancelOrder;
using Orders.Application.Orders.Commands.CreateOrder;
using Orders.Application.Orders.Queries.GetOrder;
using Orders.Application.Orders.Queries.ListOrders;
using Orders.Domain.Enums;

namespace Orders.Api.Endpoints;

public static class OrdersEndpoints
{
    public static IEndpointRouteBuilder MapOrdersEndpoints(this IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("/orders");

        group.MapPost("/", async (CreateOrderCommand command, CreateOrderCommandHandler handler, CancellationToken cancellationToken) =>
            {
                var result = await handler.Handle(command, cancellationToken);
                return Results.Created($"/orders/{result.Id}", result);
            })
            .AddEndpointFilter<ValidationFilter<CreateOrderCommand>>();

        group.MapGet("/{id:guid}", async (Guid id, GetOrderQueryHandler handler, CancellationToken cancellationToken) =>
        {
            var order = await handler.Handle(id, cancellationToken);
            return order is null ? Results.NotFound() : Results.Ok(order);
        });

        group.MapGet("/", async (string? status, ListOrdersQueryHandler handler, CancellationToken cancellationToken) =>
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

        group.MapPost("/{id:guid}/cancel", async (Guid id, CancelOrderCommandHandler handler, CancellationToken cancellationToken) =>
        {
            var result = await handler.Handle(id, cancellationToken);
            if (result.NotFound)
            {
                return Results.NotFound();
            }
            if (result.Conflict is not null)
            {
                return Results.Problem(statusCode: StatusCodes.Status409Conflict, title: "Business rule violated", detail: result.Conflict);
            }
            return Results.Ok(result.Response);
        });

        return app;
    }
}
