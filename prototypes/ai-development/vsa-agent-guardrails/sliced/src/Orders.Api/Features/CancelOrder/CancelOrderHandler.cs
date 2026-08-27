using Microsoft.EntityFrameworkCore;
using Orders.Api.Domain;
using Orders.Api.Platform.Persistence;

namespace Orders.Api.Features.CancelOrder;

public sealed class CancelOrderHandler(OrdersDbContext db, TimeProvider clock)
{
    public sealed record Result(CancelOrderResponse? Response, string? Conflict, bool NotFound);

    public async Task<Result> Handle(Guid id, CancellationToken cancellationToken)
    {
        var order = await db.Orders.SingleOrDefaultAsync(o => o.Id == id, cancellationToken);
        if (order is null)
        {
            return new Result(null, null, NotFound: true);
        }
        if (!CancellationPolicy.CanCancel(order))
        {
            return new Result(null, $"Order {id} cannot be cancelled because it is {order.Status}.", NotFound: false);
        }

        order.Cancel(clock.GetUtcNow());
        await db.SaveChangesAsync(cancellationToken);

        return new Result(new CancelOrderResponse(order.Id, order.Status.ToString(), order.CancelledAt), null, NotFound: false);
    }
}
