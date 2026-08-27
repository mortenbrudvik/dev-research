using Orders.Api.Domain;
using Orders.Api.Platform.Persistence;

namespace Orders.Api.Features.CreateOrder;

public sealed class CreateOrderHandler(OrdersDbContext db, TimeProvider clock)
{
    public async Task<CreateOrderResponse> Handle(CreateOrderRequest request, CancellationToken cancellationToken)
    {
        var lines = request.Lines.Select(l => new OrderLine(l.Sku, l.Quantity, l.UnitPrice));
        var order = Order.Create(request.CustomerId, lines, clock.GetUtcNow());

        db.Orders.Add(order);
        await db.SaveChangesAsync(cancellationToken);

        return new CreateOrderResponse(order.Id, order.Status.ToString());
    }
}
