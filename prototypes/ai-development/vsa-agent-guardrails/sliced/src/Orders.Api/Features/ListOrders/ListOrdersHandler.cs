using Microsoft.EntityFrameworkCore;
using Orders.Api.Domain;
using Orders.Api.Platform.Persistence;

namespace Orders.Api.Features.ListOrders;

public sealed class ListOrdersHandler(OrdersDbContext db)
{
    public async Task<ListOrdersResponse> Handle(OrderStatus? status, CancellationToken cancellationToken)
    {
        var query = db.Orders.AsNoTracking();
        if (status is not null)
        {
            query = query.Where(o => o.Status == status);
        }

        var orders = await query.OrderByDescending(o => o.CreatedAt).ToListAsync(cancellationToken);

        return new ListOrdersResponse(orders
            .Select(o => new OrderSummary(o.Id, o.CustomerId, o.Status.ToString(), o.CreatedAt, o.Lines.Count, o.Total))
            .ToList());
    }
}
