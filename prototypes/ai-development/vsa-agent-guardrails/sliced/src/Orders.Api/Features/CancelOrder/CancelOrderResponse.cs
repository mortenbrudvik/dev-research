namespace Orders.Api.Features.CancelOrder;

public sealed record CancelOrderResponse(Guid Id, string Status, DateTimeOffset? CancelledAt);
