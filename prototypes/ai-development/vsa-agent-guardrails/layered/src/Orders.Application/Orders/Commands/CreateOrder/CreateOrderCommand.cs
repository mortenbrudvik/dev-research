namespace Orders.Application.Orders.Commands.CreateOrder;

public sealed record CreateOrderCommand(string CustomerId, IReadOnlyList<CreateOrderLine> Lines);

public sealed record CreateOrderLine(string Sku, int Quantity, decimal UnitPrice);
