namespace Orders.Api.Features.ListOrders;

public sealed record ListOrdersResponse(IReadOnlyList<OrderSummary> Orders);

public sealed record OrderSummary(Guid Id, string CustomerId, string Status, DateTimeOffset CreatedAt, int LineCount, decimal Total);
