using Orders.Api.Platform.Endpoints;
using Orders.Api.Platform.Http;

namespace Orders.Api.Features.CreateOrder;

public sealed class CreateOrderEndpoint : IEndpoint
{
    public void Map(IEndpointRouteBuilder app) =>
        app.MapPost("/orders", async (CreateOrderRequest request, CreateOrderHandler handler, CancellationToken cancellationToken) =>
            {
                var response = await handler.Handle(request, cancellationToken);
                return Results.Created($"/orders/{response.Id}", response);
            })
            .AddEndpointFilter<ValidationFilter<CreateOrderRequest>>();
}
