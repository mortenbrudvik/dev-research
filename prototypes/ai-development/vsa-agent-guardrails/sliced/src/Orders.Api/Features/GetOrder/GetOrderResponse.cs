namespace Orders.Api.Features.GetOrder;

public sealed record GetOrderResponse(
    Guid Id,
    string CustomerId,
    string Status,
    DateTimeOffset CreatedAt,
    DateTimeOffset? ShippedAt,
    DateTimeOffset? CancelledAt,
    IReadOnlyList<GetOrderLine> Lines,
    decimal Total);

public sealed record GetOrderLine(string Sku, int Quantity, decimal UnitPrice);
