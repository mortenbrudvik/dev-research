namespace Orders.Api.Domain;

public sealed class Order
{
    private Order() { }

    public Guid Id { get; private set; }
    public string CustomerId { get; private set; } = "";
    public OrderStatus Status { get; private set; }
    public DateTimeOffset CreatedAt { get; private set; }
    public DateTimeOffset? ShippedAt { get; private set; }
    public DateTimeOffset? CancelledAt { get; private set; }
    public List<OrderLine> Lines { get; private set; } = new();

    public decimal Total => Lines.Sum(l => l.Total);

    public static Order Create(string customerId, IEnumerable<OrderLine> lines, DateTimeOffset now)
    {
        var order = new Order
        {
            Id = Guid.NewGuid(),
            CustomerId = customerId,
            Status = OrderStatus.Pending,
            CreatedAt = now,
        };
        order.Lines.AddRange(lines);
        if (order.Lines.Count == 0)
        {
            throw new DomainException("An order needs at least one line.");
        }
        return order;
    }

    public void Ship(DateTimeOffset now)
    {
        if (Status != OrderStatus.Pending)
        {
            throw new DomainException($"Order {Id} cannot be shipped because it is {Status}.");
        }
        Status = OrderStatus.Shipped;
        ShippedAt = now;
    }

    public void Cancel(DateTimeOffset now)
    {
        if (Status == OrderStatus.Cancelled)
        {
            throw new DomainException($"Order {Id} is already cancelled.");
        }
        Status = OrderStatus.Cancelled;
        CancelledAt = now;
    }
}
