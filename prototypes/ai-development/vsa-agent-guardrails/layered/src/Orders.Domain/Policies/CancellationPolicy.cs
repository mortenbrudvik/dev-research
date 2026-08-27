using Orders.Domain.Entities;
using Orders.Domain.Enums;

namespace Orders.Domain.Policies;

public static class CancellationPolicy
{
    /// <summary>Only already-cancelled orders cannot be cancelled. Shipped orders can (for now).</summary>
    public static bool CanCancel(Order order) => order.Status != OrderStatus.Cancelled;
}
