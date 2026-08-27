namespace Orders.Api.Features.CreateOrder;

public sealed record CreateOrderRequest(string CustomerId, IReadOnlyList<CreateOrderLine> Lines);

public sealed record CreateOrderLine(string Sku, int Quantity, decimal UnitPrice);
