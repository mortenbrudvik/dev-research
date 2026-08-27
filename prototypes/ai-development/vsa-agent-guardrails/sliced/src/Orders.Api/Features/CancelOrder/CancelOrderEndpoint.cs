using Orders.Api.Platform.Endpoints;

namespace Orders.Api.Features.CancelOrder;

public sealed class CancelOrderEndpoint : IEndpoint
{
    public void Map(IEndpointRouteBuilder app) =>
        app.MapPost("/orders/{id:guid}/cancel", async (Guid id, CancelOrderHandler handler, CancellationToken cancellationToken) =>
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
}
