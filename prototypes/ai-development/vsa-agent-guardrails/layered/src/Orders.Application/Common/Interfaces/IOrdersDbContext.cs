using Microsoft.EntityFrameworkCore;
using Orders.Domain.Entities;

namespace Orders.Application.Common.Interfaces;

public interface IOrdersDbContext
{
    DbSet<Order> Orders { get; }
    Task<int> SaveChangesAsync(CancellationToken cancellationToken);
}
