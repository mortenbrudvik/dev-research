using Microsoft.EntityFrameworkCore;
using Orders.Application.Common.Interfaces;

namespace Orders.Application.Orders.Queries.GetOrder;

public sealed class GetOrderQueryHandler(IOrdersDbContext db)
{
    public async Task<OrderDto?> Handle(Guid id, CancellationToken cancellationToken)
    {
        var order = await db.Orders.AsNoTracking().SingleOrDefaultAsync(o => o.Id == id, cancellationToken);
        if (order is null)
        {
            return null;
        }
        return new OrderDto(
            order.Id,
            order.CustomerId,
            order.Status.ToString(),
            order.CreatedAt,
            order.ShippedAt,
            order.CancelledAt,
            order.Lines.Select(l => new OrderLineDto(l.Sku, l.Quantity, l.UnitPrice)).ToList(),
            order.Total);
    }
}
