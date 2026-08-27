using Microsoft.EntityFrameworkCore;
using Orders.Api.Platform.Persistence;

namespace Orders.Api.Features.GetOrder;

public sealed class GetOrderHandler(OrdersDbContext db)
{
    public async Task<GetOrderResponse?> Handle(Guid id, CancellationToken cancellationToken)
    {
        var order = await db.Orders.AsNoTracking().SingleOrDefaultAsync(o => o.Id == id, cancellationToken);
        if (order is null)
        {
            return null;
        }
        return new GetOrderResponse(
            order.Id,
            order.CustomerId,
            order.Status.ToString(),
            order.CreatedAt,
            order.ShippedAt,
            order.CancelledAt,
            order.Lines.Select(l => new GetOrderLine(l.Sku, l.Quantity, l.UnitPrice)).ToList(),
            order.Total);
    }
}
