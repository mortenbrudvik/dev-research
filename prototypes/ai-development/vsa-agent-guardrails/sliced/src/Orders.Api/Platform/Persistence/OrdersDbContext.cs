using Microsoft.EntityFrameworkCore;
using Orders.Api.Domain;

namespace Orders.Api.Platform.Persistence;

public sealed class OrdersDbContext(DbContextOptions<OrdersDbContext> options) : DbContext(options)
{
    public DbSet<Order> Orders => Set<Order>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<Order>(order =>
        {
            order.HasKey(o => o.Id);
            order.Property(o => o.CustomerId).IsRequired().HasMaxLength(100);
            order.Property(o => o.Status).HasConversion<string>().HasMaxLength(20);
            order.Ignore(o => o.Total);
            order.OwnsMany(o => o.Lines, line =>
            {
                line.ToTable("OrderLines");
                line.WithOwner().HasForeignKey("OrderId");
                line.Property<int>("Id");
                line.HasKey("Id");
                line.Property(l => l.Sku).IsRequired().HasMaxLength(50);
                line.Ignore(l => l.Total);
            });
        });
    }
}
