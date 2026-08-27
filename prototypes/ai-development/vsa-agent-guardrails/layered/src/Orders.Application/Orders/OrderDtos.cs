namespace Orders.Application.Orders;

public sealed record CreateOrderResult(Guid Id, string Status);

public sealed record CancelOrderResult(Guid Id, string Status, DateTimeOffset? CancelledAt);

public sealed record OrderDto(
    Guid Id,
    string CustomerId,
    string Status,
    DateTimeOffset CreatedAt,
    DateTimeOffset? ShippedAt,
    DateTimeOffset? CancelledAt,
    IReadOnlyList<OrderLineDto> Lines,
    decimal Total);

public sealed record OrderLineDto(string Sku, int Quantity, decimal UnitPrice);

public sealed record OrderListDto(IReadOnlyList<OrderSummaryDto> Orders);

public sealed record OrderSummaryDto(Guid Id, string CustomerId, string Status, DateTimeOffset CreatedAt, int LineCount, decimal Total);
