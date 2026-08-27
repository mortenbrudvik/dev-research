using Orders.Api.Platform.Endpoints;

namespace Orders.Api.Features.GetOrder;

public sealed class GetOrderEndpoint : IEndpoint
{
    public void Map(IEndpointRouteBuilder app) =>
        app.MapGet("/orders/{id:guid}", async (Guid id, GetOrderHandler handler, CancellationToken cancellationToken) =>
        {
            var response = await handler.Handle(id, cancellationToken);
            return response is null ? Results.NotFound() : Results.Ok(response);
        });
}
