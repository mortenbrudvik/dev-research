using Microsoft.EntityFrameworkCore;
using Orders.Application.Common.Interfaces;
using Orders.Domain.Enums;

namespace Orders.Application.Orders.Queries.ListOrders;

public sealed class ListOrdersQueryHandler(IOrdersDbContext db)
{
    public async Task<OrderListDto> Handle(OrderStatus? status, CancellationToken cancellationToken)
    {
        var query = db.Orders.AsNoTracking();
        if (status is not null)
        {
            query = query.Where(o => o.Status == status);
        }

        var orders = await query.OrderByDescending(o => o.CreatedAt).ToListAsync(cancellationToken);

        return new OrderListDto(orders
            .Select(o => new OrderSummaryDto(o.Id, o.CustomerId, o.Status.ToString(), o.CreatedAt, o.Lines.Count, o.Total))
            .ToList());
    }
}
